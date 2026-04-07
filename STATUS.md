# DeskMate 3.05 Reverse Engineering Status

## Legend

| Symbol | Meaning |
|--------|---------|
| :white_large_square: | Not started |
| :construction: | In progress |
| :yellow_circle: | Partially complete |
| :white_check_mark: | Complete |

## Stage 1: Research & Acquisition

| Task | Status | Notes |
|------|--------|-------|
| DeskMate version history documented | :white_check_mark: | See research/docs/ |
| DeskMate 3.05 binaries acquired | :white_check_mark: | archive.org ISO + WinWorld 3.5"/5.25" disk images; 148 files extracted |
| DOSBox config for original | :white_check_mark: | dosbox/configs/deskmate-tandy.conf (Tandy mode, 8086, 4000 cycles) |
| File format documentation | :white_large_square: | .PDM, .SND, .SNG, .FIG, .RES |
| Hardware register documentation | :white_large_square: | TGA, SN76496, DAC |

## Stage 2: Binary Analysis

| Binary | Disassembled | Call Graph | Compiler ID | Notes |
|--------|-------------|------------|-------------|-------|
| DESK.EXE | :white_large_square: | :white_large_square: | :white_large_square: | Main shell |
| DESKTOP.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Desktop UI |
| TEXT.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Word processor |
| WORKSHT.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Spreadsheet |
| FILER.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Database |
| DRAW.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Vector graphics |
| CALENDAR.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Scheduler |
| ADDRESS.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Address book |
| MUSIC.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Music composer |
| SOUND.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Audio editor |
| TELECOM.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Terminal |
| HANGMAN.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Word game |
| PC_LINK.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Online client |
| FORMSET.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Form designer |
| PLAY.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Music player |
| MAILMRGE.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Mail merge |
| DMVID.EXE | :white_large_square: | :white_large_square: | :white_large_square: | Video config |
| *.RES | :white_large_square: | :white_large_square: | :white_large_square: | Resource drivers |

## Stage 3: Annotation

| Module | Functions Labeled | Data Structures | Hardware I/O | Notes |
|--------|------------------|-----------------|--------------|-------|
| DESK.EXE | :white_large_square: | :white_large_square: | :white_large_square: | |
| DESKTOP.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| TEXT.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| WRKSHEET.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| FILER.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| DRAW.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| ADDRESS.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| CALENDAR.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| TELECOM.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| PC_LINK.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| HANGMAN.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| FORMSET.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| PLAY.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| MAILMRGE.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| DMVID.EXE | :white_large_square: | :white_large_square: | :white_large_square: | |
| *.RES | :white_large_square: | :white_large_square: | :white_large_square: | |

## Stage 4: C Transpilation

| Module | Functions | Lines of C | Compiles | Notes |
|--------|-----------|-----------|----------|-------|
| common/ | :white_large_square: | — | :white_large_square: | DOS API, video, sound wrappers |
| desktop/ | :white_large_square: | — | :white_large_square: | Shell + desktop UI |
| text/ | :white_large_square: | — | :white_large_square: | Word processor |
| worksheet/ | :white_large_square: | — | :white_large_square: | Spreadsheet |
| filer/ | :white_large_square: | — | :white_large_square: | Database / file manager |
| draw/ | :white_large_square: | — | :white_large_square: | Vector graphics |
| calendar/ | :white_large_square: | — | :white_large_square: | Scheduler |
| addressbook/ | :white_large_square: | — | :white_large_square: | Address book |
| telecom/ | :white_large_square: | — | :white_large_square: | Terminal emulator |
| pclink/ | :white_large_square: | — | :white_large_square: | Online service client |
| hangman/ | :white_large_square: | — | :white_large_square: | Word game |
| formset/ | :white_large_square: | — | :white_large_square: | Form designer |
| play/ | :white_large_square: | — | :white_large_square: | Music player |
| mailmerge/ | :white_large_square: | — | :white_large_square: | Mail merge |

## Stage 5: Verification

| Module | Runs in DOSBox | Visual Match | File I/O Match | Regression Tests |
|--------|---------------|--------------|----------------|-----------------|
| Shell (DESK.EXE) | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Desktop | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Text | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Worksheet | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Filer | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Draw | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Address Book | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Calendar | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Telecom | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| PC-Link | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Hangman | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Form Set | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Play | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Mail Merge | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
