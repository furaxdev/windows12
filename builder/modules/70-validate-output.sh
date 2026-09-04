#!/usr/bin/env bash
# 70-validate-output.sh — validation de l'ISO générée : existence, taille, lisibilité,
# présence du fichier marqueur, checksum. Ne remplace PAS un test de boot réel en VM
# (voir vm/test-vm.sh et docs/TESTING.md) — c'est une validation structurelle uniquement.

module_70_validate_output() {
  log_step "70-validate-output : validation de l'ISO générée"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) validerait l'existence/lisibilité/contenu de $OUT_ISO"
    report_step "70-validate-output" "DRY-RUN"
    return 0
  fi

  if [[ ! -f "$OUT_ISO" ]]; then
    log_error "ISO de sortie introuvable : $OUT_ISO"
    report_step "70-validate-output" "FAILED" "fichier absent"
    return 1
  fi

  local src_size out_size
  src_size=$(stat -c '%s' "$ISO_PATH")
  out_size=$(stat -c '%s' "$OUT_ISO")
  log_info "Taille ISO source : $((src_size / 1024 / 1024)) Mo — Taille ISO générée : $((out_size / 1024 / 1024)) Mo"
  if (( out_size < src_size / 2 )); then
    log_error "L'ISO générée fait moins de la moitié de la taille de la source — probablement corrompue/incomplète."
    report_step "70-validate-output" "FAILED" "taille anormalement faible"
    return 1
  fi

  log_info "Lecture de la structure de l'ISO générée via xorriso..."
  if ! xorriso -indev "$OUT_ISO" -report_system_area plain >>"$LOG_FILE" 2>&1; then
    log_error "xorriso ne parvient pas à lire l'ISO générée."
    report_step "70-validate-output" "FAILED" "ISO générée illisible"
    return 1
  fi

  log_info "Vérification de la présence de sources/install.wim ou install.esd dans l'ISO générée..."
  local listing
  listing=$(xorriso -indev "$OUT_ISO" -find / -name 'install.wim' -o -name 'install.esd' 2>>"$LOG_FILE")
  if [[ -z "$listing" ]]; then
    log_error "sources/install.wim (ou .esd) absent de l'ISO générée."
    report_step "70-validate-output" "FAILED" "image d'installation absente du résultat"
    return 1
  fi
  log_info "OK : $listing"

  # Le fichier marqueur (module 40) est écrit DANS l'image Windows montée, donc il finit
  # DANS sources/install.wim — pas comme fichier "en vrac" dans l'arborescence de l'ISO.
  # Chercher son nom via `xorriso -find` sur l'ISO (qui ne voit que les fichiers hors WIM)
  # ne peut donc jamais le trouver — c'était une erreur de vérification, pas un vrai échec
  # du mécanisme (corrigé après l'avoir constaté sur un premier build réel : le marqueur
  # était bien présent en interrogeant install.wim directement avec wimlib-imagex).
  local marker_found="non vérifié"
  if [[ "${FEATURE_TRIVIAL_MARKER:-0}" -eq 1 && -n "${WIM_PATH:-}" && -f "$WIM_PATH" ]]; then
    log_info "Vérification de la présence du fichier marqueur DANS $WIM_PATH (pas dans l'arborescence externe de l'ISO)..."
    if wimlib-imagex extract "$WIM_PATH" "$WIM_INDEX" "/Furax-Windows-12-Beta.txt" --to-stdout >>"$LOG_FILE" 2>&1; then
      marker_found="present"
      log_info "Fichier marqueur confirmé à l'intérieur de l'image Windows (sources/install.wim)."
    else
      marker_found="absent"
      log_warn "Fichier marqueur absent de l'image Windows — la personnalisation du module 40 n'a peut-être pas été committée correctement."
    fi
  fi

  OUT_SHA256=$(sha256sum "$OUT_ISO" | awk '{print $1}')
  log_info "SHA-256 de l'ISO générée : $OUT_SHA256"

  log_warn "Validation structurelle uniquement : le boot réel de cette ISO N'A PAS été vérifié par ce module. Utilise vm/test-vm.sh pour un test de démarrage en VM (voir docs/TESTING.md) avant de considérer l'ISO comme fiable."

  report_step "70-validate-output" "OK" "SHA-256=$OUT_SHA256 marqueur=$marker_found"
  return 0
}
