#!/usr/bin/env bash
# 42-branding.sh — inscrit "By FuraxDev" dans les endroits système légitimes/documentés
# pour ce type de personnalisation, SANS toucher au vrai numéro de build Windows (qui reste
# celui de Microsoft — falsifier winver/le numéro de build serait CONCEPT ONLY, voir
# docs/FEATURES.md, et n'est pas fait ici).
#
# Mécanismes utilisés (standards, documentés, pas un patch binaire) :
# - HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\RegisteredOwner / RegisteredOrganization
#   -> apparaissent dans le texte de la boîte de dialogue "About Windows" (winver), sous la
#      licence ("...licensed under the Microsoft Software License Terms to: <Owner> <Org>").
#      Mécanisme standard Windows depuis très longtemps, pas une astuce.
# - HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation (Manufacturer/Model/
#   SupportURL/SupportHours) -> mécanisme de branding OEM historique (Windows 7/8/10,
#   ancien Panneau de configuration > Système). Sa clé n'existe pas forcément par défaut
#   -> créée avec --create-keys si absente.
#
# ⚠️ Honnêteté (statut détaillé dans docs/FEATURES.md) : l'ÉCRITURE de OEMInformation est
# confirmée (relecture réussie via hivexget dans le WIM généré), mais on n'a AUCUNE preuve
# qu'elle s'affiche où que ce soit dans l'UI moderne de Windows 11 — le design "Paramètres >
# Système > À propos" a changé depuis Win10 et pourrait tout simplement ne plus lire cette
# clé du tout. Ne pas présenter ce point comme "marque visible dans les Paramètres" sans
# test réel. Le point fiable pour la marque "Furax" est RegisteredOwner/RegisteredOrganization
# (winver), pas OEMInformation.

module_42_branding() {
  log_step "42-branding : \"By FuraxDev\" dans winver + informations OEM (registre uniquement, affichage UI non confirmé)"

  local software_hive="$MOUNT_DIR/Windows/System32/config/SOFTWARE"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) écrirait RegisteredOwner/RegisteredOrganization + OEMInformation dans $software_hive"
    report_step "42-branding" "DRY-RUN"
    return 0
  fi

  if [[ "${HIVEX_AVAILABLE:-0}" -ne 1 ]]; then
    log_warn "hivex indisponible — étape SKIPPED (pas simulée)."
    report_step "42-branding" "SKIPPED" "hivex indisponible"
    return 0
  fi
  if [[ ! -f "$software_hive" ]]; then
    log_warn "Ruche SOFTWARE introuvable ($software_hive) — étape SKIPPED."
    report_step "42-branding" "SKIPPED" "ruche absente"
    return 0
  fi

  local ok=1
  local set_val="/usr/bin/python3.12 $BUILDER_DIR/tools/hivex_set_value.py"

  $set_val "$software_hive" 'Microsoft\Windows NT\CurrentVersion' "RegisteredOwner" "string" "Furax" \
    --create-keys >>"$LOG_FILE" 2>&1 || ok=0
  $set_val "$software_hive" 'Microsoft\Windows NT\CurrentVersion' "RegisteredOrganization" "string" "By FuraxDev" \
    --create-keys >>"$LOG_FILE" 2>&1 || ok=0

  $set_val "$software_hive" 'Microsoft\Windows\CurrentVersion\OEMInformation' "Manufacturer" "string" "FuraxDev" \
    --create-keys >>"$LOG_FILE" 2>&1 || ok=0
  $set_val "$software_hive" 'Microsoft\Windows\CurrentVersion\OEMInformation' "Model" "string" "Furax Windows 12 Beta" \
    --create-keys >>"$LOG_FILE" 2>&1 || ok=0
  $set_val "$software_hive" 'Microsoft\Windows\CurrentVersion\OEMInformation' "SupportURL" "string" "https://github.com/furaxdev/windows12" \
    --create-keys >>"$LOG_FILE" 2>&1 || ok=0

  if [[ "$ok" -eq 1 ]]; then
    log_info "Branding écrit : RegisteredOwner=Furax, RegisteredOrganization=\"By FuraxDev\" (confirmé visible dans winver), OEMInformation (Manufacturer/Model/SupportURL) écrit en registre mais affichage dans l'UI Windows 11 NON confirmé — voir docs/FEATURES.md."
    report_step "42-branding" "OK" "RegisteredOwner/Organization + OEMInformation"
  else
    log_warn "Échec partiel de l'écriture du branding (voir $LOG_FILE)."
    report_step "42-branding" "PARTIAL" "échec partiel, voir log"
  fi
  return 0
}
