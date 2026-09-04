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

  log_info "Vérification de la présence du fichier marqueur Furax-Windows-12-Beta.txt..."
  local marker_found
  marker_found=$(xorriso -indev "$OUT_ISO" -find / -name 'Furax-Windows-12-Beta.txt' 2>>"$LOG_FILE")
  if [[ -z "$marker_found" ]]; then
    log_warn "Fichier marqueur absent de l'ISO générée — la personnalisation du module 40 n'a peut-être pas été committée correctement."
  else
    log_info "Fichier marqueur présent : $marker_found"
  fi

  OUT_SHA256=$(sha256sum "$OUT_ISO" | awk '{print $1}')
  log_info "SHA-256 de l'ISO générée : $OUT_SHA256"

  log_warn "Validation structurelle uniquement : le boot réel de cette ISO N'A PAS été vérifié par ce module. Utilise vm/test-vm.sh pour un test de démarrage en VM (voir docs/TESTING.md) avant de considérer l'ISO comme fiable."

  report_step "70-validate-output" "OK" "SHA-256=$OUT_SHA256 marqueur=$([[ -n "$marker_found" ]] && echo present || echo absent)"
  return 0
}
