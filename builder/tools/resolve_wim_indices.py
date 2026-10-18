#!/usr/bin/env python3
"""resolve_wim_indices.py — résout des noms d'édition en index WIM réels, en lisant
`wimlib-imagex info` (jamais de numéro d'index codé en dur dans le pipeline : ça varie
selon l'ISO/langue/version, voir builder/modules/20-identify.sh qui fait déjà ça pour un
seul index).

Fait pour le mode multi-éditions (demande FuraxDev, 18/10/2026 : "Windows 12 Pro, Home,
Famille, Entreprise, S" dans une seule ISO) : chaque édition demandée doit correspondre à
une VRAIE image présente dans le WIM source — on ne invente jamais un index qui n'existe
pas. Le nom "Windows 11 <Edition>" doit matcher EXACTEMENT (pas "Home N", pas "Pro for
Workstations", etc.) pour éviter de sélectionner la mauvaise variante par accident.

Usage :
  python3 resolve_wim_indices.py <chemin_wim> <Edition1> [<Edition2> ...]

Sortie (stdout) : une ligne par édition demandée, au format "Edition=Index".
Erreur (exit 1) si une édition demandée n'a pas de correspondance exacte — le message
liste les noms réellement disponibles pour que l'appelant (humain ou build.sh) choisisse.
"""
from __future__ import annotations

import subprocess
import sys


def list_images(wim_path: str):
    """Retourne une liste de dicts {index, name} en parsant `wimlib-imagex info <wim>`."""
    out = subprocess.run(
        ["wimlib-imagex", "info", wim_path],
        capture_output=True, text=True, check=True,
    ).stdout

    images = []
    current = {}
    for line in out.splitlines():
        line = line.rstrip()
        if line.startswith("Index:"):
            if current:
                images.append(current)
            current = {"index": line.split(":", 1)[1].strip()}
        elif line.startswith("Name:") and current:
            current["name"] = line.split(":", 1)[1].strip()
    if current:
        images.append(current)
    return images


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <chemin_wim> <Edition1> [<Edition2> ...]", file=sys.stderr)
        return 2

    wim_path = sys.argv[1]
    requested = sys.argv[2:]

    try:
        images = list_images(wim_path)
    except subprocess.CalledProcessError as e:
        print(f"Erreur : wimlib-imagex info a échoué sur {wim_path} : {e}", file=sys.stderr)
        return 1
    except FileNotFoundError:
        print("Erreur : wimlib-imagex introuvable.", file=sys.stderr)
        return 1

    if not images:
        print(f"Erreur : aucune image trouvée dans {wim_path}.", file=sys.stderr)
        return 1

    available_names = sorted({img.get("name", "") for img in images})
    results = []
    failed = []
    for edition in requested:
        target = f"Windows 11 {edition}".strip().lower()
        match = next((img for img in images if img.get("name", "").strip().lower() == target), None)
        if match is None:
            failed.append(edition)
        else:
            results.append((edition, match["index"]))

    if failed:
        print(
            f"Erreur : édition(s) introuvable(s) (correspondance EXACTE requise, "
            f"\"Windows 11 <Edition>\") : {', '.join(failed)}",
            file=sys.stderr,
        )
        print("Noms d'édition réellement présents dans ce WIM :", file=sys.stderr)
        for name in available_names:
            print(f"  - {name}", file=sys.stderr)
        return 1

    for edition, index in results:
        print(f"{edition}={index}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
