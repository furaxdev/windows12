#!/usr/bin/env bash
# 10-extract.sh — extrait l'intégralité de l'arborescence de l'ISO source vers un dossier de travail isolé.
# Ne modifie JAMAIS l'ISO source (lecture seule).
#
# IMPORTANT (découvert en testant contre une vraie ISO Windows 11 25H2 officielle) :
# les ISO Windows modernes (>4 Go) sont au format "UDF Bridge" SANS arborescence ISO9660
# complète (seul README.TXT y est visible). `xorriso -osirrox` ne lit que l'ISO9660 et ne
# voit donc quasiment aucun fichier sur ce type d'ISO. On utilise `7z x`, qui lit
# correctement l'UDF (vérifié : extrait bien sources/install.wim, boot/etfsboot.com,
# efi/microsoft/boot/efisys.bin, etc.).

module_10_extract() {
  log_step "10-extract : extraction de l'ISO (UDF) vers le dossier de travail"

  EXTRACT_DIR="$WORK_DIR/extract"
  mkdir -p "$EXTRACT_DIR"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) Commande qui serait exécutée : 7z x '$ISO_PATH' -o'$EXTRACT_DIR' -x'!__chunk_data' -y"
    report_step "10-extract" "DRY-RUN" "$EXTRACT_DIR"
    return 0
  fi

  log_info "Extraction (7z, lecteur UDF) vers $EXTRACT_DIR (lecture seule sur l'ISO source)"
  # __chunk_data est un artefact interne du parseur UDF de 7-Zip pour ce type d'image
  # (pas un fichier réel du disque Windows) — exclu pour ne pas polluer l'arborescence.
  if ! 7z x "$ISO_PATH" -o"$EXTRACT_DIR" -x'!__chunk_data' -y >>"$LOG_FILE" 2>&1; then
    log_error "Échec de l'extraction de l'ISO (7z)."
    report_step "10-extract" "FAILED"
    return 1
  fi

  chmod -R u+w "$EXTRACT_DIR"

  local file_count
  file_count=$(find "$EXTRACT_DIR" -type f | wc -l)
  log_info "Extraction terminée : $file_count fichiers extraits."

  if [[ ! -f "$EXTRACT_DIR/sources/install.wim" && ! -f "$EXTRACT_DIR/sources/install.esd" ]]; then
    log_error "sources/install.wim et sources/install.esd absents après extraction — extraction incomplète ou ISO non standard."
    report_step "10-extract" "FAILED" "install.wim/.esd absent après extraction"
    return 1
  fi
  if [[ ! -f "$EXTRACT_DIR/boot/etfsboot.com" ]]; then
    log_warn "boot/etfsboot.com absent — le boot BIOS (El Torito) risque de ne pas fonctionner sur l'ISO régénérée."
  fi
  if [[ ! -f "$EXTRACT_DIR/efi/microsoft/boot/efisys.bin" ]]; then
    log_warn "efi/microsoft/boot/efisys.bin absent — le boot UEFI (El Torito) risque de ne pas fonctionner sur l'ISO régénérée."
  fi

  report_step "10-extract" "OK" "$file_count fichiers -> $EXTRACT_DIR"
  return 0
}
