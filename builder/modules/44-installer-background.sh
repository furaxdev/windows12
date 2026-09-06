#!/usr/bin/env bash
# 44-installer-background.sh — remplace le fond d'écran de l'assistant Windows Setup
# (l'écran bleu affiché quand tu boot sur la clé USB), PAS le bureau une fois installé
# (voir 45-wallpaper.sh pour ça).
#
# Ce que ce module fait réellement (vérifié, pas supposé) :
# - monte boot.wim (PAS install.wim — c'est une image WIM séparée, présente dans
#   sources/boot.wim sur l'ISO) en lecture/écriture, index 2 ("Microsoft Windows Setup",
#   confirmé via `wimlib-imagex info` sur une vraie ISO Windows 11 25H2 — l'index 1 est
#   "Microsoft Windows PE", pas l'assistant d'installation lui-même) ;
# - remplace sources/background.bmp ET Windows/System32/setup.bmp (les deux existent et
#   sont identiques sur l'ISO stock ; vérifié par inspection directe — malgré l'extension
#   .bmp, ce sont en réalité des PNG RGBA, confirmé via `file`) ;
# - conserve les dimensions exactes de l'original (1024x768 sur l'ISO 25H2 testée) en les
#   lisant dynamiquement, pas en les codant en dur ;
# - sauvegarde les originaux en .stock-original avant de les écraser.
#
# Ce que ce module NE fait PAS : il ne touche à aucune ressource compilée dans les
# binaires du setup (SetupPlatform.exe, SetupHost.exe...) — l'animation de progression,
# la mise en page des boutons/texte de l'assistant restent celles de Windows stock. Voir
# docs/FEATURES.md pour le détail de ce qui est CONCEPT ONLY dans ce domaine.

module_44_installer_background() {
  log_step "44-installer-background : fond d'écran de l'assistant Windows Setup (boot.wim)"

  local boot_wim="$EXTRACT_DIR/sources/boot.wim"
  local bg_src="$PROJECT_ROOT/assets/wallpapers/furax-wave-primary.jpg"
  local setup_index=2
  local boot_mount="$WORK_DIR/mount-boot"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) monterait $boot_wim (index $setup_index) sur $boot_mount"
    log_info "(dry-run) remplacerait sources/background.bmp et Windows/System32/setup.bmp par une version de $bg_src"
    report_step "44-installer-background" "DRY-RUN"
    return 0
  fi

  if [[ ! -f "$boot_wim" ]]; then
    log_warn "$boot_wim introuvable après extraction — étape SKIPPED."
    report_step "44-installer-background" "SKIPPED" "boot.wim absent"
    return 0
  fi
  if [[ ! -f "$bg_src" ]]; then
    log_warn "Asset de fond d'écran introuvable : $bg_src — étape SKIPPED."
    report_step "44-installer-background" "SKIPPED" "asset absent"
    return 0
  fi

  mkdir -p "$boot_mount"
  if ! wimlib-imagex mountrw "$boot_wim" "$setup_index" "$boot_mount" >>"$LOG_FILE" 2>&1; then
    log_error "Échec du montage de boot.wim (index $setup_index)."
    report_step "44-installer-background" "FAILED" "montage boot.wim échoué"
    return 1
  fi
  # Réutilise le même filet de sécurité (trap) que pour install.wim : un seul montage actif
  # à la fois à ce stade du pipeline (44 s'exécute avant 30-mount d'install.wim... en réalité
  # après, mais les deux ne sont jamais montés simultanément dans l'ordre actuel du pipeline).
  MOUNTED_DIR="$boot_mount"
  MOUNTED_WIM_PATH="$boot_wim"

  local targets=("sources/background.bmp" "Windows/System32/setup.bmp")
  local any_ok=0
  local any_fail=0

  for rel in "${targets[@]}"; do
    local target="$boot_mount/$rel"
    if [[ ! -f "$target" ]]; then
      log_warn "$rel introuvable dans boot.wim (index $setup_index) — cible ignorée."
      continue
    fi

    local dims
    dims=$(/usr/bin/python3.12 -c "from PIL import Image; im = Image.open('$target'); print(f'{im.size[0]} {im.size[1]}')" 2>>"$LOG_FILE")
    if [[ -z "$dims" ]]; then
      log_warn "Impossible de lire les dimensions de $rel — cible ignorée."
      any_fail=1
      continue
    fi
    local w h
    read -r w h <<< "$dims"

    if [[ ! -f "$target.stock-original" ]]; then
      cp "$target" "$target.stock-original"
    fi

    local resized="$WORK_DIR/installer-bg-$(basename "$rel").png"
    if ! /usr/bin/python3.12 "$BUILDER_DIR/tools/prepare_installer_background.py" "$bg_src" "$resized" "$w" "$h" >>"$LOG_FILE" 2>&1; then
      log_warn "Échec du redimensionnement pour $rel (voir $LOG_FILE)."
      any_fail=1
      continue
    fi

    cp "$resized" "$target"
    log_info "Remplacé : $rel (${w}x${h})"
    any_ok=1
  done

  log_info "Démontage de boot.wim (commit)..."
  if ! wimlib-imagex unmount "$boot_mount" --commit >>"$LOG_FILE" 2>&1; then
    log_error "Échec du démontage/commit de boot.wim."
    report_step "44-installer-background" "FAILED" "démontage/commit échoué"
    MOUNTED_DIR=""
    MOUNTED_WIM_PATH=""
    return 1
  fi
  MOUNTED_DIR=""
  MOUNTED_WIM_PATH=""

  if [[ "$any_ok" -eq 1 && "$any_fail" -eq 0 ]]; then
    report_step "44-installer-background" "OK" "background.bmp + setup.bmp remplacés dans boot.wim"
  elif [[ "$any_ok" -eq 1 ]]; then
    report_step "44-installer-background" "PARTIAL" "au moins une cible remplacée, au moins une échouée/ignorée"
  else
    log_warn "Aucune cible remplacée dans boot.wim."
    report_step "44-installer-background" "SKIPPED" "aucune cible trouvée/remplacée"
  fi
  return 0
}
