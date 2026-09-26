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
wimlib-imagex extract "$WIM" 1 "/Windows/System32/config/SYSTEM" --dest-dir "$TEST_DIR/hives" >/dev/null
SOFTWARE="$TEST_DIR/hives/SOFTWARE"
NTUSER="$TEST_DIR/hives/NTUSER.DAT"
SYSTEM="$TEST_DIR/hives/SYSTEM"
echo "Ruches extraites : $SOFTWARE, $NTUSER, $SYSTEM"

# ControlSet actif : jamais codé en dur, lu dynamiquement (voir 47-privacy-performance.sh).
ACTIVE_CS_NUM=$(hivexget "$SYSTEM" '\Select' Default)
ACTIVE_CS=$(printf "ControlSet%03d" "$ACTIVE_CS_NUM")
echo "ControlSet actif détecté : $ACTIVE_CS (Select\\Default=$ACTIVE_CS_NUM)"

SET="/usr/bin/python3.12 $BUILDER_DIR/tools/hivex_set_value.py"
DEL_VAL="/usr/bin/python3.12 $BUILDER_DIR/tools/hivex_delete_value.py"
DEL_KEY="/usr/bin/python3.12 $BUILDER_DIR/tools/hivex_delete_key.py"

echo ""
echo "=== 2. Confirme l'état STOCK (avant toute modification) ==="
check "RegisteredOwner absent ou vide par défaut (stock)" $([[ -z "$(hivexget "$SOFTWARE" '\Microsoft\Windows NT\CurrentVersion' RegisteredOwner 2>/dev/null)" ]]; echo $?)
check "OEMInformation absent par défaut (stock)" $(! hivexget "$SOFTWARE" '\Microsoft\Windows\CurrentVersion\OEMInformation' Manufacturer >/dev/null 2>&1; echo $?)
check "AllowTelemetry absent par défaut (stock)" $(! hivexget "$SOFTWARE" '\Policies\Microsoft\Windows\DataCollection' AllowTelemetry >/dev/null 2>&1; echo $?)
check "TurnOffWindowsCopilot absent par défaut (stock)" $(! hivexget "$SOFTWARE" '\Policies\Microsoft\Windows\WindowsCopilot' TurnOffWindowsCopilot >/dev/null 2>&1; echo $?)
check "FuraxWindows12FirstLogon absent par défaut (stock)" $(! hivexget "$SOFTWARE" '\Microsoft\Windows\CurrentVersion\RunOnce' FuraxWindows12FirstLogon >/dev/null 2>&1; echo $?)
check "DisableNotifications (Defender) absent par défaut (stock)" $(! hivexget "$SOFTWARE" '\Policies\Microsoft\Windows Defender Security Center\Notifications' DisableNotifications >/dev/null 2>&1; echo $?)
check "WSearch Start = 2 par défaut (stock, Automatique)" $([[ "$(hivexget "$SYSTEM" "\\${ACTIVE_CS}\\Services\\WSearch" Start)" == "2" ]]; echo $?)
check "SysMain Start = 2 par défaut (stock, Automatique)" $([[ "$(hivexget "$SYSTEM" "\\${ACTIVE_CS}\\Services\\SysMain" Start)" == "2" ]]; echo $?)
check "FuraxWindows12Taskbar (Run) absent par défaut (stock)" $(! hivexget "$NTUSER" '\Software\Microsoft\Windows\CurrentVersion\Run' FuraxWindows12Taskbar >/dev/null 2>&1; echo $?)

