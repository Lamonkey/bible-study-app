#!/bin/bash
# Tart macOS VM helper: run and test the app in a guest so its global hotkeys
# (⌥Space, Space+P) never touch the host. Build happens on the host; the VM only runs it.
#
#   scripts/vm.sh setup    clone the image, size the VM, install an SSH key (one-off)
#   scripts/vm.sh start    boot the VM in the background with the repo mounted
#   scripts/vm.sh run      copy dist/好查经.app into the guest and launch it
#   scripts/vm.sh shot [f] screenshot the guest display to dist/vm-shot.png (or to file f)
#   scripts/vm.sh ssh ...  run a command (or open a shell) in the guest
#   scripts/vm.sh stop     shut the VM down
set -euo pipefail

VM=${CHAJING_VM:-chajing-vm}
IMAGE=${CHAJING_VM_IMAGE:-ghcr.io/cirruslabs/macos-tahoe-base:latest}
REPO=$(cd "$(dirname "$0")/.." && pwd)
KEY=$HOME/.ssh/tart_chajing
GUEST_USER=admin
SHARE="/Volumes/My Shared Files/chajing"
BUNDLE="好查经.app"
SSH_OPTS=(-i "$KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)

need_tart() { command -v tart >/dev/null || { echo "tart not installed: brew install openai/tools/tart" >&2; exit 1; }; }
ip() { tart ip "$VM" --wait 120; }
guest() { ssh "${SSH_OPTS[@]}" "$GUEST_USER@$(ip)" "$@"; }

case "${1:-}" in
setup)
    need_tart
    tart list | grep -q "[[:space:]]$VM[[:space:]]" || tart clone "$IMAGE" "$VM"
    tart set "$VM" --cpu 2 --memory 4096          # the floor for a macOS guest; host has 8 GB
    [ -f "$KEY" ] || ssh-keygen -t ed25519 -N "" -C "tart-$VM" -f "$KEY"
    "$0" start
    # Install the key through Tart's guest agent, so no password login is ever needed.
    PUB=$(cat "$KEY.pub")
    tart exec "$VM" /bin/sh -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && grep -qxF '$PUB' ~/.ssh/authorized_keys || echo '$PUB' >> ~/.ssh/authorized_keys"
    guest 'sw_vers -productVersion' && echo "VM $VM ready"
    ;;
start)
    need_tart
    if tart list | grep "[[:space:]]$VM[[:space:]]" | grep -q running; then echo "$VM already running"; exit 0; fi
    nohup tart run "$VM" --no-graphics --dir="chajing:$REPO" >/tmp/tart-$VM.log 2>&1 &
    echo "booting $VM ... $(ip)"
    ;;
run)
    [ -d "$REPO/dist/$BUNDLE" ] || { echo "build first: make app" >&2; exit 1; }
    # Stream the bundle over SSH. The virtiofs share serves stale (empty) directories
    # after the host deletes and recreates dist/*.app, so it is not used for this.
    guest "pkill -x ChaJing; rm -rf ~/'$BUNDLE'"
    COPYFILE_DISABLE=1 tar -C "$REPO/dist" -cf - "$BUNDLE" | guest "tar -C ~ -xf -"
    guest "codesign -v ~/'$BUNDLE' && open ~/'$BUNDLE' && sleep 3 && pgrep -fl MacOS/ChaJing"
    ;;
shot)
    OUT=${2:-$REPO/dist/vm-shot.png}
    guest "screencapture -x /tmp/vm-shot.png" && scp "${SSH_OPTS[@]}" "$GUEST_USER@$(ip):/tmp/vm-shot.png" "$OUT" && echo "$OUT"
    ;;
ssh)
    shift; guest "$@"
    ;;
stop)
    need_tart; tart stop "$VM"
    ;;
*)
    sed -n '2,11p' "$0"; exit 1
    ;;
esac
