#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
# Build the PurpleMonkey FM-1 emulator: build/host/pm_emu (macOS: clang, SDL2 from Homebrew, CoreMIDI, zlib;
# Linux: cc, SDL2 from sdl2-config, zlib, no MIDI ports: tools/emu/linux, set up by tools/linux/setup.sh).
#   sh tools/emu/build_pm.sh            (from anywhere)
# tools/emu/build.sh with PurpleMonkey's firmware side (pm_emu_fw.c through pm_firmware.h) in place of
# ChoralRoot's; the emulator itself (emu.c, keymap.c, emu_img.c, emu_midi.c) is the same. The generated headers
# (build/gen) are made by tools/gen.sh when one is missing or older than its generator.
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"
sh tools/gen.sh
if [ "$(uname -s)" = Darwin ]; then
    SDL_CFLAGS=$(/opt/homebrew/bin/sdl2-config --cflags 2>/dev/null || echo "-I/opt/homebrew/include/SDL2 -D_THREAD_SAFE")
    SDL_LIBS=$(/opt/homebrew/bin/sdl2-config --libs 2>/dev/null || echo "-L/opt/homebrew/lib -lSDL2")
    CC=${CC:-clang}
    COMPAT=
    MIDI=tools/emu/emu_midi.c
    LIBS="-framework CoreMIDI -framework CoreFoundation"
else
    # Linux (tools/linux/setup.sh): SDL2 from sdl2-config, a pthread mutex for the CPU lock, no host MIDI ports
    command -v sdl2-config >/dev/null 2>&1 || { echo "build_pm.sh: no sdl2-config (sh tools/linux/setup.sh)"; exit 1; }
    SDL_CFLAGS=$(sdl2-config --cflags)
    SDL_LIBS=$(sdl2-config --libs)
    CC=${CC:-cc}
    COMPAT=-Itools/emu/linux/compat
    MIDI=tools/emu/linux/emu_midi_none.c
    LIBS=-lpthread
fi
OUT=build/host
OBJ=build/host/pm_emu_obj
mkdir -p "$OUT" "$OBJ" build/emu
# the firmware: one unit (warnings off: Felucca's own code; PurpleMonkey's files are checked by tests/run_pm_tests.sh)
$CC -O2 -w $COMPAT -Ibuild/gen -Ifirmware/src -Itools/emu -c tools/emu/pm_emu_fw.c -o "$OBJ/pm_emu_fw.o"
for f in emu keymap emu_img; do
    $CC -O2 -Wall -Wextra -Wno-unused-parameter $SDL_CFLAGS -c "tools/emu/$f.c" -o "$OBJ/$f.o"
done
$CC -O2 -Wall -Wno-deprecated-declarations -c "$MIDI" -o "$OBJ/emu_midi.o" $SDL_CFLAGS
$CC -o "$OUT/pm_emu" "$OBJ/emu.o" "$OBJ/keymap.o" "$OBJ/emu_img.o" "$OBJ/emu_midi.o" "$OBJ/pm_emu_fw.o" \
    $SDL_LIBS -lz -lm $LIBS
echo "built $OUT/pm_emu"