echo ""
echo "=== 3. Applique le FORWARD (mêmes opérations que 42-branding.sh / 46-theme.sh) ==="
$SET "$SOFTWARE" 'Microsoft\Windows NT\CurrentVersion' RegisteredOwner string "Furax" --create-keys >/dev/null
$SET "$SOFTWARE" 'Microsoft\Windows NT\CurrentVersion' RegisteredOrganization string "By FuraxDev" --create-keys >/dev/null
$SET "$SOFTWARE" 'Microsoft\Windows\CurrentVersion\OEMInformation' Manufacturer string "FuraxDev" --create-keys >/dev/null
$SET "$NTUSER" 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' AppsUseLightTheme dword 0 --create-keys >/dev/null
$SET "$NTUSER" 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' ColorPrevalence dword 1 --create-keys >/dev/null
$SET "$NTUSER" 'Control Panel\Desktop' AutoColorization dword 1 --create-keys >/dev/null
$SET "$SOFTWARE" 'Policies\Microsoft\Windows\DataCollection' AllowTelemetry dword 1 --create-keys >/dev/null
$SET "$SOFTWARE" 'Policies\Microsoft\Windows\WindowsCopilot' TurnOffWindowsCopilot dword 1 --create-keys >/dev/null
$SET "$SOFTWARE" 'Policies\Microsoft\Windows\WindowsUpdate' DeferFeatureUpdatesPeriodInDays dword 7 --create-keys >/dev/null
$SET "$NTUSER" 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' SubscribedContent-338388Enabled dword 0 --create-keys >/dev/null
$SET "$NTUSER" 'Software\Microsoft\Clipboard' EnableClipboardHistory dword 1 --create-keys >/dev/null
$SET "$NTUSER" 'Software\Microsoft\GameBar' AllowAutoGameMode dword 1 --create-keys >/dev/null
$SET "$NTUSER" 'System\GameConfigStore' GameDVR_Enabled dword 0 --create-keys >/dev/null
$SET "$SOFTWARE" 'Microsoft\Windows\CurrentVersion\RunOnce' FuraxWindows12FirstLogon string "powershell.exe -File test.ps1" --create-keys >/dev/null
$SET "$SOFTWARE" 'Policies\Microsoft\Windows Defender Security Center\Notifications' DisableNotifications dword 1 --create-keys >/dev/null
$SET "$SYSTEM" "${ACTIVE_CS}\\Services\\WSearch" Start dword 4 --create-keys >/dev/null
$SET "$SYSTEM" "${ACTIVE_CS}\\Services\\SysMain" Start dword 4 --create-keys >/dev/null
$SET "$NTUSER" 'Software\Microsoft\Windows\CurrentVersion\Run' FuraxWindows12Taskbar string 'C:\FuraxWindows12\taskbar\FuraxTaskbar.exe' --create-keys >/dev/null

echo "Vérification post-forward :"
check "RegisteredOrganization = 'By FuraxDev'" $([[ "$(hivexget "$SOFTWARE" '\Microsoft\Windows NT\CurrentVersion' RegisteredOrganization)" == "By FuraxDev" ]]; echo $?)
check "OEMInformation\\Manufacturer = 'FuraxDev'" $([[ "$(hivexget "$SOFTWARE" '\Microsoft\Windows\CurrentVersion\OEMInformation' Manufacturer)" == "FuraxDev" ]]; echo $?)
check "AppsUseLightTheme = 0" $([[ "$(hivexget "$NTUSER" '\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' AppsUseLightTheme)" == "0" ]]; echo $?)
check "ColorPrevalence = 1" $([[ "$(hivexget "$NTUSER" '\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' ColorPrevalence)" == "1" ]]; echo $?)
check "AllowTelemetry = 1" $([[ "$(hivexget "$SOFTWARE" '\Policies\Microsoft\Windows\DataCollection' AllowTelemetry)" == "1" ]]; echo $?)
check "TurnOffWindowsCopilot = 1" $([[ "$(hivexget "$SOFTWARE" '\Policies\Microsoft\Windows\WindowsCopilot' TurnOffWindowsCopilot)" == "1" ]]; echo $?)
check "DeferFeatureUpdatesPeriodInDays = 7" $([[ "$(hivexget "$SOFTWARE" '\Policies\Microsoft\Windows\WindowsUpdate' DeferFeatureUpdatesPeriodInDays)" == "7" ]]; echo $?)
check "SubscribedContent-338388Enabled = 0" $([[ "$(hivexget "$NTUSER" '\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' SubscribedContent-338388Enabled)" == "0" ]]; echo $?)
check "EnableClipboardHistory = 1" $([[ "$(hivexget "$NTUSER" '\Software\Microsoft\Clipboard' EnableClipboardHistory)" == "1" ]]; echo $?)
check "AllowAutoGameMode = 1" $([[ "$(hivexget "$NTUSER" '\Software\Microsoft\GameBar' AllowAutoGameMode)" == "1" ]]; echo $?)
check "GameDVR_Enabled = 0" $([[ "$(hivexget "$NTUSER" '\System\GameConfigStore' GameDVR_Enabled)" == "0" ]]; echo $?)
check "FuraxWindows12FirstLogon écrit" $([[ -n "$(hivexget "$SOFTWARE" '\Microsoft\Windows\CurrentVersion\RunOnce' FuraxWindows12FirstLogon)" ]]; echo $?)
check "DisableNotifications (Defender) = 1" $([[ "$(hivexget "$SOFTWARE" '\Policies\Microsoft\Windows Defender Security Center\Notifications' DisableNotifications)" == "1" ]]; echo $?)
check "WSearch Start = 4 (Désactivé)" $([[ "$(hivexget "$SYSTEM" "\\${ACTIVE_CS}\\Services\\WSearch" Start)" == "4" ]]; echo $?)
check "SysMain Start = 4 (Désactivé)" $([[ "$(hivexget "$SYSTEM" "\\${ACTIVE_CS}\\Services\\SysMain" Start)" == "4" ]]; echo $?)
check "FuraxWindows12Taskbar (Run) écrit" $([[ -n "$(hivexget "$NTUSER" '\Software\Microsoft\Windows\CurrentVersion\Run' FuraxWindows12Taskbar)" ]]; echo $?)

