#!/usr/bin/env bash
# 60-build-iso.sh — régénère une ISO bootable (BIOS+UEFI) à partir de l'arborescence modifiée.
#
# IMPORTANT (découvert en testant contre une vraie ISO Windows 11 25H2 officielle) :
# la technique "xorriso -boot_image any replay" (rejouer le catalogue de boot de l'ISO
# source) ne fonctionne PAS ici, car ces ISO sont en UDF pur et xorriso journalise lui-même
# "Detected El-Torito boot information which currently is set to be discarded" en lecture —
# il n'y a donc rien de fiable à rejouer. On reconstruit à la place le catalogue El Torito
# explicitement avec `xorriso -as mkisofs`, en pointant vers les fichiers de boot standard
# présents dans toute ISO Windows (BIOS: boot/etfsboot.com, UEFI: efi/microsoft/boot/efisys.bin),
# extraits par le module 10. C'est la méthode standard pour remasteriser une ISO Windows
# depuis Linux (ISO9660 niveau 4 + Joliet + Rock Ridge + double catalogue El Torito).
#
# L'ISO source n'est ouverte QUE pour lire son Volume ID ici — jamais modifiée.

module_60_build_iso() {
  log_step "60-build-iso : régénération de l'ISO (xorriso -as mkisofs, El Torito BIOS+UEFI)"

  mkdir -p "$(dirname "$OUT_ISO")"
  [[ -f "$OUT_ISO" ]] && rm -f "$OUT_ISO"

  local bios_boot="$EXTRACT_DIR/boot/etfsboot.com"
  local efi_boot="$EXTRACT_DIR/efi/microsoft/boot/efisys.bin"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) reconstruirait l'ISO avec El Torito BIOS ($bios_boot) + UEFI ($efi_boot)"
    report_step "60-build-iso" "DRY-RUN" "$OUT_ISO"
    return 0
  fi

  if [[ ! -f "$bios_boot" ]]; then
    log_error "Fichier de boot BIOS introuvable : $bios_boot — impossible de générer une ISO bootable BIOS."
    report_step "60-build-iso" "FAILED" "boot/etfsboot.com absent"
    return 1
  fi
  if [[ ! -f "$efi_boot" ]]; then
    log_error "Fichier de boot UEFI introuvable : $efi_boot — impossible de générer une ISO bootable UEFI."
    report_step "60-build-iso" "FAILED" "efi/microsoft/boot/efisys.bin absent"
    return 1
  fi

  # xorriso écrit ce rapport sur stderr, pas stdout — on doit fusionner les deux (2>&1)
  # avant de parser, sinon le pipe ne capte rien et le Volume ID retombe systématiquement
  # sur la valeur par défaut (bug réel rencontré et corrigé après un premier build de test).
  local volid
  volid=$(xorriso -indev "$ISO_PATH" -report_system_area plain 2>&1 | tee -a "$LOG_FILE" \
            | sed -n "s/^Volume id *: *'\(.*\)'/\1/p")
  [[ -z "$volid" ]] && volid="FURAX_WIN12_BETA"
  log_info "Volume ID réutilisé de l'ISO source : $volid"

  log_info "Reconstruction de l'ISO vers $OUT_ISO à partir de $EXTRACT_DIR (modifié)"
  if ! xorriso -as mkisofs \
               -iso-level 4 \
               -full-iso9660-filenames \
               -joliet -joliet-long \
               -rational-rock \
               -volid "$volid" \
               -eltorito-boot boot/etfsboot.com \
                 -no-emul-boot -boot-load-size 8 -boot-info-table \
               -eltorito-alt-boot \
               -eltorito-platform efi \
               -eltorito-boot efi/microsoft/boot/efisys.bin \
                 -no-emul-boot \
               -eltorito-catalog boot/etfsboot.cat \
               -output "$OUT_ISO" \
               "$EXTRACT_DIR" \
               >>"$LOG_FILE" 2>&1; then
    log_error "Échec de la régénération de l'ISO via xorriso -as mkisofs."
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
  log_warn "ISO9660+Joliet+Rock Ridge+El Torito double boot (pas de bridge UDF comme l'ISO source Microsoft). Structurellement bootable en théorie — À VÉRIFIER via vm/test-vm.sh, pas encore confirmé à ce stade du pipeline."
  report_step "60-build-iso" "OK" "$OUT_ISO ($((out_size / 1024 / 1024)) Mo) volid=$volid"
  return 0
}
