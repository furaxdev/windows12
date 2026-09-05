#!/usr/bin/env bash
# OpenConnect — client (fonctionne depuis n'importe où, même le sandbox)
# Usage : ./openconnect.sh <URL_NGROK> "<commande>"
# Exemple : ./openconnect.sh https://xxxx.ngrok-free.app "ls -la ~"

set -euo pipefail

C_RESET='\033[0m'; C_CYAN='\033[0;36m'; C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'; C_RED='\033[0;31m'; C_GRAY='\033[0;90m'

usage() {
  echo "Usage: $0 <URL_NGROK_OU_IP> \"<commande>\""
  echo "  Ex : $0 https://xxxx.ngrok-free.app \"./vm/launch-viewer.sh\""
  exit 1
}

[[ $# -lt 2 ]] && usage

URL="${1%/}"   # retire le slash final si présent
CMD="$2"

# Demande le secret sans l'afficher
echo -ne "  ${C_CYAN}Secret OpenConnect :${C_RESET} "
read -rs SECRET
echo ""

# Envoi de la commande
echo -e "  ${C_GRAY}► Envoi : ${CMD}${C_RESET}"
RESPONSE=$(curl -s -X POST "$URL/run" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "
import json, hashlib, sys
secret = sys.argv[1]
cmd    = sys.argv[2]
print(json.dumps({'secret': secret, 'cmd': cmd}))
" "$SECRET" "$CMD")" 2>&1)

# Parse la réponse
RC=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('returncode','?'))" "$RESPONSE" 2>/dev/null || echo "?")
STDOUT=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('stdout',''))" "$RESPONSE" 2>/dev/null || echo "")
STDERR=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('stderr',''))" "$RESPONSE" 2>/dev/null || echo "")
ERR=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('error',''))" "$RESPONSE" 2>/dev/null || echo "")

if [[ -n "$ERR" ]]; then
  echo -e "  ${C_RED}✗ Erreur : $ERR${C_RESET}"
  exit 1
fi

[[ -n "$STDOUT" ]] && echo -e "${STDOUT}"
[[ -n "$STDERR" ]] && echo -e "${C_YELLOW}${STDERR}${C_RESET}" >&2

if [[ "$RC" == "0" ]]; then
  echo -e "  ${C_GREEN}✓ Terminé (exit 0)${C_RESET}"
else
  echo -e "  ${C_RED}✗ Exit code : $RC${C_RESET}"
  exit "$RC"
fi
