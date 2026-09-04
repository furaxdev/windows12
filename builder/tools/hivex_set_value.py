#!/usr/bin/env python3.12
"""
hivex_set_value.py — écrit UNE valeur de registre dans une ruche Windows offline via hivex.

Usage:
    python3.12 hivex_set_value.py <chemin_ruche> <chemin_clé> <nom_valeur> <type> <valeur> [--create-keys]

    type: string | dword

Notes honnêtes :
- Sans --create-keys : si la clé parente n'existe pas déjà dans la ruche, le script échoue
  proprement plutôt que de deviner une structure de registre Windows qu'on ne maîtrise pas.
- Avec --create-keys : les sous-clés manquantes du chemin sont créées au fur et à mesure
  (comportement standard de l'éditeur de registre Windows quand on ajoute une valeur sous
  une clé qui n'existe pas encore — ce n'est pas un hack, juste une création de clé normale).
  Utile pour des clés qui n'existent pas forcément par défaut sur toutes les éditions/versions
  (ex. OEMInformation).
- Testé et confirmé fonctionnel contre une vraie ruche SOFTWARE de Windows 11 25H2 officielle
  (voir docs/BUILD.md et le rapport de build du 2026-09-04) : écriture ET relecture (hivexget)
  confirmées après commit.
"""
import sys

try:
    import hivex
except ImportError as exc:
    print(f"ERREUR: module python 'hivex' introuvable ({exc}). "
          f"Ce script doit être lancé avec /usr/bin/python3.12, pas 'python3'.", file=sys.stderr)
    sys.exit(2)


def main():
    args = [a for a in sys.argv[1:] if a != "--create-keys"]
    create_keys = "--create-keys" in sys.argv[1:]

    if len(args) != 5:
        print(f"Usage: {sys.argv[0]} <ruche> <chemin_cle> <nom_valeur> <string|dword> <valeur> [--create-keys]",
              file=sys.stderr)
        return 2

    hive_path, key_path, value_name, value_type, raw_value = args

    h = hivex.Hivex(hive_path, write=True)

    node = h.root()
    if key_path not in ("", "\\", "/"):
        for part in key_path.strip("\\/").split("\\"):
            child = h.node_get_child(node, part)
            if child is None:
                if not create_keys:
                    print(f"ERREUR: clé introuvable dans la ruche : ...\\{part} "
                          f"(sous-chemin de '{key_path}') — la clé parente doit déjà exister "
                          f"(ou relance avec --create-keys pour la créer).",
                          file=sys.stderr)
                    return 1
                child = h.node_add_child(node, part)
                print(f"INFO: clé créée : ...\\{part}", file=sys.stderr)
            node = child

    if value_type == "string":
        val_bytes = raw_value.encode("utf-16-le") + b"\x00\x00"
        h.node_set_value(node, {"key": value_name, "t": 1, "value": val_bytes})  # REG_SZ = 1
    elif value_type == "dword":
        val_int = int(raw_value, 0)
        val_bytes = val_int.to_bytes(4, byteorder="little")
        h.node_set_value(node, {"key": value_name, "t": 4, "value": val_bytes})  # REG_DWORD = 4
    else:
        print(f"ERREUR: type de valeur non supporté : {value_type} (attendu: string|dword)",
              file=sys.stderr)
        return 2

    h.commit(None)
    print(f"OK: {key_path}\\{value_name} = {raw_value} ({value_type}) écrit dans {hive_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
