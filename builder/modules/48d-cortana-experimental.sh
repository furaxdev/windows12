#!/usr/bin/env bash
# 48d-cortana-experimental.sh — compile ET dépose "Furax Cortana", l'assistant local
# (apps/furax-cortana/, .NET/WPF + LLamaSharp/llama.cpp, licences MIT), avec démarrage
# automatique pour les nouveaux comptes.
#
# Demande explicite de FuraxDev (29/10/2026) : "on refait Cortana ! et on fait qu'il a pas
# besoin de connexion" + capacité à exécuter des commandes/contrôler l'écran, MAIS
# uniquement avec confirmation explicite à chaque action (choisi explicitement par
# FuraxDev face au risque qu'un petit modèle local hallucine une commande destructrice).
#
# ⚠️ Ce module reste DÉSACTIVÉ PAR DÉFAUT dans tous les profils. Risques assumés propres
# à cette fonctionnalité (au-delà du rendu visuel UNCONFIRMED commun à tout ce projet) :
# - L'assistant peut proposer d'exécuter n'importe quelle commande shell ou de
#   cliquer/taper n'importe où à l'écran — jamais exécuté automatiquement, toujours une
#   carte de confirmation explicite dans l'UI (voir apps/furax-cortana/Program.cs/
#   ActionProtocol.cs), mais une fois confirmée, l'action a les mêmes droits que
#   l'utilisateur connecté (pas d'élévation, mais pas de sandbox non plus).
# - AUCUN modèle de langage (.gguf) n'est fourni ni déposé par ce module : l'utilisateur
#   doit placer lui-même un modèle sous licence libre (ex. Qwen2.5-0.5B-Instruct-GGUF,
#   Apache-2.0) dans %LOCALAPPDATA%\FuraxCortana\models\ après l'installation. Embarquer
#   des poids de modèle dans l'ISO gonflerait le WIM de centaines de Mo à plusieurs Go et
#   soulèverait sa propre question de distribution, distincte du code (100% du projet +
#   dépendances MIT) déposé ici.
#
# ⚠️ Honnêteté : la COMPILATION est vérifiée réellement (dotnet publish, exécutable PE32+
# confirmé via `file`). L'INFÉRENCE (chargement modèle + génération de texte) a été
# vérifiée réellement avec cette exacte API (LLamaWeights/CreateContext/InteractiveExecutor)
# mais sur Linux (llama.cpp est multiplateforme) — pas de boot Windows possible dans cet
# environnement pour vérifier le chargement natif spécifique à Windows ni le raccourci
# clavier global ni le rendu de l'UI. Voir docs/FEATURES.md.

module_48d_cortana_experimental() {
  log_step "48d-cortana-experimental : compilation + dépôt de l'assistant local Furax Cortana (EXPERIMENTAL)"

  local app_src_dir="$PROJECT_ROOT/apps/furax-cortana"
  local dest_dir="$MOUNT_DIR/FuraxWindows12/cortana"
  local ntuser_hive="$MOUNT_DIR/Users/Default/NTUSER.DAT"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) compilerait $app_src_dir (dotnet publish -r win-x64) -> $dest_dir"
    log_info "(dry-run) écrirait HKCU\\...\\Run\\FuraxWindows12Cortana dans $ntuser_hive"
    report_step "48d-cortana-experimental" "DRY-RUN"
    return 0
  fi

  if [[ ! -d "$app_src_dir" ]]; then
    log_warn "Dossier source introuvable : $app_src_dir — étape SKIPPED."
    report_step "48d-cortana-experimental" "SKIPPED" "source absente"
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
    log_warn ".NET SDK introuvable — impossible de compiler apps/furax-cortana. Étape SKIPPED."
    report_step "48d-cortana-experimental" "SKIPPED" ".NET SDK indisponible"
    return 0
  fi
  log_info ".NET SDK trouvé : $dotnet_bin ($("$dotnet_bin" --version 2>/dev/null))"

  log_info "Compilation de Furax Cortana (dotnet publish -r win-x64 --self-contained)..."
  local publish_dir="$app_src_dir/bin/Release/net8.0-windows/win-x64/publish"
  if ! DOTNET_CLI_TELEMETRY_OPTOUT=1 "$dotnet_bin" publish "$app_src_dir/FuraxCortana.csproj" \
      -c Release -r win-x64 --self-contained true >>"$LOG_FILE" 2>&1; then
    log_warn "Échec de la compilation de apps/furax-cortana (voir $LOG_FILE) — étape SKIPPED, rien déposé."
    report_step "48d-cortana-experimental" "SKIPPED" "échec compilation dotnet"
    return 0
  fi
  if [[ ! -f "$publish_dir/FuraxCortana.exe" ]]; then
    log_warn "Compilation dotnet réussie mais FuraxCortana.exe introuvable dans $publish_dir — étape SKIPPED."
    report_step "48d-cortana-experimental" "SKIPPED" "exe absent après compilation"
    return 0
  fi
  log_info "Compilation réussie : $publish_dir/FuraxCortana.exe"

  mkdir -p "$dest_dir"
  cp "$publish_dir/FuraxCortana.exe" "$dest_dir/FuraxCortana.exe"
  log_info "Exécutable déposé : C:\\FuraxWindows12\\cortana\\FuraxCortana.exe (aucun modèle .gguf déposé — à fournir soi-même)."

  if [[ "${HIVEX_AVAILABLE:-0}" -ne 1 ]]; then
    log_warn "hivex indisponible — exécutable déposé mais entrée de démarrage auto (Run) SKIPPED."
    report_step "48d-cortana-experimental" "PARTIAL" "exe déposé, clé Run SKIPPED (hivex indisponible)"
    return 0
  fi
  if [[ ! -f "$ntuser_hive" ]]; then
    log_warn "Ruche NTUSER.DAT du profil Default introuvable ($ntuser_hive) — clé Run SKIPPED."
    report_step "48d-cortana-experimental" "PARTIAL" "exe déposé, ruche Default absente"
    return 0
  fi

  if "${HIVEX_PYTHON:-/usr/bin/python3.12}" "$BUILDER_DIR/tools/hivex_set_value.py" "$ntuser_hive" \
      'Software\Microsoft\Windows\CurrentVersion\Run' "FuraxWindows12Cortana" "string" \
      'C:\FuraxWindows12\cortana\FuraxCortana.exe' --create-keys >>"$LOG_FILE" 2>&1; then
    log_info "Entrée Run écrite : Furax Cortana démarrera en arrière-plan à l'ouverture de session (raccourci Ctrl+Maj+F pour afficher la fenêtre)."
    report_step "48d-cortana-experimental" "OK" "exe compilé+déposé + entrée Run écrite (rendu visuel/raccourci réel NON vérifiés, aucun modèle fourni)"
  else
    log_warn "Exécutable déposé mais échec de l'écriture de la clé Run (voir $LOG_FILE)."
    report_step "48d-cortana-experimental" "PARTIAL" "exe déposé, clé Run FAILED"
  fi
  return 0
}
