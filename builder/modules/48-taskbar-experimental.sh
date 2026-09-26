#!/usr/bin/env bash
# 48-taskbar-experimental.sh — compile ET dépose la vraie barre des tâches flottante
# maison (apps/furax-taskbar/, .NET/WPF, code source propre au projet), avec démarrage
# automatique pour les nouveaux comptes.
#
# ⚠️ Ce module reste DÉSACTIVÉ PAR DÉFAUT dans tous les profils (minimal/full/lite/light).
# Historique : la première approche envisagée pour cette fonctionnalité était un mod
# Windhawk tiers (voir git log) — abandonnée sur demande explicite de l'utilisateur
# (FuraxDev, 26/09/2026) : "pas de Windhawk ou truc tiers, on dev notre propre barre".
# apps/furax-taskbar/ est donc du code 100% du projet (C#/.NET, aucune DLL/binaire
# tiers), qui REMPLACE l'ancienne doc Windhawk (voir ui/taskbar/EXPERIMENTAL-floating-
# pill/README.md pour l'historique complet de cette décision).
#
# Mécanisme :
# - `dotnet publish` compile apps/furax-taskbar/ en un .exe Windows self-contained
#   (win-x64) AU MOMENT DU BUILD, jamais committé en binaire dans le dépôt.
# - Le .exe est déposé dans l'image sous C:\FuraxWindows12\taskbar\FuraxTaskbar.exe.
# - HKCU\Software\Microsoft\Windows\CurrentVersion\Run\FuraxWindows12Taskbar est écrit
#   dans le profil Default (hérité par tout nouveau compte, même mécanisme que
#   45-wallpaper.sh/46-theme.sh) — l'app démarre donc automatiquement à l'ouverture de
#   session. L'app elle-même masque/restaure la VRAIE barre des tâches Windows à
#   l'exécution (voir apps/furax-taskbar/Program.cs) — rien n'est patché sur disque, un
#   Ctrl+Alt+Suppr > Gestionnaire des tâches > fin de tâche restaure tout instantanément.
#
# ⚠️ Honnêteté : la COMPILATION est vérifiable ici (dotnet publish réussit ou échoue,
# code de sortie non ignoré) et le DÉPÔT dans le WIM est vérifiable par extraction
# directe (même mécanisme que tous les autres modules). Le RENDU VISUEL réel et le
# comportement au premier login sur un vrai Windows démarré restent `UNCONFIRMED` — pas
# de boot Windows possible dans cet environnement de développement. Voir docs/FEATURES.md.

module_48_taskbar_experimental() {
  log_step "48-taskbar-experimental : compilation + dépôt de la barre flottante maison (EXPERIMENTAL)"

  local app_src_dir="$PROJECT_ROOT/apps/furax-taskbar"
  local dest_dir="$MOUNT_DIR/FuraxWindows12/taskbar"
  local ntuser_hive="$MOUNT_DIR/Users/Default/NTUSER.DAT"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) compilerait $app_src_dir (dotnet publish -r win-x64) -> $dest_dir"
    log_info "(dry-run) écrirait HKCU\\...\\Run\\FuraxWindows12Taskbar dans $ntuser_hive"
    report_step "48-taskbar-experimental" "DRY-RUN"
    return 0
  fi

  if [[ ! -d "$app_src_dir" ]]; then
    log_warn "Dossier source introuvable : $app_src_dir — étape SKIPPED."
    report_step "48-taskbar-experimental" "SKIPPED" "source absente"
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
    log_warn ".NET SDK introuvable (ni \$DOTNET_ROOT, ni /opt/dotnet, ni dans PATH) — impossible de compiler apps/furax-taskbar. Étape SKIPPED. Voir docs/BUILD.md pour installer le SDK .NET 8 (prérequis UNIQUEMENT pour cette fonctionnalité expérimentale, pas pour le reste du pipeline)."
    report_step "48-taskbar-experimental" "SKIPPED" ".NET SDK indisponible"
    return 0
  fi
  log_info ".NET SDK trouvé : $dotnet_bin ($("$dotnet_bin" --version 2>/dev/null))"

  log_info "Compilation de la barre des tâches flottante (dotnet publish -r win-x64 --self-contained)..."
  local publish_dir="$app_src_dir/bin/Release/net8.0-windows/win-x64/publish"
  if ! DOTNET_CLI_TELEMETRY_OPTOUT=1 "$dotnet_bin" publish "$app_src_dir/FuraxTaskbar.csproj" \
      -c Release -r win-x64 --self-contained true >>"$LOG_FILE" 2>&1; then
    log_warn "Échec de la compilation de apps/furax-taskbar (voir $LOG_FILE) — étape SKIPPED, rien déposé."
    report_step "48-taskbar-experimental" "SKIPPED" "échec compilation dotnet"
    return 0
  fi
  if [[ ! -f "$publish_dir/FuraxTaskbar.exe" ]]; then
    log_warn "Compilation dotnet réussie mais FuraxTaskbar.exe introuvable dans $publish_dir — étape SKIPPED."
    report_step "48-taskbar-experimental" "SKIPPED" "exe absent après compilation"
    return 0
  fi
  log_info "Compilation réussie : $publish_dir/FuraxTaskbar.exe"

  mkdir -p "$dest_dir"
  cp "$publish_dir/FuraxTaskbar.exe" "$dest_dir/FuraxTaskbar.exe"
  log_info "Exécutable déposé : C:\\FuraxWindows12\\taskbar\\FuraxTaskbar.exe"

  if [[ "${HIVEX_AVAILABLE:-0}" -ne 1 ]]; then
    log_warn "hivex indisponible — exécutable déposé mais entrée de démarrage auto (Run) SKIPPED."
    report_step "48-taskbar-experimental" "PARTIAL" "exe déposé, clé Run SKIPPED (hivex indisponible)"
    return 0
  fi
  if [[ ! -f "$ntuser_hive" ]]; then
    log_warn "Ruche NTUSER.DAT du profil Default introuvable ($ntuser_hive) — clé Run SKIPPED."
    report_step "48-taskbar-experimental" "PARTIAL" "exe déposé, ruche Default absente"
    return 0
  fi

  if /usr/bin/python3.12 "$BUILDER_DIR/tools/hivex_set_value.py" "$ntuser_hive" \
      'Software\Microsoft\Windows\CurrentVersion\Run' "FuraxWindows12Taskbar" "string" \
      'C:\FuraxWindows12\taskbar\FuraxTaskbar.exe' --create-keys >>"$LOG_FILE" 2>&1; then
    log_info "Entrée Run écrite : la barre flottante démarrera automatiquement à l'ouverture de session pour tout nouveau compte."
    report_step "48-taskbar-experimental" "OK" "exe compilé+déposé + entrée Run écrite (rendu visuel réel NON vérifié)"
  else
    log_warn "Exécutable déposé mais échec de l'écriture de la clé Run (voir $LOG_FILE)."
    report_step "48-taskbar-experimental" "PARTIAL" "exe déposé, clé Run FAILED"
  fi
  return 0
}
