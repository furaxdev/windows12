#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Annule les personnalisations "Furax Windows 12 Beta" (fond d'écran, thème, branding)
    et restaure le comportement Windows 11 par défaut.

.DESCRIPTION
    Ce script s'exécute DANS Windows, après installation, sur le compte que tu utilises.
    Il n'a d'effet que sur ce qui a été explicitement ajouté par le builder Furax :
    - fond d'écran par défaut (restauré depuis la sauvegarde faite au build)
    - clés de thème (sombre/transparence/accent) ajoutées sous ton profil
    - branding "By FuraxDev" (RegisteredOwner/RegisteredOrganization, OEMInformation)
    - réglages confidentialité/performance (télémétrie, Copilot, updates différés,
      suggestions Menu Démarrer, historique presse-papiers, Mode Jeu, Game Bar)

    Il NE désinstalle PAS Windows, NE touche PAS aux fichiers système autres que ceux
    listés ci-dessus, et est conçu pour être relancé plusieurs fois sans risque
    (idempotent : si une clé est déjà absente, rien ne se passe).

.NOTES
    Statut : EXPERIMENTAL / PARTIELLEMENT TESTÉ.
    La logique miroir de ce script a été validée offline (hors ligne, sans démarrer
    Windows) par builder/tools/test_rollback_offline.sh, qui applique exactement les
    mêmes opérations de registre sur une copie de test des ruches SOFTWARE/NTUSER.DAT
    extraites du WIM généré, et vérifie par relecture que tout redevient absent/par
    défaut. Ce script PowerShell lui-même n'a PAS pu être exécuté dans un vrai Windows
    démarré depuis l'environnement de développement de ce projet (pas de VM Windows
    démarrable ici) — à valider par toi lors du premier test réel.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$WhatIfPreview
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Skip($msg) { Write-Host "    (déjà absent) $msg" -ForegroundColor DarkGray }

# --- 1. Fond d'écran : restaurer l'original sauvegardé par le builder ---
Write-Step "Fond d'écran"
$wallpaperDir = "$env:WINDIR\Web\Wallpaper\Windows"
$current      = Join-Path $wallpaperDir "img0.jpg"
$backup       = Join-Path $wallpaperDir "img0.jpg.stock-original"

if (Test-Path $backup) {
    Copy-Item -Path $backup -Destination $current -Force
    Write-Ok "img0.jpg restauré depuis la sauvegarde d'origine (img0.jpg.stock-original)."
} else {
    Write-Skip "Pas de sauvegarde trouvée ($backup) — le fond d'écran n'a probablement pas été modifié par le builder, ou la sauvegarde a déjà été utilisée."
}

# Réinitialise les réglages de fond d'écran du profil courant (pas seulement le profil
# Default utilisé à l'installation — utile si tu as déjà ouvert une session).
$desktopKey = "HKCU:\Control Panel\Desktop"
if (Test-Path $desktopKey) {
    Remove-ItemProperty -Path $desktopKey -Name "WallPaper" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $desktopKey -Name "WallpaperStyle" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $desktopKey -Name "TileWallpaper" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $desktopKey -Name "AutoColorization" -ErrorAction SilentlyContinue
    Write-Ok "Réglages WallPaper/WallpaperStyle/TileWallpaper/AutoColorization réinitialisés pour le profil courant."
}

# --- 2. Thème (sombre/transparence/accent) : supprime nos overrides ---
Write-Step "Thème"
$personalizeKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
if (Test-Path $personalizeKey) {
    foreach ($name in @("AppsUseLightTheme", "SystemUsesLightTheme", "EnableTransparency", "ColorPrevalence")) {
        Remove-ItemProperty -Path $personalizeKey -Name $name -ErrorAction SilentlyContinue
    }
    Write-Ok "Clés de thème supprimées sous Themes\Personalize (Windows retombe sur ses valeurs par défaut)."
} else {
    Write-Skip "Clé Themes\Personalize absente."
}

$advancedKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
if (Test-Path $advancedKey) {
    Remove-ItemProperty -Path $advancedKey -Name "TaskbarAl" -ErrorAction SilentlyContinue
    Write-Ok "TaskbarAl supprimé (revient à l'alignement par défaut du système)."
}

# --- 3. Branding "By FuraxDev" ---
Write-Step "Branding"
$cvKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
if (Test-Path $cvKey) {
    Remove-ItemProperty -Path $cvKey -Name "RegisteredOwner" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $cvKey -Name "RegisteredOrganization" -ErrorAction SilentlyContinue
    Write-Ok "RegisteredOwner/RegisteredOrganization supprimés (winver n'affichera plus de nom personnalisé)."
}

$oemKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation"
if (Test-Path $oemKey) {
    Remove-Item -Path $oemKey -Recurse -Force
    Write-Ok "Clé OEMInformation supprimée entièrement (elle n'existait pas avant nos modifications)."
} else {
    Write-Skip "Clé OEMInformation absente."
}

# --- 4. Confidentialité / performance (télémétrie, Copilot, updates, suggestions, etc.) ---
Write-Step "Confidentialité / performance"

# HKLM : on ne supprime QUE les valeurs qu'on a écrites, pas les clés entières — au
# contraire d'OEMInformation ci-dessus, ces clés de policy (Policies\Microsoft\Windows\...)
# peuvent légitimement contenir d'autres réglages GPO déjà présents avant notre passage.
$dataCollectionKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
if (Test-Path $dataCollectionKey) {
    Remove-ItemProperty -Path $dataCollectionKey -Name "AllowTelemetry" -ErrorAction SilentlyContinue
    Write-Ok "AllowTelemetry supprimé (télémétrie revient au comportement par défaut de l'édition)."
}

$copilotKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
if (Test-Path $copilotKey) {
    Remove-ItemProperty -Path $copilotKey -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue
    Write-Ok "TurnOffWindowsCopilot supprimé (Copilot redevient disponible selon la config Microsoft par défaut)."
}

$wuKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
if (Test-Path $wuKey) {
    Remove-ItemProperty -Path $wuKey -Name "DeferFeatureUpdatesPeriodInDays" -ErrorAction SilentlyContinue
    Write-Ok "DeferFeatureUpdatesPeriodInDays supprimé (updates de fonctionnalités ne sont plus différés)."
}

# HKCU (profil courant) : suggestions Menu Démarrer, presse-papiers, Mode Jeu, Game Bar
$cdmKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
if (Test-Path $cdmKey) {
    Remove-ItemProperty -Path $cdmKey -Name "SubscribedContent-338388Enabled" -ErrorAction SilentlyContinue
    Write-Ok "Suggestions d'apps dans le Menu Démarrer réinitialisées au comportement par défaut."
}

$clipboardKey = "HKCU:\Software\Microsoft\Clipboard"
if (Test-Path $clipboardKey) {
    Remove-ItemProperty -Path $clipboardKey -Name "EnableClipboardHistory" -ErrorAction SilentlyContinue
    Write-Ok "EnableClipboardHistory supprimé (redevient désactivé par défaut)."
}

$gameBarKey = "HKCU:\Software\Microsoft\GameBar"
if (Test-Path $gameBarKey) {
    Remove-ItemProperty -Path $gameBarKey -Name "AllowAutoGameMode" -ErrorAction SilentlyContinue
    Write-Ok "AllowAutoGameMode supprimé."
}

$gameConfigKey = "HKCU:\System\GameConfigStore"
if (Test-Path $gameConfigKey) {
    Remove-ItemProperty -Path $gameConfigKey -Name "GameDVR_Enabled" -ErrorAction SilentlyContinue
    Write-Ok "GameDVR_Enabled supprimé (enregistrement Game Bar en arrière-plan revient au défaut)."
}

# --- 5. Nettoyage du raccourci bureau (auto-suppression, ne se supprime pas lui-même
# en cours d'exécution) ---
Write-Step "Raccourci bureau"
$desktopShortcut = "$env:PUBLIC\Desktop\Rollback Furax Windows 12.bat"
if (Test-Path $desktopShortcut) {
    Remove-Item -Path $desktopShortcut -Force -ErrorAction SilentlyContinue
    Write-Ok "Raccourci bureau supprimé (plus besoin une fois le rollback fait)."
} else {
    Write-Skip "Raccourci bureau déjà absent."
}

# --- 6. Script premier login (RunOnce) : à supprimer seulement s'il n'a pas encore
# tourné — Windows supprime lui-même l'entrée RunOnce une fois exécutée, donc ce bloc
# n'a d'effet que si le rollback est lancé AVANT le tout premier login. ---
Write-Step "Script premier login"
$runOnceKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
if (Test-Path $runOnceKey) {
    Remove-ItemProperty -Path $runOnceKey -Name "FuraxWindows12FirstLogon" -ErrorAction SilentlyContinue
    Write-Ok "Entrée RunOnce supprimée (si elle était encore présente)."
}

Write-Host ""
Write-Host "Rollback terminé. Un redémarrage ou une déconnexion/reconnexion peut être nécessaire" -ForegroundColor Yellow
Write-Host "pour que l'explorateur/le bureau reflètent immédiatement tous les changements." -ForegroundColor Yellow
