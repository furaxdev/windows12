# BUILD.md — Préparer l'environnement et lancer un build

**Statut du pipeline : Phase 2 (builder minimal).** Ce document décrit ce qui existe réellement aujourd'hui, avec un état honnête de ce qui a été testé.

## 1. Préparer l'environnement (Debian/Ubuntu)

### 1.1 Détecter ton environnement

```bash
uname -a
cat /etc/os-release
df -h
free -h
nproc
```

### 1.2 Dépendances

Le builder a besoin des outils suivants (dépôts officiels Ubuntu/Debian, aucun dépôt tiers) :

```bash
sudo apt-get update
sudo apt-get install -y \
  wimtools xorriso p7zip-full libarchive-tools \
  libhivex-bin python3-hivex \
  qemu-system-x86 qemu-utils ovmf
```

| Outil | Rôle |
|---|---|
| `wimlib-imagex` (paquet `wimtools`) | monter/démonter/appliquer l'image `install.wim`/`install.esd` de Windows, offline |
| `xorriso` | extraire l'ISO source, régénérer une ISO bootable (BIOS+UEFI) |
| `7z` / `bsdtar` | inspection/extraction d'archives en secours |
| `hivex` (`libhivex-bin`, `python3-hivex`) | éditer le registre Windows offline, sans DISM |
| `qemu-system-x86_64`, `qemu-img`, `ovmf` | démarrer l'ISO générée dans une VM de test UEFI |

**⚠️ Piège spécifique à cet environnement de dev (à vérifier chez toi aussi) :** si plusieurs versions de Python sont installées et qu'un `python3` "par défaut" ne correspond pas à la version pour laquelle `python3-hivex` a été compilé (ex. `python3` pointe vers 3.11 alors que le paquet Ubuntu fournit le binding pour 3.12), l'import du module `hivex` échoue avec `ModuleNotFoundError`. Vérifie avec :

```bash
python3 -c "import hivex" || python3.12 -c "import hivex"
```

Le pipeline (`builder/tools/hivex_set_value.py`) appelle explicitement `/usr/bin/python3.12` pour éviter ce piège — adapte ce chemin si ta distribution utilise une autre version par défaut.

**KVM / virtualisation imbriquée :** dans un conteneur ou une VM sans virtualisation imbriquée activée, `/dev/kvm` peut être absent ou non fonctionnel (`kvm-ok` répond "Your CPU does not support KVM extensions"). `vm/test-vm.sh` bascule alors automatiquement sur l'accélération logicielle TCG — fonctionnel mais nettement plus lent qu'avec KVM.

## 2. Fournir l'ISO

Le builder attend une **ISO Windows 11 25H2 officielle** que tu possèdes légalement (téléchargée depuis un domaine Microsoft officiel, ex. `software.download.prss.microsoft.com` via la page officielle de téléchargement / Media Creation Tool). Le script ne télécharge rien lui-même et ne contourne aucune protection.

```bash
./builder/build.sh --iso /chemin/vers/Win11_25H2_x64.iso --profile minimal --dry-run
```

## 3. Lancer un build

```bash
# Toujours commencer par un dry-run pour vérifier que tout est en ordre :
sudo ./builder/build.sh --iso /chemin/vers/Win11.iso --profile minimal --dry-run

# Build réel :
sudo ./builder/build.sh --iso /chemin/vers/Win11.iso --profile minimal
sudo ./builder/build.sh --iso /chemin/vers/Win11.iso --profile full
```

Options principales : voir `./builder/build.sh --help`. Le script doit tourner en **root** (montage WIM + édition de registre offline nécessitent des privilèges).

## 4. Ce que fait réellement le pipeline aujourd'hui (mis à jour 22/09/2026)

Ordre d'exécution réel (voir `builder/build.sh`) :

