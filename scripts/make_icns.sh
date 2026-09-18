#!/bin/bash
# Flat artwork -> macOS .icns (and optionally an Xcode AppIcon.appiconset).
# Needs only what ships with Xcode / Command Line Tools: swiftc, sips, iconutil.
#
#   make_icns.sh <source-image> <output.icns> [--appiconset DIR] [--png PATH]
#                [--tolerance N] [--erode N] [--full-bleed] [--no-shadow]
#
#   --appiconset DIR   also write DIR (e.g. Assets.xcassets/AppIcon.appiconset) with Contents.json
#   --png PATH         keep the processed 1024px PNG (for looking at the result)
#   remaining flags    are passed to make_icon.swift (see the header of that file)
set -euo pipefail

[ $# -ge 2 ] || { sed -n '2,10p' "$0"; exit 1; }
SRC=$1; OUT=$2; shift 2
APPICONSET=""; KEEP_PNG=""; PASS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --appiconset) APPICONSET=$2; shift 2 ;;
        --png) KEEP_PNG=$2; shift 2 ;;
        --tolerance|--erode) PASS+=("$1" "$2"); shift 2 ;;
        *) PASS+=("$1"); shift ;;
    esac
done

HERE=$(cd "$(dirname "$0")" && pwd)
CACHE=${TMPDIR:-/tmp}/macos-app-icon
mkdir -p "$CACHE"
BIN=$CACHE/make_icon
if [ ! -x "$BIN" ] || [ "$HERE/make_icon.swift" -nt "$BIN" ]; then
    swiftc -O "$HERE/make_icon.swift" -o "$BIN"
fi

WORK=$(mktemp -d "$CACHE/work.XXXXXX"); trap 'rm -rf "$WORK"' EXIT
"$BIN" "$SRC" "$WORK/icon-1024.png" ${PASS[@]+"${PASS[@]}"}

SET=$WORK/AppIcon.iconset; mkdir -p "$SET"
for s in 16 32 128 256 512; do
    sips -z $s $s "$WORK/icon-1024.png" --out "$SET/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z $d $d "$WORK/icon-1024.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
mkdir -p "$(dirname "$OUT")"
iconutil -c icns "$SET" -o "$OUT"
echo "wrote $OUT"

if [ -n "$KEEP_PNG" ]; then cp "$WORK/icon-1024.png" "$KEEP_PNG"; echo "wrote $KEEP_PNG"; fi

if [ -n "$APPICONSET" ]; then
    mkdir -p "$APPICONSET"
    cp "$SET"/*.png "$APPICONSET/"
    {
        echo '{ "images" : ['
        first=1
        for s in 16 32 128 256 512; do for scale in 1 2; do
            [ $scale = 1 ] && f="icon_${s}x${s}.png" || f="icon_${s}x${s}@2x.png"
            [ $first = 1 ] && first=0 || echo ','
            printf '  { "idiom" : "mac", "size" : "%sx%s", "scale" : "%sx", "filename" : "%s" }' $s $s $scale "$f"
        done; done
        echo; echo '], "info" : { "author" : "xcode", "version" : 1 } }'
    } > "$APPICONSET/Contents.json"
    echo "wrote $APPICONSET"
fi
