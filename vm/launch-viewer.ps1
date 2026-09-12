#Requires -Version 5.1
<#
.SYNOPSIS
    Furax Windows 12 Beta — Lanceur VM one-click
.DESCRIPTION
    Lance la VM QEMU avec VNC WebSocket, démarre ngrok, puis ouvre
    automatiquement le viewer Vercel pré-rempli sur ton téléphone.
    Prérequis : QEMU et ngrok installés (voir README ci-dessous).
.PARAMETER Iso
    Chemin vers FuraxWindows12-Beta-x64.iso (ou tout autre ISO Windows).
    Si omis, cherche automatiquement dans le dossier courant.
.PARAMETER Ram
    RAM allouée à la VM en mégaoctets. Défaut : auto-détection (~50% de la RAM
    disponible, borné entre 1024 et 4096 Mo) — passe une valeur explicite pour forcer.
.PARAMETER Cores
    Nombre de cœurs CPU. Défaut : 2.
.PARAMETER VncPort
    Port WebSocket VNC local. Défaut : 5959.
.PARAMETER NgrokPort
    Port ngrok (doit correspondre à VncPort). Défaut : 5959.
.PARAMETER OpenBrowser
    Ouvre automatiquement le viewer dans le navigateur. Défaut : $true.
.EXAMPLE
    .\launch-viewer.ps1
    .\launch-viewer.ps1 -Iso "C:\ISOs\FuraxWindows12-Beta-x64.iso" -Ram 8192
