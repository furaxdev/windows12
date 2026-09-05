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

Write-Host ""
Write-Host "Rollback terminé. Un redémarrage ou une déconnexion/reconnexion peut être nécessaire" -ForegroundColor Yellow
Write-Host "pour que l'explorateur/le bureau reflètent immédiatement tous les changements." -ForegroundColor Yellow
