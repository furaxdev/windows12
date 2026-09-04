# VIDEO_ANALYSIS.md — Analyse de la vidéo concept "Windows 12.1"

**Méthode d'analyse.** La vidéo fournie (`Windows_12.1.mp4`, 1920×1080, 60 fps, 10:24 min, avec piste audio) a été échantillonnée en **208 frames, une toutes les 3 secondes**, du début à la fin (`ffmpeg -vf fps=1/3`). Chaque frame a été **effectivement ouverte et inspectée visuellement**, image par image, dans l'ordre chronologique (aucun résumé auto généré, aucune frame sautée) — le travail a été réparti en 4 segments (00:00–02:33, 02:36–05:09, 05:12–07:45, 07:48–10:21) pour couvrir l'intégralité de la vidéo. Aucune transcription audio n'a pu être réalisée (aucun outil de reconnaissance vocale disponible hors-ligne dans cet environnement) — l'analyse se fonde donc uniquement sur l'image. La vidéo ne semble de toute façon pas comporter de voix off scriptée : c'est une démo silencieuse/musicale type "concept showcase", avec un carton de fin explicite.

**Disclaimer présent dans la vidéo elle-même** (10:09) : *"I'm not affiliated by Microsoft. This video is just showing a Concept for the next generation of Microsoft Windows."* — confirmé par du texte à l'écran manifestement non natif/anglais approximatif ("This is not take a long, just sit relax.", "This not have a long, just relax.", "Add a Biometrics", "Hmmm... Now let's swipe up, and see what's happens.") : ceci est **une vidéo concept fan-made**, pas du contenu Microsoft officiel, et une partie du contenu (données de démo type "Ngtest.docx", doublons "Paint"/"Solitaire" dans les listes) est manifestement du **mock data de démonstration**, pas des captures d'un vrai OS fonctionnel.

## 1. Résumé général du concept

La vidéo montre de bout en bout : (1) l'installation complète d'un "Windows 12.1" fictif (choix de langue → activation/clé produit → édition → licence → type d'installation → partition → progression d'installation → redémarrage → OOBE), (2) l'OOBE (nom de l'appareil, région, clavier, compte perso/pro, personnalisation thème/couleur/fond d'écran, connexion Microsoft, PIN, biométrie "Face ID"/empreinte, restauration d'un ancien PC), (3) le bureau et le shell complet en usage (bureau, barre des tâches, Menu Démarrer, recherche, Explorateur de fichiers, Paramètres, widgets, Centre de notifications, Réglages rapides, écran de verrouillage, écran de connexion, arrêt), et se termine par un carton de remerciement/abonnement YouTube.

L'identité visuelle est cohérente sur toute la durée : fond dégradé animé "vagues" bleu-nuit → magenta → violet, logo Windows à 4 quadrants recoloré en dégradé rose/bleu (au lieu des 4 couleurs plates de Win11), boutons pilule en dégradé magenta→bleu, cartes vitrées translucides/floutées à coins très arrondis (~12-20px), typographie blanche/claire sur fond sombre, une salutation personnalisée ("Good Afternoon, Abdi!") réutilisée sur Démarrer/Verrouillage/Connexion, et une icône "feuille orange" façon Copilot en haut à droite des surfaces de recherche/widgets.

## 2. Analyse chronologique (avec timestamps)