#>
[CmdletBinding()]
param(
    [string]$Iso = "",
    [int]$Ram = 0,   # 0 = auto-détection (voir plus bas)
    [int]$Cores = 2,
    [int]$VncPort = 5959,
    [int]$NgrokPort = 5959,
    [bool]$OpenBrowser = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VIEWER_BASE = "https://furax-windows12-vm-viewer-furaxdev.vercel.app"
$NGROK_API   = "http://localhost:4040/api/tunnels"
$OVMF_PATHS  = @(
    "C:\Program Files\QEMU\share\edk2-x86_64-code.fd",
    "C:\Program Files\QEMU\share\OVMF.fd",
    "$env:APPDATA\qemu\edk2-x86_64-code.fd"
)

# ─── Couleurs ───────────────────────────────────────────────────────────────
function Write-Step  { param($msg) Write-Host "  ► $msg" -ForegroundColor Cyan }
function Write-Ok    { param($msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "  ✗ $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "  Furax Windows 12 Beta — VM Viewer Launcher" -ForegroundColor Magenta
Write-Host "  ════════════════════════════════════════════" -ForegroundColor DarkGray
Write-Host ""

# ─── Vérification QEMU ──────────────────────────────────────────────────────
Write-Step "Recherche de QEMU..."
$qemu = Get-Command "qemu-system-x86_64" -ErrorAction SilentlyContinue
if (-not $qemu) {
    Write-Fail "QEMU introuvable dans le PATH."
    Write-Host ""
    Write-Host "  Pour installer QEMU :" -ForegroundColor Yellow
    Write-Host "    https://www.qemu.org/download/#windows" -ForegroundColor Cyan
    Write-Host "    (télécharge le .exe, installe, puis relance ce script)" -ForegroundColor DarkGray
    Write-Host ""
    Read-Host "  Appuie sur Entrée pour quitter"
    exit 1
}
Write-Ok "QEMU trouvé : $($qemu.Source)"

# ─── Vérification ngrok ─────────────────────────────────────────────────────
Write-Step "Recherche de ngrok..."
$ngrokCmd = Get-Command "ngrok" -ErrorAction SilentlyContinue
if (-not $ngrokCmd) {
    Write-Fail "ngrok introuvable dans le PATH."
    Write-Host ""
    Write-Host "  Pour installer ngrok :" -ForegroundColor Yellow
    Write-Host "    https://ngrok.com/download  →  télécharge, extrais ngrok.exe dans C:\Windows ou là où tu veux" -ForegroundColor Cyan
    Write-Host "    Crée un compte gratuit sur ngrok.com puis lance : ngrok authtoken <ton-token>" -ForegroundColor DarkGray
    Write-Host ""
    Read-Host "  Appuie sur Entrée pour quitter"
    exit 1
}
Write-Ok "ngrok trouvé : $($ngrokCmd.Source)"

# ─── Auto-détection RAM (si -Ram non fourni) ────────────────────────────────
# Alloue ~50% de la RAM DISPONIBLE (pas totale) à la VM, borné entre 1024 et 4096 Mo.
# Le but : ne jamais affamer le reste du système hôte pendant que la VM tourne — c'est
# exactement ce qui a fait planter la VM la première fois (RAM hôte insuffisante).
if ($Ram -le 0) {
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $availMB = [int]($os.FreePhysicalMemory / 1024)
        $Ram = [Math]::Floor($availMB / 2 / 256) * 256
        if ($Ram -lt 1024) { $Ram = 1024 }
        if ($Ram -gt 4096) { $Ram = 4096 }
        Write-Ok "RAM auto-détectée : ${Ram} Mo alloués (sur ${availMB} Mo disponibles)"
    } catch {
        $Ram = 2048
        Write-Warn "Détection RAM impossible, valeur par défaut prudente : ${Ram} Mo"
    }
}

# ─── Recherche de l'ISO ─────────────────────────────────────────────────────
Write-Step "Recherche de l'ISO..."
if (-not $Iso) {
    $found = Get-ChildItem -Path "." -Filter "*.iso" -ErrorAction SilentlyContinue |
             Sort-Object -Property { if ($_.Name -match "FuraxWindows12") { 0 } else { 1 } } |
             Select-Object -First 1
    if ($found) {
        $Iso = $found.FullName
        Write-Ok "ISO trouvée automatiquement : $($found.Name)"
    } else {
        Write-Fail "Aucun fichier .iso trouvé dans le dossier courant."
        Write-Host ""
        Write-Host "  Lance le script avec : .\launch-viewer.ps1 -Iso 'C:\chemin\vers\FuraxWindows12-Beta-x64.iso'" -ForegroundColor Yellow
        Write-Host ""
        Read-Host "  Appuie sur Entrée pour quitter"
        exit 1
    }
} elseif (-not (Test-Path $Iso)) {
    Write-Fail "ISO introuvable : $Iso"
    exit 1
} else {
    Write-Ok "ISO : $(Split-Path $Iso -Leaf)"
}

# ─── Firmware UEFI (OVMF) ───────────────────────────────────────────────────
Write-Step "Recherche du firmware UEFI (OVMF)..."
$ovmf = $null
foreach ($p in $OVMF_PATHS) {
    if (Test-Path $p) { $ovmf = $p; break }
}
$qemuArgs = @("-m", "$Ram", "-smp", "$Cores")
if ($ovmf) {
    Write-Ok "OVMF : $ovmf"
    $qemuArgs += @("-drive", "if=pflash,format=raw,readonly=on,file=$ovmf")
} else {
    Write-Warn "OVMF introuvable → démarrage en mode BIOS legacy (moins compatible avec Win11)"
}
$qemuArgs += @(
    "-drive", "file=$Iso,media=cdrom,readonly=on",
    "-display", "none",
    "-vga", "virtio",
    "-vnc", ":0,websocket=$VncPort",
    "-monitor", "none"
)

# ─── Démarrage QEMU ─────────────────────────────────────────────────────────
Write-Step "Démarrage de la VM QEMU (RAM: ${Ram}MB, CPU: $Cores cœurs, VNC ws: $VncPort)..."
try {
    $qemuProc = Start-Process -FilePath "qemu-system-x86_64" `
                              -ArgumentList $qemuArgs `
                              -PassThru -WindowStyle Hidden
    Write-Ok "VM démarrée (PID $($qemuProc.Id))"
} catch {
    Write-Fail "Échec du démarrage QEMU : $_"
    exit 1
}

Start-Sleep -Seconds 2

# ─── Démarrage ngrok ────────────────────────────────────────────────────────
Write-Step "Démarrage du tunnel ngrok sur le port $NgrokPort..."
try {
    $ngrokProc = Start-Process -FilePath "ngrok" `
                               -ArgumentList @("http", "$NgrokPort") `
                               -PassThru -WindowStyle Hidden
    Write-Ok "ngrok démarré (PID $($ngrokProc.Id))"
} catch {
    Write-Fail "Échec du démarrage ngrok : $_"
    $qemuProc | Stop-Process -Force -ErrorAction SilentlyContinue
    exit 1
}

# ─── Attente de l'URL ngrok ─────────────────────────────────────────────────
Write-Step "Attente de l'URL ngrok..."
$tunnelUrl = $null
$attempts = 0
$maxAttempts = 20
while (-not $tunnelUrl -and $attempts -lt $maxAttempts) {
    Start-Sleep -Seconds 1
    $attempts++
    try {
        $resp = Invoke-RestMethod -Uri $NGROK_API -ErrorAction SilentlyContinue
        $pub = $resp.tunnels | Where-Object { $_.proto -eq "https" } | Select-Object -First 1
        if ($pub) {
            $wsUrl = $pub.public_url -replace "^https://", "wss://"
            $tunnelUrl = $wsUrl
        }
    } catch { }
    if (-not $tunnelUrl) {
        Write-Host "    attente... ($attempts/$maxAttempts)" -ForegroundColor DarkGray
    }
}

if (-not $tunnelUrl) {
    Write-Warn "Impossible de récupérer l'URL ngrok automatiquement."
    Write-Host ""
    Write-Host "  Ouvre http://localhost:4040 dans ton navigateur pour voir l'URL ngrok." -ForegroundColor Yellow
    Write-Host "  Remplace 'https://' par 'wss://' et colle-la dans le viewer :" -ForegroundColor Yellow
    Write-Host "  $VIEWER_BASE" -ForegroundColor Cyan
} else {
    Write-Ok "URL tunnel : $tunnelUrl"
    $viewerUrl = "$VIEWER_BASE/?ws=$([uri]::EscapeDataString($tunnelUrl))"
    Write-Host ""
    Write-Host "  ┌──────────────────────────────────────────────────────────┐" -ForegroundColor Magenta
    Write-Host "  │  Ouvre ce lien sur ton téléphone :                       │" -ForegroundColor Magenta
    Write-Host "  │                                                          │" -ForegroundColor Magenta
    Write-Host "  │  $VIEWER_BASE" -ForegroundColor Cyan
    Write-Host "  │  (déjà pré-rempli — lien copié dans le presse-papier)    │" -ForegroundColor Magenta
    Write-Host "  └──────────────────────────────────────────────────────────┘" -ForegroundColor Magenta
    Write-Host ""
    # Copie dans le presse-papier
    try { Set-Clipboard -Value $viewerUrl } catch { }
    if ($OpenBrowser) {
        Start-Process $viewerUrl
    }
}

# ─── Instructions d'arrêt ───────────────────────────────────────────────────
Write-Host ""
Write-Host "  La VM tourne en arrière-plan. Pour tout arrêter :" -ForegroundColor DarkGray
Write-Host "  → Ferme cette fenêtre  (QEMU PID $($qemuProc.Id), ngrok PID $($ngrokProc.Id))" -ForegroundColor DarkGray
Write-Host "  → Ou appuie sur Entrée ici" -ForegroundColor DarkGray
Write-Host ""

Read-Host "  [Entrée pour arrêter VM + tunnel]"

Write-Step "Arrêt de la VM et du tunnel..."
$qemuProc | Stop-Process -Force -ErrorAction SilentlyContinue
$ngrokProc | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Ok "Terminé. À plus, FuraxDev !"