```
00-validate               : ISO présente, lisible (xorriso), install.wim/.esd présent, outils
                             dispo, privilèges root, espace disque (~2.5x taille ISO),
                             SHA-256 calculé et loggé
10-extract                : extraction complète de l'ISO (7z, lecteur UDF — xorriso ne lit
                             pas correctement les ISO Windows modernes, voir 10-extract.sh)
                             vers un dossier de travail isolé — l'ISO source n'est JAMAIS
                             ouverte en écriture
43-autounattend  [opt.]    : dépose autounattend.xml à la racine de l'ISO (XML validé bien
                             formé avant dépôt)
44-installer-background [opt.] : monte boot.wim (index Setup) séparément, remplace le fond
                             d'écran de l'assistant Windows Setup
20-identify                : repère install.wim ou install.esd, liste les éditions/index
                             (wimlib-imagex info) — index 1 par défaut, confirmé "Core"
                             sur l'ISO Windows 11 25H2 EnglishInternational officielle
30-mount                   : monte l'index choisi en lecture/écriture (wimlib-imagex
                             mountrw, FUSE)
40-customize-minimal [opt.]: preuve de mécanisme — fichier marqueur + valeur de registre
                             de test (pas une vraie personnalisation)
41-first-logon   [opt.]    : dépose un script PowerShell + entrée RunOnce (point de
                             restauration + message de bienvenue au premier login)
42-branding      [opt.]    : "By FuraxDev" dans winver + OEMInformation
45-wallpaper     [opt.]    : remplace le fond d'écran par défaut du bureau
46-theme         [opt.]    : thème sombre + accent coloré + icônes centrées
47-privacy-performance [opt.] : télémétrie=Basique, Copilot désactivé, updates différés,
                             suggestions Menu Démarrer désactivées, presse-papiers,
                             Mode Jeu, Game Bar arrière-plan
48-taskbar-experimental    : DÉSACTIVÉ PAR DÉFAUT — dépose uniquement de la documentation,
                             n'installe/n'exécute jamais rien automatiquement
49-rollback-scripts        : toujours actif — dépose le script de rollback + un raccourci
                             bureau .bat
50-unmount                 : démonte avec commit (wimlib-imagex unmount --commit), vérifie
                             qu'aucun mount ne subsiste
60-build-iso                : régénère une ISO bootable (xorriso -as mkisofs, El Torito
                             BIOS+UEFI explicite — xorriso ne peut pas rejouer le boot
                             catalog d'une ISO UDF source, voir 60-build-iso.sh)
70-validate-output          : vérifie taille, lisibilité, présence d'install.wim, du fichier
                             marqueur et du raccourci bureau dans l'ISO générée, calcule
                             son SHA-256
```

`[opt.]` = activable/désactivable par le profil (`builder/profiles/*.yaml`), tous activés par défaut dans `minimal`/`full`/`lite` sauf `taskbar_floating_pill_experimental`.

Chaque étape écrit dans le rapport de build (`build/_out/rapport-build-<id>.txt`) avec un statut `OK`/`FAILED`/`SKIPPED`/`PARTIAL`/`DRY-RUN`. Les logs complets sont dans `build/_out/build-<id>.log`.

**Nettoyage automatique :** en cas d'erreur à n'importe quelle étape, un `trap` démonte proprement toute image WIM encore montée avant de quitter — aucun mount résiduel ne doit subsister. Le dossier de travail est conservé en cas d'échec (pour inspection), supprimé automatiquement en cas de succès (sauf `--keep-work`).

## 5. Ce qui N'A PAS encore été fait / reste non confirmé

- Personnalisations UI plus profondes (barre des tâches pilule flottante, Menu Démarrer custom, etc. — voir `docs/FEATURES.md`).
- La validation de sortie (module 70) est **structurelle** (lecture ISO9660/UDF, présence de fichiers). Elle **ne prouve pas** que l'ISO démarre réellement sur du vrai matériel/une VM — c'est le rôle de `vm/test-vm.sh` et reste un test séparé, manuel par défaut.
- Le hash SHA-256 de l'ISO source n'est **pas comparé automatiquement** à une valeur officielle Microsoft (nécessiterait de maintenir une liste de hashs de référence) — il est seulement calculé et loggé pour que tu puisses le comparer toi-même si besoin.
- Plusieurs modules écrivent des réglages dont l'ÉCRITURE est confirmée (relue directement dans le WIM généré) mais dont le RENDU/COMPORTEMENT réel au boot/premier login n'a pas pu être vérifié dans cet environnement de dev (pas de VM Windows démarrable ici) — voir le statut détaillé de chaque fonctionnalité dans `docs/FEATURES.md`.

## 6. Diagnostiquer un échec

Voir `docs/TROUBLESHOOTING.md`.
