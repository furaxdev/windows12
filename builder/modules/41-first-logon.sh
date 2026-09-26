#!/usr/bin/env bash
# 41-first-logon.sh — dépose un script PowerShell exécuté UNE SEULE FOIS au tout premier
# login (backlog #77 message de bienvenue + #79 point de restauration auto + #84 tâche de
# nettoyage temp + réapplication post-update, voir plus bas), via le mécanisme RunOnce
# natif de Windows.
#
# Mécanisme utilisé (standard, documenté, pas un patch) :
# HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce
#   FuraxWindows12FirstLogon = powershell.exe -NoProfile -ExecutionPolicy Bypass
#                              -WindowStyle Hidden -File "C:\FuraxWindows12\first-logon\
#                              FirstLogon-Furax.ps1"
# Windows exécute cette commande au prochain login utilisateur PUIS supprime lui-même
# l'entrée RunOnce — natif, pas de logique de nettoyage à écrire côté Furax.
#
# Ce module dépose AUSSI scripts/reapply/Reapply-FuraxWindows12.ps1 (simple copie de
# fichier, même mécanisme). FirstLogon-Furax.ps1 enregistre, lui, une tâche planifiée
# PERSISTANTE (pas RunOnce) qui rejoue ce script à chaque login + une fois par jour — pour
# que les réglages registre Furax survivent à une mise à jour Windows qui les écraserait.
# Demande explicite de l'utilisateur (FuraxDev, 25/09/2026) : accepte le compromis que
# cette tâche peut nécessiter d'être réécrite si son mécanisme casse à une future version
# de Windows, en échange d'une réapplication automatique plutôt qu'un rollback manuel.
#
# ⚠️ Honnêteté : écriture + relecture de la clé RunOnce confirmées dans le WIM généré
# (même mécanisme hivex que les autres modules). L'EXÉCUTION réelle au premier login
# (le point de restauration se crée-t-il vraiment ? le message s'affiche-t-il ? la tâche
# planifiée de réapplication s'enregistre-t-elle vraiment ?) n'a PAS pu être vérifiée dans
# cet environnement de développement (pas de boot Windows possible ici) — voir
# docs/FEATURES.md #77/#79/#84/#101, statut `PARTIAL` tant que non confirmé.

module_41_first_logon() {
  log_step "41-first-logon : script RunOnce (bienvenue + point de restauration)"

  local script_src_dir="$PROJECT_ROOT/scripts/first-logon"
  local script_dest_dir="$MOUNT_DIR/FuraxWindows12/first-logon"
  local reapply_src_dir="$PROJECT_ROOT/scripts/reapply"
  local reapply_dest_dir="$MOUNT_DIR/FuraxWindows12/reapply"
  local software_hive="$MOUNT_DIR/Windows/System32/config/SOFTWARE"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) copierait $script_src_dir -> $script_dest_dir"
    log_info "(dry-run) copierait $reapply_src_dir -> $reapply_dest_dir"
    log_info "(dry-run) écrirait HKLM\\...\\RunOnce\\FuraxWindows12FirstLogon dans $software_hive"
    report_step "41-first-logon" "DRY-RUN"
    return 0
  fi

  if [[ ! -d "$script_src_dir" ]]; then
    log_warn "Dossier source introuvable : $script_src_dir — étape SKIPPED."
    report_step "41-first-logon" "SKIPPED" "source absente"
    return 0
  fi
  if [[ "${HIVEX_AVAILABLE:-0}" -ne 1 ]]; then
    log_warn "hivex indisponible — scripts déposés mais entrée RunOnce SKIPPED."
    mkdir -p "$script_dest_dir" "$reapply_dest_dir"
    cp -r "$script_src_dir"/* "$script_dest_dir"/
    [[ -d "$reapply_src_dir" ]] && cp -r "$reapply_src_dir"/* "$reapply_dest_dir"/
    report_step "41-first-logon" "PARTIAL" "scripts déposés, RunOnce SKIPPED (hivex indisponible)"
    return 0
  fi
  if [[ ! -f "$software_hive" ]]; then
    log_warn "Ruche SOFTWARE introuvable ($software_hive) — étape SKIPPED."
    report_step "41-first-logon" "SKIPPED" "ruche absente"
    return 0
  fi

  mkdir -p "$script_dest_dir" "$reapply_dest_dir"
  cp -r "$script_src_dir"/* "$script_dest_dir"/
  log_info "Script déposé : C:\\FuraxWindows12\\first-logon\\FirstLogon-Furax.ps1"
  if [[ -d "$reapply_src_dir" ]]; then
    cp -r "$reapply_src_dir"/* "$reapply_dest_dir"/
    log_info "Script déposé : C:\\FuraxWindows12\\reapply\\Reapply-FuraxWindows12.ps1"
  else
    log_warn "Dossier source du script de réapplication introuvable ($reapply_src_dir) — non déposé."
  fi

  local runonce_cmd='powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\FuraxWindows12\first-logon\FirstLogon-Furax.ps1"'
  if /usr/bin/python3.12 "$BUILDER_DIR/tools/hivex_set_value.py" "$software_hive" \
      'Microsoft\Windows\CurrentVersion\RunOnce' "FuraxWindows12FirstLogon" "string" "$runonce_cmd" \
      --create-keys >>"$LOG_FILE" 2>&1; then
    log_info "Entrée RunOnce écrite : s'exécutera au tout premier login (point de restauration + message de bienvenue), puis se supprime automatiquement (comportement natif Windows)."
    report_step "41-first-logon" "OK" "scripts déposés (first-logon + reapply) + RunOnce écrit (exécution réelle au boot NON vérifiée)"
  else
    log_warn "Script déposé mais échec de l'écriture de l'entrée RunOnce (voir $LOG_FILE)."
    report_step "41-first-logon" "PARTIAL" "scripts déposés, RunOnce FAILED"
  fi
  return 0
}
