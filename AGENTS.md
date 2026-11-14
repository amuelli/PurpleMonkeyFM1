# Working on this repository (for coding agents)

This is a fork of [Quixotic7/PurpleMonkeyFM1](https://github.com/Quixotic7/PurpleMonkeyFM1), a toddler firmware for
the M-VAVE FM-1 synthesizer. The fork exists to customise it for one child, aged about two and a half. There is
no FM-1 on the desk yet, so everything is checked on the computer: the same firmware sources run in a headless
emulator, with a scripted keyboard, screenshots and a WAV of the audio.

## The loop

```
sh tools/linux/setup.sh                      # once per machine (Debian / Ubuntu); idempotent
sh tests/run_pm_tests.sh                     # unit tests, then the emulator's acceptance scripts (~10 s)
sh tools/emu/pm_try.sh SCRIPT.txt            # run one input script: log, WAV and a sheet of screenshots
```

`pm_try.sh` rebuilds the emulator when a source is newer, runs the script headless in simulated time (so the same
script gives the same LCD and the same audio, bit for bit) and writes `build/emu/try/NAME.{log,wav,png}`. Look at
the PNG (it is a contact sheet of every `shot` in the script plus the final screen) and read the numbers it
prints. The script grammar is in `tools/emu/README.md`; `tools/emu/scripts/pm_slice.txt` is a worked example:

```
wait 1800                  # let the pet say its name
btn C4 down                # press a key (computer key S)
wait 200
expect sound               # fails the run (exit 1) if nothing sounded
shot build/emu/try/note.ppm
btn C4 up
dump                       # prints the engine's state: mode, pet, voices, drum hits ...
```

Typical change: edit `firmware/src/pm_*.c` (or a generator under `tools/gen_pm_*.py`), write a small script that
exercises it, run `pm_try.sh`, look at the screenshots, then run `tests/run_pm_tests.sh`. Add a check to
`tests/pm_engine_test.c` for musical rules (no hardware needed, it is plain C with sanitizers) or a script plus
`expect` lines to `tools/emu/test_pm.sh` for what the screen and LEDs do.

`sh tools/gen.sh` regenerates `build/gen/*.h` (fonts, FM6 patches, drum kits, sprites, rigs) when a generator or
the art changes; the emulator build does it itself.

## Where things are

| Path | What |
| --- | --- |
| `firmware/src/pm_engine.c/.h` | the musical rules: keys, notes, scale, beat, phrase. Plain C, no hardware: the place for most changes |
| `firmware/src/pm_ui.c` | input, LEDs, the scene and its tile renderer; `pm_rig.c` the pets' animation |
| `firmware/src/pm_sound.c`, `tools/gen_pm_patches.py` | the FM6 sounds (SOUND knob), four a pet |
| `firmware/src/pm_out.c`, `pm_drum_synth.c` | the engine in the audio interrupt; the drums |
| `firmware/src/pm_speech.c`, `tools/gen_pm_speech.py` | the voice (letters, the pets' names) |
| `assets/purplemonkey/`, `tools/gen_pm_sprites.py`, `tools/gen_pm_rig.py` | the art and what cuts it into headers |
| `docs/PURPLEMONKEY.md` | design, architecture, what was verified, budgets. Read it before a larger change |
| everything else under `firmware/` | upstream's platform (boot, flash driver, USB, FM6, FX, update loader). Leave it alone |

## Rules

- **Never flash a device, tag, publish a release or push to `main` without the owner saying so.** Install and
  rollback are in `docs/PURPLEMONKEY.md` ("Install, rollback") and `docs/INSTALL-COMPAT.md`. You may push a feature
  branch and open a pull request on your own — that is how a change normally gets in — but the merge to `main`
  still waits on the owner.
- **Do not touch** the boot guard, the flash driver, the update loader, USB or the installers
  (`firmware/hal`, `firmware/loader`, `firmware/src/{main,ota*,usb*,cr_bootguard.h}`, `tools/fm1_install.py`,
  `web/fm1ota.js`) unless the task is about them. A mistake there is what bricks a unit; the emulator cannot show it.
- **The emulator is not the device.** A passing run says the logic, the screen and the audio levels are right on
  a computer. It says nothing about how a sound is to the ear, how a two-year-old finds it, LCD speed or the
  battery. Say so when a change depends on one of those. The three "device estimate" CPU checks need macOS's
  instruction counter and are skipped on Linux (`skip` lines): the audio-cost figures in `docs/PURPLEMONKEY.md` are
  macOS's; do not quote them for a Linux run.
- **Stay inside the budgets** (`docs/PURPLEMONKEY.md`, "Budgets"): RAM, POOL and flash limits are enforced by
  `./build.sh`, which needs the JieLi toolchain and runs in CI (`.github/workflows/release.yml`), not here. A change
  that adds sprites, speech or tables should say what it costs in flash and POOL (the sizes of the generated headers
  are a first estimate; CI's build is the check).
- **A child's toy:** no menus, nothing to save, nothing that can be broken by pressing keys. Sounds stay bounded
  and never loud. `tests/run_pm_tests.sh` holds the line on that (no sample at full scale, silence after hands
  off, no stuck notes, no lost events): keep it green, and extend it when a change adds a new way to sound.
- **Licences:** GPL-3.0-only; `LICENSING.md` lists the upstream parts. The artwork's licence is an open question
  upstream: do not add art or sounds of unknown origin.
- Match the surrounding style and comment density; the firmware is C99/C11, one compilation unit
  (`purplemonkey.c`).
- `build/` is ignored; the `.fwsc` files too.

## Linux notes

`tools/emu/build_pm.sh` builds for Linux with `tools/emu/linux/` (a pthread mutex for macOS's `os_unfair_lock`, no
host MIDI ports; the firmware's MIDI in is still tested through `PM_EMU_MIDI=1`). There is no window or sound
card in a headless session: `--front`, live audio and a CoreMIDI port are macOS-only. To hear a change, take
`build/emu/try/NAME.wav` to a machine with speakers, or build the browser emulator
(`tools/emu/web/build_pm_web.sh`, needs Emscripten) or use the GitHub Pages site a release publishes.
