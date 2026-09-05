# REMOTE_VIEWER.md — Voir la VM depuis ton téléphone

## Le lien

**https://furax-windows12-vm-viewer-furaxdev.vercel.app**

C'est une page statique (HTML/JS, aucun serveur backend) déployée sur Vercel, qui utilise **noVNC** (bibliothèque open source officielle, chargée depuis le CDN jsdelivr : `@novnc/novnc@1.4.0`) pour afficher un écran VNC dans le navigateur — y compris sur mobile.

## Ce que cette page fait, et ne fait PAS

- Elle affiche l'écran d'une VM QEMU qui tourne sur **TA machine** (ou cet environnement de dev, mais vu les limites déjà documentées sans KVM, préfère ta machine). **Rien ne tourne sur Vercel** — Vercel héberge juste la page web statique, pas la VM.
- Elle **ne stocke, ne relaie et ne voit** aucune donnée : ta machine et ton téléphone se connectent directement l'un à l'autre (via le tunnel que tu choisis) une fois que le navigateur a chargé la page.
- Elle supporte aussi les clics/le clavier (c'est natif à noVNC) — donc en pratique tu peux aussi *interagir* avec la VM depuis ton téléphone, pas juste la regarder.

## Comment l'utiliser, étape par étape

### 1. Lancer la VM avec le port VNC/WebSocket exposé

```bash
./vm/test-vm.sh --iso FuraxWindows12-Beta-x64.iso --vnc-websocket 5959
```

Ça démarre QEMU sans fenêtre graphique locale, avec l'écran exposé en WebSocket sur `127.0.0.1:5959` (accessible uniquement depuis ta machine à ce stade).

### 2. Exposer ce port sur Internet (temporairement)

Avec [ngrok](https://ngrok.com) (gratuit, un compte suffit) :

```bash
ngrok http 5959
```

Ngrok affiche une URL du style `https://xxxx.ngrok-free.app`. Le viewer a besoin d'une URL **WebSocket** (`wss://`), pas HTTP — remplace juste `https://` par `wss://` :

```
wss://xxxx.ngrok-free.app
```

(Alternative sans compte : `cloudflared tunnel --url http://localhost:5959`, syntaxe équivalente.)

### 3. Ouvrir le viewer sur ton téléphone

Ouvre **https://furax-windows12-vm-viewer-furaxdev.vercel.app**, colle l'URL `wss://...` de l'étape 2 dans le champ en haut, clique "Connecter".

Astuce : tu peux aussi mettre l'URL directement dans le lien pour l'ouvrir déjà pré-rempli :
```
https://furax-windows12-vm-viewer-furaxdev.vercel.app/?ws=wss://xxxx.ngrok-free.app
```

## Sécurité — à savoir avant d'exposer quoi que ce soit

- Le tunnel ngrok expose l'écran (et le contrôle clavier/souris) de ta VM **à quiconque devine ou obtient l'URL** pendant qu'il est actif. Ce n'est pas un problème grave pour une VM de test jetable, mais :
  - ferme le tunnel (`Ctrl+C` sur ngrok) dès que t'as fini de regarder ;
  - ne fais jamais ça avec une VM contenant des données sensibles ou un vrai poste de travail ;
  - ngrok gratuit change d'URL à chaque lancement, donc l'exposition n'est jamais permanente par accident.
- QEMU n'a **pas de mot de passe VNC** configuré ici par défaut (`-vnc :0,websocket=...` sans `password=on`) — volontairement simple pour un test ponctuel. Si tu veux un mot de passe, ajoute `password=on` à la commande QEMU et configure-le via le moniteur QEMU (`change vnc password`) — pas géré par ce viewer minimal, à faire toi-même si besoin.

## Statut

`IMPLEMENTED` pour la page (déployée, testée en HTTP 200, charge bien noVNC). `UNTESTED` pour la connexion de bout en bout à une vraie VM Windows en train de démarrer — n'a pas pu être vérifié dans cet environnement de développement (pas de tunnel sortant configuré ici, et le boot QEMU lui-même n'est pas fiable sans KVM, voir `docs/TROUBLESHOOTING.md`). À toi de confirmer lors de ton test réel.
