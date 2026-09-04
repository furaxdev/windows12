#!/usr/bin/env bash
# 45-wallpaper.sh — remplace le fond d'écran par défaut du bureau par l'asset du design
# system Furax (assets/wallpapers/), et configure le profil utilisateur par défaut pour
# l'utiliser (Fill, sans mosaïque) dès la création d'un nouveau compte.
#
# Ce que ce module fait réellement (vérifié, pas supposé) :
# - remplace Windows/Web/Wallpaper/Windows/img0.jpg (fond d'écran par défaut du bureau
#   sous Windows 11 — confirmé présent à ce chemin exact en inspectant une vraie ISO
#   Windows 11 25H2 avec `wimlib-imagex dir`), redimensionné en "cover fit" à la même
#   résolution que l'original (pas de déformation) ;
# - sauvegarde l'original en img0_stock_original.jpg avant de l'écraser ;
# - édite HKCU\Control Panel\Desktop dans la ruche NTUSER.DAT du profil "Default"
#   (Users/Default/NTUSER.DAT, présente et confirmée dans une vraie ISO Windows 11 25H2)
#   pour que les NOUVEAUX comptes créés à l'OOBE héritent de ce fond d'écran en mode
#   "Remplir" (WallpaperStyle=10), sans répétition (TileWallpaper=0).
#
# Ce que ce module NE fait PAS : il ne touche pas à l'écran de verrouillage (img19.jpg,
# LogonUI — composants plus fermés, voir docs/FEATURES.md) ni à la couleur d'accentuation.

module_45_wallpaper() {
  log_step "45-wallpaper : fond d'écran par défaut du bureau"

  local wallpaper_src="$PROJECT_ROOT/assets/wallpapers/furax-wave-primary.jpg"
  local target_rel="Windows/Web/Wallpaper/Windows/img0.jpg"
  local target="$MOUNT_DIR/$target_rel"
  local ntuser_hive="$MOUNT_DIR/Users/Default/NTUSER.DAT"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) remplacerait $target par une version redimensionnée de $wallpaper_src"
    log_info "(dry-run) écrirait HKCU\\Control Panel\\Desktop\\WallPaper dans $ntuser_hive"
    report_step "45-wallpaper" "DRY-RUN"
    return 0
  fi

  if [[ ! -f "$wallpaper_src" ]]; then
    log_warn "Asset de fond d'écran introuvable : $wallpaper_src — étape SKIPPED."
    report_step "45-wallpaper" "SKIPPED" "asset absent"
    return 0
  fi
  if [[ ! -f "$target" ]]; then
    log_warn "$target_rel introuvable dans l'image montée — édition Windows non standard ? Étape SKIPPED."
    report_step "45-wallpaper" "SKIPPED" "img0.jpg absent"
    return 0
  fi

  # Dimensions cibles = celles du fond d'écran stock, pour rester cohérent avec ce que
  # Windows attend à cet emplacement (évite un fichier surdimensionné ou sous-dimensionné).
  local dims
  dims=$(/usr/bin/python3.12 -c "from PIL import Image; im = Image.open('$target'); print(f'{im.size[0]} {im.size[1]}')" 2>>"$LOG_FILE")
  if [[ -z "$dims" ]]; then
    log_error "Impossible de lire les dimensions de $target (Pillow manquant ? voir python3-pil)."
    report_step "45-wallpaper" "FAILED" "lecture dimensions impossible"
    return 1
  fi
  local target_w target_h
  read -r target_w target_h <<< "$dims"
  log_info "Dimensions cibles (fond d'écran stock) : ${target_w}x${target_h}"

  if [[ ! -f "$MOUNT_DIR/$target_rel.stock-original" ]]; then
    cp "$target" "$MOUNT_DIR/$target_rel.stock-original"
    log_info "Original sauvegardé : $target_rel.stock-original"
  fi

  local resized="$WORK_DIR/wallpaper-resized.jpg"
  if ! /usr/bin/python3.12 "$BUILDER_DIR/tools/prepare_wallpaper.py" "$wallpaper_src" "$resized" "$target_w" "$target_h" >>"$LOG_FILE" 2>&1; then
    log_error "Échec du redimensionnement du fond d'écran (voir $LOG_FILE)."
    report_step "45-wallpaper" "FAILED" "redimensionnement échoué"
    return 1
  fi

  cp "$resized" "$target"
  log_info "Fond d'écran remplacé : $target_rel"

  if [[ "${HIVEX_AVAILABLE:-0}" -ne 1 ]]; then
    log_warn "hivex indisponible — le nouveau fond d'écran est en place mais le profil par défaut ne sera PAS configuré pour l'utiliser automatiquement (WallpaperStyle/TileWallpaper non écrits)."
    report_step "45-wallpaper" "PARTIAL" "image remplacée, registre profil par défaut SKIPPED (hivex indisponible)"
    return 0
  fi
  if [[ ! -f "$ntuser_hive" ]]; then
    log_warn "Ruche NTUSER.DAT du profil Default introuvable ($ntuser_hive) — registre SKIPPED."
    report_step "45-wallpaper" "PARTIAL" "image remplacée, registre profil par défaut SKIPPED (ruche absente)"
    return 0
  fi

  local win_path='C:\Windows\Web\Wallpaper\Windows\img0.jpg'
  local reg_ok=1
  /usr/bin/python3.12 "$BUILDER_DIR/tools/hivex_set_value.py" "$ntuser_hive" "Control Panel\\Desktop" "WallPaper" "string" "$win_path" >>"$LOG_FILE" 2>&1 || reg_ok=0
  /usr/bin/python3.12 "$BUILDER_DIR/tools/hivex_set_value.py" "$ntuser_hive" "Control Panel\\Desktop" "WallpaperStyle" "string" "10" >>"$LOG_FILE" 2>&1 || reg_ok=0
  /usr/bin/python3.12 "$BUILDER_DIR/tools/hivex_set_value.py" "$ntuser_hive" "Control Panel\\Desktop" "TileWallpaper" "string" "0" >>"$LOG_FILE" 2>&1 || reg_ok=0

  if [[ "$reg_ok" -eq 1 ]]; then
    log_info "Profil par défaut configuré : nouveau fond d'écran en mode Remplir (WallpaperStyle=10, TileWallpaper=0)."
    report_step "45-wallpaper" "OK" "img0.jpg remplacé + profil Default configuré"
  else
    log_warn "Image remplacée mais échec partiel de l'écriture registre profil Default (voir $LOG_FILE)."
    report_step "45-wallpaper" "PARTIAL" "image remplacée, registre profil par défaut FAILED"
  fi
  return 0
}
