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

## 4. Ce que fait réellement le pipeline aujourd'hui (Phase 2)

```
00-validate   : ISO présente, lisible (xorriso), install.wim/.esd présent, outils dispo,
                privilèges root, espace disque (>= 6x taille ISO), SHA-256 calculé et loggé
10-extract    : extraction complète de l'ISO (xorriso -osirrox) vers un dossier de travail
                isolé — l'ISO source n'est JAMAIS ouverte en écriture
20-identify   : repère install.wim ou install.esd, liste les éditions/index (wimlib-imagex info)
30-mount      : monte l'index choisi en lecture/écriture (wimlib-imagex mountrw, FUSE)
40-customize  : PREUVE DE MÉCANISME UNIQUEMENT — écrit un fichier marqueur
                (Furax-Windows-12-Beta.txt) et UNE valeur de registre de test
                (HKLM\SOFTWARE\Microsoft\FuraxWindows12Beta) via hivex. Ce n'est PAS
                une personnalisation UI — voir docs/FEATURES.md pour ce qui reste à faire.
50-unmount    : démonte avec commit (wimlib-imagex unmount --commit), vérifie qu'aucun
                mount ne subsiste
60-build-iso  : régénère une ISO bootable en réutilisant le catalogue de boot BIOS+UEFI de
                l'ISO source (xorriso -boot_image any replay) sur l'arborescence modifiée
70-validate   : vérifie taille, lisibilité, présence d'install.wim et du fichier marqueur
                dans l'ISO générée, calcule son SHA-256
```

Chaque étape écrit dans le rapport de build (`build/_out/rapport-build-<id>.txt`) avec un statut `OK`/`FAILED`/`SKIPPED`/`PARTIAL`/`DRY-RUN`. Les logs complets sont dans `build/_out/build-<id>.log`.

**Nettoyage automatique :** en cas d'erreur à n'importe quelle étape, un `trap` démonte proprement toute image WIM encore montée avant de quitter — aucun mount résiduel ne doit subsister. Le dossier de travail est conservé en cas d'échec (pour inspection), supprimé automatiquement en cas de succès (sauf `--keep-work`).

## 5. Ce qui N'A PAS encore été fait

- Aucune personnalisation UI (barre des tâches, Menu Démarrer, thème, etc. — voir `docs/FEATURES.md`, Phases 3-5).
- La validation de sortie (module 70) est **structurelle** (lecture ISO9660/UDF, présence de fichiers). Elle **ne prouve pas** que l'ISO démarre réellement sur du vrai matériel/une VM — c'est le rôle de `vm/test-vm.sh` et reste un test séparé, manuel par défaut.
- Le hash SHA-256 de l'ISO source n'est **pas comparé automatiquement** à une valeur officielle Microsoft (nécessiterait de maintenir une liste de hashs de référence) — il est seulement calculé et loggé pour que tu puisses le comparer toi-même si besoin.

## 6. Diagnostiquer un échec

Voir `docs/TROUBLESHOOTING.md`.