echo ""
echo "=== 4. Applique le ROLLBACK (inverse) ==="
$DEL_VAL "$SOFTWARE" 'Microsoft\Windows NT\CurrentVersion' RegisteredOwner >/dev/null
$DEL_VAL "$SOFTWARE" 'Microsoft\Windows NT\CurrentVersion' RegisteredOrganization >/dev/null
$DEL_KEY "$SOFTWARE" 'Microsoft\Windows\CurrentVersion' OEMInformation >/dev/null
$DEL_VAL "$NTUSER" 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' AppsUseLightTheme >/dev/null
$DEL_VAL "$NTUSER" 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' ColorPrevalence >/dev/null
$DEL_VAL "$NTUSER" 'Control Panel\Desktop' AutoColorization >/dev/null
$DEL_VAL "$SOFTWARE" 'Policies\Microsoft\Windows\DataCollection' AllowTelemetry >/dev/null
$DEL_VAL "$SOFTWARE" 'Policies\Microsoft\Windows\WindowsCopilot' TurnOffWindowsCopilot >/dev/null
$DEL_VAL "$SOFTWARE" 'Policies\Microsoft\Windows\WindowsUpdate' DeferFeatureUpdatesPeriodInDays >/dev/null
$DEL_VAL "$NTUSER" 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' SubscribedContent-338388Enabled >/dev/null
$DEL_VAL "$NTUSER" 'Software\Microsoft\Clipboard' EnableClipboardHistory >/dev/null
$DEL_VAL "$NTUSER" 'Software\Microsoft\GameBar' AllowAutoGameMode >/dev/null
$DEL_VAL "$NTUSER" 'System\GameConfigStore' GameDVR_Enabled >/dev/null
$DEL_VAL "$SOFTWARE" 'Microsoft\Windows\CurrentVersion\RunOnce' FuraxWindows12FirstLogon >/dev/null
$DEL_VAL "$SOFTWARE" 'Policies\Microsoft\Windows Defender Security Center\Notifications' DisableNotifications >/dev/null
# WSearch/SysMain : contrairement aux clés ci-dessus (absentes par défaut -> supprimées),
# Start=2 existe déjà en stock -> le rollback RESTAURE 2, ne supprime pas la valeur.
$SET "$SYSTEM" "${ACTIVE_CS}\\Services\\WSearch" Start dword 2 --create-keys >/dev/null
$SET "$SYSTEM" "${ACTIVE_CS}\\Services\\SysMain" Start dword 2 --create-keys >/dev/null
$DEL_VAL "$NTUSER" 'Software\Microsoft\Windows\CurrentVersion\Run' FuraxWindows12Taskbar >/dev/null

