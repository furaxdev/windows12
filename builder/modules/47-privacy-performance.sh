#!/usr/bin/env bash
# 47-privacy-performance.sh — applique une sélection de réglages registre "faciles" du
# backlog (docs/FEATURES.md) : confidentialité, performance légère, confort. Chaque valeur
# ci-dessous est une clé de policy/registre STANDARD et documentée (GPO ADMX ou comportement
# Microsoft connu) — aucun patch binaire, aucune valeur inventée sans référence.
#
# Ruche SOFTWARE (HKLM, s'applique à toute la machine, tous comptes) :
# - Policies\Microsoft\Windows\DataCollection\AllowTelemetry = 1 (Basique, au lieu de
#   3=Complet par défaut sur Win11 Pro+). Clé de policy Microsoft standard (ADMX
#   DataCollection.admx), pas une astuce.
# - Policies\Microsoft\Windows\WindowsCopilot\TurnOffWindowsCopilot = 1. Clé de policy
#   Microsoft standard (ADMX WindowsCopilot.admx, ajoutée avec le déploiement de Copilot).
# - Policies\Microsoft\Windows\WindowsUpdate\DeferFeatureUpdatesPeriodInDays = 7. Clé de
#   policy Microsoft Update standard (ADMX WindowsUpdate.admx).
#
# Ruche NTUSER.DAT du profil "Default" (HKCU pour les NOUVEAUX comptes créés à l'OOBE,
# même mécanisme que 45-wallpaper.sh/46-theme.sh) :
# - Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\
#   SubscribedContent-338388Enabled = 0 (désactive les suggestions d'apps dans le Menu
#   Démarrer). Clé communautairement bien documentée (utilisée par les outils de
#   confidentialité connus type O&O ShutUp10/W10Privacy), pas une clé officielle ADMX
#   mais un comportement Microsoft stable depuis Windows 10.
# - Software\Microsoft\Clipboard\EnableClipboardHistory = 1 (active l'historique du
#   presse-papiers, Win+V). Clé utilisée par le bouton correspondant dans Paramètres.
# - Software\Microsoft\GameBar\AllowAutoGameMode = 1 (Mode Jeu auto). Clé utilisée par le
#   bouton correspondant dans Paramètres > Jeux > Mode jeu.
# - System\GameConfigStore\GameDVR_Enabled = 0 (désactive l'enregistrement en arrière-plan
#   de la Game Bar — préférence perf, PAS la Game Bar elle-même). Clé utilisée par le
#   bouton "Enregistrements en arrière-plan" dans Paramètres > Jeux > Captures.
#
# Ruche SYSTEM (backlog #7 et #8 — désindexation recherche + Superfetch/SysMain) :
# ⚠️ Piège classique évité ici, vérifié par inspection directe (22/09/2026) : une ruche
# SYSTEM démontée n'a PAS de clé "CurrentControlSet" (c'est un lien symbolique résolu par
# le noyau Windows en cours d'exécution, absent hors ligne) — seulement des
# "ControlSet00N" réels. Le ControlSet ACTIF est déterminé dynamiquement en lisant
# \Select\Default (confirmé =1 -> ControlSet001 sur l'ISO 25H2 testée), jamais codé en dur.
# - <ControlSetActif>\Services\WSearch\Start  : 2 (Automatique, stock) -> 4 (Désactivé)
# - <ControlSetActif>\Services\SysMain\Start  : 2 (Automatique, stock) -> 4 (Désactivé)
# Valeurs de service standard Windows (0=Boot,1=System,2=Auto,3=Manuel,4=Désactivé).
# ⚠️ Contrairement aux autres clés de ce module (absentes par défaut, donc supprimées au
# rollback), celles-ci EXISTENT déjà en stock à 2 — le rollback doit donc restaurer 2,
# PAS supprimer la valeur (supprimer Start casserait la définition du service).
#
# Honnêteté : write + relecture via hivexget confirmées dans un WIM généré (même mécanisme
# que 42-branding.sh/46-theme.sh, déjà éprouvé). Le RENDU RÉEL dans l'UI Windows démarrée
# n'est pas encore vérifié — voir docs/FEATURES.md, `TESTED` réservé à ça.

