#!/usr/bin/env bash
# prepare-self-hosted-runner.sh — prépare une machine Linux (Debian/Ubuntu) pour héberger
# le runner GitHub Actions self-hosted "furax-windows12-builder", utilisé par
# .github/workflows/build-full-iso.yml (demande explicite de FuraxDev, 03/10/2026).
#
# Ce script :
#   - vérifie l'OS/l'architecture et l'espace disque disponible ;
#   - installe/vérifie TOUTES les dépendances listées dans docs/BUILD.md §7.1
#     (identiques à celles vérifiées par le workflow build-full-iso.yml) ;
#   - installe le SDK .NET 8 dans /opt/dotnet (même emplacement que celui attendu par
#     builder/build.sh et le workflow, via DOTNET_ROOT) ;
#   - télécharge et prépare le répertoire du runner GitHub Actions officiel
#     (actions/runner, binaire public, pas du contenu Microsoft sous licence) ;
#   - affiche à la fin les étapes MANUELLES restantes (enregistrement auprès de GitHub).
#
# Ce que ce script NE FAIT PAS, volontairement :
#   - il ne télécharge, ne lit ni ne manipule AUCUNE ISO Windows ;
#   - il ne demande, ne stocke ni ne transmet AUCUN secret/token — l'enregistrement du
#     runner (./config.sh --token ...) reste une étape manuelle, car le token de
#     registration s'obtient depuis l'interface GitHub et est à usage unique/court ;
#   - il n'ajoute AUCUN dépôt tiers (PPA, etc.) — cohérent avec la règle du projet
#     "dépôts officiels Ubuntu/Debian uniquement" (voir docs/BUILD.md §1.2).
#
# Usage :
#   sudo ./scripts/ci-runner/prepare-self-hosted-runner.sh [--runner-dir /chemin]
#
# Doit être exécuté en root (apt-get install, écriture dans /opt).

set -euo pipefail

RUNNER_DIR="/opt/actions-runner-furax-windows12"
GITHUB_REPO_URL="https://github.com/furaxdev/windows12"
RUNNER_LABEL="furax-windows12-builder"
MIN_DISK_GB=30
FAIL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runner-dir) RUNNER_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--runner-dir /chemin/vers/le/runner]"
      exit 0 ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
done

c_info()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
c_ok()    { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
c_warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
c_err()   { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*"; FAIL=1; }
c_step()  { printf '\n\033[1m=== %s ===\033[0m\n' "$*"; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Ce script doit être exécuté en root (sudo). Relance-le avec : sudo $0" >&2
  exit 1
fi

# --- 1. OS / architecture ------------------------------------------------------------

c_step "1. Vérification OS / architecture"

if [[ ! -r /etc/os-release ]]; then
  c_err "/etc/os-release introuvable — impossible de confirmer une base Debian/Ubuntu. Ce projet ne documente que cette famille (voir docs/BUILD.md §1). Arrêt."
  exit 1
fi
# shellcheck disable=SC1091
source /etc/os-release
OS_ID="${ID:-inconnu}"
OS_LIKE="${ID_LIKE:-}"
c_info "OS détecté : ${PRETTY_NAME:-inconnu} (ID=$OS_ID, ID_LIKE=$OS_LIKE)"
if [[ "$OS_ID" != "debian" && "$OS_ID" != "ubuntu" && "$OS_LIKE" != *debian* && "$OS_LIKE" != *ubuntu* ]]; then
  c_err "Ce script cible Debian/Ubuntu (apt) comme tout le reste du projet (docs/BUILD.md §1 : \"dépôts officiels Ubuntu/Debian\"). OS détecté non supporté par ce script : $OS_ID."
  exit 1
fi
c_ok "Base Debian/Ubuntu confirmée."

ARCH="$(uname -m)"
c_info "Architecture : $ARCH"
case "$ARCH" in
  x86_64)
    RUNNER_ARCH="x64" ;;
  aarch64|arm64)
    RUNNER_ARCH="arm64"
    c_warn "Architecture ARM64 détectée. Le pipeline (wimlib-imagex/xorriso/hivex) devrait fonctionner (outils génériques), mais ce n'est PAS la combinaison testée par ce projet jusqu'ici (toujours fait sur x86_64) — considère ce chemin comme non vérifié." ;;
  *)
    c_err "Architecture non reconnue/non supportée par ce script : $ARCH"
    exit 1 ;;
