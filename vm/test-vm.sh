#!/usr/bin/env bash
# vm/test-vm.sh — démarre une ISO Windows (générée par builder/build.sh, ou une ISO stock)
# dans une VM QEMU/KVM avec firmware UEFI (OVMF), pour test manuel ou smoke-test de boot.
#
# ⚠️ Ce script ne détruit JAMAIS un disque existant sans confirmation explicite.
#
# Usage:
#   ./vm/test-vm.sh --iso <chemin.iso> [--disk <chemin.qcow2>] [--disk-size 64G]
#                    [--ram 4096] [--cpus 2] [--boot-only-check [--timeout 120]]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_STATE_DIR="$SCRIPT_DIR/_state"
mkdir -p "$VM_STATE_DIR"

ISO_PATH=""
DISK_PATH="$VM_STATE_DIR/furax-test.qcow2"
DISK_SIZE="64G"
RAM_MB=4096
CPUS=2
BOOT_ONLY_CHECK=0
TIMEOUT=120

usage() {
  cat <<EOF
vm/test-vm.sh — VM de test QEMU/KVM (UEFI/OVMF) pour Furax Windows 12 Beta

Usage: $0 --iso <chemin.iso> [options]

Options:
  --iso <chemin>         ISO à démarrer (obligatoire)
  --disk <chemin>        Disque virtuel qcow2 (défaut : $DISK_PATH)
  --disk-size <taille>   Taille du disque si créé (défaut : $DISK_SIZE)
  --ram <Mo>             RAM allouée à la VM (défaut : $RAM_MB)
  --cpus <n>             vCPUs (défaut : $CPUS)
  --boot-only-check      Ne pas ouvrir de fenêtre graphique interactive : démarre en mode
                          "-display none -serial stdio", surveille la sortie série pendant
                          --timeout secondes puis arrête la VM. C'est un test STRUCTUREL
                          (l'ISO amorce-t-elle sans erreur immédiate), PAS une validation
                          complète d'installation Windows.
  --timeout <secondes>   Durée du test en mode --boot-only-check (défaut : $TIMEOUT)
  -h, --help             Affiche cette aide

⚠️ Ce script ne supprime ni ne réinitialise JAMAIS un disque existant sans confirmation
   explicite tapée au clavier.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso) ISO_PATH="$2"; shift 2 ;;
    --disk) DISK_PATH="$2"; shift 2 ;;
    --disk-size) DISK_SIZE="$2"; shift 2 ;;
    --ram) RAM_MB="$2"; shift 2 ;;
    --cpus) CPUS="$2"; shift 2 ;;
    --boot-only-check) BOOT_ONLY_CHECK=1; shift ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$ISO_PATH" || ! -f "$ISO_PATH" ]]; then
  echo "Erreur : --iso <chemin.iso> obligatoire et doit exister." >&2
  usage
  exit 2
fi

# --- Vérification des outils ---
for tool in qemu-system-x86_64 qemu-img; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Erreur : outil requis manquant : $tool" >&2
    exit 1
  fi
done

# --- Firmware UEFI (OVMF) — Windows 11/12 exige UEFI ---
OVMF_CODE=""
for candidate in /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd /usr/share/ovmf/OVMF.fd; do
  [[ -f "$candidate" ]] && OVMF_CODE="$candidate" && break
done
if [[ -z "$OVMF_CODE" ]]; then
  echo "Erreur : firmware OVMF introuvable (paquet 'ovmf' non installé ?)." >&2
  exit 1
fi
OVMF_VARS_TEMPLATE="/usr/share/OVMF/OVMF_VARS_4M.fd"
[[ -f "$OVMF_VARS_TEMPLATE" ]] || OVMF_VARS_TEMPLATE="/usr/share/OVMF/OVMF_VARS.fd"
OVMF_VARS_INSTANCE="$VM_STATE_DIR/OVMF_VARS.fd"
if [[ ! -f "$OVMF_VARS_INSTANCE" ]]; then
  cp "$OVMF_VARS_TEMPLATE" "$OVMF_VARS_INSTANCE"
  echo "Copie des variables UEFI créée : $OVMF_VARS_INSTANCE"
fi

# --- Disque virtuel : ne JAMAIS écraser un disque existant sans confirmation ---
if [[ -f "$DISK_PATH" ]]; then
  echo "Un disque virtuel existe déjà : $DISK_PATH"
  read -r -p "Le réutiliser tel quel (o) ou le recréer VIDE en écrasant son contenu (r) ? [o/r] : " choice
  case "$choice" in
    r|R)
      read -r -p "Confirme : taper exactement 'EFFACER' pour recréer $DISK_PATH : " confirm
      if [[ "$confirm" != "EFFACER" ]]; then
        echo "Annulé — le disque existant est conservé tel quel."
      else
        qemu-img create -f qcow2 "$DISK_PATH" "$DISK_SIZE"
        echo "Disque recréé : $DISK_PATH ($DISK_SIZE)"
      fi
      ;;
    *) echo "Disque existant conservé." ;;
  esac
else
  qemu-img create -f qcow2 "$DISK_PATH" "$DISK_SIZE"
  echo "Nouveau disque créé : $DISK_PATH ($DISK_SIZE)"
fi

# --- Accélération : KVM si disponible, sinon TCG logiciel (lent mais fonctionnel) ---
ACCEL="tcg"
if [[ -e /dev/kvm ]] && (kvm-ok >/dev/null 2>&1 || [[ -r /dev/kvm && -w /dev/kvm ]]); then
  if kvm-ok >/dev/null 2>&1; then
    ACCEL="kvm"
  fi
fi
echo "Accélération : $ACCEL $([[ "$ACCEL" == "tcg" ]] && echo '(pas de KVM disponible dans cet environnement — le boot sera lent)')"

QEMU_ARGS=(
  -machine "type=q35,accel=$ACCEL"
  -cpu "$([[ "$ACCEL" == "kvm" ]] && echo host || echo max)"
  -smp "$CPUS"
  -m "$RAM_MB"
  -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
  -drive "if=pflash,format=raw,file=$OVMF_VARS_INSTANCE"
  -drive "file=$DISK_PATH,if=virtio,format=qcow2"
  -drive "file=$ISO_PATH,media=cdrom"
  -boot "order=d,menu=on"
  -netdev "user,id=net0"
  -device "virtio-net-pci,netdev=net0"
)

if [[ "$BOOT_ONLY_CHECK" -eq 1 ]]; then
  echo "Mode --boot-only-check : démarrage sans affichage graphique, surveillance ${TIMEOUT}s de la sortie série."
  echo "⚠️ Ceci vérifie uniquement que la VM démarre sans erreur immédiate (firmware/CDROM lus)."
  echo "   Ce n'est PAS une validation d'installation Windows complète ni un smoke-test de shell."
  SERIAL_LOG="$VM_STATE_DIR/boot-check-$(date +%Y%m%d-%H%M%S).log"
  timeout "$TIMEOUT" qemu-system-x86_64 "${QEMU_ARGS[@]}" -display none -serial "file:$SERIAL_LOG" -monitor none \
    || echo "(fin du test après ${TIMEOUT}s ou arrêt de la VM — voir $SERIAL_LOG)"
  echo "Sortie série capturée dans : $SERIAL_LOG"
  exit 0
fi

echo "Démarrage interactif de la VM (fenêtre graphique). Ferme la fenêtre QEMU pour arrêter la VM."
exec qemu-system-x86_64 "${QEMU_ARGS[@]}" -display gtk -vga virtio
