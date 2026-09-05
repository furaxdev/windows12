#!/usr/bin/env bash
# Furax Windows 12 Beta — Lanceur VM one-click (Linux / Zsh / Bash)
# Usage : ./launch-viewer.sh [--iso <chemin>] [--ram 4096] [--cores 2] [--vnc-port 5959]

set -euo pipefail

VIEWER_BASE="https://furax-windows12-vm-viewer-furaxdev.vercel.app"
NGROK_API="http://localhost:4040/api/tunnels"
RAM=4096
CORES=2
VNC_PORT=5959
ISO=""
OPEN_BROWSER=true

# ─── Couleurs ────────────────────────────────────────────────────────────────
C_RESET='\033[0m'; C_CYAN='\033[0;36m'; C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'; C_RED='\033[0;31m'; C_MAGENTA='\033[0;35m'; C_GRAY='\033[0;90m'

step()  { echo -e "  ${C_CYAN}►${C_RESET} $*"; }
ok()    { echo -e "  ${C_GREEN}✓${C_RESET} $*"; }
warn()  { echo -e "  ${C_YELLOW}⚠${C_RESET} $*"; }
fail()  { echo -e "  ${C_RED}✗${C_RESET} $*"; }

# ─── Args ────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso)        ISO="$2";       shift 2 ;;
    --ram)        RAM="$2";       shift 2 ;;
    --cores)      CORES="$2";     shift 2 ;;
    --vnc-port)   VNC_PORT="$2";  shift 2 ;;
    --no-browser) OPEN_BROWSER=false; shift ;;
    *) echo "Option inconnue : $1" >&2; exit 1 ;;
  esac
done

QEMU_PIDS=()
cleanup() {
  echo ""
  step "Arrêt de la VM et du tunnel..."
  for pid in "${QEMU_PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
  ok "Terminé. À plus, FuraxDev !"
}
trap cleanup EXIT INT TERM

echo ""
echo -e "  ${C_MAGENTA}Furax Windows 12 Beta — VM Viewer Launcher${C_RESET}"
echo -e "  ${C_GRAY}════════════════════════════════════════════${C_RESET}"
echo ""

# ─── QEMU ────────────────────────────────────────────────────────────────────
step "Recherche de QEMU..."
if ! command -v qemu-system-x86_64 &>/dev/null; then
  fail "QEMU introuvable."
  echo -e "\n  ${C_YELLOW}Installe-le :${C_RESET}"
  echo "    sudo apt install qemu-system-x86 qemu-utils ovmf"
  exit 1
fi
ok "QEMU : $(command -v qemu-system-x86_64)"

# ─── ngrok ───────────────────────────────────────────────────────────────────
step "Recherche de ngrok..."
if ! command -v ngrok &>/dev/null; then
  fail "ngrok introuvable."
  echo -e "\n  ${C_YELLOW}Installe-le :${C_RESET}"
  echo "    curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc"
  echo "    echo 'deb https://ngrok-agent.s3.amazonaws.com buster main' | sudo tee /etc/apt/sources.list.d/ngrok.list"
  echo "    sudo apt update && sudo apt install ngrok"
  echo "    ngrok authtoken <ton-token>  (compte gratuit sur ngrok.com)"
  exit 1
fi
ok "ngrok : $(command -v ngrok)"

# ─── ISO ─────────────────────────────────────────────────────────────────────
step "Recherche de l'ISO..."
if [[ -z "$ISO" ]]; then
  ISO=$(ls FuraxWindows12-Beta-x64.iso *.iso 2>/dev/null | head -1 || true)
  if [[ -z "$ISO" ]]; then
    fail "Aucun .iso trouvé dans le dossier courant."
    echo -e "\n  Lance : ${C_CYAN}./launch-viewer.sh --iso /chemin/vers/FuraxWindows12-Beta-x64.iso${C_RESET}"
    exit 1
  fi
  ok "ISO trouvée automatiquement : $ISO"
elif [[ ! -f "$ISO" ]]; then
  fail "ISO introuvable : $ISO"
  exit 1
else
  ok "ISO : $(basename "$ISO")"
fi

# ─── Firmware UEFI (OVMF) ────────────────────────────────────────────────────
step "Recherche du firmware UEFI (OVMF)..."
OVMF=""
for p in /usr/share/OVMF/OVMF_CODE.fd \
          /usr/share/ovmf/OVMF.fd \
          /usr/share/edk2/ovmf/OVMF_CODE.fd; do
  if [[ -f "$p" ]]; then OVMF="$p"; break; fi