esac

# --- 2. Espace disque disponible -----------------------------------------------------

c_step "2. Vérification de l'espace disque"

TARGET_FS_PATH="$(dirname "$RUNNER_DIR")"
mkdir -p "$TARGET_FS_PATH" 2>/dev/null || true
AVAIL_KB=$(df --output=avail -k "$TARGET_FS_PATH" 2>/dev/null | tail -n1 | tr -d ' ')
AVAIL_GB=$(( AVAIL_KB / 1024 / 1024 ))
c_info "Espace disponible sur $TARGET_FS_PATH : ${AVAIL_GB} Go"
if (( AVAIL_GB < MIN_DISK_GB )); then
  c_err "Moins de ${MIN_DISK_GB} Go disponibles. Le build complet a besoin d'environ 2,5x la taille de ton ISO source (une ISO Windows 11 fait ~8 Go -> ~20 Go nécessaires) EN PLUS de la place pour le runner lui-même. Libère de l'espace avant de continuer."
else
  c_ok "Espace disque suffisant pour préparer le runner (le workflow build-full-iso.yml re-vérifiera l'espace exact nécessaire selon la taille réelle de ton ISO, à chaque run)."
fi

# --- 3. Dépendances apt (identiques à docs/BUILD.md §1.2 et §7.1) -------------------

c_step "3. Installation/vérification des dépendances (dépôts officiels Debian/Ubuntu uniquement)"

c_info "apt-get update..."
apt-get update -qq

# Liste strictement alignée sur docs/BUILD.md §1.2 (dépendances du builder) + les ajouts
# §7.1 (ce que le workflow build-full-iso.yml vérifie en plus : qemu, .NET via script
# officiel séparé ci-dessous, pas via apt).
APT_PACKAGES=(
  wimtools         # wimlib-imagex
  xorriso
  p7zip-full       # 7z
  libarchive-tools # bsdtar
  libhivex-bin
  python3-hivex
  qemu-system-x86
  qemu-utils
  ovmf
  curl             # nécessaire pour le téléchargement du runner + du script .NET
  tar
)
c_info "Installation : ${APT_PACKAGES[*]}"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${APT_PACKAGES[@]}"
c_ok "Paquets apt installés (ou déjà présents)."

# --- 4. Vérification des versions / binaires -----------------------------------------

c_step "4. Vérification des outils (doit correspondre à ce que build-full-iso.yml vérifie)"

check_tool() {
  local name="$1" version_cmd="$2"
  if command -v "$name" >/dev/null 2>&1; then
    local v
    v=$(eval "$version_cmd" 2>&1 | head -n1)
    c_ok "$name -> $(command -v "$name") ($v)"
  else
    c_err "$name introuvable après installation."
  fi
}

check_tool wimlib-imagex "wimlib-imagex --version"
check_tool xorriso "xorriso -version"
check_tool 7z "7z | head -2 | tail -1"
check_tool bsdtar "bsdtar --version"
check_tool qemu-system-x86_64 "qemu-system-x86_64 --version"
check_tool qemu-img "qemu-img --version"

if [[ -f /usr/share/OVMF/OVMF_CODE.fd ]]; then
  c_ok "Firmware UEFI OVMF trouvé : /usr/share/OVMF/OVMF_CODE.fd (nécessaire pour vm/test-vm.sh / tests QEMU UEFI)."
