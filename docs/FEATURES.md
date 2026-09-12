# FEATURES.md — Inventaire des fonctionnalités

Basé sur `docs/VIDEO_ANALYSIS.md`. États possibles : `PLANNED` (pas commencé), `PROTOTYPE` (ébauche non fiable), `PARTIAL` (fonctionne partiellement), `IMPLEMENTED` (fonctionne), `TESTED` (fonctionne + vérifié en VM Windows), `CONCEPT ONLY` (non réalisable proprement — alternative documentée), `IMPLEMENTABLE` (déjà natif à Windows 11, réglage/registre suffisant, non encore branché au builder).

**Au 05/09/2026 : le pipeline de build (Phase 2) est validé de bout en bout contre une vraie ISO Windows 11 25H2 officielle.** Fond d'écran, thème sombre/accent, branding "By FuraxDev" (winver) sont `IMPLEMENTED` — mécanismes confirmés par extraction/lecture directe du WIM généré. Le **rollback** de ces personnalisations (registre) est `TESTED` : 12/12 vérifications automatiques passées via `builder/tools/test_rollback_offline.sh` contre de vraies ruches Windows 11 25H2 (voir `docs/TESTING.md`). **Le boot réel en VM/matériel reste non confirmé** (limite de cet environnement de développement, voir `docs/TROUBLESHOOTING.md`) — c'est la prochaine validation à faire. Tout le reste du tableau ci-dessous reste `PLANNED` tant que non implémenté.

---

## 🖥️ Desktop