done

QEMU_ARGS=(-m "$RAM" -smp "$CORES")
if [[ -n "$OVMF" ]]; then
  ok "OVMF : $OVMF"
  QEMU_ARGS+=(-drive "if=pflash,format=raw,readonly=on,file=$OVMF")
else
  warn "OVMF introuvable → BIOS legacy (installe : sudo apt install ovmf)"
fi
QEMU_ARGS+=(
  -drive "file=$ISO,media=cdrom,readonly=on"
  -display none
  -vga virtio
  -vnc ":0,websocket=$VNC_PORT"
)

# ─── Démarrage QEMU ──────────────────────────────────────────────────────────
step "Démarrage de la VM QEMU (RAM: ${RAM}MB, CPU: $CORES, VNC ws: $VNC_PORT)..."
qemu-system-x86_64 "${QEMU_ARGS[@]}" &
QEMU_PIDS+=($!)
ok "VM démarrée (PID ${QEMU_PIDS[-1]})"

sleep 2

# ─── Démarrage ngrok ─────────────────────────────────────────────────────────
step "Démarrage du tunnel ngrok sur le port $VNC_PORT..."
ngrok http "$VNC_PORT" --log=stdout > /tmp/furax-ngrok.log 2>&1 &
QEMU_PIDS+=($!)
ok "ngrok démarré (PID ${QEMU_PIDS[-1]})"

# ─── Attente URL ngrok ───────────────────────────────────────────────────────
step "Attente de l'URL ngrok..."
TUNNEL_URL=""
for i in $(seq 1 20); do
  sleep 1
  TUNNEL_URL=$(curl -s "$NGROK_API" 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); t=[x for x in d.get('tunnels',[]) if x.get('proto')=='https']; print(t[0]['public_url'] if t else '')" 2>/dev/null || true)
  if [[ -n "$TUNNEL_URL" ]]; then break; fi
  echo -e "    ${C_GRAY}attente... ($i/20)${C_RESET}"
done

WS_URL="${TUNNEL_URL/https:\/\//wss:\/\/}"

if [[ -z "$WS_URL" ]]; then
  warn "Impossible de récupérer l'URL ngrok automatiquement."
  echo -e "\n  Ouvre ${C_CYAN}http://localhost:4040${C_RESET} pour voir l'URL ngrok."
  echo -e "  Remplace 'https://' par 'wss://' et colle dans : ${C_CYAN}$VIEWER_BASE${C_RESET}"
else
  ok "URL tunnel : $WS_URL"
  VIEWER_URL="$VIEWER_BASE/?ws=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$WS_URL")"
  echo ""
  echo -e "  ${C_MAGENTA}┌──────────────────────────────────────────────────────────┐${C_RESET}"
  echo -e "  ${C_MAGENTA}│  Ouvre ce lien sur ton téléphone :                       │${C_RESET}"
  echo -e "  ${C_MAGENTA}│                                                          │${C_RESET}"
  echo -e "  ${C_CYAN}  $VIEWER_BASE${C_RESET}"
  echo -e "  ${C_MAGENTA}│  (lien complet copié dans le presse-papier si xclip dispo)│${C_RESET}"
  echo -e "  ${C_MAGENTA}└──────────────────────────────────────────────────────────┘${C_RESET}"
  echo ""
  # Copie presse-papier (xclip ou xsel ou wl-copy selon dispo)
  if command -v xclip &>/dev/null; then
    echo -n "$VIEWER_URL" | xclip -selection clipboard 2>/dev/null || true
  elif command -v wl-copy &>/dev/null; then
    echo -n "$VIEWER_URL" | wl-copy 2>/dev/null || true
  elif command -v xsel &>/dev/null; then
    echo -n "$VIEWER_URL" | xsel --clipboard --input 2>/dev/null || true
  fi
  if [[ "$OPEN_BROWSER" == true ]]; then
    xdg-open "$VIEWER_URL" 2>/dev/null || true
  fi
fi

echo ""
echo -e "  ${C_GRAY}La VM tourne en arrière-plan. Ctrl+C ou Entrée pour tout arrêter.${C_RESET}"
echo ""
read -r _
