# ROLLBACK.md — Annuler les personnalisations Furax Windows 12 Beta

## Ce qui est couvert

Ce document concerne le rollback des personnalisations **appliquées par le builder** (fond d'écran, thème, branding, confidentialité/performance, raccourci bureau). Il ne concerne PAS le module `48-taskbar-experimental.sh` (documentation Windhawk uniquement, jamais appliqué automatiquement — son propre rollback est documenté dans `ui/taskbar/EXPERIMENTAL-floating-pill/README.md`), ni `autounattend.xml` (fichier déposé à la racine de l'ISO, pas une modification du système installé — rien à annuler après coup).

## Statut

| Aspect | Statut |
|---|---|
| Logique de rollback (registre) | `TESTED` — 28/28 vérifications automatiques (20/09/2026, après ajout du module 47), voir `docs/TESTING.md` |
| Script PowerShell pour Windows démarré | `IMPLEMENTED` (écrit, miroir exact de la logique testée) / `UNTESTED` en conditions réelles (pas de boot Windows possible dans l'environnement de développement de ce projet) |
| Restauration du fond d'écran | `IMPLEMENTED` — repose sur la sauvegarde automatique faite par `45-wallpaper.sh` (`img0.jpg.stock-original`) |
| Raccourci bureau (`Rollback Furax Windows 12.bat`) | `IMPLEMENTED` — déposé par `49-rollback-scripts.sh` sur `Users\Public\Desktop`, présence vérifiée dans le WIM généré, contenu (apostrophes + CRLF) vérifié par extraction directe. Auto-suppression après exécution du rollback. |

## Comment ça marche

### 1. Pendant le build (déjà fait automatiquement)

- `builder/modules/45-wallpaper.sh` sauvegarde l'image originale (`img0.jpg.stock-original`) **avant** de la remplacer.
- `builder/modules/49-rollback-scripts.sh` dépose `scripts/rollback/Rollback-FuraxWindows12.ps1` dans l'image générée, sous `C:\FuraxWindows12\rollback\`.

### 2. Sur la machine Windows installée (à faire toi-même, jamais automatique)

```powershell
# Dans un PowerShell en Administrateur :
cd C:\FuraxWindows12\rollback
.\Rollback-FuraxWindows12.ps1
```

Ce script :
- restaure `img0.jpg` depuis la sauvegarde ;
- réinitialise les réglages de fond d'écran du profil courant ;
- supprime les clés de thème ajoutées (`AppsUseLightTheme`, `SystemUsesLightTheme`, `EnableTransparency`, `ColorPrevalence`, `TaskbarAl`) — Windows retombe sur ses valeurs par défaut ;
- supprime `RegisteredOwner`/`RegisteredOrganization` (winver redevient vierge) ;
- supprime entièrement la clé `OEMInformation` (elle n'existait pas avant nos modifications).

Il est **idempotent** : le relancer plusieurs fois ne cause aucune erreur si une clé est déjà absente.

### 3. Comment on sait que ça marche (test réel, pas une supposition)

`builder/tools/test_rollback_offline.sh` a été exécuté contre de **vraies** ruches `SOFTWARE`/`NTUSER.DAT` extraites de l'ISO Windows 11 25H2 officielle :

1. Il applique le **forward** — exactement les mêmes appels `hivex_set_value.py` que `42-branding.sh`/`46-theme.sh`.
2. Il vérifie par `hivexget` que les valeurs sont bien présentes.
3. Il applique le **rollback** — les mêmes opérations que `Rollback-FuraxWindows12.ps1` (traduites en appels `hivex_delete_value.py`/`hivex_delete_key.py`, mêmes clés/valeurs cibles).
4. Il revérifie par `hivexget` que tout redevient absent.

Résultat au 05/09/2026 : 12/12 vérifications passées. Trois bugs réels ont été trouvés et corrigés pendant ce développement (mauvais déballage de tuples retournés par l'API hivex, mauvaise signature de `node_delete_child`) — voir l'historique Git pour le détail.

**Mise à jour du 20/09/2026** : extension à 33 vérifications après l'ajout du module `47-privacy-performance.sh` (télémétrie, Copilot, suggestions, presse-papiers, mode jeu). Un test a révélé un vrai problème (pas un faux positif) : une tentative d'ajouter le réglage Windows Spotlight (écran de verrouillage, backlog #70) a échoué la vérification "absent par défaut (stock)" — investigation a montré que `RotatingLockScreenEnabled`/`RotatingLockScreenOverlayEnabled` valent **déjà 1 par défaut** sur Windows 11 25H2 stock. La tentative a été retirée du builder plutôt que forcée à passer (voir `docs/FEATURES.md` #70). Résultat final après retrait : **28/28 vérifications passées**. C'est exactement le genre d'erreur qu'un rollback "écrit mais jamais testé" aurait laissé passer silencieusement jusqu'au premier essai réel — la mécanique de test a fait son travail.

### Ce qui n'est PAS testé

- Le script PowerShell lui-même n'a pas pu être exécuté dans un vrai Windows démarré (aucun boot Windows possible dans l'environnement de développement de ce projet, voir `docs/TESTING.md`). Sa logique est un miroir direct et volontairement identique de ce qui a été testé côté hivex, mais l'exécution PowerShell réelle (chemins `HKCU:`/`HKLM:`, permissions administrateur, etc.) reste à valider par toi lors du premier test réel.
- Le rendu visuel après rollback (le bureau redevient-il visuellement stock ?) n'a pas pu être observé.

Si le premier test réel révèle un écart, il faut le corriger dans `Rollback-FuraxWindows12.ps1` **et** dans `test_rollback_offline.sh` pour que les deux restent synchronisés.
