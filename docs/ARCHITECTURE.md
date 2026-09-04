# Architecture — Furax Windows 12 Beta

Statut du document : **PROPOSITION** (à valider avant d'attaquer les grosses modifications ISO — voir Phase 2 dans `README.md`).

## 1. Environnement de développement réel

Cette section documente ce qui a été **effectivement détecté** dans l'environnement de dev (pas une supposition).

| Élément | Valeur détectée |
|---|---|
| OS | **Ubuntu 24.04.4 LTS "Noble"** (`ID=ubuntu`, `ID_LIKE=debian`) — pas une Debian pure, mais une base Debian-compatible (mêmes paquets `.deb`, `apt`) |
| Noyau | Linux 6.18.44 x86_64 |
| CPU | 4 vCPU |
| RAM | 15 Gi (14 Gi libres au démarrage) |
| Disque | `/` (`/dev/vda`) : 252G total, ~30G disponibles au moment de l'inspection — **c'est la contrainte dimensionnante** : une ISO Windows 11 pèse ~5-6 Go, un WIM monté + fichiers de travail peuvent facilement doubler ce volume. Le builder doit vérifier l'espace libre *avant* de commencer (voir §6 du cahier des charges) et prévoir un mode de nettoyage. |
| Réseau sortant | Passe par un proxy d'agent préconfiguré (`HTTPS_PROXY`) — pertinent seulement si le builder doit télécharger des outils/mises à jour depuis des sources officielles. |
| Shell | bash (`/bin/bash`) |
| Privilèges | root dans ce conteneur (mais **ceci ne sera pas vrai pour l'utilisateur final** — le builder ne doit jamais supposer qu'il tourne en root ; il doit vérifier et échouer proprement sinon, ou utiliser `sudo` explicitement documenté). |

> ⚠️ Le prompt utilisateur mentionne "Debian Linux" — l'environnement réel est **Ubuntu 24.04**, qui est Debian-compatible (mêmes formats de paquets, mêmes outils). Tous les scripts ci-dessous ciblent donc "Debian/Ubuntu (apt-based)" plutôt que Debian strictement, ce qui reste compatible avec l'intention initiale.

## 2. Outils nécessaires — état réel (rien n'a été installé sans te le dire, sauf `ffmpeg`)

| Outil | Statut initial | Rôle dans le pipeline | Paquet Debian/Ubuntu | Alternative |
|---|---|---|---|---|
| `git` | ✅ déjà installé | versionnage | `git` | — |
| `python3` | ✅ déjà installé | scripts, validation, génération YAML/JSON | `python3` | — |
| `ffmpeg` / `ffprobe` | ❌ manquant → **installé par moi** (voir note ci-dessous) | extraction de frames pour analyser la vidéo de référence ; pas utilisé par le pipeline de build lui-même | `ffmpeg` | — |
| `wimlib-imagex` | ❌ manquant, dispo dans les dépôts | **cœur du pipeline** : monter/démonter/appliquer/capturer les images `.wim`/`.esd` de l'ISO Windows *depuis Linux*, sans DISM | `wimtools` | Aucune alternative Linux crédible pour manipuler un WIM Windows — c'est l'outil de référence côté open source. |
| `xorriso` | ❌ manquant, dispo | extraire l'ISO source et regénérer une ISO bootable (BIOS+UEFI, El Torito + structure Windows) | `xorriso` | `genisoimage`/`mkisofs` (moins complet pour le double boot BIOS/UEFI Windows) |
| `7z` | ❌ manquant, dispo | extraction/inspection généraliste d'archives (fallback si besoin d'ouvrir l'ISO/CAB) | `p7zip-full` | `bsdtar` |
| `bsdtar` | ❌ manquant, dispo | extraction d'archives, alternative légère à 7z | `libarchive-tools` | `7z` |
| `hivex` (`hivexregedit`, `python3-hivex`) | ❌ manquant, dispo | **édition offline des ruches de registre Windows** (SOFTWARE, SYSTEM, DEFAULT, NTUSER.DAT) sans jamais démarrer Windows — indispensable puisqu'on n'a pas DISM | `libhivex-bin` (+ `python3-hivex` pour scripter) | `chntpw` (plus limité, orienté reset mdp) |
| `qemu-system-x86_64`, `qemu-img` | ❌ manquant, dispo | démarrer l'ISO générée dans une VM de test (KVM si dispo, sinon émulation logicielle) | `qemu-system-x86`, `qemu-utils` | — |
| `OVMF` (firmware UEFI) | ❌ manquant, dispo | Windows 11/12 exige UEFI + Secure Boot capable → il faut un firmware UEFI pour QEMU | `ovmf` | — |
| PowerShell (`pwsh`) | ❌ manquant, **pas dans les dépôts Ubuntu par défaut** (dépôt Microsoft requis) | uniquement si on veut un `build.ps1` en plus de `build.sh` | dépôt `packages.microsoft.com` | On privilégie **bash + Python** comme demandé dans le cahier des charges ; PowerShell reste optionnel/secondaire, pertinent surtout pour les étapes qui *devront* tourner sous Windows (voir §4). |

**Rien de ce qui précède n'a été installé automatiquement**, à l'exception de `ffmpeg`/`ffprobe` : c'était nécessaire immédiatement pour pouvoir *regarder* la vidéo de référence (le fichier `.mp4` fourni ne peut pas être "lu" nativement par mes outils de lecture de fichiers — j'ai dû en extraire des frames image par image). Cet outil ne fait pas partie du pipeline de build final et n'écrit rien dans le projet.

