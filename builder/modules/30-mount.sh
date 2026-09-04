#!/usr/bin/env bash
# 30-mount.sh — monte l'image WIM sélectionnée en lecture/écriture (FUSE, via wimlib-imagex).

module_30_mount() {
  log_step "30-mount : montage de l'image WIM (lecture/écriture)"

  MOUNT_DIR="$WORK_DIR/mount"
  mkdir -p "$MOUNT_DIR"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) Commande qui serait exécutée : wimlib-imagex mountrw '$WIM_PATH' $WIM_INDEX '$MOUNT_DIR'"
    report_step "30-mount" "DRY-RUN" "$MOUNT_DIR"
    return 0
  fi

  if ! wimlib-imagex mountrw "$WIM_PATH" "$WIM_INDEX" "$MOUNT_DIR" >>"$LOG_FILE" 2>&1; then
    log_error "Échec du montage de l'image WIM. Cause possible : FUSE indisponible dans ce conteneur (/dev/fuse), image ESD chiffrée, ou index invalide."
    report_step "30-mount" "FAILED"
    return 1
  fi

  # Enregistré pour le nettoyage de sécurité (trap) en cas d'échec plus loin dans le pipeline.
  MOUNTED_DIR="$MOUNT_DIR"
  MOUNTED_WIM_PATH="$WIM_PATH"

  if ! mountpoint -q "$MOUNT_DIR"; then
    log_error "Le montage a été rapporté comme réussi mais $MOUNT_DIR n'est pas un point de montage actif."
    report_step "30-mount" "FAILED" "mountpoint non actif après mount"
    return 1
  fi

  local file_count
  file_count=$(find "$MOUNT_DIR" -maxdepth 2 | wc -l)
  log_info "Image montée sur $MOUNT_DIR ($file_count entrées visibles à la racine/niveau 2)."
  report_step "30-mount" "OK" "$MOUNT_DIR"
  return 0
}
