#!/usr/bin/env bash
# 46-theme.sh — thème sombre (par défaut) OU clair + accent coloré sur la barre des
# tâches/Démarrer, pour se rapprocher de l'ambiance vue dans la vidéo, en s'appuyant
# UNIQUEMENT sur des réglages natifs Windows 11 documentés (aucun patch de shell).
#
# Variante contrôlée par $THEME_VARIANT ("dark" par défaut, ou "light" — backlog #92) :
# seuls AppsUseLightTheme/SystemUsesLightTheme changent de valeur, tout le reste
# (transparence, accent, icônes centrées) est identique dans les deux variantes — c'est
# la même identité visuelle Furax, juste plus ou moins sombre.
#
# Clés utilisées, toutes sous Users/Default/NTUSER.DAT (profil par défaut -> hérité par
# tout nouveau compte créé à l'OOBE) :
#
# Software\Microsoft\Windows\CurrentVersion\Themes\Personalize
#   AppsUseLightTheme    = 0 (dark) ou 1 (light)
#   SystemUsesLightTheme = 0 (dark) ou 1 (light)  -- barre des tâches/Démarrer
#   EnableTransparency   = 1   (effets de transparence/flou, Acrylic/Mica)
#   ColorPrevalence      = 1   (la couleur d'accentuation apparaît sur la barre des
#                                tâches/Démarrer/barres de titre - désactivé par défaut
#                                sous Windows 11, c'est ce réglage qui rapproche le plus
#                                visuellement de la barre des tâches colorée de la vidéo)
#
# Control Panel\Desktop
#   AutoColorization = 1  (la couleur d'accentuation est dérivée automatiquement du fond
#                           d'écran - déjà le comportement par défaut de Windows 11, mais
#                           réglé explicitement ici. Comme notre fond d'écran, voir module
#                           45, est déjà dans les tons magenta/bleu de la vidéo, Windows
#                           calcule lui-même un accent cohérent - on évite ainsi de deviner
#                           un format de DWORD ARGB propriétaire pour forcer une couleur
#                           manuelle, ce qu'on ne maîtrise pas avec certitude)
#
# Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced
#   TaskbarAl = 1  (icônes centrées - déjà le défaut Windows 11, réglé explicitement)
#
# ⚠️ Backlog #70 (Windows Spotlight sur l'écran de verrouillage) INTENTIONNELLEMENT PAS
# implémenté ici : vérifié par extraction directe de NTUSER.DAT depuis une vraie ISO
# Windows 11 25H2 stock (20/09/2026) que RotatingLockScreenEnabled et
# RotatingLockScreenOverlayEnabled valent DÉJÀ 1 par défaut sur cette édition/build —
# les écrire n'aurait aucun effet réel, et notre rollback aurait supprimé une clé stock au
# lieu de "revenir au défaut". Backlog #70 mis à jour en conséquence dans docs/FEATURES.md.
#
# ⚠️ Honnêteté : ceci NE reproduit PAS la barre des tâches flottante en pilule avec coins
# très arrondis et marges vues dans la vidéo (docs/FEATURES.md : nécessite un patch de
# shell tiers type Windhawk, PLANNED, pas fait ici faute de temps/de validation robuste).
# Ce module ne fait que du thème natif (sombre + coloré), qui rapproche visuellement mais
# ne remplace pas la refonte structurelle de la barre.

module_46_theme() {
  local variant="${THEME_VARIANT:-dark}"
  if [[ "$variant" != "dark" && "$variant" != "light" ]]; then
    log_warn "theme_variant='$variant' invalide (attendu dark|light) — repli sur 'dark'."
    variant="dark"
  fi
  local light_flag=0
  [[ "$variant" == "light" ]] && light_flag=1

  log_step "46-theme : thème $variant + accent coloré (réglages natifs)"

  local ntuser_hive="$MOUNT_DIR/Users/Default/NTUSER.DAT"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_info "(dry-run) écrirait les réglages de thème $variant/accent dans $ntuser_hive"
    report_step "46-theme" "DRY-RUN"
    return 0
  fi

  if [[ "${HIVEX_AVAILABLE:-0}" -ne 1 ]]; then
    log_warn "hivex indisponible — étape SKIPPED (pas simulée)."
    report_step "46-theme" "SKIPPED" "hivex indisponible"
    return 0
  fi
  if [[ ! -f "$ntuser_hive" ]]; then
    log_warn "Ruche NTUSER.DAT du profil Default introuvable ($ntuser_hive) — étape SKIPPED."
    report_step "46-theme" "SKIPPED" "ruche absente"
    return 0
  fi

  local ok=1
  local set_val="/usr/bin/python3.12 $BUILDER_DIR/tools/hivex_set_value.py"

  $set_val "$ntuser_hive" 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' "AppsUseLightTheme" "dword" "$light_flag" \
    --create-keys >>"$LOG_FILE" 2>&1 || ok=0
  $set_val "$ntuser_hive" 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' "SystemUsesLightTheme" "dword" "$light_flag" \
    --create-keys >>"$LOG_FILE" 2>&1 || ok=0
  $set_val "$ntuser_hive" 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' "EnableTransparency" "dword" "1" \
    --create-keys >>"$LOG_FILE" 2>&1 || ok=0
  $set_val "$ntuser_hive" 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' "ColorPrevalence" "dword" "1" \
    --create-keys >>"$LOG_FILE" 2>&1 || ok=0

  $set_val "$ntuser_hive" 'Control Panel\Desktop' "AutoColorization" "dword" "1" \
    --create-keys >>"$LOG_FILE" 2>&1 || ok=0

  $set_val "$ntuser_hive" 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' "TaskbarAl" "dword" "1" \
    --create-keys >>"$LOG_FILE" 2>&1 || ok=0

  if [[ "$ok" -eq 1 ]]; then
    log_info "Thème appliqué au profil par défaut : mode $variant + transparence + accent sur barre des tâches/Démarrer (dérivé du fond d'écran) + icônes centrées."
    report_step "46-theme" "OK" "$variant theme + ColorPrevalence + AutoColorization + TaskbarAl"
  else
    log_warn "Échec partiel de l'écriture du thème (voir $LOG_FILE)."
    report_step "46-theme" "PARTIAL" "échec partiel, voir log"
  fi
  return 0
}