**Action requise de ta part avant la Phase 2 (builder minimal)** : confirmer que je peux installer `wimtools`, `xorriso`, `p7zip-full`, `libarchive-tools`, `libhivex-bin`, `python3-hivex`, `qemu-system-x86`, `qemu-utils`, `ovmf` (tous disponibles dans les dépôts Ubuntu standards, aucun dépôt tiers requis). Sans ça le builder ne peut rien monter/démonter/générer.

## 3. Ce que Linux ne peut PAS faire (et donc ce qu'on ne bricolera pas)

Pour rester honnête (règle absolue du projet : ne jamais fake une capacité) :

- **DISM natif, Windows ADK, WinPE** : indisponibles sous Linux. On ne les simule pas. `wimlib-imagex` couvre l'essentiel de ce dont on a besoin (mount/apply/capture WIM/ESD, ajout/suppression de fichiers offline, export d'images), mais **pas** l'intégration de pilotes/mises à jour au format `.cab` via DISM (`/Add-Package`), ni l'intégration de correctifs cumulatifs signés. Si une étape du pipeline en a strictement besoin, elle sera marquée `REQUIRES_WINDOWS` et documentée comme *étape hybride* (voir §4).
- **Activation/licence Windows** : hors sujet, non touché, non contourné — cf. cahier des charges §4.
- **Composants propriétaires figés dans les binaires système (Shell Experience Host, StartMenuExperienceHost, Explorer.exe, etc.)** : on ne les recompile pas. Toute ressemblance visuelle avec le concept "Windows 12.1" passera par : (a) réglages/registre/policies officiels, (b) remplacement d'assets (fonds d'écran, sons, icônes, thèmes `.theme`/`.deskthemepack`), (c) applications tierces qui *tournent par-dessus* le shell (barre des tâches custom, widgets, etc.), jamais par un patch binaire non documenté du shell Windows. Ce point sera détaillé élément par élément dans `docs/FEATURES.md` avec un état `CONCEPT ONLY` si aucune voie réaliste n'existe.

## 4. Architecture hybride Debian ⇄ Windows VM