else
  c_warn "Firmware OVMF non trouvé au chemin attendu (/usr/share/OVMF/OVMF_CODE.fd) — vérifie le paquet 'ovmf', le chemin peut varier selon la version."
fi

# --- 5. Python 3.12 + module hivex (piège documenté dans docs/BUILD.md §1.2) ---------

c_step "5. Vérification Python 3.12 + module hivex"

# Le pipeline (builder/tools/hivex_set_value.py) appelle explicitement /usr/bin/python3.12
# pour éviter un mismatch de version Python (voir docs/BUILD.md §1.2). On ne devine pas
# une autre version : soit elle est là et fonctionne, soit c'est signalé clairement.
if [[ -x /usr/bin/python3.12 ]]; then
  c_ok "python3.12 trouvé : /usr/bin/python3.12 ($(/usr/bin/python3.12 --version 2>&1))"
  if /usr/bin/python3.12 -c "import hivex" >/dev/null 2>&1; then
    c_ok "Module hivex importable sous python3.12."
  else
    c_err "python3.12 présent mais 'import hivex' échoue. Le paquet python3-hivex installé ne correspond probablement pas à cette version de Python (piège documenté dans docs/BUILD.md §1.2). Ce projet n'ajoute pas de dépôt tiers pour corriger ça automatiquement — à résoudre manuellement selon ta distribution exacte (ex. vérifier quelle version de Python ta distribution lie à python3-hivex via : dpkg -L python3-hivex)."
  fi
else
  c_err "python3.12 introuvable (/usr/bin/python3.12). Sans lui, le module 40/42/45/46/47/48c (édition de registre offline) sera SKIPPED par le pipeline — le build tournera mais sans la plupart des personnalisations. Installe python3.12 via les dépôts officiels de ta distribution si disponible, sans dépôt tiers (voir contrainte du projet)."
fi

# --- 6. .NET 8 SDK (installé en dehors d'apt, comme documenté/utilisé par le projet) --

c_step "6. SDK .NET 8 (/opt/dotnet)"

if [[ -x /opt/dotnet/dotnet ]] && /opt/dotnet/dotnet --list-sdks 2>/dev/null | grep -q '^8\.'; then
  c_ok ".NET 8 SDK déjà installé : $(/opt/dotnet/dotnet --list-sdks | grep '^8\.')"
else
  c_info "Installation du SDK .NET 8 via le script officiel Microsoft (dotnet-install.sh) dans /opt/dotnet..."
  curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
  bash /tmp/dotnet-install.sh --channel 8.0 --install-dir /opt/dotnet
  rm -f /tmp/dotnet-install.sh
  if [[ -x /opt/dotnet/dotnet ]]; then
    c_ok ".NET 8 SDK installé : $(/opt/dotnet/dotnet --version)"
  else
    c_err "Échec de l'installation du SDK .NET 8."
  fi
fi
c_info "Rappel : le workflow build-full-iso.yml et builder/build.sh attendent DOTNET_ROOT=/opt/dotnet et PATH incluant /opt/dotnet — rien à faire de plus ici, c'est déjà au bon endroit."

# --- 7. sudo disponible (build.sh/le workflow s'exécutent via sudo) ------------------

c_step "7. Vérification des privilèges disponibles pour le futur utilisateur du runner"

if command -v sudo >/dev/null 2>&1; then
  c_ok "sudo est installé sur cette machine."
  c_warn "Le workflow exécute 'sudo -E ./builder/build.sh ...' — l'UTILISATEUR qui fera tourner le service du runner GitHub Actions doit pouvoir faire du sudo sans mot de passe interactif (sinon le job restera bloqué en attente d'un mot de passe qui ne viendra jamais). Si le runner tourne sous un compte dédié, configure une règle sudoers adaptée (hors scope de ce script, à faire toi-même selon ta politique de sécurité)."
else
  c_err "sudo introuvable — nécessaire pour que le build.sh (montage WIM/édition de registre offline) fonctionne depuis le workflow."
