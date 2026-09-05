#!/usr/bin/env bash
# 48-taskbar-experimental.sh — dépose la documentation "barre des tâches pilule flottante"
# (EXPERIMENTAL/UNTESTED, voir ui/taskbar/EXPERIMENTAL-floating-pill/README.md) dans l'image,
# SANS RIEN INSTALLER NI EXÉCUTER AUTOMATIQUEMENT.
#
# ⚠️ Ce module est DÉSACTIVÉ PAR DÉFAUT dans tous les profils (minimal.yaml, full.yaml).
# Il ne fait qu'ajouter un dossier de documentation lisible par l'utilisateur après
# installation — aucun binaire tiers, aucune DLL, aucun patch de shell, aucune tâche
# planifiée, aucune entrée de démarrage automatique. C'est une décision délibérée : voir
# le README du dossier pour la justification complète (impossible de vérifier visuellement
# l'effet d'un patch de shell dans cet environnement de développement, donc on ne l'injecte
# pas automatiquement).

module_48_taskbar_experimental() {
  log_step "48-taskbar-experimental : documentation pilule flottante (EXPERIMENTAL, dépôt de fichiers uniquement)"

  local src_dir="$PROJECT_ROOT/ui/taskbar/EXPERIMENTAL-floating-pill"
  local dest_dir="$MOUNT_DIR/FuraxWindows12/experimental/taskbar-floating-pill"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) copierait $src_dir -> $dest_dir (documentation seule, rien d'exécutable)"
    report_step "48-taskbar-experimental" "DRY-RUN"
    return 0
  fi

  if [[ ! -d "$src_dir" ]]; then
    log_warn "Dossier source introuvable : $src_dir — étape SKIPPED."
    report_step "48-taskbar-experimental" "SKIPPED" "source absente"
    return 0
  fi

  mkdir -p "$dest_dir"
  cp -r "$src_dir"/* "$dest_dir"/

  log_info "Documentation EXPERIMENTAL déposée (lecture seule pour l'utilisateur) : C:\\FuraxWindows12\\experimental\\taskbar-floating-pill\\ — aucune exécution automatique, aucun patch de shell appliqué."
  report_step "48-taskbar-experimental" "OK" "documentation déposée, aucune exécution automatique"
  return 0
}
