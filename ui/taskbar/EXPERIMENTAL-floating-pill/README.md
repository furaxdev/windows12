# 🟦 Barre des tâches "pilule flottante" — EXPERIMENTAL / UNTESTED

**État : `EXPERIMENTAL`, `UNTESTED` (rendu visuel réel). `PARTIAL` (compilation + dépôt vérifiés).** Ne pas confondre avec les réglages natifs déjà appliqués par le builder (alignement centré, accent coloré — ceux-là sont `IMPLEMENTED`, voir `docs/FEATURES.md`).

## Historique de décision (important — lire avant de contribuer ici)

**Version 1 de ce plan (abandonnée)** : la seule voie identifiée pour reproduire visuellement une barre des tâches flottante était un patch de shell tiers, [Windhawk](https://windhawk.net/) (framework d'injection de DLL open source largement utilisé par la communauté). Ce plan a été **explicitement rejeté par l'utilisateur** (FuraxDev, 26/09/2026) : *"on dev notre propre barre flottante ! Rappelle-toi du but : faire Windows 12 ! Donc pas de Windhawk ou truc tiers !"*

**Version 2 (actuelle)** : une vraie application, code 100% du projet, sous `apps/furax-taskbar/` (C#/.NET 8, WPF). Elle ne patche RIEN sur disque ni en mémoire dans `explorer.exe` :
- elle **masque** la vraie barre des tâches Windows au démarrage (`ShowWindow(SW_HIDE)` sur la fenêtre `Shell_TrayWnd` — API Win32 publique et documentée, la vraie barre continue d'exister, juste invisible) ;
- elle affiche ses propres fenêtres flottantes par-dessus (3 "pilules" : météo, dock d'icônes, horloge/système) ;
- elle **restaure** la vraie barre des tâches à la fermeture (normale, sur exception non gérée, ou si le processus est tué depuis le Gestionnaire des tâches) — voir le bloc `finally` de `apps/furax-taskbar/Program.cs`, c'est le garde-fou de sécurité le plus important de ce module.

## Ce qui est fait vs pas fait (honnêteté)

| Aspect | Statut |
|---|---|
| Code source (C#/.NET 8, WPF, sans XAML pour fiabilité de compilation croisée) | `IMPLEMENTED` |
| Compilation réelle (`dotnet publish -r win-x64 --self-contained`) | `TESTED` — build réussi dans cet environnement (Linux, SDK .NET 8 installé via le script officiel Microsoft), exécutable Windows PE32+ réel produit (~161 Mo, self-contained) |
| Dépôt dans l'ISO générée (`builder/modules/48-taskbar-experimental.sh`) | `TESTED` — exécutable + clé de démarrage auto (`Run`) confirmés présents dans le WIM généré par extraction directe |
| **Rendu visuel réel sur un Windows démarré** | `UNCONFIRMED` — pas de boot Windows possible dans cet environnement de développement (pas de `/dev/kvm`, voir historique du projet) |
| Comportement des 3 pilules (positionnement, clics, masquage/restauration de la vraie barre) | `UNCONFIRMED` pour la même raison |
| Zone système complète (icônes d'autres apps, flyouts volume/wifi réels) | **Volontairement PAS implémenté** — réimplémenter le protocole `Shell_NotifyIcon` est un sous-système reconnu comme l'un des plus complexes de tout remplacement de shell Windows (des projets matures comme Cairo Shell y ont mis des années). Le MVP ouvre les vrais Paramètres rapides (Win+A) au clic à la place. |
| Rollback | `IMPLEMENTED` (arrête le processus + supprime la clé `Run`) dans `scripts/rollback/Rollback-FuraxWindows12.ps1`, même limite `UNCONFIRMED` sur l'exécution réelle |

## Pourquoi c'est encore désactivé par défaut

Même règle que toujours dans ce projet : ne jamais prétendre qu'une fonctionnalité marche visuellement si ce n'est pas vérifié. La compilation et le dépôt dans l'image SONT vérifiés ; le rendu à l'écran ne l'est PAS. Le flag de profil `taskbar_floating_pill_experimental` reste donc à `false` dans tous les profils — active-le volontairement si tu veux tester sur une vraie machine/VM Windows, et remonte ce que tu observes (ça permettra de faire passer ce statut de `UNCONFIRMED` à `TESTED`).

## Comment l'essayer

1. Mets `taskbar_floating_pill_experimental: true` dans le profil YAML utilisé pour le build (ex. `builder/profiles/minimal.yaml`).
2. Assure-toi que le SDK .NET 8 est disponible dans l'environnement qui lance `build.sh` (`dotnet --version`) — sinon le module est `SKIPPED` proprement, rien ne casse le reste du pipeline. Installation : `curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 8.0 --install-dir /opt/dotnet` (script officiel Microsoft).
3. Lance le build normalement. `FuraxTaskbar.exe` est compilé à la volée et déposé dans l'ISO.
4. Installe l'ISO sur une vraie machine ou VM avec accélération matérielle (pas d'émulation logicielle pure — la vraie limite de cet environnement de dev).
5. À l'ouverture de session, la barre flottante devrait démarrer automatiquement (clé `Run`).

## Rollback

- **Depuis l'app elle-même** : Ctrl+Alt+Suppr → Gestionnaire des tâches → fin de tâche sur `FuraxTaskbar.exe`. La vraie barre des tâches revient instantanément (bloc `finally` du programme).
- **Rollback complet** : `Rollback-FuraxWindows12.ps1` arrête le processus et supprime la clé `Run` — la barre flottante ne redémarrera plus aux sessions suivantes.
- Rien n'est irréversible : la vraie barre des tâches Windows n'est jamais modifiée sur disque, seulement cachée pendant que l'app tourne.

## Code source

`apps/furax-taskbar/` :
- `Program.cs` — point d'entrée, masquage/restauration de la vraie barre, positionnement des 3 pilules.
- `PillWindow.cs` — fenêtre de base (sans bordure, transparente, matériau flou DWM natif Windows 11).
- `Pills/WeatherPill.cs`, `Pills/DockPill.cs`, `Pills/SystemPill.cs` — les 3 pilules.
- `Native/NativeMethods.cs` — tous les appels Win32 utilisés, chacun documenté avec son usage précis (API publiques uniquement, jamais d'API interne non documentée).
- `Icons.cs` — icônes schématiques construites avec des formes géométriques simples (pas de police d'icônes ni de tracés SVG transcrits à l'aveugle — voir le commentaire en tête de fichier).
