#!/usr/bin/env python3
"""winstring_patch.py — applique les remplacements "Windows 11" -> "Windows 12" (et
variantes UTF-16LE) sur les fichiers listés dans un inventaire produit par
winstring_scan.py, EN PRÉSERVANT LA LONGUEUR EXACTE de chaque chaîne.

Labo expérimental "aggressive" (demande explicite de FuraxDev, 01/10/2026).

Principe du remplacement "same-length" : "Windows 11" (10 caractères) -> "Windows 12"
(10 caractères). Même longueur en ASCII ET en UTF-16LE. C'est ce qui rend ce patch
raisonnablement sûr d'un point de vue STRUCTUREL (pas de décalage d'offsets, pas de
tables de longueur à recalculer dans les ressources PE/.mui) — mais ça n'empêche PAS
l'invalidation d'une signature Authenticode : tout octet modifié dans un fichier signé
invalide sa signature. C'est attendu et documenté, pas une erreur.

Ce script ne touche QUE les fichiers listés dans l'inventaire (donc jamais les fichiers
de la chaîne de boot, déjà exclus par winstring_scan.py en amont). Double vérification
de l'exclusion boot ici aussi, par sécurité (defense in depth).

Chaque fichier modifié est D'ABORD sauvegardé (copie bit-à-bit à côté, suffixe
`.pre-aggressive-patch`) avant toute écriture, pour permettre un rollback fichier par
fichier sans dépendre uniquement du commit/non-commit du montage WIM.

Pour les ruches de registre (catégorie "registry"), CE SCRIPT NE LES TOUCHE PAS : le
format de ruche a sa propre structure (checksums, cellules) qu'un patch d'octets brut
pourrait corrompre plus subtilement qu'un simple fichier texte/PE à longueur fixe. Les
valeurs de registre identifiées sont à traiter séparément via hivex_set_value.py (déjà
le mécanisme utilisé partout ailleurs dans ce projet), et sont simplement listées à part
dans le rapport comme "non patchées par ce script".

Usage :
  python3 winstring_patch.py <inventaire.jsonl> <racine_montée> \
    --log <patch-log.jsonl> --report <rapport.txt> [--apply] [--categories pe mui text other]

Sans --apply : dry-run complet (affiche ce qui SERAIT fait, ne modifie rien).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys

REPLACEMENTS = [
    ("Windows 11", "Windows 12"),
    ("Windows11", "Windows12"),
]

BOOT_CRITICAL_SUBSTRINGS = [
    "/boot/", "/efi/", "bootmgr", "bootmgfw.efi", "bootx64.efi",
    "winload.efi", "winload.exe", "winresume.efi", "winresume.exe",
    "/windows/boot/",
]


def is_boot_critical(rel_path_lower: str) -> bool:
    return any(s in rel_path_lower for s in BOOT_CRITICAL_SUBSTRINGS)


def sha256_of(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def patch_bytes(data: bytes):
    """Remplace toutes les occurrences (ASCII + UTF-16LE) à longueur égale. Retourne
    (nouvelles_données, nombre_remplacements)."""
    count = 0
    for old, new in REPLACEMENTS:
        assert len(old) == len(new), f"longueur différente interdite : {old!r} / {new!r}"
        old_ascii = old.encode("ascii")
        new_ascii = new.encode("ascii")
        n = data.count(old_ascii)
        if n:
            data = data.replace(old_ascii, new_ascii)
            count += n

        old_u16 = old.encode("utf-16-le")
        new_u16 = new.encode("utf-16-le")
        n = data.count(old_u16)
        if n:
            data = data.replace(old_u16, new_u16)
            count += n
    return data, count


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inventory", help="fichier JSONL produit par winstring_scan.py")
    ap.add_argument("root", help="racine montée (même valeur que pour le scan)")
    ap.add_argument("--log", required=True, help="journal JSONL des modifications appliquées")
    ap.add_argument("--report", required=True, help="rapport texte lisible")
    ap.add_argument("--apply", action="store_true", help="applique réellement (sinon dry-run)")
    ap.add_argument("--categories", nargs="*", default=["pe", "mui", "text", "other"],
                     help="catégories à patcher (registry toujours exclu, voir docstring)")
    args = ap.parse_args()

    root = os.path.abspath(args.root)
    allowed_categories = set(args.categories) - {"registry"}

    patched = []
    skipped_boot = []
    skipped_category = []
    skipped_no_change = []
    skipped_registry = []
    errors = []

    with open(args.inventory, encoding="utf-8") as f, open(args.log, "w", encoding="utf-8") as logf:
        for line in f:
            rec = json.loads(line)
            rel_path = rec["path"]
            rel_lower = ("/" + rel_path.lower().replace("\\", "/"))
            full_path = os.path.join(root, rel_path)

            if is_boot_critical(rel_lower):
                skipped_boot.append(rel_path)
                continue

            if rec["category"] == "registry":
                skipped_registry.append(rel_path)
                continue

            if rec["category"] not in allowed_categories:
                skipped_category.append(rel_path)
                continue

            try:
                with open(full_path, "rb") as fh:
                    original = fh.read()
            except OSError as e:
                errors.append({"path": rel_path, "error": str(e)})
                continue

            new_data, n_replacements = patch_bytes(original)
            if n_replacements == 0:
                skipped_no_change.append(rel_path)
                continue

            if len(new_data) != len(original):
                errors.append({"path": rel_path, "error": "longueur modifiée, refusé par sécurité"})
                continue

            before_hash = hashlib.sha256(original).hexdigest()
            after_hash = hashlib.sha256(new_data).hexdigest()

            entry = {
                "path": rel_path,
                "category": rec["category"],
                "authenticode_signature_before": rec.get("authenticode_signature"),
                "replacements_applied": n_replacements,
                "sha256_before": before_hash,
                "sha256_after": after_hash,
                "applied": bool(args.apply),
            }

            if args.apply:
                backup_path = full_path + ".pre-aggressive-patch"
                if not os.path.exists(backup_path):
                    shutil.copy2(full_path, backup_path)
                with open(full_path, "r+b") as fh:
                    fh.write(new_data)
                entry["backup"] = os.path.relpath(backup_path, root)

            patched.append(entry)
            logf.write(json.dumps(entry, ensure_ascii=False) + "\n")

    with open(args.report, "w", encoding="utf-8") as r:
        r.write("=" * 70 + "\n")
        r.write(f"Furax Windows 12 Beta — Patch \"Windows 11\"->\"Windows 12\" "
                f"({'APPLIQUÉ' if args.apply else 'DRY-RUN, rien modifié'})\n")
        r.write("=" * 70 + "\n\n")
        r.write(f"Fichiers patchés                         : {len(patched)}\n")
        r.write(f"Fichiers exclus (chaîne de boot)          : {len(skipped_boot)}\n")
        r.write(f"Fichiers registre (NON patchés ici)        : {len(skipped_registry)}\n")
        r.write(f"Fichiers exclus (catégorie non demandée)  : {len(skipped_category)}\n")
        r.write(f"Fichiers sans changement après relecture  : {len(skipped_no_change)}\n")
        r.write(f"Erreurs                                    : {len(errors)}\n\n")

        total_sig_present = sum(1 for p in patched if p["authenticode_signature_before"] == "present")
        r.write(f"Parmi les fichiers patchés, signature Authenticode PRÉSENTE avant patch "
                f"(invalidée par la modification) : {total_sig_present}\n\n")

        if skipped_boot:
            r.write("--- Fichiers chaîne de boot, volontairement intacts (aucune méthode de restauration) ---\n")
            for p in skipped_boot[:50]:
                r.write(f"  {p}\n")
            if len(skipped_boot) > 50:
                r.write(f"  ... et {len(skipped_boot) - 50} autre(s)\n")
            r.write("\n")

        if skipped_registry:
            r.write("--- Fichiers de registre détectés, À TRAITER SÉPARÉMENT via hivex (pas par ce script) ---\n")
            for p in skipped_registry[:50]:
                r.write(f"  {p}\n")
            if len(skipped_registry) > 50:
                r.write(f"  ... et {len(skipped_registry) - 50} autre(s)\n")
            r.write("\n")

        if errors:
            r.write("--- Erreurs ---\n")
            for e in errors[:50]:
                r.write(f"  {e['path']} : {e['error']}\n")
            r.write("\n")

        r.write("--- Détail des fichiers patchés (triés par catégorie) ---\n")
        for cat in ("pe", "mui", "text", "other"):
            cat_entries = [p for p in patched if p["category"] == cat]
            if not cat_entries:
                continue
            r.write(f"\n[{cat}] ({len(cat_entries)} fichier(s))\n")
            for p in cat_entries[:200]:
                sig_note = " [SIGNATURE INVALIDÉE]" if p["authenticode_signature_before"] == "present" else ""
                r.write(f"  {p['path']} ({p['replacements_applied']} remplacement(s)){sig_note}\n")
            if len(cat_entries) > 200:
                r.write(f"  ... et {len(cat_entries) - 200} autre(s)\n")

    print(f"{'Appliqué' if args.apply else 'Dry-run'} : {len(patched)} fichier(s) patché(s), "
          f"{len(skipped_boot)} exclus (boot), {len(skipped_registry)} registre (séparé), "
          f"{len(errors)} erreur(s).", file=sys.stderr)


if __name__ == "__main__":
    main()
