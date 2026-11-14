#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 PurpleMonkey FM-1 contributors
# PurpleMonkey's German voice: Piper TTS (the Thorsten German voice) says the 33 words, then
# tools/gen_pm_speech.py analyses them into the LPC frames pm_speech.c plays back at 8 kHz.
#
#   sh tools/gen_pm_speech_de.sh
#
# Downloads Piper (rhasspy/piper, MIT) and the German voice de_DE-thorsten-high (a Piper model trained on
# the CC0 Thorsten-Voice dataset) into build/, says the words -- the German letters' names A..Z, then Juhu,
# Affe, Katze, Hund, Lama, Hallo, Tschuess -- as 16-bit WAVs, and writes firmware/src/pm_speech_data.h.
# A word already spoken is not spoken again; delete build/speech_src/piper-de/ to start over. The voice's
# duration is random, so a short name (E, G) is said again, slower, until it clears the 200 ms the speech
# test wants. Then listen to build/host/pm_speech.wav (sh tests/run_pm_tests.sh) or a word on the emulator
# (sh tools/emu/pm_try.sh tools/emu/scripts/pm_talk_de.txt).
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

PIPER_VER=2023.11.14-2
PIPER_URL="https://github.com/rhasspy/piper/releases/download/$PIPER_VER/piper_linux_x86_64.tar.gz"
VOICE_BASE="https://huggingface.co/rhasspy/piper-voices/resolve/main/de/de_DE/thorsten/high"
PIPER=build/piper/piper/piper
VOICE=build/piper/de_DE-thorsten-high.onnx

trimmed_ms() { # the spoken part of a WAV in ms (the silence around it removed, as gen_pm_speech.py trims)
    python3 - "$1" <<'PY'
import sys, wave
import numpy as np
w = wave.open(sys.argv[1])
x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32768.0
if w.getnchannels() > 1:
    x = x.reshape(-1, w.getnchannels()).mean(axis=1)
env = np.sqrt(np.convolve(x * x, np.ones(80) / 80, "same"))
on = np.nonzero(env > env.max() * 0.02)[0]
print(int((on[-1] - on[0]) * 1000 / w.getframerate()))
PY
}

say() { # say FILE TEXT [LENGTH_SCALE]: TEXT as one word into FILE, slowed until it is long enough
    f=$1; t=$2; scale=${3:-1.0}; tries=0
    [ -f "$f" ] && return
    while :; do
        printf '%s' "$t" | LD_LIBRARY_PATH=build/piper/piper "$PIPER" -m "$VOICE" --length_scale "$scale" -f "$f" >/dev/null 2>&1
        [ "$(trimmed_ms "$f")" -ge 220 ] && break
        tries=$((tries + 1))
        [ "$tries" -ge 6 ] && break
        scale=$(python3 -c "print(round($scale * 1.3, 2))")
    done
}

if [ ! -x "$PIPER" ]; then
    echo "gen_pm_speech_de: downloading Piper $PIPER_VER ..."
    mkdir -p build/piper
    curl -fL --retry 3 -o build/piper/piper.tar.gz "$PIPER_URL"
    tar xzf build/piper/piper.tar.gz -C build/piper
    rm -f build/piper/piper.tar.gz
fi
if [ ! -f "$VOICE" ]; then
    echo "gen_pm_speech_de: downloading the German voice (de_DE-thorsten-high) ..."
    curl -fL --retry 3 -o "$VOICE" "$VOICE_BASE/de_DE-thorsten-high.onnx"
fi
if [ ! -f "$VOICE.json" ]; then
    curl -fL --retry 3 -o "$VOICE.json" "$VOICE_BASE/de_DE-thorsten-high.onnx.json"
fi

OUT=build/speech_src/piper-de
mkdir -p "$OUT"
# the letters' names, A..Z (slowed more than the words: their names are one syllable)
for c in A B C D E F G H I J K L M N O P Q R S T U V W X Y Z; do
    say "$OUT/$(printf '%s' "$c" | tr 'A-Z' 'a-z').wav" "$c" 1.5
done
# the words, in the order gen_pm_speech.py's WORDS has them after YAY
for pair in yay:Juhu monkey:Affe cat:Katze dog:Hund llama:Lama hello:Hallo bye:Tschüss; do
    say "$OUT/${pair%%:*}.wav" "${pair#*:}" 1.3
done

exec python3 tools/gen_pm_speech.py firmware/src/pm_speech_data.h --src "$OUT"