| Fonctionnalité | État | Faisabilité | Implémentation envisagée |
|---|---|---|---|
| Fond d'écran par défaut du bureau (image statique façon "vagues" bleu/magenta) | `IMPLEMENTED` | Facile | `builder/modules/45-wallpaper.sh` : remplace `Windows/Web/Wallpaper/Windows/img0.jpg` (fond par défaut, chemin confirmé sur une vraie ISO Win11 25H2) par `assets/wallpapers/furax-wave-primary.jpg` (redimensionné en cover-fit), + configure `HKCU\Control Panel\Desktop` du profil `Default` (WallPaper/WallpaperStyle=10/TileWallpaper=0) pour que les nouveaux comptes l'utilisent en mode Remplir. Vérifié : fichier remplacé et clés registre confirmées présentes dans le WIM généré (extraction directe). **Non encore vérifié : rendu réel au premier login dans une VM** (`TESTED` réservé à ça). |
| Fond d'écran "vagues" **animé** (vidéo/parallaxe en fond de bureau) | `PLANNED` | Difficile | Nécessiterait un wallpaper engine tiers (ex. Lively Wallpaper) — pas dans ce projet à ce stade |
| Logo "Win12" géant flottant sur le bureau | `PARTIAL` | Facile | Le fond d'écran `furax-wave-primary.jpg` intègre déjà un petit logo (fait par l'artiste d'origine, voir `assets/wallpapers/CREDITS.md`), visible en bas à gauche. Un logo Windows 12 séparé et attribué a été ajouté (`assets/icons/windows12-logo-fanmade.png`, voir `assets/icons/CREDITS.md`) mais **n'est volontairement PAS superposé au wallpaper actuel** : un essai de superposition (`builder/tools/prepare_wallpaper.py`, fonction `overlay_logo`) a produit un doublon visuel disgracieux avec le logo déjà présent dans l'image — constaté visuellement, retiré. L'asset reste disponible pour un usage futur distinct (autre fond d'écran sans logo intégré, icône, écran de démarrage). |
| Thème par défaut sombre + accent coloré (dérivé du fond d'écran) | `IMPLEMENTED` | Facile | `builder/modules/46-theme.sh` : `AppsUseLightTheme`/`SystemUsesLightTheme`=0, `EnableTransparency`=1, `ColorPrevalence`=1, `AutoColorization`=1 (profil `Default`). Vérifié par lecture directe de `NTUSER.DAT` dans le WIM généré. **Non encore vérifié visuellement en VM.** Ne reproduit PAS un dégradé magenta/bleu réel sur les surfaces (Windows n'a qu'une seule couleur d'accent unie, pas de dégradé natif) — l'accent est une couleur unie extraite automatiquement du fond d'écran. |
| Gestion des fenêtres (Snap, coins arrondis, ombres) | `IMPLEMENTABLE` | Facile | Déjà natif à Windows 11 (Snap Layouts, coins arrondis DWM) — juste s'assurer que les réglages par défaut du profil `full.yaml` les activent |
| Widgets desktop persistants (météo mini-widget visible même hors du panneau Widgets) | `PLANNED` | Moyenne | App tierce légère (`apps/`) ou intégration Rainmeter/Lively, documentée comme dépendance tierce optionnelle |
| Interactions bureau (clic droit, icônes) | `IMPLEMENTABLE` | Facile | Stock Windows 11, non modifié |

## 🪟 Fenêtres

| Fonctionnalité | État | Faisabilité | Implémentation envisagée |
|---|---|---|---|
| Coins arrondis | `IMPLEMENTABLE` | Facile | Natif Win11 (DWM), déjà actif par défaut |
| Ombres | `IMPLEMENTABLE` | Facile | Natif Win11 |
| Transparence / matériau (Acrylic/Mica) | `IMPLEMENTABLE` | Facile | Natif Win11, réglage `Personnalisation > Couleurs > Effets de transparence` |
| Animations d'ouverture/fermeture | `IMPLEMENTABLE` | Facile | Natif Win11 |
| Snapping | `IMPLEMENTABLE` | Facile | Natif Win11 (Snap Layouts déjà avancé, pas besoin de recréer) |
| Transitions au redimensionnement | `IMPLEMENTABLE` | Facile | Natif Win11 |
| Style visuel des cartes vitrées "concept" (au-delà du Mica natif) | `CONCEPT ONLY` (pour les fenêtres système) | Difficile | Réservé aux apps tierces qu'on développe (`apps/`), pas aux fenêtres Explorer/Paramètres natives |

## 🟦 Barre des tâches

| Fonctionnalité | État | Faisabilité | Implémentation envisagée |
|---|---|---|---|
| Position (bas, centrée) | `IMPLEMENTED` | Facile | `builder/modules/46-theme.sh` : `TaskbarAl`=1 (icônes centrées, déjà le défaut Win11, réglé explicitement dans le profil `Default`) |
| Couleur d'accent visible sur la barre (fond sombre + teinte dérivée du wallpaper) | `IMPLEMENTED` | Facile | `builder/modules/46-theme.sh` : `ColorPrevalence`=1 + `AutoColorization`=1. Vérifié par lecture registre ; rendu visuel réel **non encore vérifié en VM**. |
| Barre flottante en pilule avec marges (coins très arrondis, détachée des bords) | `EXPERIMENTAL` / `UNTESTED` | Moyenne/Difficile | Voir `ui/taskbar/EXPERIMENTAL-floating-pill/README.md`. Mécanisme identifié (Windhawk), **documenté mais volontairement PAS intégré au pipeline automatique** — flag de profil `taskbar_floating_pill_experimental` désactivé par défaut dans `minimal.yaml` ET `full.yaml`. Quand activé, dépose uniquement de la documentation dans l'image (`builder/modules/48-taskbar-experimental.sh`), n'installe/n'exécute rien automatiquement. Aucun test visuel réel effectué (pas de boot Windows possible dans l'environnement de dev). Rollback : ne pas installer Windhawk, ou le désinstaller — aucune modification irréversible d'`explorer.exe`. |
| Widget météo intégré dans la barre | `PLANNED` | Moyenne | Dépend du même mécanisme de patch shell |
| Icônes (style, espacement) | `PARTIAL` | Facile (via thème d'icônes) | Pack d'icônes custom dans `assets/icons/` |
| Animations | `PARTIAL` | Facile | Natif Win11 en grande partie |
| Zone système (horloge, réseau, volume) | `IMPLEMENTABLE` | Facile | Natif Win11 |
| Interactions (survol, clic) | `IMPLEMENTABLE` | Facile | Natif Win11 |

## 🏠 Menu Démarrer

| Fonctionnalité | État | Faisabilité | Implémentation envisagée |
|---|---|---|---|
| Layout épinglé (grille d'apps) | `IMPLEMENTABLE` | Facile | Déjà natif à Win11 |
| Recherche intégrée | `IMPLEMENTABLE` | Facile | Déjà natif à Win11 |
| Salutation dynamique "Good Afternoon, [Nom]!" | `CONCEPT ONLY` (Start réel) / `PLANNED` (app tierce) | Difficile | App de remplacement tierce (`apps/start/`), jamais un patch du vrai `StartMenuExperienceHost` |
| Mini-carte horloge/calendrier dans le Démarrer | `PLANNED` | Difficile | App tierce |
| Rail alphabétique A-Z inline (fusion pinned + all apps) | `PLANNED` | Difficile | App tierce |
| Section "Your last activities" | `PARTIAL` | Facile (le natif a déjà "Recommended") | Réutilise le natif, renommage visuel seulement possible via app tierce |
| Animations d'ouverture | `IMPLEMENTABLE` | Facile | Natif Win11 |
| Design (cartes vitrées, dégradés) | `PLANNED` (natif limité) | Difficile | Réservé à l'app tierce ; le vrai Start ne peut pas être re-thémé aussi profondément |

## 📁 Explorateur

| Fonctionnalité | État | Faisabilité | Implémentation envisagée |
|---|---|---|---|
| Interface générale (dark mode, espacement) | `IMPLEMENTABLE` | Facile | Thème sombre natif + réglages |
| Onglets façon navigateur | `IMPLEMENTABLE` | Facile | Déjà natif à Win11 (22H2+) |
| Navigation (breadcrumb, historique) | `IMPLEMENTABLE` | Facile | Natif |
| Panneau latéral | `IMPLEMENTABLE` | Facile | Natif |
| Fonction "Tags" à puces de couleur | `CONCEPT ONLY` (intégration native) / `PLANNED` (app séparée) | Difficile | App/extension tierce de gestion de tags (métadonnées NTFS), pas d'injection dans le vrai panneau de navigation |
| Icônes | `PARTIAL` | Facile | Pack d'icônes custom |
| Animations | `IMPLEMENTABLE` | Facile | Natif |
| Menus contextuels | `IMPLEMENTABLE` | Facile | Natif, extensible via shell extensions si besoin |
| Position des toasts de notification (haut-droite vs bas-droite natif) | `CONCEPT ONLY` | Difficile | Non configurable proprement, non modifié |

## 🔔 Notifications / Quick Settings

| Fonctionnalité | État | Faisabilité | Implémentation envisagée |
|---|---|---|---|
| Centre de notifications (contenu, "Clear all") | `IMPLEMENTABLE` | Facile | Natif Win11 |
| Texte d'état vide personnalisé ("No more notifications") | `CONCEPT ONLY` | Difficile | Texte système, non éditable proprement |
| Réglages rapides (tuiles, sliders) — contenu | `IMPLEMENTABLE` | Facile | Natif Win11 |
| Style visuel (dégradés, coins) des Quick Settings | `CONCEPT ONLY` / `PLANNED` si patch shell | Difficile | Dépend du même patch shell que la barre des tâches |
| Widgets (météo, calendrier, tâches, notes) | `PARTIAL` | Facile (le natif existe) | Panneau Widgets natif de Win11 déjà très proche en fonction |
| Widget "News" avec sources | `PARTIAL` | Facile | Natif (piloté par Microsoft, contenu non personnalisable côté client) |
| "Widget settings" (interrupteurs par service) | `IMPLEMENTABLE` | Facile | Natif |
| Interactions/animations | `IMPLEMENTABLE` | Facile | Natif |

## ⚙️ Paramètres

| Fonctionnalité | État | Faisabilité | Implémentation envisagée |
|---|---|---|---|
| Interface / navigation générale | `IMPLEMENTABLE` | Facile | Structure déjà très proche du natif Win11, pas de reconstruction nécessaire |
| Pages Système / Personnalisation / Comptes etc. | `IMPLEMENTABLE` | Facile | Natif |
| Transition de thème "live" en plein écran (fondu coloré) | `PLANNED` | Moyenne | Overlay tiers déclenché sur changement de wallpaper/thème (watcher registre) |
| Sélecteur de thème (galerie de vignettes) | `IMPLEMENTABLE` | Facile | Natif, packs `.theme` custom dans `assets/themes/` |
| Composants (sliders, toggles) | `IMPLEMENTABLE` | Facile | Natif |
| Animations | `IMPLEMENTABLE` | Facile | Natif |

## 🔐 Écran de connexion

| Fonctionnalité | État | Faisabilité | Implémentation envisagée |
|---|---|---|---|
| Lock Screen — fond d'écran | `IMPLEMENTABLE` | Facile | Registre `PersonalizationCSP` / fichier de fond custom |
| Lock Screen — diaporama (plusieurs fonds) | `PARTIAL` (natif = auto, pas swipe) | Facile | Diaporama natif Win11 avec pack `assets/wallpapers/` |
| Lock Screen — swipe manuel + indice tactile | `CONCEPT ONLY` | Difficile | `LockApp.exe` fermé, non modifiable proprement |
| Login — salutation dynamique | `CONCEPT ONLY` | Difficile | `LogonUI` fermé, non modifiable proprement |
| Login — informations système affichées | `IMPLEMENTABLE` | Facile | Comportement déjà natif (nom de compte) |
| Animations (déverrouillage, transition blur) | `IMPLEMENTABLE` | Facile | Natif Win11 (effet Acrylic déjà présent) |

## 🏷️ Branding "Furax"

| Fonctionnalité | État | Faisabilité | Implémentation envisagée |
|---|---|---|---|
| "By FuraxDev" dans la boîte de dialogue "About Windows" (winver) | `IMPLEMENTED` | Facile | `builder/modules/42-branding.sh` : `RegisteredOwner`=Furax / `RegisteredOrganization`="By FuraxDev" (`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion`) — mécanisme standard Windows (licence affichée dans winver), pas un patch. Vérifié par lecture directe de la ruche SOFTWARE dans le WIM généré. **Rendu visuel réel dans winver non encore vérifié en VM.** |
| Informations OEM (fabricant/modèle) dans Paramètres | `PARTIAL` — à lire précisément, voir détail | Facile (écriture) / **incertaine (affichage)** | Deux choses bien distinctes à ne pas confondre : **(1) l'écriture registre** — `builder/modules/42-branding.sh` écrit `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation` (Manufacturer/Model/SupportURL) — **ça, c'est `IMPLEMENTED` et vérifié** : la clé et les valeurs ont été relues avec succès via `hivexget` directement dans le WIM généré, donc l'écriture fonctionne réellement. **(2) l'affichage dans l'interface Windows** — ça reste `UNCONFIRMED`, et honnêtement plus proche d'un doute que d'un "PARTIAL" optimiste : `OEMInformation` est historiquement un mécanisme de branding **Windows 7/8/10** (visible dans l'ancien Panneau de configuration → Système, onglet général, logo/fabricant). Le nouveau design "Paramètres → Système → À propos" de Windows 11 **n'a, à notre connaissance, pas de champ confirmé qui lise cette clé** — il se peut donc que ces informations ne s'affichent nulle part de visible dans l'UI moderne de Windows 11, même si la clé existe bel et bien en registre. **Ne pas présenter ce point comme "de la marque visible dans les Paramètres" tant qu'un test réel sur un Windows 11 démarré n'a pas confirmé où (ou si) ça s'affiche.** Le point fiable et démontrable pour la marque "Furax" reste `RegisteredOwner`/`RegisteredOrganization` (winver), voir la ligne au-dessus. |
| Numéro de build / nom de produit Windows modifié en "Windows 12.1" | `CONCEPT ONLY` | Très difficile | Le nom "Windows 11" et le numéro de build sont générés dynamiquement par le noyau/`ntoskrnl.exe`+ressources système signées, pas des chaînes de registre librement éditables sans casser la validation de version utilisée par de nombreux composants système et applications. Non tenté. |

## 🎨 Design System

Voir `docs/DESIGN_SYSTEM.md` pour le détail complet. Résumé de faisabilité :

| Aspect | État | Faisabilité |
|---|---|---|
| Couleurs (dégradé magenta↔bleu, palette) | `PLANNED` | Facile (accent color + assets) |
| Typographie | `IMPLEMENTABLE` | Facile (police système déjà proche ; personnalisation limitée sans casser la lisibilité système) |
| Tailles / espacements | `PARTIAL` | Moyenne (limité aux apps tierces) |
| Rayons (coins arrondis) | `IMPLEMENTABLE` | Facile (déjà natif) |
| Ombres | `IMPLEMENTABLE` | Facile (déjà natif) |
| Transparence / matériaux | `IMPLEMENTABLE` | Facile (déjà natif) |
| Icônes | `PLANNED` | Facile à Moyenne (pack d'icônes complet = travail de design) |
| Animations / transitions custom | `PARTIAL` | Difficile au-delà du natif |

---

## Synthèse : où l'effort de développement doit porter en priorité

1. **Facile, natif, haute valeur perçue** (Phase 2-3) : thème par défaut, wallpapers, accent color, alignement barre des tâches, coins/ombres/transparence (déjà actifs), icônes custom, sons.
2. **Moyenne difficulté, fort impact visuel** (Phase 4-5) : re-thème de la barre des tâches (patch shell tiers à évaluer sérieusement — c'est l'élément qui rapproche le plus visuellement du concept), diaporama de verrouillage, overlay de transition de thème.
3. **Difficile, nécessite des apps tierces dédiées** (Phase 5+) : Menu Démarrer personnalisé, widget board maison, Explorateur "Tags".
4. **`CONCEPT ONLY`, ne pas tenter** : LogonUI, LockApp, StartMenuExperienceHost en profondeur, position des toasts, build number falsifié. *(Mise à jour 12/09/2026 : le fond d'écran de l'assistant Setup/boot USB, lui, s'est révélé faisable et est maintenant `IMPLEMENTED` — voir `builder/modules/44-installer-background.sh` ci-dessous. Ne pas généraliser trop vite le "CONCEPT ONLY" avant d'avoir vraiment inspecté le WIM concerné.)*

## 💿 Installateur Windows Setup (boot USB)

| Fonctionnalité | État | Faisabilité | Implémentation envisagée |
|---|---|---|---|
| Fond d'écran de l'assistant Setup (écran bleu au boot USB) | `IMPLEMENTED` | Facile (une fois localisé) | `builder/modules/44-installer-background.sh` : monte `boot.wim` (index 2 "Microsoft Windows Setup", séparé d'`install.wim`), remplace `sources/background.bmp` ET `Windows/System32/setup.bmp` — malgré l'extension `.bmp` ce sont en réalité des PNG RGBA (confirmé via `file`), 1024×768 sur l'ISO 25H2 testée. Build réel exécuté avec succès (06/09/2026), fichiers confirmés remplacés après commit/démontage. **Rendu visuel réel au boot non encore vérifié en VM** (`TESTED` réservé à ça). |
| Mise en page / style des boutons et texte de l'assistant | `CONCEPT ONLY` | Très difficile | Compilé en ressources PE dans `SetupPlatform.exe`/`SetupHost.exe` — pas de fichier séparé équivalent au background, patch de ressources PE natif Windows non tenté (nécessiterait Resource Hacker ou équivalent, pas d'outil Linux fiable identifié) |
| Animation de progression (points qui tournent) pendant la copie | `CONCEPT ONLY` | Très difficile | Ressource compilée, idem ci-dessus |
| Pré-remplissage langue/région/clavier | `IMPLEMENTABLE` | Facile | `autounattend.xml` à la racine de l'ISO — mécanisme Microsoft standard et documenté, non exploité pour l'instant |
| Saut d'écrans (licence, choix édition) via réponses automatiques | `IMPLEMENTABLE` | Facile | `autounattend.xml`, idem |
| Logo/watermark additionnel sur le fond Setup (au-dessus du dégradé) | `PLANNED` | Facile | Variante de `prepare_installer_background.py` avec `overlay_logo()` (déjà écrit pour le wallpaper bureau, réutilisable) |

---

## 💡 Backlog d'idées (100 pistes, non triées par priorité — brainstorm brut)

Liste de fonctionnalités/idées supplémentaires envisageables pour le projet, au-delà de ce qui est directement inspiré de la vidéo concept. **Aucune de ces lignes n'est implémentée** sauf mention contraire — c'est un backlog de brainstorm, pas un plan engagé. Chaque catégorie suit la même règle d'honnêteté que le reste du document.

### ⚡ Performance & ressources système

| # | Idée | État | Note |
|---|---|---|---|
| 1 | Profil de build "léger" (moins de composants optionnels, WIM plus petit) | `PLANNED` | Voir `builder/profiles/lite.yaml` — juste ajouté, voir plus bas |
| 2 | Désactivation par défaut des apps préinstallées inutiles (bloatware Xbox/Office promo/etc.) | `PLANNED` | Faisable via suppression de packages provisionnés dans le WIM (`dism /Remove-ProvisionedAppxPackage` côté Windows, ou édition directe du WIM côté Linux) |
| 3 | Mode "batterie longue durée" pré-configuré (plan d'alimentation custom) | `PLANNED` | Registre `powercfg`, faisable offline |
| 4 | Détection auto de la RAM dispo côté VM de test et ajustement auto (déjà partiellement fait dans `launch-viewer.sh`) | `PARTIAL` | À généraliser (voir section resources ci-dessous) |
| 5 | Nettoyage auto des anciens builds/ISOs dans `build/_out` (éviter accumulation disque) | `PLANNED` | Flag `--clean-old-outputs` sur `build.sh` |
| 6 | Édition WIM "Core"/"Home" par défaut plutôt que Pro (empreinte disque installée plus faible) | `IMPLEMENTABLE` | Déjà possible via `--wim-index`, pas encore le défaut documenté clairement |
| 7 | Désactivation de la recherche indexée par défaut (moins de CPU/disque en fond) | `PLANNED` | Registre `WSearch` service start type |
| 8 | Superfetch/Prefetch désactivé pour SSD | `PLANNED` | Registre `SysMain` |
| 9 | Mode "faible RAM" désactivant les effets de transparence/animations automatiquement si <4 Go détectés | `PLANNED` | Nécessiterait un script post-install (PowerShell), pas encore écrit |
| 10 | Compression WIM plus agressive (LZMS) pour réduire la taille de l'ISO finale | `PLANNED` | `wimlib-imagex` supporte LZMS, pas encore testé dans le pipeline |

### 🔒 Sécurité & confidentialité

| # | Idée | État | Note |
|---|---|---|---|
| 11 | Désactivation télémétrie par défaut (niveau "Basique" au lieu de "Complet") | `PLANNED` | Registre `AllowTelemetry`, standard et documenté |
| 12 | Pare-feu avec profil "strict" par défaut | `PLANNED` | `netsh advfirewall` offline via script post-install |
| 13 | Compte local par défaut à l'OOBE (pas de compte Microsoft forcé) | `IMPLEMENTABLE` | `autounattend.xml`, mécanisme bien connu (`BypassNRO`) |
| 14 | Désactivation Cortana/Copilot au premier démarrage | `PLANNED` | Registre + `autounattend.xml` |
| 15 | Windows Defender pré-configuré en mode "silencieux" (moins de popups) | `PLANNED` | Registre notifications Defender |
| 16 | Chiffrement BitLocker proposé (pas forcé) dès l'installation | `CONCEPT ONLY` | Dépend du matériel (TPM), pas pilotable de façon fiable depuis le builder offline |
| 17 | Blocage des apps "suggérées" dans le Menu Démarrer (pub) | `IMPLEMENTABLE` | Registre `HKCU\...\ContentDeliveryManager` |
| 18 | Nettoyeur de permissions apps (audit visuel des accès caméra/micro) | `PLANNED` | App tierce (`apps/`) |
| 19 | Mode "invité sécurisé" (session éphémère qui efface tout à la fermeture) | `CONCEPT ONLY` | Windows 11 a retiré le compte Invité natif ; recréation via script complexe et fragile |
| 20 | VPN/Proxy système pré-configurable via profil de build | `PLANNED` | Registre réseau, offline |

### 🎮 Jeux & performance graphique

| # | Idée | État | Note |
|---|---|---|---|
| 21 | Mode Jeu activé par défaut | `IMPLEMENTABLE` | Registre `AllowAutoGameMode` |
| 22 | Xbox Game Bar désactivée par défaut (préférence perf) | `IMPLEMENTABLE` | Registre `AppCaptureEnabled` |
| 23 | Overlay FPS natif activé | `IMPLEMENTABLE` | Registre Game Bar |
| 24 | Profil GPU "performance" par défaut (plutôt qu'équilibré) | `PLANNED` | Dépend du fabricant GPU (Intel/AMD/NVIDIA), pas uniforme |
| 25 | Auto-HDR activé par défaut | `IMPLEMENTABLE` | Registre, natif Win11 |
| 26 | VRR (Variable Refresh Rate) activé par défaut si supporté | `IMPLEMENTABLE` | Registre, natif Win11 |
| 27 | Optimisation plein écran désactivée par défaut (moins de latence input) | `IMPLEMENTABLE` | Registre par app, complexe à généraliser |
| 28 | Raccourci "Mode Jeu Furax" (bascule rapide perf) dans la barre des tâches | `PLANNED` | Nécessiterait une mini-app tierce |
| 29 | Détection auto GPU et suggestion de pilotes à jour au premier boot | `CONCEPT ONLY` | Hors du périmètre offline du builder |
| 30 | Wallpaper dynamique réactif au FPS (concept gadget) | `CONCEPT ONLY` | Idée gadget, pas de mécanisme Windows natif pour ça |

### 🗂️ Productivité & multitâche

| # | Idée | État | Note |
|---|---|---|---|
| 31 | Bureaux virtuels nommés/thémés par défaut (Travail/Perso/Jeux) | `IMPLEMENTABLE` | Natif Win11, config possible via script post-install |
| 32 | Raccourcis clavier custom pré-configurés (façon "Furax shortcuts") | `PLANNED` | Registre `HKCU\...\Keyboard Layout` |
| 33 | PowerToys pré-installé et pré-configuré (FancyZones, etc.) | `PLANNED` | App tierce Microsoft officielle, installable offline via provisioning |
| 34 | Presse-papiers multi-éléments activé par défaut | `IMPLEMENTABLE` | Registre `EnableClipboardHistory`, natif Win11 |
| 35 | Snap Layouts avec préréglages custom (grilles Furax) | `CONCEPT ONLY` | Windows ne permet pas de définir des grilles Snap custom nativement |
| 36 | Barre des tâches multi-écrans avec réglages indépendants | `IMPLEMENTABLE` | Natif Win11, réglage existant |
| 37 | Mode "focus"/Ne pas déranger programmable par horaire | `IMPLEMENTABLE` | Natif Win11 (Focus Assist), config par défaut possible |
| 38 | Widget "notes rapides" épinglable au bureau | `PLANNED` | App tierce légère |
| 39 | Historique du presse-papiers synchronisé (opt-in) | `IMPLEMENTABLE` | Natif Win11, nécessite compte Microsoft (à documenter comme tel) |
| 40 | Terminal Windows pré-configuré avec thème Furax (couleurs, police) | `PLANNED` | Fichier `settings.json` de Windows Terminal, déposable dans le profil par défaut |

### ♿ Accessibilité

| # | Idée | État | Note |
|---|---|---|---|
| 41 | Contrastes élevés en option pré-visible dans le sélecteur de thème | `IMPLEMENTABLE` | Natif Win11 |
| 42 | Narrateur avec voix française par défaut si langue FR détectée | `IMPLEMENTABLE` | Natif, dépend de la langue d'installation choisie |
| 43 | Curseur agrandi par défaut en option facile d'accès à l'OOBE | `IMPLEMENTABLE` | Natif Win11, réglage OOBE |
| 44 | Sous-titres système activés par défaut sur médias | `IMPLEMENTABLE` | Natif Win11 |
| 45 | Mode "lecture facile" (police plus grande, espacement) en un clic | `PLANNED` | Combo de réglages existants, pas de bouton unique natif |
| 46 | Reconnaissance vocale système pré-activée | `IMPLEMENTABLE` | Natif Win11, opt-in |
| 47 | Filtres de couleur (daltonisme) accessibles depuis Quick Settings | `PARTIAL` | Natif dans Paramètres, pas dans Quick Settings par défaut |
| 48 | Zoom d'écran avec raccourci Furax dédié | `PLANNED` | Registre raccourcis |
| 49 | Retour haptique clavier virtuel renforcé | `CONCEPT ONLY` | Dépend du matériel, pas pilotable de façon fiable |
| 50 | Thème audio (sons système) pensé accessibilité (sons distincts) | `PLANNED` | Pack de sons `.wav` custom, mécanisme natif de thème sonore |

### 🌐 Réseau & connectivité

| # | Idée | État | Note |
|---|---|---|---|
| 51 | Profil réseau "Privé" par défaut sur les nouveaux réseaux (au lieu de demander) | `IMPLEMENTABLE` | Registre, mais impact sécurité à documenter clairement si activé |
| 52 | DNS pré-configuré (ex. Cloudflare/Quad9) en option au build | `PLANNED` | Registre interface réseau |
| 53 | Partage de connexion (hotspot) accessible en un clic depuis Quick Settings | `IMPLEMENTABLE` | Déjà natif Win11 |
| 54 | Mode avion programmable par horaire | `CONCEPT ONLY` | Pas de mécanisme natif de programmation horaire pour ça |
| 55 | Détection réseau lent et bascule auto vers mode "économie de données" | `IMPLEMENTABLE` | Natif Win11 (partiellement), réglage existant |
| 56 | Bluetooth désactivé par défaut (économie batterie) avec réactivation rapide | `IMPLEMENTABLE` | Registre |
| 57 | Partage de fichiers local simplifié (façon AirDrop) entre PC Furax | `CONCEPT ONLY` | Nécessiterait une vraie app propriétaire, hors périmètre |
| 58 | VPN intégré au profil de build (config WireGuard pré-remplie, opt-in) | `PLANNED` | Faisable offline si l'utilisateur fournit sa propre config |
| 59 | Indicateur de qualité Wi-Fi détaillé (dBm) dans la barre des tâches | `CONCEPT ONLY` | Nécessiterait un patch shell, comme la barre pilule |
| 60 | Historique des connexions réseau consultable simplement | `IMPLEMENTABLE` | Natif via Event Viewer, pas d'UI dédiée simple nativement |

### 🤖 IA & assistant

| # | Idée | État | Note |
|---|---|---|---|
| 61 | Copilot désactivé par défaut (opt-in explicite) | `IMPLEMENTABLE` | Registre `TurnOffWindowsCopilot` |
| 62 | Assistant vocal local léger (alternative offline à Copilot) | `CONCEPT ONLY` | Développement d'app IA complet, hors périmètre de ce projet de customisation ISO |
| 63 | Résumé auto des notifications manquées (façon "digest") | `CONCEPT ONLY` | Nécessiterait une app tierce avec accès notifications |
| 64 | Recherche Windows augmentée par IA locale (recherche sémantique fichiers) | `CONCEPT ONLY` | Hors périmètre, projet de customisation pas de moteur IA |
| 65 | Raccourci "Furax Assistant" configurable (ouvre l'app IA de son choix) | `PLANNED` | Simple raccourci clavier/menu, faisable |

### 🎵 Multimédia

| # | Idée | État | Note |
|---|---|---|---|
| 66 | Lecteur multimédia natif re-thémé (accent Furax) | `PARTIAL` | Le lecteur Windows Media Player natif hérite déjà de l'accent système |
| 67 | Codecs additionnels pré-installés (via provisioning) | `PLANNED` | Provisioning package offline, faisable |
| 68 | Egaliseur audio système accessible depuis Quick Settings | `CONCEPT ONLY` | Pas de mécanisme natif, dépend du pilote audio |
| 69 | Mode "Cinéma" (assombrit l'écran, désactive notifications) en un raccourci | `PLANNED` | Combo Focus Assist + luminosité, scriptable |
| 70 | Wallpaper Spotlight (rotation quotidienne d'images officielles Bing/Windows) activé par défaut | `IMPLEMENTABLE` | Natif Win11, juste activer le réglage par défaut |
| 71 | Thème sonore complet "Furax" (démarrage, notifications, erreurs) | `PLANNED` | Pack `.wav` + fichier `.theme`, mécanisme natif |
| 72 | Capture d'écran améliorée (annotations rapides intégrées) | `IMPLEMENTABLE` | Déjà natif Win11 (Outil Capture d'écran) |
| 73 | Enregistrement d'écran système avec watermark Furax optionnel | `CONCEPT ONLY` | Nécessiterait modification de l'app Xbox Game Bar, non supporté |
| 74 | Visionneuse de photos par défaut re-thémée | `IMPLEMENTABLE` | Registre associations de fichiers |
| 75 | Radio/webradio intégrée en widget | `PLANNED` | App tierce légère |

### 💽 Installation, maintenance & mises à jour

| # | Idée | État | Note |
|---|---|---|---|
| 76 | `autounattend.xml` complet (langue, edition, partitionnement pré-rempli) | `PLANNED` | Mécanisme Microsoft standard, gros gain d'ergonomie pour l'installeur |
| 77 | Écran de bienvenue post-install "Bienvenue sur Furax Windows 12" | `PLANNED` | Script `RunOnce` au premier login, faisable |
| 78 | Mises à jour Windows différées de X jours par défaut (stabilité) | `IMPLEMENTABLE` | Registre `DeferFeatureUpdates` |
| 79 | Point de restauration auto créé juste après l'installation | `PLANNED` | Script post-install PowerShell |
| 80 | Vérification d'intégrité (SFC/DISM) programmée en tâche planifiée mensuelle | `PLANNED` | Tâche planifiée offline, faisable |
| 81 | Sauvegarde auto vers un dossier local dès la configuration initiale | `PLANNED` | Configuration "Historique des fichiers" via script |
| 82 | Rollback en un clic depuis un raccourci bureau (déjà en partie fait) | `IMPLEMENTED` | Voir `scripts/rollback/Rollback-FuraxWindows12.ps1`, juste ajouter un raccourci bureau au dépôt |
| 83 | Rapport de santé système (espace disque, RAM, température) au démarrage | `CONCEPT ONLY` | Nécessiterait une app de monitoring dédiée |
| 84 | Nettoyage auto des fichiers temporaires programmé | `IMPLEMENTABLE` | Tâche planifiée native `cleanmgr` |
| 85 | Mode "installation silencieuse" complet sans interaction (entreprise) | `PLANNED` | `autounattend.xml` poussé à fond, cas d'usage différent du profil grand public |

### 🎨 Personnalisation avancée

| # | Idée | État | Note |
|---|---|---|---|
| 86 | Galerie de wallpapers Furax (plusieurs variantes, pas qu'une seule) | `PLANNED` | Juste ajouter des assets dans `assets/wallpapers/` + logique de sélection au build |
| 87 | Curseurs de souris custom (pack assorti au thème) | `PLANNED` | Mécanisme natif `.inf` de pack de curseurs, faisable offline |
| 88 | Icônes système custom (dossiers, corbeille, ce PC) | `PLANNED` | Registre `Shell Icons`, faisable |
| 89 | Police système alternative (si lisibilité confirmée) | `PLANNED` | Remplacement de police système = risque de casse UI, à tester prudemment |
| 90 | Sons de démarrage custom | `PLANNED` | Mécanisme natif `.wav` de son de démarrage |
| 91 | Écran de veille custom (vagues animées Furax) | `PLANNED` | `.scr` natif Windows, faisable |
| 92 | Thème clair alternatif (pas que sombre) avec la même identité visuelle | `PLANNED` | Variante du travail déjà fait sur le thème sombre |
| 93 | Fonds d'écran adaptatifs (différents par heure de la journée) | `IMPLEMENTABLE` | Natif Win11 ("Windows Spotlight" ou diaporama programmé) |
| 94 | Pack de thème complet exportable/partageable (`.deskthemepack`) | `PLANNED` | Format natif Windows, packaging à faire |

### 🧪 Outillage projet (pas des features Windows, mais utiles au dev)

| # | Idée | État | Note |
|---|---|---|---|
| 95 | Profil de build `lite.yaml` optimisé ressources | `IMPLEMENTED` | Ajouté à l'instant, voir `builder/profiles/lite.yaml` |
| 96 | Détection auto de RAM dispo dans `launch-viewer.sh`/`.ps1` (ajuste `--ram` automatiquement) | `PLANNED` | Amélioration des scripts existants, pas encore faite |
| 97 | `osh` : mode "batch" pour envoyer plusieurs commandes en une fois (moins de latence Supabase) | `PLANNED` | Amélioration de `tools/openconnect/osh` |
| 98 | Tests automatisés du builder en CI (GitHub Actions) sur une ISO factice | `PLANNED` | Nécessiterait une ISO de test légère, pas la vraie Windows (droits de distribution) |
| 99 | Dashboard web de suivi des builds (historique, tailles, features actives) | `PLANNED` | Petit artifact/app séparée, hors périmètre immédiat |
| 100 | Documentation vidéo (screencast) du build de bout en bout | `PLANNED` | Nécessite un boot VM confirmé d'abord (prérequis non encore validé) |
