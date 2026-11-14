/* SPDX-License-Identifier: GPL-3.0-only */
/* emu_midi.c for the Linux build (tools/emu/build_pm.sh): no host MIDI ports (emu_midi.c is CoreMIDI's). The
 * firmware's MIDI in is still tested: PM_EMU_MIDI=1 feeds it from pm_emu_fw.c (tools/emu/test_pm.sh). */
#include "../emu.h"

int emu_midi_open(int log) { (void)log; return 1; }
void emu_midi_close(void) {}
void emu_midi_send(uint32_t pkt) { (void)pkt; }
int emu_midi_take(uint32_t *pkt) { (void)pkt; return 0; }
void emu_midi_unget(uint32_t pkt) { (void)pkt; }
