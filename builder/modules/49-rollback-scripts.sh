#!/usr/bin/env bash
# 49-rollback-scripts.sh — dépose le script de rollback (scripts/rollback/) dans l'image,
# pour que l'utilisateur puisse annuler les personnalisations Furax après installation.
# Dépôt de fichier uniquement : rien n'est exécuté automatiquement, à aucun moment.
#
# Dépose aussi un lanceur .bat sur le Bureau Public (Users\Public\Desktop) — visible pour
# TOUS les comptes dès le premier login, pas seulement le profil Default (backlog #82).
# Un .bat texte plutôt qu'un vrai raccourci .lnk : le format .lnk est un format binaire
# propriétaire Microsoft non trivial à générer correctement depuis Linux sans risquer un
# raccourci cassé — un .bat est un fichier texte simple, fiable, et fonctionnellement
# équivalent ici (double-clic -> exécution élevée du script PowerShell via UAC).

module_49_rollback_scripts() {
  log_step "49-rollback-scripts : dépôt du script de rollback + raccourci bureau"

  local src_dir="$PROJECT_ROOT/scripts/rollback"
  local dest_dir="$MOUNT_DIR/FuraxWindows12/rollback"
  local desktop_dir="$MOUNT_DIR/Users/Public/Desktop"
  local bat_dest="$desktop_dir/Rollback Furax Windows 12.bat"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) copierait $src_dir -> $dest_dir"
    log_info "(dry-run) écrirait $bat_dest (lanceur élevé du rollback)"
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

  local bat_ok=0
  if [[ -d "$desktop_dir" ]]; then
    # Heredoc 'EOF' (guillemets sur le délimiteur) : contenu pris littéralement, aucune
    # interpolation/échappement bash à gérer — plus fiable que printf pour du texte avec
    # apostrophes/guillemets imbriqués (bug constaté avec printf, corrigé ici : les
    # apostrophes autour de -ArgumentList disparaissaient à cause de l'interprétation
    # bash de '' comme frontière de chaîne, pas comme apostrophe littérale).
    cat > "$bat_dest" <<'BATEOF'
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"C:\FuraxWindows12\rollback\Rollback-FuraxWindows12.ps1\"' -Verb RunAs"
BATEOF
    # CRLF requis (fichier .bat lu par cmd.exe) — conversion LF -> CRLF après écriture.
    sed -i 's/$/\r/' "$bat_dest"
    log_info "Raccourci bureau déposé : Users\\Public\\Desktop\\Rollback Furax Windows 12.bat (double-clic -> exécution élevée via UAC)."
    bat_ok=1
  else
    log_warn "Users/Public/Desktop introuvable dans l'image — raccourci bureau SKIPPED (script rollback quand même déposé)."
  fi

  if [[ "$bat_ok" -eq 1 ]]; then
    report_step "49-rollback-scripts" "OK" "script + raccourci bureau déposés dans l'image"
  else
    report_step "49-rollback-scripts" "PARTIAL" "script déposé, raccourci bureau SKIPPED (dossier absent)"
  fi
  return 0
}
