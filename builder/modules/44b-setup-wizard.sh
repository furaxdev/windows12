#!/usr/bin/env bash
# 44b-setup-wizard.sh — compile ET dépose un écran d'accueil "Windows 12" maison qui
# s'affiche AVANT le vrai Windows Setup, via winpeshl.ini (mécanisme WinPE officiellement
# documenté par Microsoft, pas un patch de binaire signé).
#
# ⚠️ EXPERIMENTAL, désactivé par défaut dans tous les profils. Demande explicite de
# l'utilisateur (FuraxDev, 26/09/2026) : "l'UI, pas l'exe système" — cette app est
# UNIQUEMENT une fenêtre de bienvenue (apps/furax-setup-wizard/). Elle ne partitionne
# rien, ne formate rien, n'installe rien : le vrai moteur d'installation reste
# intégralement celui de Microsoft (X:\sources\setup.exe, jamais modifié ni remplacé).
#
# Mécanisme d'accroche :
# - HKLM\SYSTEM\Setup\CmdLine dans boot.wim (index 2) vaut déjà "winpeshl.exe" sur l'ISO
#   officielle (vérifié par hivexget, 26/09/2026) — c'est winpeshl.exe qui décide quoi
#   lancer au boot WinPE, en lisant Windows\System32\winpeshl.ini.
# - Vérifié par recherche exhaustive dans boot.wim (26/09/2026) : AUCUN winpeshl.ini
#   n'existe sur l'ISO stock. Plutôt que de deviner le comportement de repli implicite de
#   winpeshl.exe sans ini (incertain, non documenté précisément pour ce cas), ce module en
#   dépose un explicite, entièrement sous notre contrôle.
# - Contenu déposé :
#     [LaunchApps]
#     wpeinit.exe
#     %SYSTEMDRIVE%\FuraxSetup\FuraxSetupWizard.exe
#     %SYSTEMDRIVE%\sources\setup.exe
#   wpeinit.exe en premier (identique à startnet.cmd d'origine — initialise réseau/PnP,
#   ne JAMAIS sauter cette étape). winpeshl.exe lance les entrées de [LaunchApps] en
#   SÉQUENCE (chacune doit se terminer avant la suivante, comportement par défaut
#   documenté) — c'est le filet de sécurité : que notre app plante, ne s'affiche pas
#   (WinPE peut manquer de composants de composition dont WPF dépend — risque assumé,
#   documenté dans apps/furax-setup-wizard/Program.cs), ou que l'utilisateur ferme la
#   fenêtre, l'entrée suivante (le vrai setup.exe) démarre quand même automatiquement.
#   Notre app elle-même ne lance JAMAIS setup.exe — elle se contente d'exister puis de se
#   terminer sur clic ; winpeshl.ini gère tout l'enchaînement.
#
# ⚠️ Honnêteté : la COMPILATION est vérifiable ici (dotnet publish réussit ou échoue) et
# le DÉPÔT dans le WIM est vérifiable par extraction directe. Le RENDU RÉEL au boot
# (l'app s'affiche-t-elle dans WinPE ? le clic fonctionne-t-il ? l'enchaînement vers
# setup.exe se fait-il vraiment ?) reste `UNCONFIRMED` — pas de boot Windows possible
# dans cet environnement de développement. Voir docs/FEATURES.md.

