═══════════════════════════════════════════════════════════
  OpenConnect — shell distant HTTPS (sans SSH)
═══════════════════════════════════════════════════════════

CONCEPT :
  Au lieu d'SSH (port 22 souvent bloqué), tout passe par HTTPS.
  Le serveur tourne sur ton PC, ngrok expose l'URL publique,
  le client envoie les commandes via requêtes HTTPS authentifiées.

  Ton PC ──(localhost:7800)── ngrok ──(HTTPS)── n'importe où

DÉMARRAGE (sur ton PC) :
─────────────────────────

  Terminal 1 — serveur :
    python3 tools/openconnect/server.py --secret MONSECRETCHOISI

  Terminal 2 — tunnel ngrok :
    ngrok http 7800
    # → note l'URL : https://xxxx.ngrok-free.app

UTILISATION (depuis n'importe où) :
────────────────────────────────────

  ./tools/openconnect/openconnect.sh https://xxxx.ngrok-free.app "COMMANDE"

  Exemples :
    ./openconnect.sh https://xxxx.ngrok-free.app "ls ~/ISOs"
    ./openconnect.sh https://xxxx.ngrok-free.app "./vm/launch-viewer.sh --no-browser"
    ./openconnect.sh https://xxxx.ngrok-free.app "uname -a"

  Le secret est demandé à l'entrée (invisible, jamais affiché).

SÉCURITÉ :
──────────
  ✓ Le secret n'est JAMAIS transmis en clair — seul son SHA-256 est
    comparé côté serveur (comparaison constante, anti timing-attack).
  ✓ Le serveur n'écoute que sur 127.0.0.1 — ngrok est le seul point
    d'entrée public.
  ✓ Chaque requête = timeout 60s max.
  ⚠ L'URL ngrok change à chaque relance (compte gratuit) — ne la
    partage pas, ferme ngrok quand tu as fini.
  ⚠ Choisis un secret long (20+ caractères) — quelqu'un qui a l'URL
    ngrok peut brute-forcer un secret court.

═══════════════════════════════════════════════════════════
