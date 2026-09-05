#!/usr/bin/env bash
# builder/lib/common.sh — logging, vérifications et nettoyage partagés par le pipeline.
# Sourcé par build.sh ; ne pas exécuter directement.

# --- Logging -----------------------------------------------------------

_log_ts() { date '+%Y-%m-%d %H:%M:%S'; }

WARNING_LINES=()

log_info()  { printf '[%s] [INFO ] %s\n'  "$(_log_ts)" "$*" | tee -a "${LOG_FILE:-/dev/null}" ; }
log_warn()  { printf '[%s] [WARN ] %s\n'  "$(_log_ts)" "$*" | tee -a "${LOG_FILE:-/dev/null}" >&2 ; WARNING_LINES+=("$*") ; }
log_error() { printf '[%s] [ERROR] %s\n'  "$(_log_ts)" "$*" | tee -a "${LOG_FILE:-/dev/null}" >&2 ; }
log_step()  { printf '[%s] [STEP ] === %s ===\n' "$(_log_ts)" "$*" | tee -a "${LOG_FILE:-/dev/null}" ; }
log_cmd()   { printf '[%s] [CMD  ] %s\n'  "$(_log_ts)" "$*" | tee -a "${LOG_FILE:-/dev/null}" ; }

# Exécute une commande en la journalisant. En mode --dry-run, l'affiche sans l'exécuter.
run() {
  log_cmd "$*"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) commande non exécutée"
    return 0
  fi
  "$@"
}

# --- Rapport de build ----------------------------------------------------

REPORT_LINES=()
report_step() {
  # report_step <nom_étape> <STATUT: OK|FAILED|SKIPPED|DRY-RUN> [détail]
  local name="$1" status="$2" detail="${3:-}"
  REPORT_LINES+=("$(_log_ts) | ${status} | ${name} | ${detail}")
}

