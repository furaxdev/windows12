═══════════════════════════════════════════════════════════
  OpenConnect (osh) — shell distant HTTPS, sans ngrok ni SSH
═══════════════════════════════════════════════════════════

PRINCIPE :
  Ton PC et le client se connectent tous les deux à Supabase
  en HTTPS sortant. Zéro port ouvert, zéro tunnel, zéro ngrok.

  osh (n'importe où) ──POST──▶ Supabase ◀──POLL── serveur (ton PC)
                     ◀──POLL──          ──UPDATE──▶

DÉMARRAGE (sur ton PC, une seule fois) :
─────────────────────────────────────────
  python3 tools/openconnect/server.py --secret TONSECRETCHOISI

  C'est tout. Pas de ngrok, pas d'autre terminal.

UTILISATION (depuis n'importe où) :
────────────────────────────────────
  # One-shot
  osh --ip=monpc@furax "ls -la ~"
  osh --ip=monpc@furax --password=TONSECRETCHOISI "uname -a"

  # Shell interactif
  osh --ip=monpc@furax

  L'hôte ("monpc") est juste un label visuel — le routage
  passe par Supabase, pas par l'IP.

SÉCURITÉ :
──────────
  ✓ Le secret est hashé (SHA-256) avant d'être stocké dans
    Supabase — la valeur brute ne quitte jamais ton terminal.
  ✓ Le serveur vérifie le hash avant d'exécuter quoi que ce soit.
  ✓ Chaque commande est supprimée de Supabase après exécution.
  ⚠ Choisis un secret long (20+ caractères).
  ⚠ La clé anon Supabase est publique dans ce repo — elle
    permet seulement d'insérer/lire dans osh_queue, pas de
    modifier le schéma ni d'accéder à d'autres tables.

RELAY :
  Supabase project : furax-osh
  URL : https://vohddkxqdeivqcoogtzd.supabase.co
═══════════════════════════════════════════════════════════
