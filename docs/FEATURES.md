# FEATURES.md — Inventaire des fonctionnalités

Basé sur `docs/VIDEO_ANALYSIS.md`. États possibles : `PLANNED` (pas commencé), `PROTOTYPE` (ébauche non fiable), `PARTIAL` (fonctionne partiellement), `IMPLEMENTED` (fonctionne), `TESTED` (fonctionne + vérifié en VM Windows), `CONCEPT ONLY` (non réalisable proprement — alternative documentée), `IMPLEMENTABLE` (déjà natif à Windows 11, réglage/registre suffisant, non encore branché au builder).

**Au 04/09/2026 : le pipeline de build (Phase 2) est validé de bout en bout contre une vraie ISO Windows 11 25H2 officielle. La première fonctionnalité UI réelle (fond d'écran par défaut, voir Desktop ci-dessous) est `IMPLEMENTED` — mécanisme confirmé par extraction/lecture directe du WIM généré, mais boot réel en VM `PLANNED` (pas encore testé). Tout le reste du tableau ci-dessous reste `PLANNED` tant que non implémenté.**

---

## 🖥️ Desktop

| Fonctionnalité | État | Faisabilité | Implémentation envisagée |
|---|---|---|---|
| Fond d'écran par défaut du bureau (image statique façon "vagues" bleu/magenta) | `IMPLEMENTED` | Facile | `builder/modules/45-wallpaper.sh` : remplace `Windows/Web/Wallpaper/Windows/img0.jpg` (fond par défaut, chemin confirmé sur une vraie ISO Win11 25H2) par `assets/wallpapers/furax-wave-primary.jpg` (redimensionné en cover-fit), + configure `HKCU\Control Panel\Desktop` du profil `Default` (WallPaper/WallpaperStyle=10/TileWallpaper=0) pour que les nouveaux comptes l'utilisent en mode Remplir. Vérifié : fichier remplacé et clés registre confirmées présentes dans le WIM généré (extraction directe). **Non encore vérifié : rendu réel au premier login dans une VM** (`TESTED` réservé à ça). |
| Fond d'écran "vagues" **animé** (vidéo/parallaxe en fond de bureau) | `PLANNED` | Difficile | Nécessiterait un wallpaper engine tiers (ex. Lively Wallpaper) — pas dans ce projet à ce stade |
| Logo "Win12" géant flottant sur le bureau | `PLANNED` | Facile | Asset intégré au wallpaper, ou petit widget desktop overlay |
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
4. **`CONCEPT ONLY`, ne pas tenter** : ré-habillage du Setup/OOBE natif, LogonUI, LockApp, StartMenuExperienceHost en profondeur, position des toasts, build number falsifié.
