═══════════════════════════════════════════════════════════
  Furax Windows 12 Beta — Lanceur VM one-click (Windows PC)
═══════════════════════════════════════════════════════════

PRÉREQUIS (à faire une seule fois) :

  1. QEMU pour Windows
     https://www.qemu.org/download/#windows
     → télécharge le .exe, installe, laisse cocher "Add to PATH"

  2. ngrok (gratuit)
     https://ngrok.com/download
     → extrais ngrok.exe n'importe où dans ton PATH (ex: C:\Windows)
     → crée un compte gratuit sur ngrok.com
     → lance une fois : ngrok authtoken <ton-token>

  3. Mets FuraxWindows12-Beta-x64.iso dans le même dossier que
     launch-viewer.ps1 (ou passe le chemin en paramètre).

UTILISATION :

  Double-clique sur launch-viewer.ps1
  (ou clic droit → "Exécuter avec PowerShell")

  Si Windows bloque le script :
    → clic droit sur le fichier → Propriétés → Décocher "Bloquer"
    Ou lance depuis PowerShell :
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

PARAMÈTRES OPTIONNELS :

  .\launch-viewer.ps1 -Iso "C:\ISOs\FuraxWindows12-Beta-x64.iso"
  .\launch-viewer.ps1 -Ram 8192 -Cores 4
  .\launch-viewer.ps1 -OpenBrowser $false   (ne pas ouvrir le navigateur auto)

CE QUE ÇA FAIT AUTOMATIQUEMENT :

  ✓ Démarre la VM QEMU (ISO + VNC WebSocket)
  ✓ Démarre le tunnel ngrok
  ✓ Récupère l'URL publique ngrok
  ✓ Ouvre le viewer Vercel pré-rempli dans ton navigateur
  ✓ Copie le lien dans ton presse-papier (pour l'envoyer sur ton tel)
  ✓ Tout arrête proprement quand tu appuies sur Entrée

Viewer web : https://furax-windows12-vm-viewer-furaxdev.vercel.app
═══════════════════════════════════════════════════════════