write_report() {
  local report_file="$1"
  local out_size_mo="N/A"
  if [[ -n "${OUT_ISO:-}" && -f "${OUT_ISO:-}" ]]; then
    out_size_mo="$(( $(stat -c '%s' "$OUT_ISO") / 1024 / 1024 )) Mo"
  fi
  {
    echo "======================================================================"
    echo "Furax Windows 12 Beta — Rapport de build (Release Candidate)"
    echo "======================================================================"
    echo ""
    echo "--- Build ---"
    echo "Build ID       : ${BUILD_ID:-N/A}"
    echo "Démarré        : ${BUILD_START_TS:-N/A}"
    echo "Terminé        : $(_log_ts)"
    echo "Profil         : ${PROFILE:-N/A}"
    echo "Mode           : $([[ "${DRY_RUN:-0}" -eq 1 ]] && echo 'DRY-RUN (aucune modification)' || echo 'RÉEL')"
    echo ""
    echo "--- Source Windows ---"
    echo "ISO source     : ${ISO_PATH:-N/A}"
    echo "SHA-256 source : ${ISO_SHA256:-N/A}"
    echo "Produit        : ${WIN_PRODUCT_NAME:-N/A}"
    echo "Édition        : ${WIN_EDITION_ID:-N/A}"
    echo "Architecture   : ${WIN_ARCHITECTURE:-N/A}"
    echo "Version        : ${WIN_MAJOR_VERSION:-N/A}.${WIN_MINOR_VERSION:-N/A} (build ${WIN_BUILD:-N/A}.${WIN_SP_BUILD:-N/A})"
    echo "Langues        : ${WIN_LANGUAGES:-N/A}"
    echo ""
    echo "--- Fonctionnalités activées / désactivées (profil ${PROFILE:-N/A}) ---"
    echo "trivial_marker (preuve de mécanisme)         : $([[ "${FEATURE_TRIVIAL_MARKER:-0}" -eq 1 ]] && echo ACTIVÉ || echo désactivé)"
    echo "branding (\"By FuraxDev\" winver + OEM)         : $([[ "${FEATURE_BRANDING:-0}" -eq 1 ]] && echo ACTIVÉ || echo désactivé)"
    echo "wallpaper (fond d'écran par défaut)          : $([[ "${FEATURE_WALLPAPER:-0}" -eq 1 ]] && echo ACTIVÉ || echo désactivé)"
    echo "theme (sombre + transparence + accent)       : $([[ "${FEATURE_THEME:-0}" -eq 1 ]] && echo ACTIVÉ || echo désactivé)"
    echo "taskbar_floating_pill_experimental           : $([[ "${FEATURE_TASKBAR_EXPERIMENTAL:-0}" -eq 1 ]] && echo "ACTIVÉ (EXPERIMENTAL/UNTESTED)" || echo désactivé)"
    echo ""
    echo "--- Résultat ---"
    echo "ISO générée    : ${OUT_ISO:-N/A}"
    echo "Taille ISO     : ${out_size_mo}"
    echo "SHA-256 ISO    : ${OUT_SHA256:-N/A}"
    echo ""
    echo "--- Étapes du pipeline ---"
    printf '%s\n' "${REPORT_LINES[@]}"
    echo ""
    if [[ ${#WARNING_LINES[@]} -gt 0 ]]; then
      echo "--- Warnings (${#WARNING_LINES[@]}) ---"
      printf -- '- %s\n' "${WARNING_LINES[@]}"
    else
      echo "--- Warnings : aucun ---"
    fi
    echo ""
    echo "--- Rappel honnête ---"
    echo "Ce rapport atteste que les étapes ci-dessus ont réellement été exécutées et que"
    echo "les valeurs/fichiers modifiés ont été vérifiés par relecture directe dans le WIM"
    echo "généré (registre via hivexget, fichiers via wimlib-imagex extract). Il n'atteste"
    echo "PAS d'un boot réel confirmé de cette ISO précise ni d'un rendu visuel dans un"
    echo "bureau Windows démarré — voir docs/TESTING.md pour l'état exact des validations."
  } > "$report_file"
  log_info "Rapport écrit : $report_file"
}

# --- Vérifications --------------------------------------------------------

require_tool() {
  local tool="$1" pkg_hint="${2:-}"
  if ! command -v "$tool" >/dev/null 2>&1; then
    log_error "Outil requis manquant : '$tool'${pkg_hint:+ (paquet: $pkg_hint)}"
    return 1
  fi
  log_info "Outil trouvé : $tool -> $(command -v "$tool")"
  return 0
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    log_error "Ce script doit être exécuté en root (montage WIM/hivex nécessite des privilèges)."
    return 1
  fi
  log_info "Exécution en root confirmée (EUID=0)."
  return 0
}

# check_disk_space <chemin> <octets_minimum>
check_disk_space() {
  local path="$1" min_bytes="$2"
  local avail
  avail=$(df --output=avail -B1 "$path" 2>/dev/null | tail -n1 | tr -d ' ')
  if [[ -z "$avail" ]]; then
    log_error "Impossible de déterminer l'espace disque disponible pour $path"
    return 1
  fi
  log_info "Espace disponible sur $path : $((avail / 1024 / 1024)) Mo (requis : $((min_bytes / 1024 / 1024)) Mo)"
  if (( avail < min_bytes )); then
    log_error "Espace disque insuffisant sur $path"
    return 1
  fi
  return 0
}

# --- Nettoyage (trap) ------------------------------------------------------

# État global suivi pour le nettoyage de sécurité en cas d'échec.
MOUNTED_WIM_PATH=""
MOUNTED_DIR=""

cleanup_on_exit() {
  local exit_code=$?
  if [[ -n "$MOUNTED_DIR" && -d "$MOUNTED_DIR" ]]; then
    if mountpoint -q "$MOUNTED_DIR" 2>/dev/null; then
      log_warn "Nettoyage de sécurité : démontage de $MOUNTED_DIR (build interrompu)"
      wimlib-imagex unmount "$MOUNTED_DIR" >>"${LOG_FILE:-/dev/null}" 2>&1 \
        || fusermount -uz "$MOUNTED_DIR" >>"${LOG_FILE:-/dev/null}" 2>&1 \
        || log_error "Échec du démontage de sécurité de $MOUNTED_DIR — intervention manuelle requise : wimlib-imagex unmount '$MOUNTED_DIR'"
    fi
  fi

  if [[ $exit_code -ne 0 ]]; then
    log_error "Build interrompu (code de sortie $exit_code)."
    report_step "BUILD" "FAILED" "code de sortie $exit_code"
  fi

  # On copie le log dans OUT_DIR (persistant) AVANT de potentiellement supprimer WORK_DIR,
  # pour ne jamais perdre la trace d'un build (réussi ou non).
  if [[ -n "${LOG_FILE:-}" && -f "${LOG_FILE:-}" && -n "${OUT_DIR:-}" ]]; then
    mkdir -p "$OUT_DIR" 2>/dev/null || true
    cp -f "$LOG_FILE" "$OUT_DIR/build-${BUILD_ID:-unknown}.log" 2>/dev/null || true
  fi

  if [[ -n "${REPORT_FILE:-}" ]]; then
    write_report "$REPORT_FILE" || true
    if [[ -n "${OUT_DIR:-}" ]]; then
      cp -f "$REPORT_FILE" "$OUT_DIR/FuraxWindows12-Beta-x64.rapport.txt" 2>/dev/null || true
    fi
  fi

  if [[ -n "${WORK_DIR:-}" && -d "${WORK_DIR:-}" ]]; then
    if [[ $exit_code -ne 0 ]]; then
      log_warn "Le répertoire de travail est conservé pour inspection après échec : $WORK_DIR"
    elif [[ "${DRY_RUN:-0}" -eq 0 && "${KEEP_WORK:-0}" -eq 0 ]]; then
      rm -rf "$WORK_DIR"
    fi
  fi

  exit "$exit_code"
}
