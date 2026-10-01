# Labo expérimental "aggressive" — suppression des mentions "Windows 11"

Demande explicite de FuraxDev (01/10/2026) : « Nulle part dans l'expérience utilisateur
finale ne doit apparaître "Windows 11" », avec acceptation explicite des risques (signatures
Authenticode invalidées, composants potentiellement restaurés par SFC/DISM, pas de garantie
de boot dans cet environnement). Pipeline construit exactement comme demandé : backup,
inventaire avant modification, classification, application réversible, journal complet,
avant/après, second scan de vérification, rapport.

**Statut : `PARTIAL` (expérimental).** Fait sur une vraie image Windows 11 25H2 officielle,
vérifié par inventaire avant/après réel (pas simulé). **Rendu réel au boot non testé** (pas
de boot possible dans cet environnement, comme pour tout le reste du projet).

## Outils

- `builder/tools/winstring_scan.py` — inventaire en lecture seule. Cherche "Windows 11" et
  "Windows11" en ASCII/UTF-8 ET en UTF-16LE, classe chaque fichier concerné
  (`registry`/`mui`/`pe`/`text`/`other`), détecte la présence d'une signature Authenticode
  (via `pefile`, présence seulement — pas de validation cryptographique).
- `builder/tools/winstring_patch.py` — applique "Windows 11" → "Windows 12" (et
  "Windows11" → "Windows12") à **longueur strictement égale** (ASCII et UTF-16LE), ce qui
  évite de décaler les offsets/tables de longueur internes aux ressources PE/.mui. Backup
  par fichier avant écriture, dry-run par défaut, catégorie `registry` explicitement
  exclue (traitement différent nécessaire, voir plus bas).

Les deux exclusions dures, conservées même en mode agressif (aucune méthode de
restauration disponible si ça casse — limite that FuraxDev a lui-même posée au point 7 de
sa demande) :
- Chaîne de boot : tout chemin contenant `/boot/`, `/efi/`, `bootmgr`, `bootmgfw.efi`,
  `bootx64.efi`, `winload.efi/.exe`, `winresume.efi/.exe`.
- Ruches de registre : traitées à part (voir plus bas), jamais par patch d'octets brut.

## Méthodologie

1. Image source (`install.wim` de la vraie ISO Windows 11 25H2 EnglishInternational
   officielle) jamais modifiée — copiée en deux fichiers séparés :
   - `build-safe.wim` : copie intacte, référence/rollback.
   - `build-aggressive.wim` : copie sur laquelle le patch est appliqué.
2. Montage en lecture seule (FUSE, `wimlib-imagex mount`) pour le scan — pas d'extraction
   complète sur disque.
3. Scan complet (141 209 fichiers lus), inventaire JSONL détaillé (chemin, catégorie,
   présence de signature, offset + contexte de chaque occurrence).
