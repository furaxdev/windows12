#!/usr/bin/env bash
# 00-validate.sh — vérifie l'ISO source, les outils, l'espace disque et les privilèges.
# Sourcé par build.sh. Variables attendues en entrée : ISO_PATH, WORK_ROOT, LOG_FILE.

module_00_validate() {
  log_step "00-validate : validation de l'environnement et de l'ISO source"

  if [[ -z "${ISO_PATH:-}" ]]; then
    log_error "Aucune ISO fournie (--iso <chemin>)."
    report_step "00-validate" "FAILED" "ISO manquante"
    return 1
  fi

  if [[ ! -f "$ISO_PATH" ]]; then
    log_error "Fichier ISO introuvable : $ISO_PATH"
    report_step "00-validate" "FAILED" "fichier introuvable"
    return 1
  fi

  # --- Outils requis ---
  local tool_fail=0
  require_tool xorriso xorriso || tool_fail=1
  require_tool wimlib-imagex wimtools || tool_fail=1
  require_tool 7z p7zip-full || tool_fail=1
  require_tool bsdtar libarchive-tools || tool_fail=1
  require_tool qemu-system-x86_64 qemu-system-x86 || tool_fail=1
  require_tool qemu-img qemu-utils || tool_fail=1
  if [[ ! -x /usr/bin/python3.12 ]] || ! /usr/bin/python3.12 -c "import hivex" >/dev/null 2>&1; then
    log_warn "python3.12 + module hivex indisponible — l'édition de registre offline (module 40) sera SKIPPED, pas simulée."
    HIVEX_AVAILABLE=0
  else
    log_info "hivex disponible via /usr/bin/python3.12"
    HIVEX_AVAILABLE=1
  fi
  if [[ $tool_fail -ne 0 ]]; then
    report_step "00-validate" "FAILED" "outil(s) manquant(s)"
    return 1
  fi

  # --- Privilèges ---
  require_root || { report_step "00-validate" "FAILED" "privilèges insuffisants"; return 1; }

  # --- Espace disque ---
  # Le montage WIM via FUSE n'écrit pas de copie complète séparée (overlay léger), donc le
  # gros du besoin réel est : arborescence extraite (~= taille ISO) + ISO régénérée (~= taille
  # ISO) + marge de sécurité 25%. On exige 2.5x la taille de l'ISO source, pas plus — un
  # multiplicateur type "6x" était injustifié et faisait échouer des builds qui auraient
  # parfaitement tenu dans l'espace disponible.
  local iso_size min_required
  iso_size=$(stat -c '%s' "$ISO_PATH")
  min_required=$(( iso_size * 5 / 2 ))
  log_info "Estimation d'espace requis : extraction (~1x ISO) + ISO de sortie (~1x ISO) + marge 25% = $((min_required / 1024 / 1024)) Mo"
  check_disk_space "$(dirname "$WORK_ROOT")" "$min_required" \
    || { report_step "00-validate" "FAILED" "espace disque insuffisant"; return 1; }

  # --- Intégrité / structure de l'ISO ---
  log_info "Taille de l'ISO source : $(( iso_size / 1024 / 1024 )) Mo"
  log_info "SHA-256 de l'ISO source (peut prendre du temps sur une grosse ISO)..."
  ISO_SHA256=$(sha256sum "$ISO_PATH" | awk '{print $1}')
  log_info "SHA-256 = $ISO_SHA256"
  log_warn "Aucun hash officiel Microsoft n'est comparé automatiquement (nécessiterait de télécharger l'ISO officielle pour comparaison, ce que ce projet ne fait pas). Vérifie toi-même ce hash contre la page officielle de téléchargement Microsoft si besoin."

  log_info "Lecture de la structure de l'ISO via xorriso (validation non destructive, système de boot)..."
  if ! xorriso -indev "$ISO_PATH" -report_system_area plain >>"$LOG_FILE" 2>&1; then
    log_error "xorriso n'a pas pu lire l'ISO — fichier probablement corrompu ou pas une image ISO valide."
    report_step "00-validate" "FAILED" "ISO illisible par xorriso"
    return 1
  fi

  # IMPORTANT : les ISO Windows modernes (>4 Go) sont en UDF pur, sans arborescence ISO9660
  # complète — `xorriso -find` ne verrait quasiment aucun fichier sur ce type d'image (vérifié
  # en pratique). On utilise `7z l` (lecteur UDF fonctionnel, vérifié) pour vérifier la
  # présence de sources/install.wim ou sources/install.esd.
  local listing
  listing=$(7z l "$ISO_PATH" 2>>"$LOG_FILE" | grep -iE 'sources[\\/](install\.wim|install\.esd)' || true)
  if [[ -z "$listing" ]]; then
    log_error "Aucun sources/install.wim ni sources/install.esd trouvé dans l'ISO (via 7z l) — ce n'est probablement pas une ISO d'installation Windows standard."
    report_step "00-validate" "FAILED" "install.wim/install.esd absent"
    return 1
  fi
  log_info "Image(s) d'installation trouvée(s) dans l'ISO :"
  echo "$listing" | tee -a "$LOG_FILE"

  log_info "Validation 00-validate : OK"
  report_step "00-validate" "OK" "SHA-256=$ISO_SHA256"
  return 0
}