echo "Vérification post-rollback :"
check "RegisteredOwner de nouveau absent" $(! hivexget "$SOFTWARE" '\Microsoft\Windows NT\CurrentVersion' RegisteredOwner >/dev/null 2>&1; echo $?)
check "RegisteredOrganization de nouveau absent" $(! hivexget "$SOFTWARE" '\Microsoft\Windows NT\CurrentVersion' RegisteredOrganization >/dev/null 2>&1; echo $?)
check "OEMInformation entièrement supprimé" $(! hivexget "$SOFTWARE" '\Microsoft\Windows\CurrentVersion\OEMInformation' Manufacturer >/dev/null 2>&1; echo $?)
check "AppsUseLightTheme de nouveau absent" $(! hivexget "$NTUSER" '\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' AppsUseLightTheme >/dev/null 2>&1; echo $?)
check "ColorPrevalence de nouveau absent" $(! hivexget "$NTUSER" '\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' ColorPrevalence >/dev/null 2>&1; echo $?)
check "AutoColorization de nouveau absent" $(! hivexget "$NTUSER" '\Control Panel\Desktop' AutoColorization >/dev/null 2>&1; echo $?)
check "AllowTelemetry de nouveau absent" $(! hivexget "$SOFTWARE" '\Policies\Microsoft\Windows\DataCollection' AllowTelemetry >/dev/null 2>&1; echo $?)
check "TurnOffWindowsCopilot de nouveau absent" $(! hivexget "$SOFTWARE" '\Policies\Microsoft\Windows\WindowsCopilot' TurnOffWindowsCopilot >/dev/null 2>&1; echo $?)
check "DeferFeatureUpdatesPeriodInDays de nouveau absent" $(! hivexget "$SOFTWARE" '\Policies\Microsoft\Windows\WindowsUpdate' DeferFeatureUpdatesPeriodInDays >/dev/null 2>&1; echo $?)
check "SubscribedContent-338388Enabled de nouveau absent" $(! hivexget "$NTUSER" '\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' SubscribedContent-338388Enabled >/dev/null 2>&1; echo $?)
check "EnableClipboardHistory de nouveau absent" $(! hivexget "$NTUSER" '\Software\Microsoft\Clipboard' EnableClipboardHistory >/dev/null 2>&1; echo $?)
check "AllowAutoGameMode de nouveau absent" $(! hivexget "$NTUSER" '\Software\Microsoft\GameBar' AllowAutoGameMode >/dev/null 2>&1; echo $?)
check "GameDVR_Enabled de nouveau absent" $(! hivexget "$NTUSER" '\System\GameConfigStore' GameDVR_Enabled >/dev/null 2>&1; echo $?)
check "FuraxWindows12FirstLogon de nouveau absent" $(! hivexget "$SOFTWARE" '\Microsoft\Windows\CurrentVersion\RunOnce' FuraxWindows12FirstLogon >/dev/null 2>&1; echo $?)
check "DisableNotifications (Defender) de nouveau absent" $(! hivexget "$SOFTWARE" '\Policies\Microsoft\Windows Defender Security Center\Notifications' DisableNotifications >/dev/null 2>&1; echo $?)
check "WSearch Start restauré à 2 (pas supprimé)" $([[ "$(hivexget "$SYSTEM" "\\${ACTIVE_CS}\\Services\\WSearch" Start)" == "2" ]]; echo $?)
check "SysMain Start restauré à 2 (pas supprimé)" $([[ "$(hivexget "$SYSTEM" "\\${ACTIVE_CS}\\Services\\SysMain" Start)" == "2" ]]; echo $?)
check "FuraxWindows12Taskbar (Run) de nouveau absent" $(! hivexget "$NTUSER" '\Software\Microsoft\Windows\CurrentVersion\Run' FuraxWindows12Taskbar >/dev/null 2>&1; echo $?)

echo ""
echo "=== Résultat : $PASS PASS / $FAIL FAIL ==="
if [[ "$FAIL" -eq 0 ]]; then
  echo "Rollback offline validé : la logique d'annulation (registre) est correcte."
  exit 0
else
  echo "ÉCHEC : au moins une vérification de rollback a échoué — NE PAS considérer le rollback comme fiable."
  exit 1
fi
