# Tandy DeskMate 3.05 Archive

Released in 1990 by Tandy Corporation. An integrated office environment and
desktop shell for IBM PC compatibles running DOS, including word processing,
spreadsheet, database, telecommunications, calendar, and drawing applications.

## Sources

### Archive.org
- **URL:** https://archive.org/details/DOS-GUI-DOS-Tandy-DeskMate-v3.05-1990
- **File:** `Tandy_Deskmate_3.05.iso` (3.6 MB) — ISO 9660 image containing 5x 720KB
  3.5" floppy disk images (DISK1.IMG through DISK5.IMG)
- **Downloaded:** 2026-04-06

### WinWorld
- **URL:** https://winworldpc.com/product/tandy-deskmate/deskmate-3x
- **File:** `Tandy_DeskMate_3.05_3.5.7z` (1.0 MB) — 3.5" 720KB disk set (5 disks)
- **File:** `Tandy_DeskMate_3.05_5.25.7z` (1.0 MB) — 5.25" 360KB disk set (9 disks)
- **Downloaded:** 2026-04-06

## Directory Structure

```
Tandy_Deskmate_3.05.iso        — Archive.org ISO image
Tandy_DeskMate_3.05_3.5.7z    — WinWorld 3.5" archive
Tandy_DeskMate_3.05_5.25.7z   — WinWorld 5.25" archive
iso_contents/                   — Raw files from ISO (5x .IMG disk images + readme)
winworld_3.5/                   — Extracted WinWorld 3.5" archive (5x .IMG)
winworld_5.25/                  — Extracted WinWorld 5.25" archive (9x .IMG)
extracted/                      — All DOS binaries extracted from disk images
```

## Key Binaries (in extracted/)

| File | Size | Description |
|------|------|-------------|
| DESK.EXE | 19,047 | DeskMate main executable / shell |
| DMVID.EXE | 16,477 | DeskMate video driver loader |
| INSTALL.EXE | 828 | Installer stub |
| DESKTOP.PDM | 72,681 | Desktop manager module |
| CALENDAR.PDM | 72,593 | Calendar application |
| TEXT.PDM | 75,185 | Word processor |
| DRAW.PDM | 78,256 | Drawing application |
| WRKSHEET.PDM | 59,590 | Spreadsheet |
| ADDRESS.PDM | 61,025 | Address book / database |
| FILER.PDM | 40,081 | File manager |
| FORMSET.PDM | 60,163 | Form designer |
| TELECOM.PDM | 35,661 | Telecommunications |
| PC_LINK.PDM | 72,087 | PC-Link communications |
| HANGMAN.PDM | 27,027 | Hangman game |
| PLAY.PDM | 12,183 | Music player |
| MAILMRGE.PDM | 21,333 | Mail merge |
| INSTALL.PDM | 27,235 | Installer module |

## File Types

- **.EXE** — DOS executables
- **.PDM** — DeskMate Program/Desktop Modules (the main applications)
- **.ACC** — DeskMate Accessories (desk accessories / TSR-like modules)
- **.RES** — Resource files (video drivers, printer drivers, fonts, UI resources)
- **.HLP** — Help files
- **.TUT** — Tutorial files
- **.R89** — Resource files (1989 format variant)
- **.CFG** — Configuration files
- **.SPL** — Spelling dictionary
- **.PCL** — Printer control language files
- **.FIL** — Sample database files
- **.WKS** — Sample worksheet files
- **.FF1** — Font files
- **.RFD** — Printer driver definition files
- **.MOD** — Module/compatibility files

## Extracted File Count

148 files totaling approximately 2.8 MB across all 5 distribution disks.

## Notes

- The Archive.org and WinWorld 3.5" sets are identical (same 5x 720KB disk images).
- The WinWorld 5.25" set contains 9x 360KB disk images with the same content
  spread across more disks.
- These files are preserved as abandonware for historical research and
  reverse engineering purposes.