```
                          DEBIAN/UBUNTU (ce conteneur / ta machine de dev)
                          ────────────────────────────────────────────────
  Windows 11 25H2 ISO (fournie par toi, légale)
          │
          ▼
  builder/build.sh --iso <path> --profile <full|minimal> [--dry-run]
          │
          ├─ 00-validate   : hash, structure ISO, espace disque, privilèges, outils
          ├─ 10-extract    : xorriso -osirrox → dossier de travail isolé
          ├─ 20-mount      : wimlib-imagex mountrw install.wim <index>
          ├─ 30-registry   : hivexregedit --merge (SOFTWARE/SYSTEM/DEFAULT/NTUSER.DAT)
          ├─ 40-policies   : dépôt de fichiers ADMX/GPO + registre équivalent (gpedit non dispo offline → on écrit directement les clés de registre que la policy aurait posées)
          ├─ 50-ui-assets  : copie assets/ (wallpapers, sons, icônes, thèmes) dans le WIM monté
          ├─ 60-apps       : dépôt d'applications tierces (ex. widget host) + config d'auto-run
          ├─ 70-servicing  : opérations offline supplémentaires (fichiers de config, unattend.xml)
          ├─ 80-commit     : wimlib-imagex unmount --commit
          └─ 90-iso        : xorriso -as mkisofs (structure BIOS+UEFI bootable) → Furax-Windows-12-Beta.iso
          │
          ▼
  Validation finale (checksum, montage de contrôle, boot QEMU/OVMF en mode --dry-run de vérif)
          │
          ▼
  Furax-Windows-12-Beta.iso
          │
          ▼
  vm/test-vm.sh  →  QEMU/KVM + OVMF (UEFI)  →  VM Windows
          │
          ▼
                          🪟 CÔTÉ WINDOWS (uniquement dans la VM)
                          ────────────────────────────────────────────────
          Boot → Installation → Premier démarrage → Smoke tests manuels/scriptés
          (Start Menu, Taskbar, Explorer, Settings, animations, stabilité)
```

**Toute étape marquée `REQUIRES_WINDOWS`** (rare, à éviter autant que possible) sera isolée dans `docs/TROUBLESHOOTING.md` avec la raison exacte et, si possible, un contournement offline (hivex/wimlib) qui produit un résultat équivalent sans avoir besoin de Windows pour builder.

## 5. Arborescence du projet (proposée)

Différences avec ta proposition initiale : `scripts/` renommé implicitement en gardant sa place pour les utilitaires dev génériques, ajout de `vm/` dédié aux VM de test (plus clair que de le laisser dans `scripts/`), `builder/` détaillé avec `lib/`, `modules/`, `profiles/`, `tools/`.

```
furax-windows-12-beta/
│
├── builder/                    # Pipeline de build, exécuté sous Debian/Ubuntu
│   ├── build.sh                 # point d'entrée (./build.sh --iso ... --profile ... [--dry-run])
│   ├── lib/                     # fonctions bash partagées (logging, checks, cleanup/trap)
│   ├── modules/                 # une étape = un script numéroté (00-validate.sh … 90-iso.sh)
│   ├── profiles/                # full.yaml, minimal.yaml (feature flags, §7 du cahier des charges)
│   └── tools/                   # wrappers/détection d'outils (wimlib, xorriso, hivex, 7z…)
│
├── system/                      # Ce qui modifie le comportement "système" de Windows
│   ├── registry/                 # fichiers .reg / diffs de clés, appliqués via hivex
│   ├── policies/                 # équivalents ADMX/GPO traduits en clés registre
│   ├── configuration/            # unattend.xml, fichiers de config offline
│   └── defaults/                 # profil utilisateur par défaut (Default User hive)
│
├── ui/                           # Modifications visuelles/comportementales du shell
│   ├── start/  ├── taskbar/  ├── explorer/  ├── settings/  ├── notifications/  └── desktop/
│
├── apps/                         # Applications tierces qu'on développe (ex. widget host, barre custom)
│
├── assets/
│   ├── icons/  ├── wallpapers/  ├── sounds/  └── themes/
│
├── vm/                           # Test dans une VM Windows via QEMU/KVM
│   └── test-vm.sh
│
├── scripts/                      # Utilitaires dev divers (non liés au pipeline de build)
│
├── tests/
│   ├── build/                    # ISO valide, WIM valide, montable/démontable, aucun mount résiduel
│   ├── configuration/            # registre, policies, fichiers, services appliqués correctement
│   └── runtime/                  # smoke tests dans la VM (si automatisables)
│
├── docs/
│   ├── VIDEO_ANALYSIS.md
│   ├── FEATURES.md
│   ├── ARCHITECTURE.md           # ce document
│   ├── BUILD.md
│   ├── TESTING.md
│   ├── TROUBLESHOOTING.md
│   └── DESIGN_SYSTEM.md
│
└── README.md
```

## 6. Prochaine étape

Cette architecture est une **proposition** : elle sera ajustée une fois `docs/VIDEO_ANALYSIS.md` et `docs/FEATURES.md` terminés (certaines fonctionnalités pourraient nécessiter un dossier `ui/` supplémentaire, par exemple `ui/lockscreen/`). Pas de développement du builder tant que tu n'as pas validé cette structure et donné le feu vert pour installer les outils listés au §2.
