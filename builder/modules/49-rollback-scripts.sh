#!/usr/bin/env bash
# 49-rollback-scripts.sh — dépose le script de rollback (scripts/rollback/) dans l'image,
# pour que l'utilisateur puisse annuler les personnalisations Furax après installation.
# Dépôt de fichier uniquement : rien n'est exécuté automatiquement, à aucun moment.

module_49_rollback_scripts() {
  log_step "49-rollback-scripts : dépôt du script de rollback"

  local src_dir="$PROJECT_ROOT/scripts/rollback"
  local dest_dir="$MOUNT_DIR/FuraxWindows12/rollback"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) copierait $src_dir -> $dest_dir"
    report_step "49-rollback-scripts" "DRY-RUN"
    return 0
  fi

  if [[ ! -d "$src_dir" ]]; then
    log_warn "Dossier source introuvable : $src_dir — étape SKIPPED."
    report_step "49-rollback-scripts" "SKIPPED" "source absente"
    return 0
  fi

  mkdir -p "$dest_dir"
  cp -r "$src_dir"/* "$dest_dir"/

  log_info "Script de rollback déposé : C:\\FuraxWindows12\\rollback\\Rollback-FuraxWindows12.ps1 (à exécuter manuellement en administrateur pour annuler les personnalisations)."
  report_step "49-rollback-scripts" "OK" "script déposé dans l'image"
  return 0
}
