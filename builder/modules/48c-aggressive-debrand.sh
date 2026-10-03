#!/usr/bin/env bash
# 48c-aggressive-debrand.sh — intègre au pipeline le labo expérimental "aggressive"
# (demande explicite de FuraxDev, 01/10/2026, risques acceptés) : supprime "Windows 11" de
# tout ce qui est scannable/modifiable sans toucher à la chaîne de boot ni au registre
# Windows Update/CBS. Voir docs/AGGRESSIVE_DEBRANDING_LAB.md pour la méthodologie complète
# et les résultats du premier run (vérifiés manuellement, hors pipeline).
#
# Opère directement sur $MOUNT_DIR (install.wim déjà monté en lecture-écriture par le
# module 30, après les autres personnalisations 40-47) — donc le remplacement "Windows 11"
# -> "Windows 12" s'applique aussi aux chaînes déjà déposées par les autres modules si elles
# en contenaient (aucune ne devrait, mais le scan le couvrirait quand même).
#
# --no-backup : dans le pipeline, le vrai mécanisme de rollback est l'ISO source, jamais
# modifiée (voir builder/build.sh, header). Les copies .pre-aggressive-patch par fichier
# (utiles pour le labo manuel autonome, voir docs/AGGRESSIVE_DEBRANDING_LAB.md) seraient ici
# redondantes et doublent transitoirement l'usage disque des fichiers patchés — cause réelle
# d'un échec par manque d'espace rencontré lors du premier run intégré au pipeline
# (03/10/2026, voir historique de commits). Supprimé pour cette raison précise.
#
# ⚠️ EXPERIMENTAL, désactivé par défaut dans tous les profils. Risques assumés par
# FuraxDev : signatures Authenticode invalidées sur les fichiers patchés (listés dans le
# rapport), rendu réel au boot non testable dans cet environnement.
#
# Exclusions dures (jamais levées, même en mode agressif) :
# - Registre (SOFTWARE/SYSTEM/...) : les occurrences trouvées dans SOFTWARE sont des
#   identifiants de paquets Windows Update/CBS ("Windows11.0-KB...), pas du texte affiché.
#   Les modifier casserait la correspondance avec le catalogue Microsoft. Vérifié par
#   inspection réelle du contenu (pas supposé) lors du premier run du labo.
# - Chaîne de boot (bootmgr/winload/BCD/EFI) : aucune méthode de restauration disponible
#   dans cet environnement si ça casse.

module_48c_aggressive_debrand() {
  log_step "48c-aggressive-debrand : suppression des mentions \"Windows 11\" (EXPERIMENTAL, risques assumés)"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) scannerait et patcherait \$MOUNT_DIR ($MOUNT_DIR) — voir docs/AGGRESSIVE_DEBRANDING_LAB.md"
    report_step "48c-aggressive-debrand" "DRY-RUN"
    return 0
  fi

  if [[ ! -d "$MOUNT_DIR" ]]; then
    log_warn "\$MOUNT_DIR introuvable ($MOUNT_DIR) — étape SKIPPED."
    report_step "48c-aggressive-debrand" "SKIPPED" "MOUNT_DIR absent"
    return 0
  fi

  local inv="$WORK_DIR/debrand-inventory.jsonl"
  local scan_report="$WORK_DIR/debrand-scan-report.txt"
  local patch_log="$WORK_DIR/debrand-patch-log.jsonl"
  local patch_report="$WORK_DIR/debrand-patch-report.txt"

  log_info "Scan de \$MOUNT_DIR (peut prendre plusieurs minutes, ~140k fichiers sur une image complète)..."
  if ! /usr/bin/python3.12 "$BUILDER_DIR/tools/winstring_scan.py" "$MOUNT_DIR" \
       --out "$inv" --report "$scan_report" >>"$LOG_FILE" 2>&1; then
    log_error "Échec du scan winstring_scan.py (voir $LOG_FILE)."
    report_step "48c-aggressive-debrand" "FAILED" "scan échoué"
    return 1
  fi
  cat "$scan_report" >>"$LOG_FILE"

  log_info "Application du patch (longueur égale, registre et chaîne de boot exclus, --no-backup : rollback = ISO source)..."
  if ! /usr/bin/python3.12 "$BUILDER_DIR/tools/winstring_patch.py" "$inv" "$MOUNT_DIR" \
       --log "$patch_log" --report "$patch_report" --apply --no-backup >>"$LOG_FILE" 2>&1; then
    log_error "Échec du patch winstring_patch.py (voir $LOG_FILE)."
    report_step "48c-aggressive-debrand" "FAILED" "patch échoué"
    return 1
  fi
  cat "$patch_report" >>"$LOG_FILE"

  local patched_count sig_invalidated
  patched_count=$(grep -oP 'Fichiers patchés\s*:\s*\K[0-9]+' "$patch_report" || echo "?")
  sig_invalidated=$(grep -oP 'signature Authenticode PRÉSENTE avant patch.*:\s*\K[0-9]+' "$patch_report" || echo "?")

  log_info "Debranding appliqué : $patched_count fichier(s) patché(s), $sig_invalidated signature(s) Authenticode invalidée(s) (assumé). Détails : $patch_report"
  report_step "48c-aggressive-debrand" "OK" "$patched_count fichier(s) patché(s), $sig_invalidated signature(s) invalidée(s), registre+boot volontairement intacts"
  return 0
}
