# Tandy 1000 Hardware Register Reference

**Project:** Bayside — DeskMate 3.05 Reverse Engineering
**Last updated:** 2026-04-06
**Scope:** TGA/TGA2 video, SN76496 sound chip, Tandy DAC (PSSJ), PC speaker, keyboard, mouse

This document is the primary hardware reference for Stage 3 annotation work. All register
addresses are I/O port numbers unless otherwise stated. Confirmed facts are noted; educated
guesses based on DOSBox emulation source or community research are marked [inferred].

---

## Table of Contents

1. [Tandy Graphics Adapter (TGA / TGA2)](#1-tandy-graphics-adapter-tga--tga2)
2. [SN76496 Programmable Sound Generator](#2-sn76496-programmable-sound-generator)
3. [Tandy DAC / PSSJ Chip](#3-tandy-dac--pssj-chip)
4. [PC Speaker (Fallback)](#4-pc-speaker-fallback)
5. [Keyboard Controller (8255 / PPI)](#5-keyboard-controller-8255--ppi)
6. [Joystick Port](#6-joystick-port)
7. [Mouse Support](#7-mouse-support)
8. [System Detection](#8-system-detection)
9. [DeskMate Driver Notes](#9-deskmate-driver-notes)
10. [Sources](#10-sources)

---

## 1. Tandy Graphics Adapter (TGA / TGA2)

### 1.1 Overview

The Tandy Graphics Adapter is the integrated video subsystem on all Tandy 1000 series
computers. TGA (Tandy Video I) is present on the original 1000 through the 1000 TX. TGA2
(Tandy Video II, also called ETGA) is present on the SL, TL, and RL series. Both are
derived from the IBM PCjr Video Gate Array, enhanced with CGA-compatible mode/color control
registers that the PCjr lacked.

The TGA uses system RAM as video RAM — there is no dedicated video memory chip. The video
controller pages in a window of main RAM at segment B800h.

### 1.2 I/O Port Map (3D0h–3DFh)

| Port | RW | Name | Notes |
|------|----|------|-------|
| 3D0h | — | (Unused) | Not decoded on TGA |
| 3D4h | W | CRTC Address Register | Selects MC6845-compatible register 0–17 |
| 3D5h | RW | CRTC Data Register | Read/write selected CRTC register |
| 3D8h | W | Mode Control Register | CGA-compatible; see §1.4 |
| 3D9h | W | Color Select Register | CGA-compatible; see §1.5 |
| 3DAh | R | CRT Status Register | CGA-compatible vertical/horizontal retrace bits |
| 3DAh | W | Video Array Address Register | Write index 01h–1Fh to select internal VA register |
| 3DEh | W | Video Array Data Register | Write data for index previously latched at 3DAh |
| 3DFh | W | CRT/Processor Page Register | Video page select; see §1.7 |

Notes:
- 3D8h and 3D9h are absent on the PCjr (its BIOS programs the VA directly). Tandy added
  them for CGA software compatibility.
- The dual use of 3DAh (read = status, write = VA index) is a Tandy/PCjr design that
  differs from CGA where 3DAh is read-only.
- Ports 3DBh (Clear Light Pen Latch) and 3DCh (Set Light Pen Latch) exist for CGA
  compatibility but light pen support is not used by DeskMate.

### 1.3 CRTC Registers (MC6845-compatible, indexed via 3D4h/3D5h)

| Index | Name | Description |
|-------|------|-------------|
| 00h | Horizontal Total | Total characters per line (minus 1) |
| 01h | Horizontal Displayed | Displayed characters per line |
| 02h | Horizontal Sync Position | Start of HSYNC |
| 03h | Horizontal Sync Width | Width of HSYNC pulse |
| 04h | Vertical Total | Total character rows (minus 1) |
| 05h | Vertical Total Adjust | Fine-tune vertical timing |
| 06h | Vertical Displayed | Displayed character rows |
| 07h | Vertical Sync Position | Start of VSYNC |
| 08h | Interlace Mode | 00h = non-interlace |
| 09h | Max Scan Line | Scan lines per character row (minus 1) |
| 0Ah | Cursor Start | Cursor blink and start scan line |
| 0Bh | Cursor End | Cursor end scan line |
| 0Ch | Start Address High | High byte of display memory start address |
| 0Dh | Start Address Low | Low byte of display memory start address |
| 0Eh | Cursor Location High | High byte of cursor address |
| 0Fh | Cursor Location Low | Low byte of cursor address |
| 10h | Light Pen High | (read-only) |
| 11h | Light Pen Low | (read-only) |

Registers 0Ch/0Dh together form the 14-bit display start address (in 16-bit words from the
video page base). Writing these registers allows smooth hardware vertical scrolling.
DeskMate uses this for page-flipping between double-buffered display pages.

### 1.4 Mode Control Register (3D8h) — Write Only

| Bit | Mask | Name | Description |
|-----|------|------|-------------|
| 0 | 01h | Alpha/Graphics | 0 = alphanumeric (text) mode, 1 = graphics mode |
| 1 | 02h | Graphics Resolution | 0 = 320-dot wide, 1 = 640-dot wide (hi-res) |
| 2 | 04h | Color Disable | 0 = color burst enabled, 1 = color burst disabled (B/W) |
| 3 | 08h | Video Enable | 0 = blank display, 1 = display enabled |
| 4 | 10h | 40/80 Column | 0 = 40-col text, 1 = 80-col text (text modes only) |
| 5 | 20h | Blink Enable | 0 = background intensity, 1 = character blinking |

Typical values written by BIOS INT 10h mode-set code:

| Mode (AL) | 3D8h Value | Description |
|-----------|-----------|-------------|
| 01h | 08h | 40x25 color text |
| 03h | 29h | 80x25 color text |
| 04h | 0Ah | 320x200 4-color graphics |
| 06h | 1Eh | 640x200 2-color graphics |
| 08h | 0Bh | 160x200 16-color graphics |
| 09h | 0Bh | 320x200 16-color graphics |
| 0Ah | 0Bh | 640x200 4-color graphics |

### 1.5 Color Select Register (3D9h) — Write Only

This is the CGA-compatible palette/border control register.

| Bit | Mask | Name | Description |
|-----|------|------|-------------|
| 0 | 01h | Background Blue | Background/border color bit 0 |
| 1 | 02h | Background Green | Background/border color bit 1 |
| 2 | 04h | Background Red | Background/border color bit 2 |
| 3 | 08h | Background Intensity | Background/border color bit 3 (intensity) |
| 4 | 10h | Foreground Intensity | Increases all foreground colors by 8 (graphics) |
| 5 | 20h | Palette Select | 0 = palette 0 (green/red/yellow), 1 = palette 1 (cyan/magenta/white) |

Bits 0–3 select the border color in text mode and the background color in 320x200 4-color
mode. Bit 5 selects the CGA 4-color palette (meaningful only in 320x200x4 mode 04h).

### 1.6 Video Array Registers (indexed via 3DAh write / data at 3DEh)

To write a Video Array register: OUT 3DAh, index; OUT 3DEh, data.

Reading 3DAh returns the CGA-compatible status byte (vertical/horizontal retrace flags);
writing to 3DAh sets the index for the next data write to 3DEh.

| VA Index | Name | Bits | Description |
|----------|------|------|-------------|
| 01h | Palette Mask | 3:0 | 4-bit write-only mask. Any bit set to 0 forces that address line into the palette to 0, effectively collapsing palette entries. Typical value: 0Fh (all entries active). |
| 02h | Border Color | 3:0 | 4-bit border color register. Selects one of 16 RGBI colors for the screen border area. |
| 03h | Mode Control | 4:0 | See table below. |
| 10h–1Fh | Palette Entry 0–15 | 3:0 | Individual palette remapping. Index 10h = color 0 (black by default) through 1Fh = color 15. Each holds a 4-bit RGBI value to substitute for that DAC entry. |

**VA Register 03h — Mode Control bits:**

| Bit | Mask | Description |
|-----|------|-------------|
| 0 | 01h | Video Enable — 0 disables video output. Writing 0 here (and to 3D8h bit 3) disables onboard video when an ISA card is installed. |
| 1 | 02h | [inferred] Reserved / model-dependent |
| 2 | 04h | [inferred] Reserved |
| 3 | 08h | [inferred] Reserved |
| 4 | 10h | [inferred] Reserved |

To disable onboard TGA video: write 03h to 3DAh, write 00h to 3DEh; also set A0h bit 0 = 1.

**Palette register programming example (set all 16 defaults):**

```asm
    ; Write identity palette (color N maps to RGBI N)
    mov  dx, 3DAh
    mov  cx, 16
    mov  bx, 10h          ; first palette index
    xor  si, si           ; color value starts at 0
palette_loop:
    out  dx, al           ; write index (bx) — AL must hold index
    ; ... set AL = bx, then AL = si for data
    ; out  3DEh, data
    inc  bx
    inc  si
    loop palette_loop
```

### 1.7 CRT/Processor Page Register (3DFh) — Write Only

This register selects which 16 KB page of system RAM is used for video and which 16 KB
window at B800h is accessible to the CPU.

| Bits | Mask | Name | Description |
|------|------|------|-------------|
| 2:0 | 07h | CRT Page | Selects the 16 KB page displayed by the video hardware (0–7). In 32 KB modes (16-color), bit 0 is ignored and two consecutive pages are used. |
| 5:3 | 38h | Processor Page | Selects which 16 KB page of system RAM is mapped to the B800h segment for CPU access. |
| 7:6 | C0h | Video Address Mode | Controls address mapping (see below). |

**Video Address Mode field (bits 7:6):**

| Value | Mode | Description |
|-------|------|-------------|
| 00b | CGA-compatible interleaved | Even lines at base, odd lines at base+8 KB. Standard for modes 04h–0Ah. |
| 01b | [inferred] Linear | Sequential line addressing (may be used by 160x200 mode). |
| 10b | [inferred] 32 KB linear | Full 32 KB sequential layout for 16-color modes. |
| 11b | [inferred] Reserved | — |

The TGA maps video memory into the last 128 KB of the system's installed RAM. On a 256 KB
machine this is at 192 KB–256 KB; on a 640 KB machine at 512 KB–640 KB. Page 0 is the
lowest 16 KB of that range, page 7 the highest.

**Standard page register values used by BIOS:**

| Mode | Typical 3DFh | CRT Page | Processor Page | Notes |
|------|-------------|----------|----------------|-------|
| Text modes | 00h | 0 | 0 | Both pages at same location |
| 320x200x4 | 00h | 0 | 0 | 16 KB at B8000h |
| 160x200x16 | 06h | 0 | 0 | [inferred] 16 KB mode |
| 320x200x16 | 0Eh | 0 (32K) | 0 (32K) | 32 KB; bits 6:7 = 10b for TGA2 |
| 640x200x4 | 06h | 0 | 0 | 32 KB interleaved |

### 1.8 Video Modes Reference Table

| INT 10h AL | Name | Resolution | Colors | VRAM | Notes |
|-----------|------|-----------|--------|------|-------|
| 00h | Text 40x25 B/W | 320x200 text | mono | 16 KB | |
| 01h | Text 40x25 color | 320x200 text | 16 | 16 KB | |
| 02h | Text 80x25 B/W | 640x200 text | mono | 16 KB | |
| 03h | Text 80x25 color | 640x200 text | 16 | 16 KB | DeskMate desktop default |
| 04h | CGA 320x200x4 | 320x200 | 4 | 16 KB | CGA palette 0 or 1 |
| 05h | CGA 320x200x4 B/W | 320x200 | 4 (gray) | 16 KB | Color burst off |
| 06h | CGA 640x200x2 | 640x200 | 2 | 16 KB | |
| 07h | MDA 80x25 mono | 640x200 text | mono | — | Not supported on TGA |
| 08h | PCjr 160x200x16 | 160x200 | 16 | 16 KB | TGA extension |
| 09h | PCjr 320x200x16 | 320x200 | 16 | 32 KB | DeskMate graphics mode |
| 0Ah | PCjr 640x200x4 | 640x200 | 4 | 32 KB | |
| 0Bh | — | — | — | — | Reserved |
| 0Ch | — | — | — | — | Reserved |
| 0Dh | EGA 320x200x16 | 320x200 | 16 | 32 KB | EGA only, not TGA |
| 0Eh | EGA 640x200x16 | 640x200 | 16 | 64 KB | EGA only, not TGA |
| 11h | ETGA 640x200x16 | 640x200 | 16 | 64 KB | **TGA2 only (SL/TL/RL)** |

Mode 09h (320x200x16) is the primary graphics mode used by DeskMate's DRAW.PDM and the
desktop wallpaper. The video memory layout is interleaved: even scan lines begin at offset
0000h, odd scan lines at offset 2000h (8 KB later).

**Memory layout for mode 09h (320x200x16):**

```
B800:0000  Line 0 (pixels 0–319, 4 bits/pixel, 160 bytes)
B800:0160  Line 2
B800:02C0  Line 4
...
B800:3E80  Line 198
B800:2000  Line 1
B800:2160  Line 3
...
B800:5E80  Line 199
```

Each byte encodes two pixels: high nibble = left pixel, low nibble = right pixel. The
palette index (0–15) maps through the Video Array palette registers to an RGBI color.

### 1.9 TGA vs. TGA2 Differences

| Feature | TGA (1000–TX) | TGA2 / ETGA (SL/TL/RL) |
|---------|--------------|------------------------|
| Max modes | Mode 0Ah (640x200x4) | Adds mode 11h (640x200x16) |
| BIOS mode 11h | Not supported | Supported via INT 10h AX=0011h |
| Video RAM | Up to 128 KB paged from system RAM | Same, but 64 KB needed for mode 11h |
| VA registers | 01h–1Fh | Same set, no new VA registers added |
| CRT page select | 3 bits (pages 0–7) | Same |
| PSSJ chip | No | Yes (also integrates SN76496 + DAC) |
| Onboard serial | No (TX has ISA slot for add-in) | Yes |

Mode 11h on TGA2 uses a linear (non-interleaved) 64 KB framebuffer, unlike the interleaved
32 KB layout of mode 09h. This mode had no official BIOS documentation and was rarely used
by games; DeskMate does not use it.

### 1.10 16-Color RGBI Palette (Hardware Default)

| Index | Binary RGBI | Color Name |
|-------|------------|-----------|
| 0 | 0000 | Black |
| 1 | 0001 | Blue |
| 2 | 0010 | Green |
| 3 | 0011 | Cyan |
| 4 | 0100 | Red |
| 5 | 0101 | Magenta |
| 6 | 0110 | Brown (reduced green: GR bits, intensity=0) |
| 7 | 0111 | Light Gray |
| 8 | 1000 | Dark Gray |
| 9 | 1001 | Light Blue |
| A | 1010 | Light Green |
| B | 1011 | Light Cyan |
| C | 1100 | Light Red |
| D | 1101 | Light Magenta |
| E | 1110 | Yellow |
| F | 1111 | White |

The palette registers (VA index 10h–1Fh) can remap any of these 16 slots. DeskMate uses
the default RGBI mapping.

---

## 2. SN76496 Programmable Sound Generator

### 2.1 Overview

The SN76496 (Texas Instruments) is the 3-voice tone + 1-voice noise PSG used in all Tandy
1000 models. On the original 1000 through TX, it is a discrete chip. On the SL, TL, and RL
series, its functionality is integrated into the PSSJ ASIC alongside the DAC.

The chip is connected to the 3.579545 MHz color-burst clock. It is **write-only** — there
is no way to read back register values. Detection must be done via system BIOS signature
checks (see §8).

The chip ignores address lines A0, A1, A2, so it responds to a write at any port in the
range C0h–C7h. Conventional code writes to C0h.

### 2.2 Register Map

The SN76496 has 8 internal registers, accessed through a single write port:

| Register | Name | Access |
|----------|------|--------|
| 0 | Tone 1 Frequency | 10-bit write (two bytes) |
| 1 | Tone 1 Attenuation | 4-bit write (one byte) |
| 2 | Tone 2 Frequency | 10-bit write (two bytes) |
| 3 | Tone 2 Attenuation | 4-bit write (one byte) |
| 4 | Tone 3 Frequency | 10-bit write (two bytes) |
| 5 | Tone 3 Attenuation | 4-bit write (one byte) |
| 6 | Noise Control | 3-bit write (one byte) |
| 7 | Noise Attenuation | 4-bit write (one byte) |

### 2.3 Command Byte Protocol

Every write to C0h is one byte. The high bit (bit 7) determines the byte type:

**Latch/Data byte (bit 7 = 1):** selects a register and loads the low 4 data bits.

```
  7   6   5   4   3   2   1   0
  1  R2  R1  R0  D3  D2  D1  D0
```

- Bits 6:4 (R2:R0): register select (0–7, see table above)
- Bits 3:0 (D3:D0): low 4 bits of data (for frequency registers, these are bits 9:6 of the
  10-bit counter; for attenuation/noise registers, these are the complete value)

**Data byte (bit 7 = 0):** loads the upper 6 bits of the most recently latched frequency
register. Only meaningful for tone frequency registers (registers 0, 2, 4).

```
  7   6   5   4   3   2   1   0
  0   x  D5  D4  D3  D2  D1  D0
```

- Bit 6 is ignored
- Bits 5:0 (D5:D0): bits 5:0 of the 10-bit frequency counter

The two bytes together form the 10-bit counter N:

```
  N[9:6] = D3:D0 from latch byte
  N[5:0] = D5:D0 from data byte
```

### 2.4 Frequency Calculation

The chip divides the input clock (3,579,545 Hz) by 32, then divides again by the 10-bit
counter N:

```
  f_out = 3,579,545 / (32 * N)   = 111,860 / N   Hz
```

Special case: if N = 0, the chip behaves as if N = 0x400 (1024) on most implementations,
producing the lowest possible tone (~109 Hz).

**Frequency counter values for musical notes (A=440 Hz reference):**

| Note | Frequency (Hz) | Counter N (approx.) |
|------|---------------|---------------------|
| A4   | 440.0 | 254 |
| B4   | 493.9 | 226 |
| C5   | 523.3 | 214 |
| D5   | 587.3 | 190 |
| E5   | 659.3 | 170 |
| F5   | 698.5 | 160 |
| G5   | 784.0 | 143 |
| A5   | 880.0 | 127 |

**To convert a desired frequency to counter N:**

```c
/* clock = 3579545 Hz */
int sn76496_freq_to_counter(int freq_hz) {
    return 111860 / freq_hz;   /* integer division */
}
```

**Minimum audible frequency:** N = 1023 -> ~109 Hz
**Maximum frequency:** N = 1 -> ~111,860 Hz (supersonic; useful as "mute without using attenuation")

### 2.5 Attenuation Register Format

Attenuation bytes use the latch/data format with register select pointing to register 1, 3,
5, or 7:

```
  7   6   5   4   3   2   1   0
  1  R2  R1  R0  A3  A2  A1  A0
```

- A3:A0 is the attenuation level, 0 = maximum volume, 15 = silence.
- Each step is approximately 2 dB of attenuation.

| A3:A0 | Attenuation | Relative Level |
|-------|------------|----------------|
| 0000 | 0 dB | Full volume |
| 0001 | 2 dB | — |
| 0010 | 4 dB | — |
| 0011 | 6 dB | — |
| 0100 | 8 dB | — |
| 0101 | 10 dB | — |
| 0110 | 12 dB | — |
| 0111 | 14 dB | — |
| 1000 | 16 dB | — |
| 1001 | 18 dB | — |
| 1010 | 20 dB | — |
| 1011 | 22 dB | — |
| 1100 | 24 dB | — |
| 1101 | 26 dB | — |
| 1110 | 28 dB | — |
| 1111 | silence | Off |

The MAME/DOSBox implementation uses a 15-step logarithmic table where each step divides the
amplitude by 10^(2/20) ≈ 1.2589. Step 15 is hard silence.

### 2.6 Noise Channel Control Register (Register 6)

The noise channel register is written with a single latch/data byte (R2:R0 = 110):

```
  7   6   5   4   3   2   1   0
  1   1   1   0   0  FB NF1 NF0
```

- **FB (bit 2):** Feedback type
  - 0 = periodic noise (repeating pattern)
  - 1 = white noise (pseudo-random, LFSR-based)
- **NF1:NF0 (bits 1:0):** Shift rate / frequency
  - 00 = clock / 512 (~6,991 Hz with 3.58 MHz clock)
  - 01 = clock / 1024 (~3,496 Hz)
  - 10 = clock / 2048 (~1,748 Hz)
  - 11 = use Tone 3 output as noise clock (allows any noise frequency)

When NF1:NF0 = 11 (use Tone 3), writing to the Tone 3 frequency register will also affect
the noise channel frequency. This is the canonical method for wide-range noise effects in
games that use DeskMate's OMUSIC.RES driver.

### 2.7 Silence All Channels

To immediately silence all output (e.g., during sound driver teardown):

```asm
    mov  dx, 0C0h
    mov  al, 9Fh    ; register 1 (tone 1 atten), value 0Fh (silence)
    out  dx, al
    mov  al, 0BFh   ; register 3 (tone 2 atten), value 0Fh
    out  dx, al
    mov  al, 0DFh   ; register 5 (tone 3 atten), value 0Fh
    out  dx, al
    mov  al, 0FFh   ; register 7 (noise atten),  value 0Fh
    out  dx, al
```

### 2.8 OMUSIC.RES — DeskMate 3-Voice Music Driver

DeskMate uses OMUSIC.RES to drive the SN76496 for 3-channel music playback from .SNG files.
The driver maps:
- SNG channel 0 -> SN76496 Tone 1 (registers 0, 1)
- SNG channel 1 -> SN76496 Tone 2 (registers 2, 3)
- SNG channel 2 -> SN76496 Tone 3 (registers 4, 5)
- Noise channel is not used by OMUSIC.RES in normal playback

The music driver uses a timer-driven ISR to advance the SNG sequencer and write new
frequency/attenuation values to C0h at regular intervals.

---

## 3. Tandy DAC / PSSJ Chip

### 3.1 Overview

The PSSJ (Parallel, Serial, Sound and Joystick) is a custom ASIC present on the Tandy 1000
SL, TL, TLX, RL, and RLX motherboards. It integrates:
- The SN76496-equivalent 3-voice PSG (still at port C0h)
- An 8-bit DAC for digital sample playback (ports C4h–C7h)
- An ADC (recording support, same ports as DAC)
- The joystick interface (port 201h, shared with DAC)
- Serial port (built-in COM1 on SL/TL)

The DAC uses **DMA channel 1** and **IRQ 7** — hardwired, not configurable. This conflicts
with Sound Blaster cards which also use DMA 1, making the two devices mutually exclusive.

A hardware bug: the joystick port and the DAC share an I/O register at C4h. A DAC read or
write disables joystick mode, and joystick reads disable DAC mode. The two cannot be used
simultaneously.

### 3.2 I/O Port Map (C4h–C7h)

| Port | Direction | Name | Description |
|------|-----------|------|-------------|
| C4h | R | Mode/Status Register (read) | Low 2 bits reflect current operating mode |
| C4h | W | Mode Control Register (write) | Low 2 bits select operating mode |
| C5h | W | Control Register | Mode-dependent (see below) |
| C6h | RW | Frequency Low Byte | Low 8 bits of the 12-bit sample rate divisor |
| C7h | RW | Frequency/Amplitude Register | Bits 3:0 = high 4 bits of frequency divisor; bits 7:5 = amplitude |

Port C4h mode bits (bits 1:0):

| Value | Mode | Description |
|-------|------|-------------|
| 00b | Joystick mode | Normal joystick reads at 201h active; DAC disabled |
| 01b | Control mode | DAC configuration; intermediate state |
| 10b | Recording mode | ADC active; samples captured via DMA to memory |
| 11b | Playback mode | DAC active; samples output via DMA from memory |

Bits 3:2 of C4h (when in playback/recording mode) control DMA operation:
- Both bits set (0Ch) enables DMA-driven transfer.
- Writing 0Fh to C4h initiates DMA playback.

### 3.3 Frequency / Sample Rate Register (C6h / C7h)

The 12-bit divisor N in registers C6h (low 8 bits) and C7h bits 3:0 (high 4 bits) sets
the sample rate:

```
  sample_rate = 3,579,545 / N   Hz
```

Standard sample rates and their divisor values:

| Sample Rate (Hz) | Divisor N | C6h | C7h bits 3:0 |
|-----------------|-----------|-----|-------------|
| 5,512 | 649 | 89h | 02h |
| 11,025 | 325 | 45h | 01h |
| 22,050 | 162 | A2h | 00h |

The BIOS and NMUSIC.RES use 11,025 Hz as the standard playback rate. SOUND.PDM supports
all three rates for record and playback.

[inferred from DOSBox-X tandy_sound.cpp: freq = 3579545.0 / frequency_value]

### 3.4 Amplitude / Volume Register (C7h bits 7:5)

Bits 7:5 of C7h control the DAC output volume:

```
  amplitude_value = bits 7:5 of C7h   (0–7)
  volume = amplitude_value / 7.0      (linear, 0.0–1.0)
```

| C7h bits 7:5 | Relative Volume |
|-------------|----------------|
| 000 | Muted (0%) |
| 001 | ~14% |
| 010 | ~29% |
| 011 | ~43% |
| 100 | ~57% |
| 101 | ~71% |
| 110 | ~86% |
| 111 | Full (100%) |

**Important:** Always set amplitude to 0 before enabling or disabling the DAC to avoid
audible clicks. This is documented in Frank Durda IV's PSSJ notes and enforced by
SOUND.PDM.

### 3.5 DMA Playback Sequence

The following is the standard PSSJ DAC playback initialization sequence derived from
Frank Durda IV's comp.sys.tandy documentation and the DOSBox-X implementation:

```
1. Set DMA channel 1 to transfer mode:
   OUT 0Ah, 05h        ; mask DMA channel 1
   OUT 0Bh, 49h        ; mode: single, read, auto-init off, ch 1
   OUT 83h, <page>     ; DMA page register ch 1 (address bits A16:A19)
   OUT 02h, <addr_lo>  ; DMA base address low byte  (ch 1 addr reg)
   OUT 02h, <addr_hi>  ; DMA base address high byte
   OUT 03h, <count_lo> ; DMA count low byte (ch 1 word count reg)
   OUT 03h, <count_hi> ; DMA count high byte
   OUT 0Ah, 01h        ; unmask DMA channel 1

2. Configure PSSJ DAC:
   OUT 0C7h, 00h       ; amplitude = 0 (prevent click)
   OUT 0C4h, 0Fh       ; mode = playback + DMA enable
   OUT 0C6h, <N_low>   ; frequency divisor low byte
   OUT 0C7h, <N_hi | (amplitude << 5)>  ; freq high + volume

3. Start playback:
   OUT 0C5h, 01h       ; [inferred] write to C5h triggers start

4. When IRQ 7 fires (DMA terminal count):
   ; Optionally reload DMA for next buffer, or stop:
   OUT 0C4h, 00h       ; return to joystick mode
   OUT 0C7h, 00h       ; amplitude = 0
```

### 3.6 PSSJ Chip Revisions

There are two known PSSJ silicon revisions with different initialization requirements:

**Original PSSJ ("Bonanza" revision):**
- Used on early SL/TL boards.
- Standard DMA start works without extra priming steps.

**Revised PSSJ:**
- Used on later boards.
- DMA must be "primed" to start: the double-buffer inside the chip must be pre-loaded
  before DMA starts, or it will not begin transferring.
- After playback stops, the chip must be explicitly drained (write 00h to DAC until empty)
  before returning to joystick mode, otherwise subsequent joystick reads fail.

The safe approach (used by SOUND.PDM) works correctly on both revisions.

### 3.7 NMUSIC.RES — DeskMate Digital Audio Driver

NMUSIC.RES drives the PSSJ DAC for .SND file playback and SOUND.PDM recording. It:
- Configures DMA channel 1 for 8-bit transfer
- Sets the sample rate (typically 11,025 Hz)
- Streams .SND audio data through the DAC using IRQ 7 double-buffering
- Falls back to PC speaker output if PSSJ is not detected (based on BIOS signature check)

---

## 4. PC Speaker (Fallback)

### 4.1 Overview

On Tandy 1000 models without the PSSJ DAC (original 1000 through TX), or on non-Tandy
machines that run DeskMate via emulation, the PC speaker is the only audio output. The
speaker is driven by PIT (Intel 8253/8254) channel 2.

### 4.2 Port Map

| Port | RW | Name | Description |
|------|----|------|-------------|
| 40h | W | PIT Channel 0 Counter | System timer (18.2 Hz tick) |
| 41h | W | PIT Channel 1 Counter | DRAM refresh timer |
| 42h | W | PIT Channel 2 Counter | Speaker frequency counter |
| 43h | W | PIT Control Word | Mode/command register for channels 0–2 |
| 61h | RW | PPI Port B | Bit 0 = Timer 2 gate; Bit 1 = Speaker data; see table |

### 4.3 PIT Control Word (43h)

To set up channel 2 for square-wave speaker output:

```
  OUT 43h, 0B6h       ; channel 2, lobyte/hibyte, mode 3 (square wave), binary
  OUT 42h, <freq_lo>  ; low byte of 16-bit count
  OUT 42h, <freq_hi>  ; high byte of 16-bit count
```

Control word 0B6h decodes as:

```
  7   6   5   4   3   2   1   0
  1   0   1   1   0   1   1   0
  |SC1 SC0|RL1 RL0|M2  M1  M0| BCD
  | ch 2  |lo/hi  | mode 3   | binary
```

The 16-bit counter N relates to output frequency:

```
  f_out = 1,193,182 / N   Hz   (PIT input clock = 1.193182 MHz)
  N = 1,193,182 / desired_freq
```

### 4.4 Port 61h (PPI Port B) — Speaker Enable Bits

| Bit | Mask | Name | Description |
|-----|------|------|-------------|
| 0 | 01h | Timer 2 Gate | 1 = enable PIT channel 2 counting (gate open) |
| 1 | 02h | Speaker Data Enable | 1 = connect PIT channel 2 output to speaker |
| 4 | 10h | Tandy audio enable | 0 = mute all analog audio outputs on Tandy |
| 5 | 20h | [Tandy] Sound control 0 | Audio multiplexer select bit 0 |
| 6 | 40h | [Tandy] Sound control 1 | Audio multiplexer select bit 1 |

To enable speaker output:

```asm
    in   al, 61h
    or   al, 03h        ; set bits 0 and 1
    out  61h, al
```

To disable (restore silence):

```asm
    in   al, 61h
    and  al, 0FCh       ; clear bits 0 and 1
    out  61h, al
```

On Tandy hardware, bit 4 of port 61h controls whether the SN76496 output, the DAC output,
and the speaker are mixed to the headphone jack and external audio output. DeskMate sets
this bit when any sound is active.

### 4.5 Frequency Example

To produce a 440 Hz (A4) square wave:

```asm
    mov  al, 0B6h
    out  43h, al            ; set up channel 2
    mov  ax, 2711           ; 1193182 / 440 = 2711
    out  42h, al            ; low byte
    mov  al, ah
    out  42h, al            ; high byte
    in   al, 61h
    or   al, 03h
    out  61h, al            ; enable speaker
```

---

## 5. Keyboard Controller (8255 / PPI)

### 5.1 Overview

The Tandy 1000 keyboard interface is based on an Intel 8255 Programmable Peripheral
Interface (PPI), similar to the original IBM PC but with minor differences. The keyboard
connects via a 5-pin DIN connector using a serial protocol. A shift register on the keyboard
converts keypresses to serial data which is shifted into the PPI.

### 5.2 PPI Port Map

| Port | Direction | Register | Description |
|------|-----------|----------|-------------|
| 60h | R | PPI Port A | Keyboard scan code (current key) |
| 61h | RW | PPI Port B | Control bits (speaker, timer, keyboard ACK) |
| 62h | R | PPI Port C | System configuration switches |

### 5.3 Port 60h — Scan Code Input

Reading port 60h returns the last received keyboard scan code. The Tandy 1000 uses
**IBM PC-compatible scan codes** (Set 1) for nearly all keys. Notable Tandy-specific keys:

| Key | Scan Code | Notes |
|-----|-----------|-------|
| F1–F10 | 3Bh–44h | Same as IBM PC |
| Hold | — | Tandy-specific key; maps to Ctrl+NumLock behavior |
| Back (Backspace) | 0Eh | Same as PC |
| (Tandy function keys) | — | Non-standard extended codes on some models |

The keyboard generates an IRQ1 on each keypress/release, which vectors to INT 09h. The
BIOS INT 09h handler reads port 60h, decodes the scan code, and updates the BIOS keyboard
buffer at 40:1Ah.

### 5.4 Port 61h — Control Register

Bit 7 of port 61h serves as the keyboard acknowledge bit on the Tandy (write 1 then 0 to
acknowledge and reset the keyboard shift register after reading port 60h). This is
consistent with the IBM PC design.

### 5.5 Port 62h — Configuration

| Bit | Name | Description |
|-----|------|-------------|
| 1 | Video RAM size | 0 = 32 KB video RAM, 1 = 16 KB video RAM |
| 3 | Display type | 0 = RGB monitor, 1 = composite monitor |
| 4 | CPU speed | Model-dependent clock rate bit |

DeskMate reads port 62h during initialization to determine monitor type (used by DMVID.EXE
to select appropriate video driver).

---

## 6. Joystick Port

### 6.1 Port 201h

The standard IBM PC joystick port is present at port 201h. Reading this port returns a
one-shot timer value: writing any byte to 201h starts four one-shot capacitor timers (one
per axis), and reading 201h returns which timers have expired (1 = expired).

| Bit | Joystick | Description |
|-----|---------|-------------|
| 0 | JA axis 1 | 0 = timer expired (axis 1, joystick A) |
| 1 | JA axis 2 | 0 = timer expired (axis 2, joystick A) |
| 2 | JB axis 1 | 0 = timer expired (axis 1, joystick B) |
| 3 | JB axis 2 | 0 = timer expired (axis 2, joystick B) |
| 4 | JA button 1 | 0 = pressed |
| 5 | JA button 2 | 0 = pressed |
| 6 | JB button 1 | 0 = pressed |
| 7 | JB button 2 | 0 = pressed |

On PSSJ machines (SL/TL/RL), port C4h shares the joystick circuitry. The PSSJ must be in
joystick mode (C4h bits 1:0 = 00b) for port 201h to work correctly. Setting the DAC to
playback or record mode disables joystick reads.

---

## 7. Mouse Support

### 7.1 Mouse Types by Model

| Model | Mouse Interface | Notes |
|-------|----------------|-------|
| 1000, 1000A, 1000HD | Joystick port (DigiMouse) or serial | DigiMouse = quadrature mouse on joystick port |
| 1000 SX | Joystick port or serial | First model with full ISA bus |
| 1000 TX | Serial (COM1 via ISA card) | No built-in serial; ISA slot required |
| 1000 EX / HX | PLUS expansion bus | Requires PLUS mouse card |
| 1000 SL / TL | Serial (built-in COM1 via PSSJ) | PS/2-style via adapter also supported |
| 1000 RL / RLX | Serial or PS/2 | RSX models have PS/2 port |

### 7.2 INT 33h Mouse Driver

DeskMate (confirmed by DRAW.PDM disassembly) uses standard Microsoft INT 33h mouse driver
calls. The MOUSE.SYS or MOUSE.COM driver must be loaded before DeskMate starts. DeskMate
does not make direct hardware mouse reads.

Key INT 33h functions used:
- AX=0000h: Reset mouse and return mouse hardware info
- AX=0001h: Show mouse cursor
- AX=0002h: Hide mouse cursor
- AX=0003h: Get mouse position and button status
- AX=000Ch: Set mouse event handler (callback)

### 7.3 DigiMouse (Joystick-Port Mouse)

The Tandy DigiMouse (catalog number 26-5144 or 25-1010) is a bus mouse using a quadrature
encoder. It is read via the same INT 33h interface through a dedicated mouse driver. The
driver reads port 201h for movement deltas and button state. DeskMate programs are
unaware of which physical interface backs INT 33h.

---

## 8. System Detection

DeskMate and its resource drivers detect Tandy hardware at runtime to select the correct
audio and video paths. Since the SN76496 is write-only, detection is done via BIOS ROM
signature, not port I/O.

### 8.1 Tandy 1000 Detection

Check the BIOS ROM identity byte and string:

```asm
    ; Check system ID byte at F000:FFFEh
    mov  ax, 0F000h
    mov  es, ax
    mov  al, es:[0FFFEh]
    cmp  al, 0FFh           ; Tandy 1000 (original) returns FFh
    je   is_tandy

    ; Confirm with Tandy string at F000:C078h (most models)
    mov  di, 0C078h
    ; compare es:[di] with "TANDY" string
```

BIOS identity values:
- FFh at F000:FFFEh = IBM PC / XT compatible (also used by early Tandy 1000)
- FDh at F000:FFFEh = IBM PCjr
- After confirming non-PCjr, check F000:C000h = 21h and "TANDY" string at F000:C078h

### 8.2 TGA2 (ETGA) Detection

TGA2 systems (SL/TL/RL) can be detected by attempting to set mode 11h via INT 10h and
checking whether video output changes, or by checking the extended BIOS data area for a
Tandy model code. DOSBox-X exposes a machine type check.

---

## 9. DeskMate Driver Notes

### 9.1 Video Drivers (DMVE*.RES)

DMVID.EXE is a standalone configuration utility that writes a `DMCSR.CFG` file selecting
which video driver DeskMate should load at startup. The video RES files are:

| File | Target | Video Mode |
|------|--------|-----------|
| DMVETN.RES | TGA (Tandy) | 320x200x16, mode 09h |
| DMVEET.RES | ETGA / TGA2 | Same + mode 11h capability |
| DMVEGA.RES | EGA | EGA 320x200x16 (mode 0Dh) |
| DMVECG.RES | CGA | 320x200x4 (mode 04h) |

Each video RES driver provides a set of INT E0h video service callbacks that DESK.EXE calls
for all rendering operations, abstracting hardware details from the PDM applications.

### 9.2 Sound Drivers

| File | Target | Hardware |
|------|--------|---------|
| OMUSIC.RES | 3-voice music | SN76496 at C0h |
| NMUSIC.RES | Digital audio | PSSJ DAC at C4h–C7h |
| SOUND.PDM | Record/playback UI | Uses NMUSIC.RES |

DESK.EXE probes for PSSJ hardware at startup using the BIOS signature check (§8.1) combined
with a model check for SL/TL/RL. If no PSSJ is found, NMUSIC.RES falls back to PC speaker
output.

### 9.3 Memory Map Summary

| Segment | Address Range | Contents |
|---------|--------------|---------|
| 0000:0000 | 00000h–003FFh | Interrupt Vector Table |
| 0040:0000 | 00400h–004FFh | BIOS Data Area |
| — | 00500h–9FFFFh | Conventional RAM (TPA) |
| — | A0000h–BFFFFh | Video memory area |
| B800:0000 | B8000h–BFFFFh | TGA video window (CPU page) |
| — | C0000h–EFFFFh | Expansion ROMs |
| F000:0000 | F0000h–FFFFFh | BIOS ROM |

DeskMate loads DESK.EXE into conventional RAM starting around segment 0100h. PDM modules
are loaded above DESK.EXE. The TGA video window is the B800h segment, with actual video
data stored in the top 128 KB of installed RAM and paged through the 3DFh register.

---

## 10. Sources

All sources consulted during research for this document:

- [Tandy Graphics Adapter — Wikipedia](https://en.wikipedia.org/wiki/Tandy_Graphics_Adapter)
- [Texas Instruments SN76489 — Wikipedia](https://en.wikipedia.org/wiki/Texas_Instruments_SN76489)
- [Tandy 1000 — Wikipedia](https://en.wikipedia.org/wiki/Tandy_1000)
- [Tandy 1000-series FAQ — oldskool.org](http://www.oldskool.org/guides/tvdog/1kfaq.html)
- [Tandy 1000 Documentation Files — oldskool.org](http://www.oldskool.org/guides/tvdog/documents.html)
- [Tandy 1000 EX Technical Reference Manual — archive.org](https://archive.org/stream/tandy1000extechnicalreferencemanual/Tandy_1000EX_Technical_Reference_Manual_djvu.txt)
- [Tandy 1000 TX Technical Reference Manual — archive.org](https://archive.org/stream/tandy1000txtechnicalreferencemanual/Tandy%201000TX%20Technical%20Reference%20Manual_djvu.txt)
- [Radio Shack Hardware Manual: Tandy 1000 Computer Service Manual (1985) — archive.org](https://archive.org/stream/Tandy_1000_Computer_Service_Manual_1985_Tandy/Tandy_1000_Computer_Service_Manual_1985_Tandy_djvu.txt)
- [Tandy 1000 SL Technical Reference Manual — ManualsLib](https://www.manualslib.com/manual/1219946/Tandy-1000-Sl.html)
- [Tandy 1000 Technical Reference Manual — ManualsLib](https://www.manualslib.com/manual/887518/Tandy-1000.html)
- [Tandy DAC — VGMPF Wiki](https://www.vgmpf.com/Wiki/index.php/Tandy_DAC)
- [Tandy 3 Voice — VGMPF Wiki](https://www.vgmpf.com/Wiki/index.php?title=Tandy_3_Voice)
- [Nerdly Pleasures: CGA and Tandy Compatibility](http://nerdlypleasures.blogspot.com/2012/07/cga-and-tandy-compatibility.html)
- [Nerdly Pleasures: The Journey of the PCjr/Tandy Sound Chip](http://nerdlypleasures.blogspot.com/2015/10/the-journey-of-pcjrtandy-sound-chip.html)
- [Nerdly Pleasures: Tandy Video vs. EGA](https://nerdlypleasures.blogspot.com/2023/07/tandy-video-vs-ega-battle-of-16-colors.html)
- [VOGONS: The TANDY DAC, how its implemented?](https://www.vogons.org/viewtopic.php?t=61243)
- [VOGONS: The Tandy 1000 ISA sound card brainstorm thread (page 4)](https://www.vogons.org/viewtopic.php?t=42521&start=60)
- [Questions for Frank Durda on PSSJ (Tandy DAC) — comp.sys.tandy](https://groups.google.com/g/comp.sys.tandy/c/7VxlbVGughE/m/wekj31wJfZYJ)
- [SN76489 Technical Notes — TMS9919 page, unige.ch](https://www.unige.ch/medecine/nouspikel/ti99/tms9919.htm)
- [SN76489 Sound Generator Chip — silicon-heaven.org](https://silicon-heaven.org/howel/parts/76489.htm)
- [DOSBox-X: tandy_sound.cpp source](https://dosbox-x.com/doxygen/html/tandy__sound_8cpp_source.html)
- [DOSBox-X: sn76496.cpp source](https://dosbox-x.com/doxygen/html/sn76496_8cpp_source.html)
- [MAME: sn76496.cpp — GitHub](https://github.com/mamedev/mame/blob/master/src/devices/sound/sn76496.cpp)
- [Tandy graphics 320x200 16 colors programming — VCF Forums](https://forum.vcfed.org/index.php?threads/tandy-graphics-320x200-16-colors-programming.80542/)
- [Tandy (1000) Video II, Mode E 640x200x16 — VCF Forums](https://forum.vcfed.org/index.php?threads/tandy-1000-video-ii-mode-e-640x200x16.30948/)
- [Tandy 1000 mouse — VCF Forums](https://forum.vcfed.org/index.php?threads/tandy-1000-mouse.70690/)
- [Grafix 2.7 Chapter 4 — classicdosgames.com](https://www.classicdosgames.com/tutorials/grafix/chapter4.html)
- [PC Speaker programming — fenixfox-studios.com](https://fenixfox-studios.com/content/pc_speaker/)
- [INT 10H — Wikipedia](https://en.wikipedia.org/wiki/INT_10H)
