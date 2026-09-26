#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Réapplique les personnalisations Furax Windows 12 Beta (registre uniquement).
    Conçu pour tourner en tâche planifiée (voir 50-reapply-task.sh), pas lancé à la main.

.DESCRIPTION
    Windows Update peut réinitialiser certaines clés de registre (policies, valeurs
    utilisateur) lors d'une mise à jour de fonctionnalités ou de qualité. Ce script
    réapplique, de façon strictement IDEMPOTENTE, les mêmes valeurs que celles écrites
    hors ligne au build par les modules 42/45/46/47 — mais via les cmdlets PowerShell
    natifs (Set-ItemProperty), puisqu'ici on tourne DANS un Windows démarré, pas sur une
    ruche démontée. Chaque bloc a son propre try/catch : un échec n'empêche jamais les
    autres de s'exécuter, et n'empêche jamais l'ouverture de session.

    ⚠️ Honnêteté : cette logique est un miroir volontaire de ce que les modules du builder
    écrivent hors ligne (mêmes clés, mêmes valeurs, testées offline via
    builder/tools/test_rollback_offline.sh). Mais CE script lui-même — son déclenchement
    réel par la tâche planifiée après une mise à jour Windows, et son effet réel sur un
    Windows redémarré — n'a PAS pu être vérifié dans cet environnement de développement
    (pas de boot Windows possible ici). Voir docs/FEATURES.md et docs/TESTING.md.

    Ne touche PAS au fond d'écran lui-même (fichier image) : si une mise à jour de
    fonctionnalités remplace des fichiers système, le fond d'écran custom devrait déjà
    être réintégré par le nouveau média d'installation Furax, pas par ce script — ce
    script ne réapplique que des VALEURS DE REGISTRE.
#>

param(
    [switch]$WhatIfPreview
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Skip($msg) { Write-Host "    (échec, ignoré) $msg" -ForegroundColor DarkYellow }

# Set-RegValue : équivalent de hivex_set_value.py --create-keys, mais en live.
function Set-RegValue {
    param($Path, $Name, $Value, $Type = "DWord")
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
        Write-Ok "$Path\$Name = $Value"
    } catch {
        Write-Skip "$Path\$Name ($($_.Exception.Message))"
    }
}

# --- 1. Branding "By FuraxDev" (module 42) ---
Write-Step "Branding"
Set-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "RegisteredOwner" -Value "Furax" -Type String
Set-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "RegisteredOrganization" -Value "By FuraxDev" -Type String
Set-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "Manufacturer" -Value "FuraxDev" -Type String
Set-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "Model" -Value "Furax Windows 12 Beta" -Type String
Set-RegValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "SupportURL" -Value "https://github.com/furaxdev/windows12" -Type String

# --- 2. Fond d'écran : réglages (pas le fichier lui-même, voir note en tête) ---
Write-Step "Réglages fond d'écran (profil courant)"
Set-RegValue -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value "10" -Type String
Set-RegValue -Path "HKCU:\Control Panel\Desktop" -Name "TileWallpaper" -Value "0" -Type String
Set-RegValue -Path "HKCU:\Control Panel\Desktop" -Name "AutoColorization" -Value 1

# --- 3. Thème (module 46) ---
Write-Step "Thème"
$personalizeKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
Set-RegValue -Path $personalizeKey -Name "AppsUseLightTheme" -Value 0
Set-RegValue -Path $personalizeKey -Name "SystemUsesLightTheme" -Value 0
Set-RegValue -Path $personalizeKey -Name "EnableTransparency" -Value 1
Set-RegValue -Path $personalizeKey -Name "ColorPrevalence" -Value 1
Set-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 1

# --- 4. Confidentialité / performance (module 47) ---
Write-Step "Confidentialité / performance"
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 1
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "DeferFeatureUpdatesPeriodInDays" -Value 7
Set-RegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" -Name "DisableNotifications" -Value 1
Set-RegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Value 0
Set-RegValue -Path "HKCU:\Software\Microsoft\Clipboard" -Name "EnableClipboardHistory" -Value 1
Set-RegValue -Path "HKCU:\Software\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 1
Set-RegValue -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0

# WSearch/SysMain : CurrentControlSet fonctionne ici car on tourne dans un Windows
# démarré (résolu par le noyau) — contrairement à la ruche SYSTEM hors ligne, voir
# builder/modules/47-privacy-performance.sh pour le détail de ce piège.
Set-RegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WSearch" -Name "Start" -Value 4
Set-RegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SysMain" -Name "Start" -Value 4

Write-Host ""
Write-Host "Réapplication terminée. Une déconnexion/reconnexion peut être nécessaire pour" -ForegroundColor Yellow
Write-Host "que l'explorateur reflète immédiatement les réglages HKCU ci-dessus." -ForegroundColor Yellow
