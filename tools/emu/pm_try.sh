#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
# Try a change on the emulator without a window: one script in, what it drew and what it played out.
#   sh tools/emu/pm_try.sh SCRIPT [NAME]        (NAME: the script's name without .txt when not given)
#   -> build/emu/try/NAME.log   the run: expectations, dumps, timing
#      build/emu/try/NAME.wav   the audio; its numbers are printed (tools/emu/pm_wav.py)
#      build/emu/try/NAME.png   the script's screenshots in order and the LCD at the end, one labelled sheet
# The script grammar: tools/emu/README.md; an example: tools/emu/scripts/pm_slice.txt. The emulator is rebuilt
# when a source is newer, as tools/emu/test_pm.sh does. Exit status: the emulator's (1: an expect failed,
# 2: a script error).
set -u
[ $# -ge 1 ] || { sed -n '3,10p' "$0"; exit 2; }
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
case "$1" in /*) SCRIPT=$1 ;; *) SCRIPT=$PWD/$1 ;; esac
[ -f "$SCRIPT" ] || { echo "pm_try: no script $1"; exit 2; }
NAME=${2:-$(basename "$SCRIPT" .txt)}
cd "$ROOT"
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
EMU=build/host/pm_emu
OUT=build/emu/try
if [ ! -x "$EMU" ] || [ -n "$(find tools firmware/src tests/hostsim.c -newer "$EMU" \( -name '*.[ch]' -o -name 'gen_*.py' \) 2>/dev/null | head -1)" ]; then
    sh tools/emu/build_pm.sh >/dev/null || { echo "pm_try: the build failed (sh tools/emu/build_pm.sh)"; exit 2; }
fi
mkdir -p "$OUT"
"$EMU" --headless --script "$SCRIPT" --wav "$OUT/$NAME.wav" --shot "$OUT/$NAME.end.ppm" >"$OUT/$NAME.log" 2>&1
st=$?
grep -E '^expect .*FAILED|^script|^expect: ' "$OUT/$NAME.log"
grep -E '^headless: [0-9]|^  pm: ' "$OUT/$NAME.log" | tail -4
[ -s "$OUT/$NAME.wav" ] && echo "audio: $(python3 tools/emu/pm_wav.py "$OUT/$NAME.wav")"
shots=$(sed -n 's/^screenshot: \(.*\)$/\1/p' "$OUT/$NAME.log" | sed 's/\.png$/.ppm/' | awk '!seen[$0]++')
# shellcheck disable=SC2086
[ -n "$shots" ] && python3 tools/pm_contact.py "$OUT/$NAME.png" $shots
echo "pm_try: exit $st; $OUT/$NAME.log, $NAME.wav, $NAME.png"
exit $st
