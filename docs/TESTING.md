# TESTING.md — Stratégie de tests

**Statut : Phase 2.** Ce document décrit les tests qui existent réellement aujourd'hui et ceux qui restent à écrire (Phase 6 dans le planning de `README.md`).

## 1. Build tests (existants, exécutés automatiquement par le pipeline)

Ces vérifications sont intégrées directement dans `builder/modules/00-*.sh` à `70-*.sh` — elles s'exécutent à chaque build, pas seulement en CI :

| Test | Module | Statut |
|---|---|---|
| ISO source lisible et structurée (El Torito présent) | `00-validate.sh` | `IMPLEMENTED` |
| `sources/install.wim` ou `install.esd` présent dans l'ISO source | `00-validate.sh` | `IMPLEMENTED` |
| Espace disque suffisant avant de commencer | `00-validate.sh` | `IMPLEMENTED` |
| Privilèges root vérifiés | `00-validate.sh` | `IMPLEMENTED` |
| Extraction complète (fichiers de boot BIOS+UEFI présents) | `10-extract.sh` | `IMPLEMENTED` |
| Image montable | `30-mount.sh` (vérifie `mountpoint -q`) | `IMPLEMENTED` |
| Image démontable, aucun mount résiduel après commit | `50-unmount.sh` | `IMPLEMENTED` |
| ISO finale lisible, taille cohérente, `install.wim` présent | `70-validate-output.sh` | `IMPLEMENTED` |
| Aucun mount résiduel en cas d'échec à n'importe quelle étape | `lib/common.sh::cleanup_on_exit` (trap) | `IMPLEMENTED` |
| **ISO finale réellement bootable** | — | `PLANNED` (nécessite `vm/test-vm.sh`, voir §3 — test manuel/semi-auto, pas encore automatisé en CI) |

## 2. Configuration tests

| Test | Statut |
|---|---|
| Le fichier marqueur de preuve de mécanisme est bien committé dans l'ISO finale | `IMPLEMENTED` (vérifié par `70-validate-output.sh`, non bloquant si absent — juste un avertissement) |
| La valeur de registre de test est bien écrite offline via hivex | `PARTIAL` — dépend de la disponibilité de `python3.12`+`hivex` dans l'environnement ; si absent, l'étape est `SKIPPED` proprement (jamais simulée comme réussie) |
| Policies/GPO appliquées | `PLANNED` (rien n'existe encore dans `system/policies/`) |
| Services/configuration par défaut | `PLANNED` |
| **Rollback** (annulation branding + thème) | `TESTED` — `builder/tools/test_rollback_offline.sh` : 12/12 vérifications passées (05/09/2026) contre de vraies ruches SOFTWARE/NTUSER.DAT extraites de l'ISO Windows 11 25H2 officielle. Applique le forward (mêmes appels que `42-branding.sh`/`46-theme.sh`), vérifie par `hivexget`, applique le rollback (`hivex_delete_value.py`/`hivex_delete_key.py`), revérifie que tout redevient absent. Couvre le registre uniquement — le script PowerShell `scripts/rollback/Rollback-FuraxWindows12.ps1` destiné à l'utilisateur final n'a lui-même pas pu être exécuté dans un vrai Windows démarré (pas de boot possible dans cet environnement), voir ses notes internes. |

## 3. Runtime tests (VM)

`vm/test-vm.sh` démarre l'ISO générée dans QEMU avec firmware UEFI (OVMF) :

```bash
./vm/test-vm.sh --iso build/_out/furax-windows-12-beta-<id>.iso --boot-only-check --timeout 180
```

- `--boot-only-check` : test **structurel** de démarrage, sans interface graphique, borné dans le temps. Capture la sortie série. Prouve seulement que le firmware trouve et charge un chargeur d'amorçage sans erreur immédiate — **ne prouve pas** qu'une installation Windows complète aboutit.
- Sans `--boot-only-check` : ouvre une fenêtre QEMU interactive pour suivre/piloter manuellement l'installation (Setup → premier démarrage → shell → smoke tests).

**Limite connue de cet environnement de développement précis (documentée honnêtement, à revérifier sur ta machine) :** `kvm-ok` y rapporte l'absence d'extensions KVM (pas de virtualisation imbriquée) → les tests VM y tournent uniquement en émulation logicielle TCG, ce qui est *correct* mais *lent* (potentiellement plusieurs dizaines de minutes pour atteindre l'écran de Setup). Sur une machine avec KVM natif disponible, ce sera nettement plus rapide.

**Testé le 05/09/2026 :** dans cet environnement précis, `--boot-only-check` échoue systématiquement avec `BdsDxe: ... Time out` en lisant le CD-ROM UEFI — **identiquement sur l'ISO Furax générée ET sur l'ISO Windows 11 25H2 officielle non modifiée**. Ceci confirme que c'est une limite de l'environnement (TCG trop lent pour le timeout interne du firmware OVMF face à une image de ~8 Go), pas un défaut du pipeline de reconstruction. Voir `docs/TROUBLESHOOTING.md` pour le détail. **Conséquence concrète : le boot réel de l'ISO générée n'a pas pu être validé dans cette session — à refaire sur une machine avec KVM natif ou sur du matériel physique.**

Objectif complet (Phase 6, pas encore automatisé) :

```
Build → ISO → VM → Boot → Installation → First Boot → Smoke Tests
```

Seuls "Build → ISO → VM → Boot (structurel, --boot-only-check)" ont un script prêt à l'emploi aujourd'hui. "Installation → First Boot → Smoke Tests" nécessitent une exécution manuelle interactive de l'installeur Windows dans la VM (aucune automatisation d'installation Windows headless n'est fournie par ce projet à ce stade).

## 4. Ce qui a été réellement exécuté vs simulé

Voir le rapport de build le plus récent dans `build/_out/rapport-build-*.txt` et les logs associés `build/_out/build-*.log` — ce sont la seule source de vérité sur ce qui a réellement tourné. Ne te fie pas à un résumé texte : les logs bruts font foi.
