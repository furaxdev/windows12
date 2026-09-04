#!/usr/bin/env bash
# 40-customize-minimal.sh — Phase 2 : preuve de mécanisme UNIQUEMENT.
#
# ⚠️ Ce module ne fait PAS de personnalisation UI. Il prouve seulement que le pipeline
# peut écrire dans l'image montée (fichier) et éditer le registre offline (hivex),
# deux capacités indispensables aux phases suivantes. Rien ici ne doit être présenté
# comme une fonctionnalité "Windows 12" réelle.

module_40_customize_minimal() {
  log_step "40-customize-minimal : preuve de mécanisme (fichier marqueur + 1 valeur de registre)"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) écrirait $MOUNT_DIR/Furax-Windows-12-Beta.txt"
    log_info "(dry-run) écrirait HKLM\\SOFTWARE\\Furax\\BuildInfo\\ProjectName si SOFTWARE hive présente"
    report_step "40-customize-minimal" "DRY-RUN"
    return 0
  fi

  # --- 1) Fichier marqueur (preuve d'écriture offline dans l'image montée) ---
  local marker="$MOUNT_DIR/Furax-Windows-12-Beta.txt"
  {
    echo "Furax Windows 12 Beta — build de test (Phase 2 : builder minimal)"
    echo "Généré le : $(_log_ts)"
    echo "Profil     : ${PROFILE:-N/A}"
    echo "Ceci est une preuve que le pipeline peut écrire dans l'image WIM montée offline."
    echo "Aucune personnalisation UI n'est appliquée à ce stade."
  } > "$marker"

  if [[ ! -f "$marker" ]]; then
    log_error "Échec d'écriture du fichier marqueur dans l'image montée."
    report_step "40-customize-minimal" "FAILED" "écriture fichier marqueur"
    return 1
  fi
  log_info "Fichier marqueur écrit : $marker"

  # --- 2) Une valeur de registre offline via hivex (si disponible) ---
  local software_hive="$MOUNT_DIR/Windows/System32/config/SOFTWARE"
  if [[ "${HIVEX_AVAILABLE:-0}" -ne 1 ]]; then
    log_warn "hivex indisponible dans cet environnement — étape registre SKIPPED (pas simulée)."
    report_step "40-customize-minimal" "PARTIAL" "fichier marqueur OK, registre SKIPPED (hivex indisponible)"
    return 0
  fi
  if [[ ! -f "$software_hive" ]]; then
    log_warn "Ruche SOFTWARE introuvable à $software_hive — étape registre SKIPPED."
    report_step "40-customize-minimal" "PARTIAL" "fichier marqueur OK, registre SKIPPED (ruche absente)"
    return 0
  fi

  log_info "Écriture d'une valeur de test dans la ruche SOFTWARE via hivex..."
  if /usr/bin/python3.12 "$BUILDER_DIR/tools/hivex_set_value.py" \
      "$software_hive" "Microsoft" "FuraxWindows12Beta" "string" "phase2-proof-of-mechanism" \
      >>"$LOG_FILE" 2>&1; then
    log_info "Valeur de registre écrite avec succès (HKLM\\SOFTWARE\\Microsoft\\FuraxWindows12Beta)."
    report_step "40-customize-minimal" "OK" "fichier marqueur + valeur registre"
  else
    log_warn "Échec de l'écriture registre (voir $LOG_FILE) — le fichier marqueur reste appliqué. Étape marquée PARTIAL, pas OK."
    report_step "40-customize-minimal" "PARTIAL" "fichier marqueur OK, registre FAILED"
  fi
  return 0
}