fi

# --- 8. Préparation du répertoire du runner GitHub Actions ---------------------------

c_step "8. Préparation du répertoire du runner GitHub Actions ($RUNNER_DIR)"

mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

if [[ -x "$RUNNER_DIR/config.sh" ]]; then
  c_ok "Binaire du runner déjà présent dans $RUNNER_DIR — rien à télécharger."
else
  c_info "Récupération de la dernière version du runner GitHub Actions officiel (actions/runner, binaire public, aucun contenu Microsoft sous licence)..."
  LATEST_TAG=$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | grep -m1 '"tag_name"' | sed -E 's/.*"v([0-9.]+)".*/\1/')
  if [[ -z "$LATEST_TAG" ]]; then
    c_err "Impossible de déterminer la dernière version du runner (problème réseau/API GitHub ?). Télécharge-le manuellement depuis https://github.com/actions/runner/releases et extrais-le dans $RUNNER_DIR."
  else
    RUNNER_PKG="actions-runner-linux-${RUNNER_ARCH}-${LATEST_TAG}.tar.gz"
    RUNNER_URL="https://github.com/actions/runner/releases/download/v${LATEST_TAG}/${RUNNER_PKG}"
    c_info "Téléchargement : $RUNNER_URL"
    curl -fsSL -o "$RUNNER_PKG" "$RUNNER_URL"
    tar xzf "$RUNNER_PKG"
    rm -f "$RUNNER_PKG"
    c_ok "Runner v$LATEST_TAG téléchargé et extrait dans $RUNNER_DIR."
    if [[ -x "$RUNNER_DIR/bin/installdependencies.sh" ]]; then
      c_info "Installation des dépendances système du runner lui-même (script officiel installdependencies.sh)..."
      "$RUNNER_DIR/bin/installdependencies.sh" || c_warn "installdependencies.sh a renvoyé une erreur non bloquante — vérifie la sortie ci-dessus."
    fi
  fi
fi

chown -R "${SUDO_USER:-root}:${SUDO_USER:-root}" "$RUNNER_DIR" 2>/dev/null || true

# --- Résumé final ----------------------------------------------------------------------

c_step "Résumé"

if [[ "$FAIL" -eq 0 ]]; then
  c_ok "Toutes les vérifications automatisables sont passées."
else
  c_warn "Au moins une vérification a échoué (voir [FAIL] ci-dessus) — corrige-la avant d'enregistrer le runner."
fi

cat <<EOF

================================================================================
 ÉTAPES MANUELLES RESTANTES (ce script ne les fait PAS, volontairement)
================================================================================

1. Récupère un token de registration (usage unique, valable ~1h) sur GitHub :
   $GITHUB_REPO_URL/settings/actions/runners/new

2. Enregistre ce runner avec le label "$RUNNER_LABEL" (requis : le workflow
   build-full-iso.yml cible spécifiquement ce label) :

     cd $RUNNER_DIR
     ./config.sh --url $GITHUB_REPO_URL --token <TON_TOKEN_ICI> --labels $RUNNER_LABEL

   (remplace <TON_TOKEN_ICI> par le token affiché à l'étape 1 — ne le mets jamais dans un
   script versionné ou un fichier commité)

3. Lance le runner :
     - en premier plan pour tester : ./run.sh
     - ou comme service persistant :
         sudo ./svc.sh install
         sudo ./svc.sh start

4. Vérifie qu'il apparaît "Idle" sur :
   $GITHUB_REPO_URL/settings/actions/runners

5. Ensuite, déclenche le build depuis l'onglet Actions du dépôt : workflow
   "Build complet ISO (self-hosted uniquement)" > Run workflow, avec le chemin
   ABSOLU de ta vraie ISO Windows 11 sur CETTE machine (iso_path) — elle ne
   sera jamais uploadée vers GitHub, voir docs/BUILD.md §7.

================================================================================
EOF

exit "$FAIL"
