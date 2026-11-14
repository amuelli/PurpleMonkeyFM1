#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
# What a Linux host (Debian / Ubuntu) needs for the host side (BUILDING.md, "Host side, on Linux"): the generated
# headers, the tests and the headless emulator. No device toolchain, no Emscripten.
#   sh tools/linux/setup.sh         (as root, or with sudo on the PATH)
# Every step is skipped when what it installs is already there:
#   apt   zlib1g-dev (the emulator's PNGs), libfribidi0 (Pillow's Raqm layout loads it: without it the fonts are
#         not generated), python3-pip
#   pip   Pillow and fontTools at the versions of .github/workflows/release.yml, numpy (tools/gen_pm_speech.py),
#         into /usr/local (--break-system-packages: none of them is an apt package here)
#   SDL2  built from source into /usr/local with no video or audio backend but the dummy ones: all the headless
#         emulator uses (distributions' libsdl2-dev brings some 180 packages of X11, Wayland and audio headers).
#         A host that already has sdl2-config keeps its own.
# With --emscripten it also installs the Emscripten SDK (the version pages.yml uses) into ~/emsdk, about 1.7 GB, for
# the browser emulator (tools/emu/web/serve_pm.sh); without the flag an existing ~/emsdk is only reported.
set -e
EMSDK_VERSION=6.0.11
WANT_EMSDK=
[ "${1:-}" = "--emscripten" ] && WANT_EMSDK=1
PILLOW_VERSION=11.1.0
FONTTOOLS_VERSION=4.66.1
SDL_VERSION=2.32.10
SDL_SHA256=5f5993c530f084535c65a6879e9b26ad441169b3e25d789d83287040a9ca5165

if [ "$(id -u)" = 0 ]; then SUDO=; else SUDO=sudo; fi
say() { echo "setup: $*"; }

need=""
[ -f /usr/include/zlib.h ] || need="$need zlib1g-dev"
ldconfig -p | grep -q 'libfribidi\.so\.0' || need="$need libfribidi0"
python3 -m pip --version >/dev/null 2>&1 || need="$need python3-pip"
for c in cc make curl; do
    command -v $c >/dev/null 2>&1 || need="$need build-essential curl"
done
if [ -n "$need" ]; then
    say "apt:$need"
    $SUDO apt-get update -q
    # shellcheck disable=SC2086
    $SUDO apt-get install -y -q --no-install-recommends $need
else
    say "apt: nothing to install"
fi

if python3 - <<PY 2>/dev/null
import sys, PIL, fontTools, numpy
from PIL import features
sys.exit(0 if PIL.__version__ == "$PILLOW_VERSION" and fontTools.version == "$FONTTOOLS_VERSION" and features.check("raqm") else 1)
PY
then
    say "python: Pillow $PILLOW_VERSION with Raqm, fontTools $FONTTOOLS_VERSION and numpy are there"
else
    say "pip: Pillow $PILLOW_VERSION, fontTools $FONTTOOLS_VERSION, numpy"
    $SUDO python3 -m pip install --disable-pip-version-check --break-system-packages \
        "Pillow==$PILLOW_VERSION" "fonttools==$FONTTOOLS_VERSION" numpy
    python3 -c 'from PIL import features; import sys; sys.exit(0 if features.check("raqm") else "Pillow has no Raqm layout (libfribidi missing?)")'
fi

if command -v sdl2-config >/dev/null 2>&1; then
    say "SDL2 $(sdl2-config --version) is there ($(command -v sdl2-config))"
else
    say "SDL2 $SDL_VERSION from source into /usr/local (dummy video and audio only; a few minutes)"
    T=$(mktemp -d)
    trap 'rm -rf "$T"' EXIT
    curl -fsSL -o "$T/sdl.tar.gz" \
        "https://github.com/libsdl-org/SDL/releases/download/release-$SDL_VERSION/SDL2-$SDL_VERSION.tar.gz"
    echo "$SDL_SHA256  $T/sdl.tar.gz" | sha256sum -c - >/dev/null || { echo "setup: the SDL2 archive's sha256 differs"; exit 1; }
    tar -xzf "$T/sdl.tar.gz" -C "$T"
    mkdir "$T/build"
    (cd "$T/build" && "../SDL2-$SDL_VERSION/configure" --prefix=/usr/local --disable-shared --enable-static \
        --disable-video-x11 --disable-video-wayland --disable-video-kmsdrm --disable-video-opengl \
        --disable-video-opengles --disable-video-vulkan --disable-alsa --disable-pulseaudio --disable-pipewire \
        --disable-jack --disable-sndio --disable-esd --disable-oss --disable-dbus --disable-ibus --disable-fcitx \
        --disable-libudev --disable-joystick --disable-haptic --disable-sensor --disable-hidapi \
        --disable-libsamplerate --disable-libdecor >configure.log 2>&1 \
        && make -j"$(nproc)" >make.log 2>&1) || { echo "setup: SDL2 did not build (see $T/build/*.log)"; trap - EXIT; exit 1; }
    (cd "$T/build" && $SUDO make install >/dev/null)
    say "SDL2 $(sdl2-config --version) installed"
fi
if [ -n "$WANT_EMSDK" ]; then
    if [ -x "$HOME/emsdk/upstream/emscripten/emcc" ] && "$HOME/emsdk/upstream/emscripten/emcc" --version | head -1 | grep -q " $EMSDK_VERSION "; then
        say "Emscripten $EMSDK_VERSION is there ($HOME/emsdk)"
    else
        command -v git >/dev/null 2>&1 || { $SUDO apt-get install -y -q --no-install-recommends git ca-certificates; }
        say "Emscripten $EMSDK_VERSION into $HOME/emsdk (about 1.7 GB; a few minutes)"
        [ -d "$HOME/emsdk" ] || git clone --quiet https://github.com/emscripten-core/emsdk.git "$HOME/emsdk"
        (cd "$HOME/emsdk" && ./emsdk install "$EMSDK_VERSION" && ./emsdk activate "$EMSDK_VERSION") \
            >"${TMPDIR:-/tmp}/emsdk-setup.log" 2>&1 \
            || { echo "setup: Emscripten did not install (see ${TMPDIR:-/tmp}/emsdk-setup.log)"; exit 1; }
        say "Emscripten installed"
    fi
elif [ -x "$HOME/emsdk/upstream/emscripten/emcc" ]; then
    say "Emscripten is at $HOME/emsdk (sh tools/emu/web/serve_pm.sh)"
else
    say "no Emscripten (only the browser emulator needs it: sh tools/linux/setup.sh --emscripten)"
fi
say "done: sh tests/run_pm_tests.sh"
