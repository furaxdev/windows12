#!/usr/bin/env bash
# 20-identify.sh — repère l'image WIM/ESD d'installation et l'index (édition) à utiliser.

module_20_identify() {
  log_step "20-identify : identification de l'image d'installation"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) recherche de sources/install.wim ou sources/install.esd sous $EXTRACT_DIR"
    # Valeurs fictives pour que les étapes dry-run suivantes (30-mount etc.) puissent
    # afficher un plan cohérent sans planter sous 'set -u'.
    WIM_PATH="$EXTRACT_DIR/sources/install.wim"
    WIM_INDEX="${WIM_INDEX:-1}"
    report_step "20-identify" "DRY-RUN"
    return 0
  fi

  if [[ -f "$EXTRACT_DIR/sources/install.wim" ]]; then
    WIM_PATH="$EXTRACT_DIR/sources/install.wim"
  elif [[ -f "$EXTRACT_DIR/sources/install.esd" ]]; then
    WIM_PATH="$EXTRACT_DIR/sources/install.esd"
    log_warn "install.esd détecté : certaines ESD de distribution Windows Update sont chiffrées et ne peuvent pas être montées offline. Si le montage (module 30) échoue, c'est la cause la plus probable — il faut alors repartir d'une ISO avec install.wim, ou convertir l'ESD au préalable avec un outil disposant des bonnes clés (hors scope de ce projet)."
  else
    log_error "Ni sources/install.wim ni sources/install.esd trouvé sous $EXTRACT_DIR"
    report_step "20-identify" "FAILED" "image absente"
    return 1
  fi

  log_info "Image sélectionnée : $WIM_PATH"
  log_info "Liste des index/éditions disponibles (wimlib-imagex info) :"
  if ! wimlib-imagex info "$WIM_PATH" >>"$LOG_FILE" 2>&1; then
    log_error "wimlib-imagex info a échoué sur $WIM_PATH — fichier WIM/ESD probablement corrompu ou format non supporté."
    report_step "20-identify" "FAILED" "wimlib-imagex info a échoué"
    return 1
  fi
  wimlib-imagex info "$WIM_PATH" | tee -a "$LOG_FILE"

  WIM_INDEX="${WIM_INDEX:-1}"
  log_info "Index d'image utilisé : $WIM_INDEX (par défaut 1, surchargeable via --wim-index)"

  # Métadonnées de l'édition, capturées pour le rapport de build final (docs/BUILD.md §rapport).
  local image_info
  image_info=$(wimlib-imagex info "$WIM_PATH" "$WIM_INDEX" 2>>"$LOG_FILE")
  WIN_PRODUCT_NAME=$(echo "$image_info" | sed -n 's/^Product Name: *//p' | head -1)
  WIN_EDITION_ID=$(echo "$image_info" | sed -n 's/^Edition ID: *//p' | head -1)
  WIN_ARCHITECTURE=$(echo "$image_info" | sed -n 's/^Architecture: *//p' | head -1)
  WIN_MAJOR_VERSION=$(echo "$image_info" | sed -n 's/^Major Version: *//p' | head -1)
  WIN_MINOR_VERSION=$(echo "$image_info" | sed -n 's/^Minor Version: *//p' | head -1)
  WIN_BUILD=$(echo "$image_info" | sed -n 's/^Build: *//p' | head -1)
  WIN_SP_BUILD=$(echo "$image_info" | sed -n 's/^Service Pack Build: *//p' | head -1)
  WIN_LANGUAGES=$(echo "$image_info" | sed -n 's/^Languages: *//p' | head -1)
  log_info "Édition détectée : $WIN_PRODUCT_NAME / $WIN_EDITION_ID / $WIN_ARCHITECTURE / version $WIN_MAJOR_VERSION.$WIN_MINOR_VERSION build $WIN_BUILD.$WIN_SP_BUILD"

  report_step "20-identify" "OK" "$WIM_PATH index=$WIM_INDEX ($WIN_EDITION_ID $WIN_ARCHITECTURE)"
  return 0
}
