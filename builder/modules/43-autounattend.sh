#!/usr/bin/env bash
# 43-autounattend.sh — dépose autounattend.xml à la racine de l'ISO (arborescence extraite,
# AVANT reconstruction en 60-build-iso). Mécanisme Microsoft standard et documenté : Windows
# Setup (WinPE) cherche ce fichier à la racine du média de boot au démarrage et applique ses
# réponses automatiquement — ce n'est pas un patch, juste un fichier XML au bon endroit.
#
# Contrairement aux modules 42/45/46/47 (registre offline dans install.wim), celui-ci ne
# touche à AUCUN WIM — il place juste un fichier dans l'arborescence extraite de l'ISO, donc
# n'a pas besoin d'attendre le montage d'install.wim (peut tourner juste après 10-extract).
#
# ⚠️ Honnêteté : ce module valide que le XML déposé est bien formé (xml.dom.minidom), ce qui
# confirme que le FICHIER est syntaxiquement correct — ça ne confirme PAS que Windows Setup
# l'interprète comme prévu lors d'un vrai boot (jamais testé dans cet environnement de dev,
# voir docs/FEATURES.md item #76 et docs/TROUBLESHOOTING.md). Ne pas présenter ce point comme
# "les écrans sont sautés" avant un test réel.

module_43_autounattend() {
  log_step "43-autounattend : dépôt d'autounattend.xml à la racine de l'ISO"

  local src="$PROJECT_ROOT/assets/unattend/autounattend.xml"
  local dest="$EXTRACT_DIR/autounattend.xml"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) copierait $src vers $dest"
    report_step "43-autounattend" "DRY-RUN"
    return 0
  fi

  if [[ ! -f "$src" ]]; then
    log_warn "Asset autounattend.xml introuvable : $src — étape SKIPPED."
    report_step "43-autounattend" "SKIPPED" "asset absent"
    return 0
  fi

  if ! python3 -c "import xml.dom.minidom, sys; xml.dom.minidom.parse(sys.argv[1])" "$src" >>"$LOG_FILE" 2>&1; then
    log_error "autounattend.xml n'est pas un XML bien formé — refus de le déposer sur l'ISO (éviterait un Setup cassé)."
    report_step "43-autounattend" "FAILED" "XML mal formé"
    return 1
  fi
  log_info "autounattend.xml validé bien formé (XML)."

  cp "$src" "$dest"
  log_info "Déposé : autounattend.xml à la racine de l'ISO."
  log_warn "Comportement réel au boot Windows Setup NON vérifié dans cet environnement (pas de VM Windows démarrable ici) — à confirmer lors d'un test réel, voir docs/FEATURES.md item #76."
  report_step "43-autounattend" "OK" "fichier déposé et validé bien formé — comportement au boot non testé"
  return 0
}
