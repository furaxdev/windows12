#!/usr/bin/env python3.12
"""
hivex_delete_value.py — supprime UNE valeur de registre dans une ruche Windows offline,
sans toucher aux autres valeurs de la même clé (contrairement à un remplacement complet).

Usage:
    python3.12 hivex_delete_value.py <chemin_ruche> <chemin_clé> <nom_valeur>

Mécanique : hivex n'expose pas de "node_delete_value" direct, seulement
"node_set_values" qui remplace TOUTES les valeurs d'un nœud d'un coup. On lit donc la
liste actuelle des valeurs, on retire celle demandée, et on réécrit la liste filtrée.

Si la clé ou la valeur n'existe pas, ce n'est PAS une erreur (rollback idempotent : on
peut le relancer plusieurs fois sans conséquence) — juste un message informatif.
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
        print(f"Usage: {sys.argv[0]} <ruche> <chemin_cle> <nom_valeur>", file=sys.stderr)
        return 2

    hive_path, key_path, value_name = sys.argv[1:4]

    h = hivex.Hivex(hive_path, write=True)

    node = h.root()
    if key_path not in ("", "\\", "/"):
        for part in key_path.strip("\\/").split("\\"):
            child = h.node_get_child(node, part)
            if child is None:
                print(f"INFO: clé déjà absente : {key_path} — rien à supprimer.")
                return 0
            node = child

    values = h.node_values(node)
    remaining = []
    found = False
    for v in values:
        name = h.value_key(v)
        if name == value_name:
            found = True
            continue
        # Le docstring de la lib dit "retourne longueur, type et donnée" (3 valeurs) mais
        # le binding réel de ce système retourne (type, donnée) — vérifié empiriquement.
        vtype, vdata = h.value_value(v)
        remaining.append({"key": name, "t": vtype, "value": vdata})

    if not found:
        print(f"INFO: valeur déjà absente : {key_path}\\{value_name} — rien à supprimer.")
        return 0

    h.node_set_values(node, remaining)
    h.commit(None)
    print(f"OK: {key_path}\\{value_name} supprimée de {hive_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
