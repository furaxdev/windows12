#!/usr/bin/env python3.12
"""
hivex_delete_key.py — supprime une clé de registre entière (et ses sous-clés/valeurs)
dans une ruche Windows offline. Utilisé pour le rollback de clés qui n'existaient PAS
avant nos modifications (ex. OEMInformation, créée via --create-keys) : la façon la plus
propre de revenir en arrière est de supprimer la clé entièrement plutôt que de deviner
quelles valeurs individuelles remettre.

Usage:
    python3.12 hivex_delete_key.py <chemin_ruche> <chemin_clé_parente> <nom_sous_clé>

Idempotent : si la clé n'existe déjà pas, ce n'est pas une erreur.
"""
import sys

try:
    import hivex
except ImportError as exc:
    print(f"ERREUR: module python 'hivex' introuvable ({exc}). "
          f"Ce script doit être lancé avec /usr/bin/python3.12, pas 'python3'.", file=sys.stderr)
    sys.exit(2)


def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <ruche> <chemin_cle_parente> <nom_sous_cle>", file=sys.stderr)
        return 2

    hive_path, parent_path, child_name = sys.argv[1:4]

    h = hivex.Hivex(hive_path, write=True)

    node = h.root()
    if parent_path not in ("", "\\", "/"):
        for part in parent_path.strip("\\/").split("\\"):
            child = h.node_get_child(node, part)
            if child is None:
                print(f"INFO: clé parente déjà absente : {parent_path} — rien à supprimer.")
                return 0
            node = child

    target = h.node_get_child(node, child_name)
    if target is None:
        print(f"INFO: clé déjà absente : {parent_path}\\{child_name} — rien à supprimer.")
        return 0

    h.node_delete_child(node, child_name)
    h.commit(None)
    print(f"OK: clé {parent_path}\\{child_name} supprimée de {hive_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