module_47_privacy_performance() {
  log_step "47-privacy-performance : télémétrie/Copilot/suggestions/presse-papiers/mode jeu"

  local software_hive="$MOUNT_DIR/Windows/System32/config/SOFTWARE"
  local ntuser_hive="$MOUNT_DIR/Users/Default/NTUSER.DAT"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) écrirait les réglages télémétrie/Copilot/updates dans $software_hive"
    log_info "(dry-run) écrirait suggestions/presse-papiers/mode jeu dans $ntuser_hive"
    report_step "47-privacy-performance" "DRY-RUN"
    return 0
  fi

  if [[ "${HIVEX_AVAILABLE:-0}" -ne 1 ]]; then
    log_warn "hivex indisponible — étape SKIPPED (pas simulée)."
    report_step "47-privacy-performance" "SKIPPED" "hivex indisponible"
    return 0
  fi

  local set_val="/usr/bin/python3.12 $BUILDER_DIR/tools/hivex_set_value.py"
  local ok=1
  local any=0

  if [[ -f "$software_hive" ]]; then
    $set_val "$software_hive" 'Policies\Microsoft\Windows\DataCollection' "AllowTelemetry" "dword" "1" \
      --create-keys >>"$LOG_FILE" 2>&1 && any=1 || ok=0
    $set_val "$software_hive" 'Policies\Microsoft\Windows\WindowsCopilot' "TurnOffWindowsCopilot" "dword" "1" \
      --create-keys >>"$LOG_FILE" 2>&1 && any=1 || ok=0
    $set_val "$software_hive" 'Policies\Microsoft\Windows\WindowsUpdate' "DeferFeatureUpdatesPeriodInDays" "dword" "7" \
      --create-keys >>"$LOG_FILE" 2>&1 && any=1 || ok=0
    log_info "Ruche SOFTWARE : télémétrie=Basique, Copilot désactivé, mises à jour de fonctionnalités différées de 7 jours."
  else
    log_warn "Ruche SOFTWARE introuvable ($software_hive) — section HKLM ignorée."
  fi

  if [[ -f "$ntuser_hive" ]]; then
    $set_val "$ntuser_hive" 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' "SubscribedContent-338388Enabled" "dword" "0" \
      --create-keys >>"$LOG_FILE" 2>&1 && any=1 || ok=0
    $set_val "$ntuser_hive" 'Software\Microsoft\Clipboard' "EnableClipboardHistory" "dword" "1" \
      --create-keys >>"$LOG_FILE" 2>&1 && any=1 || ok=0
    $set_val "$ntuser_hive" 'Software\Microsoft\GameBar' "AllowAutoGameMode" "dword" "1" \
      --create-keys >>"$LOG_FILE" 2>&1 && any=1 || ok=0
    $set_val "$ntuser_hive" 'System\GameConfigStore' "GameDVR_Enabled" "dword" "0" \
      --create-keys >>"$LOG_FILE" 2>&1 && any=1 || ok=0
    log_info "Profil Default : suggestions Menu Démarrer désactivées, historique presse-papiers activé, Mode Jeu auto activé, enregistrement Game Bar en arrière-plan désactivé."
  else
    log_warn "Ruche NTUSER.DAT du profil Default introuvable ($ntuser_hive) — section HKCU ignorée."
  fi

  local system_hive="$MOUNT_DIR/Windows/System32/config/SYSTEM"
  local system_detail=""
  if [[ -f "$system_hive" ]]; then
    local active_cs
    active_cs=$(hivexget "$system_hive" '\Select' Default 2>>"$LOG_FILE")
    if [[ -n "$active_cs" ]]; then
      local cs_path
      cs_path=$(printf "ControlSet%03d" "$active_cs")
      $set_val "$system_hive" "${cs_path}\\Services\\WSearch" "Start" "dword" "4" \
        --create-keys >>"$LOG_FILE" 2>&1 && any=1 || ok=0
      $set_val "$system_hive" "${cs_path}\\Services\\SysMain" "Start" "dword" "4" \
        --create-keys >>"$LOG_FILE" 2>&1 && any=1 || ok=0
      log_info "Ruche SYSTEM ($cs_path) : Windows Search (WSearch) et Superfetch (SysMain) désactivés (Start=4)."
      system_detail=" + WSearch/SysMain désactivés (SYSTEM/$cs_path)"
    else
      log_warn "Impossible de déterminer le ControlSet actif (\\Select\\Default) — section SYSTEM ignorée."
    fi
  else
    log_warn "Ruche SYSTEM introuvable ($system_hive) — section SYSTEM ignorée."
  fi

  if [[ "$any" -eq 0 ]]; then
    log_warn "Aucune ruche disponible — étape SKIPPED."
    report_step "47-privacy-performance" "SKIPPED" "aucune ruche disponible"
    return 0
  fi

  if [[ "$ok" -eq 1 ]]; then
    report_step "47-privacy-performance" "OK" "télémétrie/Copilot/updates (SOFTWARE) + suggestions/presse-papiers/mode jeu (Default)${system_detail}"
  else
    log_warn "Échec partiel de l'écriture des réglages confidentialité/performance (voir $LOG_FILE)."
    report_step "47-privacy-performance" "PARTIAL" "échec partiel, voir log"
  fi
  return 0
}
