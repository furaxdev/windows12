#!/usr/bin/env bash
# 10-extract.sh — extrait l'intégralité de l'arborescence de l'ISO source vers un dossier de travail isolé.
# Ne modifie JAMAIS l'ISO source (lecture seule).

module_10_extract() {
  log_step "10-extract : extraction de l'ISO vers le dossier de travail"

  EXTRACT_DIR="$WORK_DIR/extract"
  mkdir -p "$EXTRACT_DIR"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) Commande qui serait exécutée : xorriso -osirrox on -indev '$ISO_PATH' -extract / '$EXTRACT_DIR'"
    report_step "10-extract" "DRY-RUN" "$EXTRACT_DIR"
    return 0
  fi

  log_info "Extraction vers $EXTRACT_DIR (lecture seule sur l'ISO source, aucune écriture sur $ISO_PATH)"
  if ! xorriso -osirrox on -indev "$ISO_PATH" -extract / "$EXTRACT_DIR" >>"$LOG_FILE" 2>&1; then
    log_error "Échec de l'extraction de l'ISO."
    report_step "10-extract" "FAILED"
    return 1
  fi

  # Les fichiers extraits d'une ISO Windows sont souvent marqués lecture-seule ; on doit pouvoir les modifier ensuite.
  chmod -R u+w "$EXTRACT_DIR"

  local file_count
  file_count=$(find "$EXTRACT_DIR" -type f | wc -l)
  log_info "Extraction terminée : $file_count fichiers extraits."
  report_step "10-extract" "OK" "$file_count fichiers -> $EXTRACT_DIR"
  return 0
}