module_44b_setup_wizard() {
  log_step "44b-setup-wizard : compilation + dépôt de l'écran d'accueil maison avant Setup (EXPERIMENTAL)"

  local app_src_dir="$PROJECT_ROOT/apps/furax-setup-wizard"
  local boot_wim="$EXTRACT_DIR/sources/boot.wim"
  local setup_index=2
  local boot_mount="$WORK_DIR/mount-boot-wizard"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) compilerait $app_src_dir (dotnet publish -r win-x64) et déposerait winpeshl.ini dans boot.wim"
    report_step "44b-setup-wizard" "DRY-RUN"
    return 0
  fi

  if [[ ! -d "$app_src_dir" ]]; then
    log_warn "Dossier source introuvable : $app_src_dir — étape SKIPPED."
    report_step "44b-setup-wizard" "SKIPPED" "source absente"
    return 0
  fi
  if [[ ! -f "$boot_wim" ]]; then
    log_warn "$boot_wim introuvable après extraction — étape SKIPPED."
    report_step "44b-setup-wizard" "SKIPPED" "boot.wim absent"
    return 0
  fi

  local dotnet_bin=""
  local candidates=()
  [[ -n "${DOTNET_ROOT:-}" ]] && candidates+=("$DOTNET_ROOT/dotnet")
  candidates+=("/opt/dotnet/dotnet")
  [[ -n "$(command -v dotnet 2>/dev/null)" ]] && candidates+=("$(command -v dotnet)")
  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      dotnet_bin="$candidate"
      break
    fi
  done
  if [[ -z "$dotnet_bin" ]]; then
    log_warn ".NET SDK introuvable — impossible de compiler apps/furax-setup-wizard. Étape SKIPPED."
    report_step "44b-setup-wizard" "SKIPPED" ".NET SDK indisponible"
    return 0
  fi
  log_info ".NET SDK trouvé : $dotnet_bin ($("$dotnet_bin" --version 2>/dev/null))"

  log_info "Compilation de l'écran d'accueil Setup (dotnet publish -r win-x64 --self-contained)..."
  local publish_dir="$app_src_dir/bin/Release/net8.0-windows/win-x64/publish"
  if ! DOTNET_CLI_TELEMETRY_OPTOUT=1 "$dotnet_bin" publish "$app_src_dir/FuraxSetupWizard.csproj" \
      -c Release -r win-x64 --self-contained true >>"$LOG_FILE" 2>&1; then
    log_warn "Échec de la compilation de apps/furax-setup-wizard (voir $LOG_FILE) — étape SKIPPED, rien déposé."
    report_step "44b-setup-wizard" "SKIPPED" "échec compilation dotnet"
    return 0
  fi
  if [[ ! -f "$publish_dir/FuraxSetupWizard.exe" ]]; then
    log_warn "Compilation dotnet réussie mais FuraxSetupWizard.exe introuvable — étape SKIPPED."
    report_step "44b-setup-wizard" "SKIPPED" "exe absent après compilation"
    return 0
  fi
  log_info "Compilation réussie : $publish_dir/FuraxSetupWizard.exe"

  mkdir -p "$boot_mount"
  if ! wimlib-imagex mountrw "$boot_wim" "$setup_index" "$boot_mount" >>"$LOG_FILE" 2>&1; then
    log_error "Échec du montage de boot.wim (index $setup_index)."
    report_step "44b-setup-wizard" "FAILED" "montage boot.wim échoué"
    return 1
  fi
  MOUNTED_DIR="$boot_mount"
  MOUNTED_WIM_PATH="$boot_wim"

  local dest_dir="$boot_mount/FuraxSetup"
  mkdir -p "$dest_dir"
  cp "$publish_dir/FuraxSetupWizard.exe" "$dest_dir/FuraxSetupWizard.exe"
  log_info "Exécutable déposé : X:\\FuraxSetup\\FuraxSetupWizard.exe (dans boot.wim)"

  local winpeshl_path="$boot_mount/Windows/System32/winpeshl.ini"
  if [[ -f "$winpeshl_path" ]]; then
    cp "$winpeshl_path" "$winpeshl_path.stock-original"
  fi
  cat > "$winpeshl_path.tmp" <<'WINPESHL_EOF'
[LaunchApps]
wpeinit.exe
%SYSTEMDRIVE%\FuraxSetup\FuraxSetupWizard.exe
%SYSTEMDRIVE%\sources\setup.exe
WINPESHL_EOF
  sed 's/$/\r/' "$winpeshl_path.tmp" > "$winpeshl_path" && rm -f "$winpeshl_path.tmp"
  log_info "winpeshl.ini écrit : wpeinit -> FuraxSetupWizard.exe -> setup.exe (séquentiel, filet de sécurité si notre app échoue)."

  log_info "Démontage de boot.wim (commit)..."
  if ! wimlib-imagex unmount "$boot_mount" --commit >>"$LOG_FILE" 2>&1; then
    log_error "Échec du démontage/commit de boot.wim."
    report_step "44b-setup-wizard" "FAILED" "démontage/commit échoué"
    MOUNTED_DIR=""
    MOUNTED_WIM_PATH=""
    return 1
  fi
  MOUNTED_DIR=""
  MOUNTED_WIM_PATH=""

  report_step "44b-setup-wizard" "OK" "exe compilé+déposé + winpeshl.ini écrit (rendu visuel réel au boot NON vérifié)"
  return 0
}
