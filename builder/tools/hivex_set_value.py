#!/usr/bin/env python3.12
"""
hivex_set_value.py — écrit UNE valeur de registre dans une ruche Windows offline via hivex.

Outil volontairement minimal pour la Phase 2 (builder minimal) : preuve que le pipeline
peut éditer le registre Windows hors-ligne (sans DISM, sans Windows démarré), pas une
fonctionnalité UI. Utilisé par builder/modules/40-customize-minimal.sh.

Usage:
    python3.12 hivex_set_value.py <chemin_ruche> <chemin_clé> <nom_valeur> <type> <valeur>

    type: string | dword

Notes honnêtes :
- Ce script ne crée PAS la clé parente si elle n'existe pas déjà dans la ruche — il échoue
  proprement plutôt que de deviner une structure de registre Windows qu'on ne maîtrise pas.
- Testé uniquement contre une ruche SOFTWARE synthétique construite pour ce projet
  (voir builder/tools/make_test_iso.py) — PAS ENCORE testé contre une vraie ruche
  SOFTWARE de Windows 11 25H2, faute d'ISO officielle fournie dans cet environnement.
"""
import sys

try:
    import hivex
except ImportError as exc:
    print(f"ERREUR: module python 'hivex' introuvable ({exc}). "
          f"Ce script doit être lancé avec /usr/bin/python3.12, pas 'python3'.", file=sys.stderr)
    sys.exit(2)


def main():
    if len(sys.argv) != 6:
        print(f"Usage: {sys.argv[0]} <ruche> <chemin_cle> <nom_valeur> <string|dword> <valeur>",
              file=sys.stderr)
        return 2

    hive_path, key_path, value_name, value_type, raw_value = sys.argv[1:6]

    h = hivex.Hivex(hive_path, write=True)

    node = h.root()
    if key_path not in ("", "\\", "/"):
        for part in key_path.strip("\\/").split("\\"):
            child = h.node_get_child(node, part)
            if child is None:
                print(f"ERREUR: clé introuvable dans la ruche : ...\\{part} "
                      f"(sous-chemin de '{key_path}') — la clé parente doit déjà exister.",
                      file=sys.stderr)
                return 1
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