4. Montage en lecture-écriture de `build-aggressive.wim`, application du patch, backup par
   fichier avant écriture, retrait des backups avant commit (le rollback réel passe par
   `build-safe.wim`, pas par des fichiers résiduels dans l'image).
5. Commit (`wimlib-imagex unmount --commit`) dans `build-aggressive.wim`.
6. Second scan complet sur l'image patchée pour vérifier ce qu'il reste.

## Résultats

### Inventaire initial (image stock)

| | |
|---|---|
| Fichiers scannés | 141 209 |
| Fichiers avec ≥1 occurrence | 1 346 |
| Occurrences totales (ASCII+UTF-16LE) | 9 253 |
| Fichiers chaîne de boot exclus d'office | 778 |

Répartition par catégorie (fichiers / occurrences) :

| Catégorie | Fichiers | Occurrences |
|---|---|---|
| `registry` | 3 | 5 285 |
| `mui` | 16 | 241 |
| `pe` | 51 | 424 |
| `text` | 7 | 16 |
| `other` (surtout `.pak` de locales Edge, `.pri`) | 1 269 | 3 287 |

Signatures Authenticode (fichiers PE/.mui concernés) : 39 présentes, 28 absentes.

### Découverte clé : la source réelle du texte affiché

`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProductName` vaut **déjà** "Windows 10
Home" sur cette image Windows 11 25H2 stock (bug connu et documenté de Microsoft) — preuve
que Windows n'affiche pas "Windows 11" en lisant cette chaîne de registre brute. La vraie
source est `Windows/Branding/Basebrd/basebrd.dll` (+ ses copies `WinSxS` et `.mui`
localisées) : une table de ressources listant littéralement chaque variante ("Windows 11
Home", "Windows 11 Pro", "Windows 11 Enterprise", "Windows 11 Education", etc., 35
occurrences dans ce seul fichier), avec entrées à longueur préfixée (STRINGTABLE) — le
format PE pour lequel un remplacement à longueur égale est justement sûr.

### Application du patch

| | |
|---|---|
| Fichiers réellement réécrits | 553 |
| Fichiers déjà corrects après coup (stockage à instance unique du WIM — patcher une copie propage aux doublons identiques, ex. Edge/EdgeCore) | 790 |
| Fichiers registre (non patchés ici, voir plus bas) | 3 |
| Erreurs | 0 |
| Signatures Authenticode invalidées par la modification | 20 fichiers (parmi eux : tous les `msedge.dll`, `OneDriveSetup.exe`, `basebrd.dll`, `bootstr.dll`, `appraiser.dll`, quelques pilotes) |

Remplacement : `Windows 11` → `Windows 12` (et `Windows11` → `Windows12`), longueur
identique en toute circonstance (10 et 9 caractères respectivement dans les deux langues).

### Registre : volontairement non modifié

Les 3 fichiers de ruche concernés (`SOFTWARE`, `SOFTWARE.LOG1`, `SOFTWARE.LOG2`, 5 285
occurrences) ont été **inspectés avant de décider**, pas juste exclus par principe. Le
contenu réel : des identifiants de paquets de mise à jour/servicing (Component-Based
Servicing), de la forme `Windows11.0-KB5043080-x64...`, répétés des milliers de fois. Ce ne
sont **pas** des chaînes d'affichage — ce sont des identifiants utilisés par Windows Update
et le magasin de servicing (TrustedInstaller/CBS) pour faire correspondre les paquets
installés au catalogue Microsoft. Les modifier :
- ne changerait rien de visible à l'utilisateur ;
- casserait potentiellement la correspondance avec le catalogue Microsoft (mises à jour
  mal détectées, re-proposées, ou conflits de version) ;
- demanderait un outillage hivex dédié (comprendre la structure CBS exacte) qui n'existe
  pas dans ce projet et n'a pas été développé, faute de bénéfice visible identifié.

**Décision : laissé intact.** Documenté ici plutôt que silencieusement ignoré, conformément
à la demande explicite de FuraxDev.

### Chaîne de boot : volontairement non scannée ni modifiée

778 fichiers exclus d'office (`bootmgr`, `bootmgfw.efi`, `bootx64.efi`, `winload.efi/.exe`,
`winresume.efi/.exe`, et tout chemin sous `/Windows/Boot/` ou `/EFI/`). Aucune méthode de
restauration disponible dans cet environnement si une modification empêchait le démarrage —
limite posée par FuraxDev lui-même (point 7 de sa demande).

### Scan final de vérification (image patchée)

| | |
|---|---|
| Fichiers scannés | 141 209 (identique) |
| Fichiers avec ≥1 occurrence restante | **3** (uniquement les 3 fichiers de ruche, volontairement non touchés) |
| Occurrences restantes | 5 285 (100% dans le registre CBS, 0% ailleurs) |

**Résultat : les 1 343 fichiers non-registre ciblés ne contiennent plus aucune occurrence
de "Windows 11" (ASCII ou UTF-16LE), vérifié par un second scan indépendant, pas supposé.**

## Ce qui reste `UNCONFIRMED`

- Le rendu réel dans l'UI (Paramètres > Système > À propos, winver, Propriétés système, Edge
  `about:version`, etc.) sur une machine qui boote réellement cette image — **pas testable
  dans cet environnement** (pas de boot possible), exactement comme pour le reste du projet
  (taskbar flottante, Setup wizard, autounattend...).
- Le comportement de SFC/DISM face aux 20 fichiers dont la signature Authenticode a été
  invalidée : en théorie, `sfc /scannow` ou une réparation Windows Update pourrait détecter
  l'écart et restaurer la version d'origine depuis le magasin de composants — mais comme le
  patch a aussi été appliqué aux copies `WinSxS` (magasin de composants) de ces mêmes
  fichiers, la référence que SFC utiliserait pour comparer est elle-même patchée de façon
  cohérente. Reste une hypothèse raisonnée, pas une certitude testée.
- Les fichiers `.pak`/`.pri` (catégorie `other`, l'essentiel des 1 269 fichiers) sont des
  formats de ressources Chromium/UWP non signés — le remplacement textuel est sûr
  structurellement (longueur égale), mais leur rendu réel dans l'UI d'Edge/des apps n'est
  pas vérifié non plus.

## Artefacts (non versionnés, locaux à cette session)

- `build/_work/aggressive-lab-<horodatage>/build-safe.wim` — image intacte, référence.
- `build/_work/aggressive-lab-<horodatage>/build-aggressive.wim` — image patchée.
- `build/_work/aggressive-lab-<horodatage>/inventory/` — tous les JSONL (inventaire avant,
  journal d'application, inventaire après) + rapports texte détaillés par fichier.

Ces fichiers sont volumineux (WIM de ~7,5-8,3 Go chacun) et ne sont pas versionnés (voir
`.gitignore`, `build/_work/` est ignoré) — ils vivent dans l'espace de travail de cette
session. Pour les réutiliser dans le pipeline normal (`build.sh`), il faudrait un nouveau
module qui substitue `build-aggressive.wim` à l'`install.wim` extrait avant les étapes de
montage/personnalisation existantes — pas encore fait, c'est la suite logique si ce labo est
jugé concluant.