### 00:00–02:33 — Installation ("Windows Setup")
- **00:00** — Écran de démarrage noir : logo 4 quadrants (rouge/vert/bleu/jaune) qui se fond en version dégradée bleu→magenta, spinner circulaire blanc dessous. Diffère du spinner à points nu de Win11 (pas de logo coloré animé).
- **00:09** — Écran de langue : fond plein écran en vagues animées (bleu/violet/magenta), carte sombre translucide centrée-gauche (coins ~12-16px, fond flouté), titre "Windows 12.1", 3 listes déroulantes (langue, format, clavier) affichées avec un simple **soulignement en dégradé** au lieu des combo-box encadrées de Win11, bouton "Next" pilule en dégradé.
- **00:21** — Écran "Activate Windows" : indicateur d'étapes en bas ("1 Collecting information / 2 Installing Windows") avec barre de progression pleine largeur (élément absent de l'OOBE Win11 actuel sous cette forme). Illustration animée (badge vert à ondes concentriques + curseur main jaune). Champ de clé produit avec un **soulignement rouge type correcteur orthographique** sous la clé saisie (artefact probablement non intentionnel).
- **00:39** — Écran "Choose your edition" : liste de **6 éditions** (Pro, Home, Enterprise, Education, Pro Education, SE) — absent du parcours grand public normal de Win11 (n'apparaît que sur ISO multi-édition).
- **00:42** — Écran de licence classique (case à cocher + texte légal).
- **00:45** — Type d'installation : "Upgrade" (désactivé, note "start the installation from Windows") vs "Custom" — cartes sélectionnables à bordure dégradée.
- **00:54** — Sélection de partition : tableau Nom/Taille/Espace libre/Type très proche de l'UI réelle de Windows Setup.
- **01:00** — "Installing Windows" : check-list 5 étapes (Copying/Extracting/Installing features/Installing updates/Finishing up) avec **icônes illustrées différentes par étape** (dossiers, engrenage, flèche de téléchargement, disque+coche verte) — Win11 n'anime pas d'icône différente par étape.
- **01:17** — Écran "Restart".
- **01:20–01:44** — Redémarrage : logo 4 quadrants dégradé, puis écrans texte noir/blanc "Setup is updating registry settings" / "Getting ready" / "Setup is starting services..." (style proche du Win11 réel).
- **01:53** — Reprise du flux "Installing Windows" (second passage), toutes les étapes cochées sauf "Finishing up" — cohérent avec le comportement réel en deux phases de Windows Setup.

### 02:36–06:03 — OOBE (Out-of-Box Experience)
- **02:36–03:00** — Fin d'installation, redémarrage, logo de boot.
- **03:06** — Premier démarrage : lockup "Windows 12.1" en haut, "Get ready to running your PC for first use", puis "Checking your performance" avec barre de progression en dégradé.
- **03:18** — Le fond passe en plein écran aux vagues colorées (bascule visuelle nette), header persistant "Windows 12.1 Pro" (édition précisée), carte de wizard "Set Up Windows" avec flèche retour + icônes aide/réglages en bas à droite — template réutilisé pour tout le reste de l'OOBE.
- **03:27** — "Let's name your device" (nom de l'appareil, règles de validation affichées).
- **03:33** — "Is this the right country or region?" avec recherche + liste filtrable.
- **03:42** — Disposition clavier secondaire (option).
- **03:51** — "How would you like to set up this device?" (perso vs pro), sélection à bordure dégradée.
- **04:00–04:15** — "Personalize your device" : **choix de thème** (2 vignettes "Aa"), **slider dégradé↔couleur unie** pour l'accent, palette de couleurs, **grille de fonds d'écran** (3×2). Fait notable : à 04:03 le fond d'écran global de tout l'écran de setup **change de teinte en direct** pendant la prévisualisation du thème (effet réactif non présent dans Win11 Setup).
- **04:18** — Connexion au compte Microsoft (icônes Edge/OneDrive/Store/Xbox/Teams/Office réutilisées telles quelles), champ email puis mot de passe.
- **04:27** — Configuration du **PIN** (Windows Hello).
- **04:33** — **"Add a Biometrics"** : texte "*Windows 12.1 have a new Biometric on lock screen, they are Face ID And Fingerprint*" — **utilise explicitement le terme "Face ID"** (terminologie Apple, pas la marque réelle "Windows Hello Face").
- **04:36–04:51** — Capture d'empreinte avec **anneau de progression circulaire vert animé** autour de l'icône d'empreinte (scan en 3 étapes visuelles).
- **04:54–05:09** — "Welcome back, Abdi!" avec choix "Restore from DESKTOP-..." vs "Set up as new device" (flux de restauration façon OneDrive/compte existant).
- **05:24** — "Let's customize your experience" (cases Gaming/School/Family/Entertainment/Creativity/Business).
- **05:30** — Choix OneDrive (stockage cloud vs local).
- **05:33** — Offre d'essai Microsoft 365.
- **05:36** — Écran "Thank you!" de fin d'OOBE.
- **05:39–06:03** — Séquence de finalisation ("Now we prepare your desktop...", "Getting ready…", "Almost ready…"), logo central, puis **révélation du bureau**.

### 06:03–06:45 — Bureau, Menu Démarrer, Explorateur
- **06:03** — Premier bureau : fond en vagues animées, **grand logo décoratif "Win12" semi-transparent flottant au milieu-droite du bureau** (élément permanent, absent de Win11), pas d'icônes de bureau visibles. **Barre des tâches flottante centrée en pilule** (pas pleine largeur, coins très arrondis ~20px) avec un **widget météo intégré directement dans la barre** ("28° Sunny, H:34°/L:23°") — différent de Win11 où la météo est un simple bouton dans le coin, pas un widget intégré.
- **06:03–06:15** — **Menu Démarrer** : en-tête avec avatar utilisateur + salutation dynamique "Good Afternoon, Abdi!" + email (absent de Win11), mini-carte calendrier/horloge, barre de recherche pleine largeur, section "Pinned" (grille 6×2), section "Your last activities" (fichiers récents en cartes 2×2). Une **liste alphabétique "Toutes les applications" est fusionnée dans la même vue** (rail d'index A-Z) au lieu d'un écran séparé comme sous Win11.
- **06:18–06:36** — **Explorateur de fichiers** : thème sombre complet, **onglets façon navigateur** avec icône dossier-étoile colorée, barre de commande similaire à Win11 mais plus espacée, barre d'adresse + **champ de recherche pilule séparé et très arrondi**, panneau gauche avec **fonctionnalité "Tags" à puces de couleur** (Rouge/Bleu/Jaune/Vert/Orange/Violet/Rose — absente de Win11), mini-barre de capacité disque. Menu contextuel clic-droit sur clé USB → éjection → **toast de notification en haut à droite** (Win11 l'affiche en bas à droite — déviation délibérée de placement).

### 06:45–08:06 — Paramètres, thème dynamique, "About Windows"
- **06:45** — Ouverture de l'app **Paramètres** (icône engrenage en chargement).
- **06:48** — Page **Système** : structure de navigation très proche de Win11 (Bluetooth, Réseau, Personnalisation, Comptes, etc.), carte appareil avec specs, liste Affichage/Son/Notifications/Focus/Alimentation.
- **06:57–07:03** — Page **Personnalisation** : galerie de thèmes, et surtout — en sélectionnant un nouveau thème, **tout l'écran (fenêtre Paramètres + fond d'écran + barre des tâches) bascule en direct vers une palette rose/violette plus claire avec une transition en fondu** : un vrai "live re-theme" que Win11 ne fait pas de façon aussi spectaculaire/immédiate.
- **07:06** — Panneau de **recherche** distinct du Menu Démarrer, en matériau clair/translucide (contraste avec le reste de l'UI sombre) avec sections "Recommended", "Fast search" (puces de raccourcis vers des pages de Paramètres, en dégradé) et "Top apps".
- **07:48–08:03** — Recherche d'app ("winver") → boîte de dialogue **"About Windows"** confirmant : **"Windows 12.1 Pro", Version 24H2, OS Build 26000.190**, utilisateur "Abdi".

### 08:06–08:39 — Widgets
- **08:09** — Panneau **Widgets** pleine hauteur ouvert depuis le bord gauche : colonne gauche (météo, calendrier, icônes rapides, liste de tâches "My Tasks", note autocollante jaune), colonne droite **"News"** (articles avec images, sources factices "Le Tech", "9to5Mac.com", "Techplaceug.com" — dont un titre méta-ironique *"20 Reasons why you love AR OS than Windows"*).
- **08:18–08:33** — Sous-panneau **"Widget settings"** : liste de services avec interrupteurs à bascule (Calculator, Calendar, Clock, Contacts, Currency, Feed Headlines, Media Player, Microsoft News) + lien "Get more widgets in Microsoft Store".

### 08:39–09:45 — Réglages rapides, notifications, verrouillage, connexion
- **08:39** — La barre des tâches passe d'un alignement **centré à un alignement à gauche** entre deux segments — probablement une coupe de montage démontrant les deux modes d'alignement disponibles dans les Paramètres (non capturé explicitement à l'écran dans les frames échantillonnées).
- **08:51** — **Réglages rapides** (Quick Settings) : grille de tuiles Wi-Fi/Bluetooth/Avion/Capture/Tablette/Accessibilité, curseurs Luminosité/Volume avec poignée dégradée rose, mini-carte appareil "ABDI-PC" avec specs.
- **09:03** — **Centre de notifications** : cartes de notification (USB éjectée, "Welcome to Windows"), bloc date/calendrier avec grand logo décoratif, footer compte (avatar, nom, "Sign Out"/"Lock PC"/"Switch user"). "Clear all" → état vide **"No more notifications"** (Win11 affiche "No new notifications").
- **09:15–09:27** — **Écran de verrouillage** : horloge "12:00", indice tactile "Swipe left or right to change the background", puis **carrousel swipeable de 3 fonds d'écran photographiques** (skyline nocturne, lac/montagne, bord de mer tropical) façon "Spotlight" mais navigable manuellement — Win11 n'offre pas ce swipe manuel sur l'écran de verrouillage.
- **09:30** — **Écran de connexion** : fond flouté (Acrylic/Mica) dérivé du fond de verrouillage, avatar circulaire, salutation dynamique "Good Afternoon, Abdi!" (au lieu du simple nom de compte statique de Win11), champ PIN, icône d'empreinte/chargement animée.

### 09:48–10:24 — Démarrer (vue complète), arrêt, fin
- **09:48** — Menu Démarrer complet à nouveau, mêmes éléments que 06:03 (salutation, épinglés, activités récentes, rail alphabétique).
- **09:54–10:03** — Séquence d'**arrêt** : fond flouté, spinner, texte "Shutting down...".
- **10:06** — Carton noir "Thanks for Watching!".
- **10:09–10:24** — Disclaimer explicite ("not affiliated by Microsoft... just a Concept"), écran de fin YouTube standard (emplacements vidéos suggérées + bouton "SUBSCRIBE"). Fin de vidéo.

## 3. Liste exhaustive des changements identifiés vs Windows 11

Chaque entrée suit le format demandé (Nom / Description / Différence avec Win11 / Timestamp / Type / Faisabilité / Implémentation envisagée / Dépendances / État). Pour la lisibilité, les éléments sont groupés par surface UI ; le détail catégorisé complet avec états est dans `docs/FEATURES.md`.

### 🖥️ Système / branding
1. **Nom : Branding "Windows 12.1"**
   Description : nouveau nom de produit, nouveau logo 4-quadrants en dégradé rose→bleu→violet (au lieu des 4 aplats rouge/vert/bleu/jaune de Win11), nouveau build number fictif "26000.190".
   Différence : identité visuelle et textuelle complète.
   Timestamp : 00:00, 03:06, 08:03 ("About Windows").
   Type : Configuration / Système.
   Faisabilité : Facile (remplacement de logo/branding via ressources et clés de registre `RegisteredOwner`/OEM branding, wallpaper de logo) à Moyenne (le vrai "About Windows"/`winver` et le numéro de build sont générés par le noyau — on ne peut pas changer le vrai build number sans corrompre l'identification système).
   Implémentation envisagée : remplacement d'assets (logo, fonds d'écran), clé OEM branding (`OEMBackground`/`Manufacturer`), **ne pas** tenter de falsifier `winver`/build réel — le présenter comme personnalisation cosmétique assumée (splash/logo uniquement), jamais comme un vrai changement de version.
   Dépendances : assets graphiques.
   État : `PLANNED`.

2. **Nom : Écran "About Windows" avec build factice**
   Faisabilité : `CONCEPT ONLY` pour le numéro de build réel (immuable, généré par le système) — on peut au mieux personnaliser le logo/texte du dialogue si on recompile la ressource (`ExplorerFrame.dll`/`SystemPropertiesComputerName` selon la version), ce qui touche à un binaire système signé → risqué et fragile. Alternative réaliste : ne pas y toucher, ou fournir un raccourci "About Furax Windows 12" custom séparé plutôt que de patcher le vrai dialogue.
   État : `CONCEPT ONLY` (alternative : app "About" maison).

### 🎬 Setup / OOBE
3. **Nom : Fond d'écran animé "vagues" plein écran pendant tout le Setup/OOBE**
   Différence : Win11 Setup utilise un fond uni/flou statique, pas d'animation de vagues colorées continue.
   Timestamp : 00:09 → 06:03.
   Type : UI / Animation.
   Faisabilité : Très difficile — l'UI de Windows Setup (`WinPE`/`setup.exe`) est un composant propriétaire non modifiable sans Windows ADK et sans risquer de casser l'installeur signé.
   Implémentation envisagée : `CONCEPT ONLY` pour le vrai Setup. Alternative réaliste : ignorer cette partie (le Setup réel de Windows 11 25H2 sera utilisé tel quel), et ne recréer l'esthétique "vagues" que **dans l'OOBE post-installation, le verrouillage, le bureau** où c'est jouable via wallpaper/thème.
   Dépendances : Windows ADK/WinPE (non disponible, hors scope Debian).
   État : `CONCEPT ONLY`.

4. **Nom : Étapes d'installation avec icônes illustrées par phase**
   Faisabilité : `CONCEPT ONLY` — fait partie du binaire Setup signé.
   État : `CONCEPT ONLY`.

5. **Nom : OOBE personnalisée (nom appareil, thème, avatar, PIN, biométrie "Face ID")**
   Différence : le contenu fonctionnel (nommage PC, compte MS, PIN, biométrie) est déjà réel dans Win11 — seul l'habillage graphique (cartes vitrées, dégradés, icônes) change.
   Faisabilité : Difficile — l'OOBE (`UserOOBEBroker`, `oobe.exe`) est également un composant système peu modifiable proprement offline.
   Implémentation envisagée : `CONCEPT ONLY` pour re-skinner l'OOBE lui-même. Alternative réaliste : accepter l'OOBE stock de Windows 11 tel quel (fonctionnellement il fait déjà le même travail : nommage, compte, PIN, Windows Hello), et concentrer l'effort de reproduction visuelle sur le **thème par défaut, le fond d'écran, le curseur, les sons** qui s'appliquent dès le premier login.
   État : `CONCEPT ONLY` pour l'UI Setup/OOBE elle-même ; `IMPLEMENTABLE` pour le thème par défaut post-OOBE.

### 🟦 Barre des tâches
6. **Nom : Barre des tâches flottante, centrée, en pilule**
   Description : coins très arrondis (~20px), marges visibles à gauche/droite (pas pleine largeur), fond translucide/flouté.
   Timestamp : 06:03.
   Type : UI.
   Faisabilité : Moyenne — la vraie barre des tâches Windows 11 (`explorer.exe`/`ShellExperienceHost`) n'expose pas nativement un mode "flottant en pilule avec marges" ; ceci nécessite soit un remplacement de shell tiers, soit des outils communautaires connus (type "TranslucentTB", "ExplorerPatcher", "Windhawk") qui patchent le comportement d'Explorer en mémoire.
   Implémentation envisagée : intégrer/packager une solution communautaire de shell-patch (à évaluer et documenter précisément, avec ses limites et risques de casse à chaque mise à jour Windows) plutôt que de réinventer un patch binaire maison. Alternative 100% "propre" : bureau avec taskbar Win11 stock + accepter que cet aspect reste `PARTIAL`.
   Dépendances : outil tiers de shell-patching (à choisir/valider), Windhawk ou équivalent.
   État : `PLANNED`.

7. **Nom : Widget météo intégré directement dans la barre des tâches**
   Différence : Win11 n'affiche la météo qu'en bouton simple ouvrant un flyout ; ici la donnée est affichée en clair dans la barre.
   Faisabilité : Moyenne, dépend du même mécanisme de patch de barre des tâches que #6.
   État : `PLANNED`.

8. **Nom : Bascule d'alignement des icônes (centré ↔ gauche)**
   Différence : Win11 propose déjà nativement ce réglage (`Paramètres > Personnalisation > Barre des tâches > Comportements de la barre des tâches > Alignement`) — **c'est en fait déjà une fonctionnalité stock de Windows 11**, pas une nouveauté.
   Faisabilité : Facile — réglage natif existant.
   Implémentation envisagée : simple valeur de registre par défaut (`TaskbarAl`), rien à développer.
   État : `IMPLEMENTABLE` (registre natif).

### 🏠 Menu Démarrer
9. **Nom : Menu Démarrer avec salutation personnalisée + horloge/calendrier intégrés**
   Description : "Good Afternoon, Abdi!" + email, mini-carte horloge/calendrier en haut à droite.
   Différence : Win11 Start n'a ni salutation ni mini-widget horloge intégré.
   Timestamp : 06:03, 09:48.
   Type : UI / Fonctionnalité.
   Faisabilité : Très difficile via le vrai `StartMenuExperienceHost` (composant fermé, pas de plugin officiel pour y injecter du contenu). 
   Implémentation envisagée : `CONCEPT ONLY` pour modifier le vrai menu Démarrer de Win11 in-place. Alternative réaliste : développer une **application de remplacement tierce** (dans `apps/`) qui reproduit ce menu Démarrer (fenêtre plein-écran-partiel personnalisée, lancée en lieu et place du vrai Start, ou accessible par un raccourci dédié) — c'est l'approche que prennent déjà des projets comme "Start11"/"StartAllBack" sur Windows, mais en développement maison, documentée comme app tierce et non comme modification du vrai Explorer Start.
   Dépendances : framework UI Windows (WinUI3/WPF), à développer.
   État : `PLANNED` (comme app tierce, pas comme patch du vrai Start).

10. **Nom : Grille d'applications épinglées + section "Your last activities"**
    Différence : structure proche du Start réel (pinned + recommended), rebaptisée et réagencée.
    Faisabilité : `IMPLEMENTABLE` en partie nativement (Win11 a déjà pinned apps + recommended files), sinon via l'app tierce du point 9.
    État : `PARTIAL` (le Start réel fait déjà l'essentiel, juste pas avec ce visuel).

11. **Nom : Rail alphabétique A-Z inline (liste complète d'apps fusionnée)**
    Faisabilité : Difficile hors app tierce.
    État : `PLANNED` (via app tierce).

### 📁 Explorateur de fichiers
12. **Nom : Onglets façon navigateur avec icône colorée**
    Différence : Win11 22H2+/23H2 a déjà des onglets natifs dans l'Explorateur — la nouveauté ici est purement stylistique (icône pilule colorée).
    Faisabilité : Facile — fonctionnalité déjà native, juste re-stylée si on personnalise le thème visuel de l'Explorateur (registre `Explorer` + `ImmersiveColorSet`, ou remplacement de ressources visuelles limité).
    État : `IMPLEMENTABLE` (natif) / `PARTIAL` pour le style exact.

13. **Nom : Fonction "Tags" avec puces de couleur dans le panneau latéral**
    Différence : fonctionnalité absente de l'Explorateur Win11 stock (existe dans macOS Finder, pas Windows).
    Faisabilité : Difficile — nécessiterait soit une extension shell (Shell Extension DLL) ajoutant une colonne de métadonnées + UI dans le panneau de navigation, soit un explorateur de fichiers tiers complet.
    Implémentation envisagée : `CONCEPT ONLY` pour une intégration native au vrai Explorateur (pas d'API publique simple pour ça côté panneau de navigation). Alternative : application "Furax Tags" tierce indépendante (gestionnaire de tags via NTFS Extended Attributes ou fichier d'index), sans prétendre l'intégrer visuellement dans `explorer.exe`.
    État : `CONCEPT ONLY` (intégration native) / `PLANNED` (app séparée).

14. **Nom : Toast de notification (éjection USB) en haut à droite au lieu de bas à droite**
    Faisabilité : Difficile — la position des toasts Windows (`Windows.UI.Notifications`) est gérée par le système de notification central, pas configurable nativement par position à l'écran.
    État : `CONCEPT ONLY`.

### ⚙️ Paramètres / thème
15. **Nom : Transition de thème "live" en plein écran (fondu coloré immédiat)**
    Différence : Win11 applique un nouveau thème avec un simple re-rendu, pas de fondu plein écran spectaculaire.
    Faisabilité : Moyenne — un effet de fondu/transition peut être simulé par une **application d'overlay** qui joue une animation de transition juste avant/pendant l'application effective du thème (wallpaper + accent color natifs), sans modifier le moteur de thème Windows lui-même.
    Implémentation envisagée : petit service/app tierce déclenché sur changement de wallpaper (watcher registre) qui joue un overlay de transition.
    État : `PLANNED`.

16. **Nom : Page Personnalisation / Système globalement proche de Win11**
    Différence : mineure, cosmétique (coins plus arrondis, palette plus saturée).
    Faisabilité : Facile — thème visuel Windows (`.theme`), accent color, `DWM` (transparence/coins) sont déjà configurables nativement.
    État : `IMPLEMENTABLE`.

### 🔔 Notifications / Réglages rapides / Widgets
17. **Nom : Widgets — panneau "News" avec sources/articles factices**
    Différence : Win11 a déjà un panneau Widgets quasi identique en concept (météo, actu, calendrier) — nouveauté = mise en page 2 colonnes + branding.
    Faisabilité : `IMPLEMENTABLE` en grande partie nativement (le panneau Widgets de Win11 existe déjà et est piloté par le service Microsoft, non re-brandable côté client).
    État : `PARTIAL` (le natif existe déjà, on ne peut pas le re-skinner en profondeur) — alternative : widget board maison en complément.

18. **Nom : "Widget settings" avec interrupteurs par service**
    Faisabilité : Le vrai panneau Widgets Win11 a déjà des réglages de flux similaires — nouveauté purement visuelle.
    État : `IMPLEMENTABLE` (natif, re-swkin limité).

19. **Nom : Centre de notifications — état vide "No more notifications"**
    Faisabilité : `CONCEPT ONLY` (texte système, pas éditable proprement) sauf via resource hacking risqué.
    État : `CONCEPT ONLY`.

20. **Nom : Réglages rapides avec sliders à poignée dégradée rose et tuiles arrondies**
    Faisabilité : Difficile — le flyout Quick Settings (`QuickActionsSystemSettings`) est un composant fermé du shell ; on ne peut pas le re-thémer finement sans patch shell (voir #6).
    État : `CONCEPT ONLY` / `PLANNED` si intégré au même patch de shell que la barre des tâches.

### 🔐 Écran de verrouillage / connexion
21. **Nom : Carrousel de fonds d'écran swipeable sur l'écran de verrouillage**
    Différence : Win11 a "Windows Spotlight" (rotation auto, pas de swipe manuel affiché comme ici) — le swipe manuel avec indice tactile est une nouveauté du concept.
    Faisabilité : Moyenne — l'écran de verrouillage (`LockApp.exe`) est fermé, mais Windows Spotlight/diaporama de fond d'écran (`Paramètres > Personnalisation > Écran de verrouillage > Diaporama`) existe déjà nativement en mode diaporama automatique (pas swipe manuel).
    Implémentation envisagée : utiliser le diaporama natif avec le pack de fonds d'écran custom (`assets/wallpapers/`) comme approximation raisonnable ; le geste "swipe manuel" reste `CONCEPT ONLY`.
    État : `PARTIAL` (diaporama natif) / `CONCEPT ONLY` (swipe manuel).

22. **Nom : Salutation dynamique "Good Afternoon, [Nom]!" sur écran de connexion/Démarrer/notifications**
    Faisabilité : Difficile nativement (LogonUI est un composant système fermé) — replicable uniquement via l'app tierce mentionnée en #9 pour les surfaces qu'on contrôle (pas l'écran de connexion réel, qui reste `CONCEPT ONLY`).
    État : `CONCEPT ONLY` (écran de connexion réel) / `PLANNED` (dans les apps tierces Start/Notifications maison).

### 🎨 Design system transverse
23. **Nom : Logo décoratif géant flottant sur le bureau**
    Faisabilité : Facile — simple fond d'écran/asset PNG superposé, ou petit widget desktop (type Rainmeter) affichant le logo.
    État : `PLANNED`.

24. **Nom : Palette de couleurs (dégradé magenta↔bleu), coins très arrondis, boutons pilule, cartes vitrées floutées**
    Faisabilité : Facile à Moyenne pour tout ce qui touche : fonds d'écran, curseur, accent color Windows, thème visuel `.theme`. Moyenne à Difficile pour re-styliser en profondeur les contrôles système eux-mêmes (boutons/dialogues natifs) sans patch de DLL.
    État : `PARTIAL` (design system documenté dans `docs/DESIGN_SYSTEM.md`, application progressive via assets + thème natif).

## 4. Tableau de faisabilité technique (résumé)

| Catégorie | Faisabilité dominante | Approche |
|---|---|---|
| Setup/OOBE (habillage visuel du binaire Setup lui-même) | `CONCEPT ONLY` | Non modifiable proprement — ISO 25H2 stock utilisée telle quelle pour cette partie |
| Branding (logo, nom, fonds d'écran, sons, curseur, thème par défaut) | Facile/Moyenne | Assets + registre, natif |
| Barre des tâches flottante/repensée, Quick Settings re-thémées | Moyenne/Difficile | Patch de shell tiers (type Windhawk) à évaluer et documenter, jamais un binaire modifié "à la main" non traçable |
| Menu Démarrer personnalisé (salutation, rail A-Z, activités) | Difficile | Application de remplacement tierce développée dans `apps/`, pas un patch du vrai Start |
| Explorateur — Tags, style | Difficile (natif) / Faisable (app tierce) | App tierce complémentaire |
| Widgets/Notifications | Partiellement natif | Le natif Win11 fait déjà l'essentiel ; re-styling profond limité |
| Écran de verrouillage — diaporama | Partiellement natif | Diaporama natif + pack wallpapers custom |
| Salutations dynamiques sur surfaces système fermées (Start réel, LogonUI) | `CONCEPT ONLY` | Reproductible uniquement dans les apps tierces qu'on développe |

## 5. Éléments impossibles/non réalistes (`CONCEPT ONLY`)

- Réhabillage visuel du binaire `setup.exe`/OOBE/WinPE lui-même (fond animé, cartes vitrées, icônes par étape).
- Modification du numéro de build/version réel affiché par `winver`/"About Windows".
- Réagencement profond du vrai `StartMenuExperienceHost`, `ShellExperienceHost`, `LogonUI`, panneau Widgets serveur (Microsoft), toasts de notification (position/texte système).
- Geste de swipe manuel sur l'écran de verrouillage natif.
- Terminologie inventée ("Face ID" pour la reconnaissance faciale Windows Hello) — sera reproduite uniquement comme un **nommage cosmétique dans notre propre UI tierce**, jamais comme un renommage du vrai composant Windows Hello.

Pour chacun de ces points, l'alternative réaliste retenue est documentée dans `docs/FEATURES.md` (colonne "Implémentation envisagée").

## 6. Éléments nécessitant une VM Windows pour être testés

Absolument tout ce qui touche au **rendu réel du shell** (barre des tâches patchée, thème appliqué, Explorateur, Paramètres, Démarrer tiers, transitions, écran de verrouillage/connexion, comportement au démarrage/arrêt) ne peut être validé que dans une VM Windows démarrée sur l'ISO générée (`vm/test-vm.sh`, QEMU/KVM + OVMF). Le pipeline côté Debian (§ `docs/ARCHITECTURE.md`) ne peut garantir que : l'intégrité de l'ISO, la présence des fichiers/clés de registre injectés, et le montage/démontage propre du WIM — jamais le rendu visuel final, qui est un test **runtime obligatoire**.

## 7. Limites de cette analyse

- Estimation visuelle des couleurs (pas d'échantillonnage pixel précis) — les valeurs hex données dans les rapports de segment sont approximatives.
- Aucune transcription audio (pas d'outil de reconnaissance vocale disponible hors-ligne) — si la vidéo contient une narration parlée avec des détails non visibles à l'écran, ils ne sont pas couverts ici.
- Échantillonnage à 1 frame/3s (208 frames) : des micro-animations plus rapides que 3 secondes (transitions de survol, easing exact) ne sont pas capturées avec précision — seule leur existence et leur direction générale sont notées.
- Le changement d'alignement de la barre des tâches (centré → gauche, ~08:39) se produit pendant un segment occupé par le panneau Widgets dans les frames échantillonnées ; l'action déclenchante exacte n'a pas pu être observée directement.
