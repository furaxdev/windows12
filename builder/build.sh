#!/usr/bin/env bash
# build.sh — Furax Windows 12 Beta — pipeline de build (Phase 2 : builder minimal)
#
# Usage:
#   ./builder/build.sh --iso <chemin.iso> [--profile minimal|full] [--dry-run]
#                       [--work-dir <chemin>] [--out <chemin.iso>] [--wim-index N] [--keep-work]
#
# Ce script NE modifie JAMAIS l'ISO source (toujours ouverte en lecture seule).
# Il doit être exécuté en root (montage WIM + édition de registre offline).
set -euo pipefail

BUILDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$BUILDER_DIR/.." && pwd)"

# shellcheck source=lib/common.sh
source "$BUILDER_DIR/lib/common.sh"
for m in "$BUILDER_DIR"/modules/*.sh; do
  # shellcheck disable=SC1090
  source "$m"
done

# --- Valeurs par défaut ---
ISO_PATH=""
PROFILE="minimal"
DRY_RUN=0
WORK_ROOT="$PROJECT_ROOT/build/_work"
OUT_DIR="$PROJECT_ROOT/build/_out"
OUT_ISO=""
WIM_INDEX=""
KEEP_WORK=0

usage() {
  cat <<EOF
Furax Windows 12 Beta — builder (Phase 2 : builder minimal)

Usage: $0 --iso <chemin.iso> [options]

Options:
  --iso <chemin>        Chemin vers l'ISO Windows 11 source (obligatoire)
  --profile <nom>       Profil de fonctionnalités : minimal (défaut) | full
  --wim-index <N>       Index de l'image dans install.wim/install.esd (défaut : 1)
  --work-dir <chemin>   Dossier de travail (défaut : $WORK_ROOT)
  --out <chemin>        Chemin de l'ISO générée (défaut : $OUT_DIR/FuraxWindows12-Beta-x64.iso)
  --keep-work           Ne pas supprimer le dossier de travail après un build réussi
  --dry-run             N'exécute aucune commande destructive/de montage, affiche le plan
  -h, --help            Affiche cette aide
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso) ISO_PATH="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --wim-index) WIM_INDEX="$2"; shift 2 ;;
    --work-dir) WORK_ROOT="$2"; shift 2 ;;
    --out) OUT_ISO="$2"; shift 2 ;;
    --keep-work) KEEP_WORK=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$ISO_PATH" ]]; then
  echo "Erreur : --iso <chemin.iso> est obligatoire." >&2
  usage
  exit 2
fi
ISO_PATH="$(readlink -f "$ISO_PATH" 2>/dev/null || echo "$ISO_PATH")"

PROFILE_FILE="$BUILDER_DIR/profiles/${PROFILE}.yaml"
if [[ ! -f "$PROFILE_FILE" ]]; then
  echo "Erreur : profil inconnu '$PROFILE' (fichier attendu : $PROFILE_FILE)" >&2
  exit 2
fi

BUILD_ID="$(date '+%Y%m%d-%H%M%S')"
WORK_DIR="$WORK_ROOT/furax-build-$BUILD_ID"
mkdir -p "$WORK_DIR" "$OUT_DIR"
LOG_FILE="$WORK_DIR/build.log"
REPORT_FILE="$OUT_DIR/rapport-build-$BUILD_ID.txt"
: > "$LOG_FILE"

[[ -z "$OUT_ISO" ]] && OUT_ISO="$OUT_DIR/FuraxWindows12-Beta-x64.iso"

BUILD_START_TS="$(_log_ts)"

trap cleanup_on_exit EXIT

log_step "Furax Windows 12 Beta — build $BUILD_ID"
log_info "ISO source     : $ISO_PATH"
log_info "Profil         : $PROFILE ($PROFILE_FILE)"
log_info "Mode           : $([[ "$DRY_RUN" -eq 1 ]] && echo 'DRY-RUN (aucune modification)' || echo 'RÉEL')"
log_info "Dossier travail: $WORK_DIR"
log_info "ISO de sortie  : $OUT_ISO"
log_info "Fichier de log : $LOG_FILE"

# Lecture minimale du profil (le format est volontairement simple en Phase 2 — pas de vraie
# hiérarchie de features à interpréter pour l'instant, voir builder/profiles/*.yaml).
if grep -q '^\s*trivial_marker:\s*true' "$PROFILE_FILE"; then
  FEATURE_TRIVIAL_MARKER=1
else
  FEATURE_TRIVIAL_MARKER=0
fi
if grep -q '^\s*wallpaper:\s*true' "$PROFILE_FILE"; then
  FEATURE_WALLPAPER=1
else
  FEATURE_WALLPAPER=0
fi
if grep -q '^\s*branding:\s*true' "$PROFILE_FILE"; then
  FEATURE_BRANDING=1
else
  FEATURE_BRANDING=0
fi
if grep -q '^\s*theme:\s*true' "$PROFILE_FILE"; then
  FEATURE_THEME=1
else
  FEATURE_THEME=0
fi
if grep -q '^\s*taskbar_floating_pill_experimental:\s*true' "$PROFILE_FILE"; then
  FEATURE_TASKBAR_EXPERIMENTAL=1
else
  FEATURE_TASKBAR_EXPERIMENTAL=0
fi
log_info "Feature trivial_marker (profil $PROFILE) : $FEATURE_TRIVIAL_MARKER"
log_info "Feature wallpaper (profil $PROFILE) : $FEATURE_WALLPAPER"
log_info "Feature branding (profil $PROFILE) : $FEATURE_BRANDING"
log_info "Feature theme (profil $PROFILE) : $FEATURE_THEME"
log_info "Feature taskbar_floating_pill_experimental (profil $PROFILE) : $FEATURE_TASKBAR_EXPERIMENTAL (EXPERIMENTAL/UNTESTED — documentation uniquement, jamais d'exécution auto)"

# --- Pipeline ---
module_00_validate
module_10_extract
module_20_identify
module_30_mount

if [[ "$FEATURE_TRIVIAL_MARKER" -eq 1 ]]; then
  module_40_customize_minimal
else
  log_step "40-customize-minimal : SKIPPED (désactivé par le profil $PROFILE)"
  report_step "40-customize-minimal" "SKIPPED" "désactivé par le profil"
fi

if [[ "$FEATURE_BRANDING" -eq 1 ]]; then
  module_42_branding
else
  log_step "42-branding : SKIPPED (désactivé par le profil $PROFILE)"
  report_step "42-branding" "SKIPPED" "désactivé par le profil"
fi

if [[ "$FEATURE_WALLPAPER" -eq 1 ]]; then
  module_45_wallpaper
else
  log_step "45-wallpaper : SKIPPED (désactivé par le profil $PROFILE)"
  report_step "45-wallpaper" "SKIPPED" "désactivé par le profil"
fi

if [[ "$FEATURE_THEME" -eq 1 ]]; then
  module_46_theme
else
  log_step "46-theme : SKIPPED (désactivé par le profil $PROFILE)"
  report_step "46-theme" "SKIPPED" "désactivé par le profil"
fi

if [[ "$FEATURE_TASKBAR_EXPERIMENTAL" -eq 1 ]]; then
  module_48_taskbar_experimental
else
  log_step "48-taskbar-experimental : SKIPPED (EXPERIMENTAL, désactivé par défaut/par le profil $PROFILE)"
  report_step "48-taskbar-experimental" "SKIPPED" "expérimental, désactivé par défaut"
fi

# Toujours déposé (zéro risque : dépôt de fichier, aucune exécution automatique) — c'est le
# contrepoint direct des personnalisations réellement appliquées ci-dessus.
module_49_rollback_scripts

module_50_unmount
module_60_build_iso
module_70_validate_output

log_step "Build terminé avec succès : $OUT_ISO"
report_step "BUILD" "OK" "$OUT_ISO"
[[ "$DRY_RUN" -eq 0 && "$KEEP_WORK" -eq 0 ]] && log_info "Le dossier de travail sera nettoyé automatiquement (utilise --keep-work pour le conserver) : $WORK_DIR"

exit 0
