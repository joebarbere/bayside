# Tandy DeskMate — Technical Reference

## Version History

| Version | Year | Platform | Notes |
|---------|------|----------|-------|
| DeskMate 1.0 | 1984 | Tandy 1000 | Text-mode, single floppy, no mouse, requires Tandy F11/F12 keys |
| DeskMate II | ~1986 | Tandy 1000 SX | Text-mode, two floppies, hard drive support, primitive task switching |
| Personal DeskMate | 1986 | Tandy 1000 EX | First GUI version, Mac-influenced, full-screen apps, joystick/bus mouse |
| Personal DeskMate 2 | 1987 | Tandy 1000 HX/TX | Added Music program (3-voice), 320x200x16 Paint, serial mouse |
| DeskMate 3.00 | 1989 | IBM PC compatible | Major rewrite, Draw replaced Paint, Sound/Music/PC-Link/Hangman/Dictionary added |
| DeskMate 3.02 | 1988-89 | Tandy 1000 SL/TL | Partially ROM-resident, PS/2 mouse |
| DeskMate 3.03 | ~1989 | Tandy 1000 TL/2 | Minor TL/2 hardware update |
| DeskMate 3.04 | post-1990 | Tandy 2500 RSX only | NOT IBM PC compatible |
| **DeskMate 3.05** | **1990** | **IBM PC compatible** | **Final version. Desktop internally "Desktop 3.69". PRIMARY TARGET.** |

## DeskMate 3.05 Applications

### Core Shell
- **DESK.EXE** — Main host environment. Loads .PDM programs, provides API services, manages video/sound/input.
- **DESKTOP.PDM** — Desktop UI with icon launcher and file management.
- **DMVID.EXE** — Video adapter detection/selection utility.

### Productivity
- **TEXT.PDM** — Word processor
- **WORKSHT.PDM** — Spreadsheet (.WKS format)
- **FILER.PDM** — Flat-file database (.FIL format)

### Graphics
- **DRAW.PDM** — Vector graphics editor (.FIG format)

### Communication
- **TELECOM.PDM** — Terminal emulator (modem/serial)
- **PCLINK.PDM** — CompuServe/Tandy online service client

### Multimedia
- **MUSIC.PDM** — 3-channel music composer with digitized instrument samples (.SNG format). Ships with Piano, Clarinet, Bells, Cello, Bass samples.
- **SOUND.PDM** — Digital audio recorder/editor (.SND format). 8-bit at 5500/11000/22000 Hz. Proprietary compression.

### PIM
- **CALENDAR.PDM** — Scheduler with alarm support
- **ADDRBOOK.PDM** — Address/phone book

### Utilities & Games
- **CALC.PDM** — Calculator accessory
- **HANGMAN.PDM** — Word guessing game
- **Dictionary** — Spell checker / word lookup

### Resource Drivers
- **COMPRESS.RES** — Compression routines
- **MEMORY.RES** — Memory management
- **NMUSIC.RES** — New music driver (digitized samples)
- **OMUSIC.RES** — Old music driver (SN76496 square waves)
- **DMEMM.RES** — Extended memory manager
- **DMVSIND.RES** — Video device driver

## Hardware Details

### Tandy Graphics Adapter (TGA)
- Video RAM mapped at segment B800h
- Modes: 160x200x16, 320x200x4, 320x200x16, 640x200x2, 640x200x4

### Tandy Graphics Adapter II (TGA2)
- Present in SL/TL models
- Adds: 640x200x16 (DeskMate 3's default mode on these machines)

### DeskMate 3 Supported Video Adapters
Selectable via DMVID.EXE:
- CGA (640x200x2 / 320x200x4)
- EGA (640x350x16)
- VGA (640x480x16)
- MCGA
- Hercules Monochrome
- Tandy TGA / TGA2

### SN76496 Sound Chip
- 3 square-wave tone channels + 1 noise channel
- I/O port: C0h
- Used by OMUSIC.RES driver

### Tandy DAC
- 8-bit mono digital audio
- Sample rates: 5500, 11000, 22000 Hz
- Used by NMUSIC.RES (instrument playback) and SOUND.PDM (recording/playback)

## File Formats

### .SND (Sound)
- Magic byte: 0x1A
- 16-byte fixed header:
  - Byte 0: ID (0x1A)
  - Byte 1: Compression code (0 = none)
  - Bytes 2-3: Note count (word)
  - Byte 4: Instrument number (0 for sound files, 0xFF for unassigned)
  - Bytes 5-14: Name (10 bytes, null-padded)
  - Bytes 15-16: Sampling rate (word)
- Followed by 28-byte note records, then sample data
- Compression modes: "music" and "speech" (nearly identical algorithms, undocumented)
- Instrument files always at 11000 Hz

### .SNG (Music)
- 3-channel composition data
- References .SND instrument samples
- Backward compatible between Personal DeskMate 2 and DeskMate 3

### .PDM (Program)
- Executable format for DeskMate environment
- Runs inside DESK.EXE host (not standalone)
- INSTALL.PDM mechanism for auto-discovery of third-party apps

### .FIG (Draw)
- Vector graphics format
- Documented in DeskMate Development Guide Appendix A
- "Form Manager" command set in Technical Reference

### .RES (Resources)
- Loadable driver/resource modules
- Video, memory, sound, and compression drivers

## UI Architecture
- Top-of-screen menu bar with dropdown menus (File, Edit, etc.)
- Primarily full-screen applications (not overlapping windows)
- Mouse-driven with full keyboard navigation fallback
- Task switching between DeskMate and DOS applications
- On SL/TL/RL models: portions ROM-resident for instant boot
- Third-party apps integrate via .PDM format and runtime library

## Sources
- [Wikipedia: DeskMate](https://en.wikipedia.org/wiki/DeskMate)
- [Nerdly Pleasures: Tandy DeskMate](http://nerdlypleasures.blogspot.com/2024/07/tandy-deskmate-tandys-ace-in-hole.html)
- [oldskool.org: Tandy 1000 DeskMate](http://www.oldskool.org/guides/tvdog/deskmate.html)
- [WinWorld: Tandy DeskMate 3.x](https://winworldpc.com/product/tandy-deskmate/deskmate-3x)
- [ToastyTech: DeskMate 3.05](http://toastytech.com/guis/deskmate.html)
- [Archive.org: DeskMate 3.05](https://archive.org/details/DOS-GUI-DOS-Tandy-DeskMate-v3.05-1990)
- [DeskMate 3 Manual (PDF)](https://colorcomputerarchive.com/repo/Documents/Manuals/Applications/Deskmate%203%20(Tandy).pdf)
