#!/usr/bin/env bash
# 60-build-iso.sh — régénère une ISO bootable (BIOS+UEFI) à partir de l'arborescence modifiée,
# en rejouant le catalogue de boot de l'ISO source (xorriso "-boot_image any replay").
# L'ISO source n'est ouverte qu'en LECTURE ici (-indev), jamais modifiée.

module_60_build_iso() {
  log_step "60-build-iso : régénération de l'ISO"

  mkdir -p "$(dirname "$OUT_ISO")"
  [[ -f "$OUT_ISO" ]] && rm -f "$OUT_ISO"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) Commande qui serait exécutée : xorriso -indev '$ISO_PATH' -outdev '$OUT_ISO' -map '$EXTRACT_DIR' / -boot_image any replay"
    report_step "60-build-iso" "DRY-RUN" "$OUT_ISO"
    return 0
  fi

  log_info "Reconstruction de l'ISO vers $OUT_ISO (catalogue de boot rejoué depuis l'ISO source, arbre de fichiers = $EXTRACT_DIR modifié)"
  if ! xorriso -indev "$ISO_PATH" \
               -outdev "$OUT_ISO" \
               -map "$EXTRACT_DIR" / \
               -boot_image any replay \
               >>"$LOG_FILE" 2>&1; then
    log_error "Échec de la régénération de l'ISO via xorriso."
    report_step "60-build-iso" "FAILED"
    return 1
  fi

  if [[ ! -f "$OUT_ISO" ]]; then
    log_error "xorriso a rapporté un succès mais $OUT_ISO n'existe pas."
    report_step "60-build-iso" "FAILED" "fichier de sortie absent"
    return 1
  fi

  local out_size
  out_size=$(stat -c '%s' "$OUT_ISO")
  log_info "ISO générée : $OUT_ISO ($((out_size / 1024 / 1024)) Mo)"
  report_step "60-build-iso" "OK" "$OUT_ISO ($((out_size / 1024 / 1024)) Mo)"
  return 0
}
