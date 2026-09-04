#!/usr/bin/env bash
# 50-unmount.sh — démonte proprement l'image WIM en committant les changements.

module_50_unmount() {
  log_step "50-unmount : démontage et commit de l'image WIM"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) Commande qui serait exécutée : wimlib-imagex unmount --commit '$MOUNT_DIR'"
    report_step "50-unmount" "DRY-RUN"
    return 0
  fi

  if ! wimlib-imagex unmount --commit "$MOUNT_DIR" >>"$LOG_FILE" 2>&1; then
    log_error "Échec du démontage/commit de l'image WIM. L'image reste potentiellement montée."
    report_step "50-unmount" "FAILED"
    return 1
  fi

  # Démontage confirmé : on efface l'état suivi par le trap de nettoyage.
  MOUNTED_DIR=""
  MOUNTED_WIM_PATH=""

  if mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
    log_error "$MOUNT_DIR est toujours un point de montage actif après unmount --commit."
    report_step "50-unmount" "FAILED" "mountpoint encore actif"
    return 1
  fi

  log_info "Démontage confirmé, aucun mount résiduel sur $MOUNT_DIR."
  report_step "50-unmount" "OK"
  return 0
}
