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
| DeskMate 3.05 binaries acquired | :white_large_square: | Check archive.org / WinWorld |
| DOSBox config for original | :white_large_square: | |
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
| ADDRBOOK.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Contacts |
| MUSIC.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Music composer |
| SOUND.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Audio editor |
| TELECOM.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Terminal |
| CALC.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Calculator |
| HANGMAN.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Word game |
| PCLINK.PDM | :white_large_square: | :white_large_square: | :white_large_square: | Online client |
| DMVID.EXE | :white_large_square: | :white_large_square: | :white_large_square: | Video config |
| *.RES | :white_large_square: | :white_large_square: | :white_large_square: | Resource drivers |

## Stage 3: Annotation

| Module | Functions Labeled | Data Structures | Hardware I/O | Notes |
|--------|------------------|-----------------|--------------|-------|
| DESK.EXE | :white_large_square: | :white_large_square: | :white_large_square: | |
| DESKTOP.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| TEXT.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| WORKSHT.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| FILER.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| DRAW.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| MUSIC.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |
| SOUND.PDM | :white_large_square: | :white_large_square: | :white_large_square: | |

## Stage 4: C Transpilation

| Module | Functions | Lines of C | Compiles | Notes |
|--------|-----------|-----------|----------|-------|
| common/ | :white_large_square: | — | :white_large_square: | DOS API, video, sound wrappers |
| desktop/ | :white_large_square: | — | :white_large_square: | Shell + desktop UI |
| text/ | :white_large_square: | — | :white_large_square: | Word processor |
| worksheet/ | :white_large_square: | — | :white_large_square: | Spreadsheet |
| filer/ | :white_large_square: | — | :white_large_square: | Database |
| draw/ | :white_large_square: | — | :white_large_square: | Vector graphics |
| calendar/ | :white_large_square: | — | :white_large_square: | Scheduler |
| addressbook/ | :white_large_square: | — | :white_large_square: | Contacts |
| music/ | :white_large_square: | — | :white_large_square: | Music composer |
| sound/ | :white_large_square: | — | :white_large_square: | Audio editor |
| calculator/ | :white_large_square: | — | :white_large_square: | Calculator |
| hangman/ | :white_large_square: | — | :white_large_square: | Word game |

## Stage 5: Verification

| Module | Runs in DOSBox | Visual Match | File I/O Match | Regression Tests |
|--------|---------------|--------------|----------------|-----------------|
| Shell | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Desktop | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Text | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Worksheet | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Draw | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Music | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
| Sound | :white_large_square: | :white_large_square: | :white_large_square: | :white_large_square: |
