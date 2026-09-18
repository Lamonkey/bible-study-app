#!/bin/bash
# Checks, inside the Tart VM, that summoning 好查经 with its hotkey OVERLAYS a full-screen
# app instead of switching away from its Space. Never touches the host's GUI.
#
#   make app && scripts/vmtest/fullscreen_overlay_test.sh [prefix]
#
# MANUAL TOOL: nothing runs this automatically, and it boots the Tart VM (slow on 8 GB).
#
# The hotkey is "pressed" with `kill -USR1`, because posting key events over SSH would need
# Accessibility permission, and `open`/URL schemes make LaunchServices activate the app,
# which by itself switches Spaces and would hide the bug. The shipped app has NO such
# signal hook; to use this script, temporarily add this to AppDelegate and call it from
# applicationDidFinishLaunching (do not commit it):
#
#     private var debugTrigger: DispatchSourceSignal?
#     private func installDebugTrigger() {
#         signal(SIGUSR1, SIG_IGN) // the default action would terminate the process
#         let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
#         source.setEventHandler { [weak self] in self?.toggleSearch() }
#         source.resume()
#         debugTrigger = source
#     }
#
# Screenshots land in dist/<prefix>-{1-fullscreen,2-summoned,3-dismissed}.png
# (prefix defaults to "overlay"). Exit status 0 = overlay works, 1 = it does not.
set -uo pipefail

REPO=$(cd "$(dirname "$0")/../.." && pwd)
HERE=$REPO/scripts/vmtest
OUT=$REPO/dist/vmtest
PREFIX=${1:-overlay}
VMSH=$REPO/scripts/vm.sh
g() { "$VMSH" ssh "$@"; }

# 1. Build the two helpers on the host (the guest has no compiler).
mkdir -p "$OUT/FullscreenHost.app/Contents/MacOS"
swiftc -O -o "$OUT/FullscreenHost.app/Contents/MacOS/FullscreenHost" "$HERE/FullscreenHost.swift" || exit 2
swiftc -O -o "$OUT/winlist" "$HERE/winlist.swift" || exit 2
cp "$HERE/Info.plist" "$OUT/FullscreenHost.app/Contents/Info.plist"
codesign --force --sign - "$OUT/FullscreenHost.app" 2>/dev/null

# 2. Deploy everything and start 好查经.
"$VMSH" start
g "pkill -x FullscreenHost; sleep 1; rm -rf ~/vmtest /tmp/fshost-state.txt; mkdir -p ~/vmtest"
COPYFILE_DISABLE=1 tar -C "$OUT" -cf - FullscreenHost.app winlist | g "tar -C ~/vmtest -xf -"
"$VMSH" run || exit 2

search_on_screen() { g "~/vmtest/winlist" | awk -F'\t' '$2=="好查经" && ($1==0 || $1==3)' | grep -q .; }
front() { g 'lsappinfo info -only name $(lsappinfo front)' | sed 's/.*="\(.*\)"/\1/'; }
trigger() {
    g "pkill -USR1 -x ChaJing"; sleep 1.5
    g "pgrep -x ChaJing >/dev/null" || { echo "好查经 died on SIGUSR1: this build lacks the debug hook (see header)"; exit 2; }
}

# 3. Put the search window away (it shows on launch). Toggle until it is gone.
for _ in 1 2 3; do search_on_screen || break; trigger; done
search_on_screen && { echo "could not hide the search window"; exit 2; }

# 4. A full-screen app to sit in.
g "open ~/vmtest/FullscreenHost.app"
for _ in $(seq 1 30); do
    sleep 1
    [ "$(g 'cat /tmp/fshost-state.txt 2>/dev/null')" = "active=1 key=1 fullscreen=1 onActiveSpace=1" ] && break
done
sleep 1
echo "before : front=$(front)  host: $(g 'cat /tmp/fshost-state.txt')"
"$VMSH" shot "$REPO/dist/$PREFIX-1-fullscreen.png" >/dev/null

# 5. "Press the hotkey".
trigger
S_FRONT=$(front); S_HOST=$(g 'cat /tmp/fshost-state.txt'); search_on_screen && S_SEARCH=1 || S_SEARCH=0
echo "summon : front=$S_FRONT  host: $S_HOST  search-on-screen=$S_SEARCH"
g "~/vmtest/winlist" | grep -v "Control Center" | sed 's/^/           /'
"$VMSH" shot "$REPO/dist/$PREFIX-2-summoned.png" >/dev/null

# 6. "Press it again": the search goes away, the full-screen app has the keyboard back.
trigger
D_FRONT=$(front); D_HOST=$(g 'cat /tmp/fshost-state.txt'); search_on_screen && D_SEARCH=1 || D_SEARCH=0
echo "dismiss: front=$D_FRONT  host: $D_HOST  search-on-screen=$D_SEARCH"
"$VMSH" shot "$REPO/dist/$PREFIX-3-dismissed.png" >/dev/null

g "pkill -x FullscreenHost"

FAIL=0
check() { if [ "$2" = "$3" ]; then echo "ok    $1"; else echo "FAIL  $1 (got '$2', want '$3')"; FAIL=1; fi; }
check "summon : full-screen app is still the frontmost app" "$S_FRONT" "FullscreenHost"
check "summon : its Space is still the active one"          "${S_HOST##* }" "onActiveSpace=1"
check "summon : search window is on that Space"             "$S_SEARCH" "1"
check "dismiss: full-screen app frontmost"                  "$D_FRONT" "FullscreenHost"
check "dismiss: it has the keyboard back, still full screen" "$D_HOST" "active=1 key=1 fullscreen=1 onActiveSpace=1"
check "dismiss: search window gone"                         "$D_SEARCH" "0"
echo "screenshots: dist/$PREFIX-{1-fullscreen,2-summoned,3-dismissed}.png"
exit $FAIL
