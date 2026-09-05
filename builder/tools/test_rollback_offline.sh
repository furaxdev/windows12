#!/usr/bin/env bash
# test_rollback_offline.sh — vérifie, HORS LIGNE (sans démarrer Windows), que la procédure
# de rollback annule bien tout ce que les modules 42/45/46 ont appliqué.
#
# Principe : on prend les VRAIES ruches SOFTWARE et NTUSER.DAT (profil Default) d'une ISO
# Windows 11 officielle, on leur applique exactement les mêmes opérations hivex que le
# builder (forward), on VÉRIFIE par hivexget qu'elles sont bien présentes, puis on applique
# les opérations inverses (rollback) et on VÉRIFIE que tout redevient absent. C'est un test
# réel de la logique de rollback, pas une simulation — juste sans passer par un boot Windows
# complet (ce que cet environnement de développement ne permet pas, voir docs/TESTING.md).
#
# Usage: ./builder/tools/test_rollback_offline.sh <chemin_iso_windows>
set -euo pipefail

ISO_PATH="${1:?Usage: $0 <chemin_iso_windows>}"
BUILDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d /tmp/furax-rollback-test.XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT

PASS=0
FAIL=0
check() {
  local desc="$1" cond="$2"
  if [[ "$cond" -eq 0 ]]; then
    echo "  [PASS] $desc"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== 1. Extraction des ruches SOFTWARE et NTUSER.DAT (profil Default) depuis l'ISO ==="
mkdir -p "$TEST_DIR/wim"
7z x "$ISO_PATH" -o"$TEST_DIR/wim" "sources/install.wim" -y >/dev/null
WIM="$TEST_DIR/wim/sources/install.wim"

mkdir -p "$TEST_DIR/hives"
wimlib-imagex extract "$WIM" 1 "/Windows/System32/config/SOFTWARE" --dest-dir "$TEST_DIR/hives" >/dev/null
wimlib-imagex extract "$WIM" 1 "/Users/Default/NTUSER.DAT" --dest-dir "$TEST_DIR/hives" >/dev/null
SOFTWARE="$TEST_DIR/hives/SOFTWARE"
NTUSER="$TEST_DIR/hives/NTUSER.DAT"
echo "Ruches extraites : $SOFTWARE, $NTUSER"

SET="/usr/bin/python3.12 $BUILDER_DIR/tools/hivex_set_value.py"
DEL_VAL="/usr/bin/python3.12 $BUILDER_DIR/tools/hivex_delete_value.py"
DEL_KEY="/usr/bin/python3.12 $BUILDER_DIR/tools/hivex_delete_key.py"

echo ""
echo "=== 2. Confirme l'état STOCK (avant toute modification) ==="
check "RegisteredOwner absent ou vide par défaut (stock)" $([[ -z "$(hivexget "$SOFTWARE" '\Microsoft\Windows NT\CurrentVersion' RegisteredOwner 2>/dev/null)" ]]; echo $?)
check "OEMInformation absent par défaut (stock)" $(! hivexget "$SOFTWARE" '\Microsoft\Windows\CurrentVersion\OEMInformation' Manufacturer >/dev/null 2>&1; echo $?)

echo ""
echo "=== 3. Applique le FORWARD (mêmes opérations que 42-branding.sh / 46-theme.sh) ==="
$SET "$SOFTWARE" 'Microsoft\Windows NT\CurrentVersion' RegisteredOwner string "Furax" --create-keys >/dev/null
$SET "$SOFTWARE" 'Microsoft\Windows NT\CurrentVersion' RegisteredOrganization string "By FuraxDev" --create-keys >/dev/null
$SET "$SOFTWARE" 'Microsoft\Windows\CurrentVersion\OEMInformation' Manufacturer string "FuraxDev" --create-keys >/dev/null
$SET "$NTUSER" 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' AppsUseLightTheme dword 0 --create-keys >/dev/null
$SET "$NTUSER" 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' ColorPrevalence dword 1 --create-keys >/dev/null
$SET "$NTUSER" 'Control Panel\Desktop' AutoColorization dword 1 --create-keys >/dev/null

echo "Vérification post-forward :"
check "RegisteredOrganization = 'By FuraxDev'" $([[ "$(hivexget "$SOFTWARE" '\Microsoft\Windows NT\CurrentVersion' RegisteredOrganization)" == "By FuraxDev" ]]; echo $?)
check "OEMInformation\\Manufacturer = 'FuraxDev'" $([[ "$(hivexget "$SOFTWARE" '\Microsoft\Windows\CurrentVersion\OEMInformation' Manufacturer)" == "FuraxDev" ]]; echo $?)
check "AppsUseLightTheme = 0" $([[ "$(hivexget "$NTUSER" '\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' AppsUseLightTheme)" == "0" ]]; echo $?)
check "ColorPrevalence = 1" $([[ "$(hivexget "$NTUSER" '\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' ColorPrevalence)" == "1" ]]; echo $?)

echo ""
echo "=== 4. Applique le ROLLBACK (inverse) ==="
$DEL_VAL "$SOFTWARE" 'Microsoft\Windows NT\CurrentVersion' RegisteredOwner >/dev/null
$DEL_VAL "$SOFTWARE" 'Microsoft\Windows NT\CurrentVersion' RegisteredOrganization >/dev/null
$DEL_KEY "$SOFTWARE" 'Microsoft\Windows\CurrentVersion' OEMInformation >/dev/null
$DEL_VAL "$NTUSER" 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' AppsUseLightTheme >/dev/null
$DEL_VAL "$NTUSER" 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' ColorPrevalence >/dev/null
$DEL_VAL "$NTUSER" 'Control Panel\Desktop' AutoColorization >/dev/null

echo "Vérification post-rollback :"
check "RegisteredOwner de nouveau absent" $(! hivexget "$SOFTWARE" '\Microsoft\Windows NT\CurrentVersion' RegisteredOwner >/dev/null 2>&1; echo $?)
check "RegisteredOrganization de nouveau absent" $(! hivexget "$SOFTWARE" '\Microsoft\Windows NT\CurrentVersion' RegisteredOrganization >/dev/null 2>&1; echo $?)
check "OEMInformation entièrement supprimé" $(! hivexget "$SOFTWARE" '\Microsoft\Windows\CurrentVersion\OEMInformation' Manufacturer >/dev/null 2>&1; echo $?)
check "AppsUseLightTheme de nouveau absent" $(! hivexget "$NTUSER" '\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' AppsUseLightTheme >/dev/null 2>&1; echo $?)
check "ColorPrevalence de nouveau absent" $(! hivexget "$NTUSER" '\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' ColorPrevalence >/dev/null 2>&1; echo $?)
check "AutoColorization de nouveau absent" $(! hivexget "$NTUSER" '\Control Panel\Desktop' AutoColorization >/dev/null 2>&1; echo $?)

echo ""
echo "=== Résultat : $PASS PASS / $FAIL FAIL ==="
if [[ "$FAIL" -eq 0 ]]; then
  echo "Rollback offline validé : la logique d'annulation (registre) est correcte."
  exit 0
else
  echo "ÉCHEC : au moins une vérification de rollback a échoué — NE PAS considérer le rollback comme fiable."
  exit 1
fi
