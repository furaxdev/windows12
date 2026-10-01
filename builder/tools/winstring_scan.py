#!/usr/bin/env python3
"""winstring_scan.py — inventaire exhaustif des occurrences de "Windows 11" (et variantes)
dans une arborescence Windows montée (WIM monté en lecture seule via wimlib-imagex mount).

Labo expérimental "aggressive" (demande explicite de FuraxDev, 01/10/2026) : AVANT toute
modification, on scanne et on classe. Rien n'est modifié par ce script — lecture seule.

Recherche, en ASCII/UTF-8 ET en UTF-16LE (encodage natif de la plupart des chaînes Windows
internes : ressources PE, .mui, registre) :
  - "Windows 11"
  - "Windows 11 Pro" / "Home" / "Enterprise" / "Education" / "Pro N" / "Home N" etc. (couvert
    par la recherche de "Windows 11" tout court : ces variantes la contiennent)
  - "Windows11" (sans espace, rare mais vérifié)

Classification de chaque fichier touché :
  - registry   : ruches de registre (SOFTWARE, SYSTEM, SAM, SECURITY, DEFAULT, COMPONENTS,
                 NTUSER.DAT, BCD-Template, ...)
  - mui        : fichiers de ressources de langue (.mui)
  - pe         : binaires PE (.exe/.dll/.sys/.ocx/.efi, détecté aussi par en-tête MZ réel)
  - text       : texte/XML/manifest/inf/ini/json/reg/ps1/cmd
  - other      : tout le reste

Pour les PE, détecte (via pefile) si une signature Authenticode est PRÉSENTE (répertoire de
données IMAGE_DIRECTORY_ENTRY_SECURITY non vide) — pas une validation cryptographique, juste
la présence, ce qui suffit pour avertir : "modifier ce fichier invalide très probablement
cette signature".

Usage :
  python3 winstring_scan.py <racine_montée> --out <inventaire.jsonl> --report <rapport.txt>
    [--exclude-boot-critical] [--max-file-mb N] [--roots sous/chemin1 sous/chemin2 ...]
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time

try:
    import pefile  # type: ignore
except ImportError:
    pefile = None

PATTERNS_TEXT = ["Windows 11", "Windows11"]

# Fichiers/chemins de la chaîne de boot : JAMAIS touchés, aucune méthode de restauration
# disponible dans cet environnement si ça casse (pas de boot réel testable). Exclusion dure,
# conservée même en mode "aggressive" — voir docs/FEATURES.md.
BOOT_CRITICAL_SUBSTRINGS = [
    "/boot/",
    "/efi/",
    "bootmgr",
    "bootmgfw.efi",
    "bootx64.efi",
    "winload.efi",
    "winload.exe",
    "winresume.efi",
    "winresume.exe",
    "/windows/boot/",
]

REGISTRY_HIVE_NAMES = {
    "software", "system", "sam", "security", "default", "components",
    "ntuser.dat", "usrclass.dat", "bcd", "bcd-template", "drivers", "elam",
}


def is_boot_critical(rel_path_lower: str) -> bool:
    return any(s in rel_path_lower for s in BOOT_CRITICAL_SUBSTRINGS)


def classify(rel_path: str, head_bytes: bytes) -> str:
    lower = rel_path.lower()
    base = os.path.basename(lower)
    stem, ext = os.path.splitext(base)
    if base in REGISTRY_HIVE_NAMES or stem in REGISTRY_HIVE_NAMES:
        return "registry"
    if ext == ".mui":
        return "mui"
    if ext in (".exe", ".dll", ".sys", ".ocx", ".efi", ".drv", ".cpl", ".mun"):
        return "pe"
    if head_bytes[:2] == b"MZ":
        return "pe"
    if ext in (".xml", ".manifest", ".inf", ".ini", ".json", ".reg", ".ps1", ".cmd", ".bat",
               ".txt", ".config", ".admx", ".adml", ".vbs", ".wxs"):
        return "text"
    return "other"


def has_authenticode_signature(full_path: str) -> str:
    """Retourne 'present' / 'absent' / 'unknown' (pefile indisponible ou fichier non-PE)."""
    if pefile is None:
        return "unknown"
    try:
        pe = pefile.PE(full_path, fast_load=True)
        pe.parse_data_directories(directories=[pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_SECURITY"]])
        dd = pe.OPTIONAL_HEADER.DATA_DIRECTORY[pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_SECURITY"]]
        pe.close()
        return "present" if dd.VirtualAddress and dd.Size else "absent"
    except Exception:
        return "unknown"


def find_occurrences(data: bytes):
    """Cherche toutes les occurrences ASCII/UTF-8 ET UTF-16LE de chaque motif. Retourne une
    liste de (offset, encodage, motif, contexte_imprimable)."""
    occurrences = []
    for pattern in PATTERNS_TEXT:
        ascii_bytes = pattern.encode("ascii")
        start = 0
        while True:
            idx = data.find(ascii_bytes, start)
            if idx == -1:
                break
            ctx = data[max(0, idx - 16):idx + len(ascii_bytes) + 16]
            occurrences.append((idx, "ascii/utf8", pattern, ctx.decode("latin-1", errors="replace")))
            start = idx + 1

        utf16_bytes = pattern.encode("utf-16-le")
        start = 0
        while True:
            idx = data.find(utf16_bytes, start)
            if idx == -1:
                break
            ctx = data[max(0, idx - 32):idx + len(utf16_bytes) + 32]
            try:
                ctx_txt = ctx.decode("utf-16-le", errors="replace")
            except Exception:
                ctx_txt = repr(ctx)
            occurrences.append((idx, "utf-16le", pattern, ctx_txt))
            start = idx + 1
    return occurrences


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root", help="racine de l'arborescence montée à scanner")
    ap.add_argument("--out", required=True, help="fichier de sortie JSONL (un objet par fichier concerné)")
    ap.add_argument("--report", required=True, help="fichier de sortie : rapport texte lisible")
    ap.add_argument("--max-file-mb", type=int, default=300,
                     help="ignore (log à part) les fichiers plus gros que ça, en Mo (défaut 300)")
    ap.add_argument("--roots", nargs="*", default=None,
                     help="limiter le scan à ces sous-chemins relatifs à root (sinon tout l'arbre)")
    args = ap.parse_args()

    root = os.path.abspath(args.root)
    scan_roots = [os.path.join(root, r) for r in args.roots] if args.roots else [root]

    t0 = time.time()
    files_scanned = 0
    files_with_hits = 0
    files_skipped_too_large = 0
    files_unreadable = 0
    files_boot_critical_skipped = 0
    total_occurrences = 0
    by_category = {"registry": 0, "mui": 0, "pe": 0, "text": 0, "other": 0}
    by_category_files = {"registry": 0, "mui": 0, "pe": 0, "text": 0, "other": 0}
    pe_signed_present = 0
    pe_signed_absent = 0
    pe_signed_unknown = 0

    max_bytes = args.max_file_mb * 1024 * 1024

    with open(args.out, "w", encoding="utf-8") as out_f:
        for scan_root in scan_roots:
            for dirpath, dirnames, filenames in os.walk(scan_root):
                for fname in filenames:
                    full_path = os.path.join(dirpath, fname)
                    rel_path = os.path.relpath(full_path, root)
                    rel_lower = rel_path.lower().replace("\\", "/")

                    if is_boot_critical("/" + rel_lower):
                        files_boot_critical_skipped += 1
                        continue

                    try:
                        st = os.lstat(full_path)
                    except OSError:
                        files_unreadable += 1
                        continue
                    if not os.path.isfile(full_path) or os.path.islink(full_path):
                        continue
                    if st.st_size == 0:
                        continue
                    if st.st_size > max_bytes:
                        files_skipped_too_large += 1
                        continue

                    files_scanned += 1
                    try:
                        with open(full_path, "rb") as f:
                            data = f.read()
                    except OSError:
                        files_unreadable += 1
                        continue

                    occs = find_occurrences(data)
                    if not occs:
                        continue

                    category = classify(rel_path, data[:2])
                    sig_status = None
                    if category == "pe" or category == "mui":
                        sig_status = has_authenticode_signature(full_path)
                        if sig_status == "present":
                            pe_signed_present += 1
                        elif sig_status == "absent":
                            pe_signed_absent += 1
                        else:
                            pe_signed_unknown += 1

                    files_with_hits += 1
                    by_category_files[category] = by_category_files.get(category, 0) + 1
                    by_category[category] = by_category.get(category, 0) + len(occs)
                    total_occurrences += len(occs)

                    record = {
                        "path": rel_path,
                        "size": st.st_size,
                        "category": category,
                        "authenticode_signature": sig_status,
                        "occurrence_count": len(occs),
                        "occurrences": [
                            {"offset": o, "encoding": enc, "pattern": pat, "context": ctx}
                            for (o, enc, pat, ctx) in occs
                        ],
                    }
                    out_f.write(json.dumps(record, ensure_ascii=False) + "\n")

                    if files_scanned % 5000 == 0:
                        print(f"... {files_scanned} fichiers scannés, {files_with_hits} avec occurrence(s), "
                              f"{time.time()-t0:.0f}s écoulées", file=sys.stderr)

    elapsed = time.time() - t0
    with open(args.report, "w", encoding="utf-8") as r:
        r.write("=" * 70 + "\n")
        r.write("Furax Windows 12 Beta — Inventaire \"Windows 11\" (labo expérimental)\n")
        r.write("=" * 70 + "\n\n")
        r.write(f"Racine scannée  : {root}\n")
        r.write(f"Sous-chemins    : {args.roots if args.roots else '(arbre complet)'}\n")
        r.write(f"Durée           : {elapsed:.1f}s\n\n")
        r.write(f"Fichiers scannés (contenu lu)         : {files_scanned}\n")
        r.write(f"Fichiers avec au moins 1 occurrence   : {files_with_hits}\n")
        r.write(f"Occurrences totales (toutes encodages): {total_occurrences}\n")
        r.write(f"Fichiers ignorés (trop gros, >{args.max_file_mb} Mo) : {files_skipped_too_large}\n")
        r.write(f"Fichiers illisibles (erreur I/O)       : {files_unreadable}\n")
        r.write(f"Fichiers chaîne de boot EXCLUS d'office: {files_boot_critical_skipped} "
                "(bootmgr/winload/BCD/EFI — jamais scannés ni modifiés, aucune méthode de restauration)\n\n")
        r.write("--- Répartition par catégorie (fichiers / occurrences) ---\n")
        for cat in ("registry", "mui", "pe", "text", "other"):
            r.write(f"  {cat:10s} : {by_category_files.get(cat,0):6d} fichier(s) / {by_category.get(cat,0):6d} occurrence(s)\n")
        r.write("\n--- Signatures Authenticode (fichiers PE/.mui concernés) ---\n")
        r.write(f"  Signature PRÉSENTE (sera invalidée si modifié) : {pe_signed_present}\n")
        r.write(f"  Signature ABSENTE (non signé à l'origine)      : {pe_signed_absent}\n")
        r.write(f"  Statut INCONNU (pefile n'a pas pu analyser)    : {pe_signed_unknown}\n")

    print(f"Terminé en {elapsed:.1f}s. {files_with_hits} fichier(s) avec occurrence(s) sur {files_scanned} scannés.",
          file=sys.stderr)


if __name__ == "__main__":
    main()
