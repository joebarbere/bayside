; ========================================================================
; DMSSM.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMSSM.RES is the Sound/Music Manager driver for DeskMate 3.05.
; It provides the core sound synthesis and music playback engine that
; other modules (PLAY.PDM, etc.) use to produce audio output on the
; Tandy SN76496 sound chip (port C0h) and PC speaker.
;
; The driver installs as a TSR via INT 21h/31h and registers itself
; with the DeskMate host via INT E0h. It provides:
;   - 3-channel square wave synthesis (SN76496)
;   - Note frequency lookup and channel mixing
;   - Music sequence playback from .SNG format data
;   - Sound effect queuing and prioritization
;   - Cursor/screen driver integration via DMCSR
;
; Version string: "02.09"
;
; DM89 imports: DMCSR (cursor/screen driver)
; Supported video modes: 1000, CGA, DDGA, EGA, HERC, PLAN, TC16, TC4,
;                        VGA, MCGA, LRES, T256, TC40, H
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 6,032 bytes
; Load image: 5,520 bytes (after header)
; DM89 entry point: 0122:0010
; SS:SP = 0159:0002
;
; Segment Map (5 segments, 17 relocations):
;   seg_0000  0x01220 bytes  CODE   Sound engine: synthesis, channel mgmt,
;                                   note lookup, SNG playback, SN76496 I/O
;   seg_0122  0x00080 bytes  CODE   TSR entry point, DM89 registration,
;                                   far-call dispatcher
;   seg_012A  0x002F0 bytes  DATA   Module header ("DMSSM"), version "02.09",
;                                   BSS state, DMCSR/video mode strings
;   seg_0159  0x00010 bytes  STACK  Stack segment
;   seg_015A  0x00000 bytes  BSS    Additional BSS
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; --- Sound Engine (seg_0000) ---
;
; Address     Name                          Description
; -------     ----                          -----------
; 0000:0000   dmssm_dispatch                Main API dispatcher - routes calls by function code
; 0000:002E   dmssm_saveSoundState          Save current sound chip state before API call
; 0000:0060   dmssm_restoreSoundState       Restore sound chip state after API call
; 0000:007E   dmssm_processNoteEvent        Process a note event from music stream
; 0000:00EA   dmssm_parseNoteData           Parse note/instrument data from stream
; 0000:0147   dmssm_outputNoteToChip        Send note frequency data to SN76496 via port C0h
; 0000:0170   dmssm_setupSoundParams        Initialize sound parameters from stream header
; 0000:0195   dmssm_buildFrequencyTable     Build frequency lookup table (256 entries)
; 0000:0204   dmssm_lookupFrequency         Look up frequency value for a note index
; 0000:0216   dmssm_scaleFrequency          Scale frequency by octave/detune value
; 0000:027C   dmssm_mapNoteToRegister       Map note number to SN76496 register address
; 0000:02AC   dmssm_initChannelState        Initialize all channel state to silence
; 0000:02CC   dmssm_setChannelVolume        Set volume for a single channel
; 0000:02E6   dmssm_clearAllChannels        Clear all channel volume/frequency registers
; 0000:02FC   dmssm_getChannelState         Get current channel state (volume + frequency)
; 0000:032C   dmssm_sortChannelPriority     Sort channels by priority for mixing
; 0000:0353   dmssm_mixActiveChannels       Mix active sound channels together
; 0000:0394   dmssm_playSoundEffect         Play a sound effect (handles priority/queuing)
; 0000:03FE   dmssm_sortEffectQueue         Sort sound effect queue by priority
; 0000:0434   dmssm_writeToSN76496          Write value to SN76496 sound chip (port C0h)
; 0000:04A7   dmssm_playMusicSequence       Play music from SNG sequence data
; 0000:05C4   dmssm_advanceMusicStep        Advance to next step in music sequence
; 0000:0656   dmssm_outputToHardware        Low-level hardware output (SN76496/speaker)
; 0000:068A   dmssm_processStreamEvent      Process event from music/sound stream
; 0000:06CE   dmssm_sendRawToChip           Send raw byte sequence to SN76496
; 0000:075A   dmssm_playFromBuffer          Play sound data from memory buffer
; 0000:07EC   dmssm_stopPlayback            Stop all active playback and silence channels
; 0000:0F7A   dmssm_initHardware            Initialize SN76496 hardware, detect capabilities
; 0000:0FCC   dmssm_shutdownHardware        Shutdown SN76496, restore silence
; 0000:10AF   dmssm_enableInterrupts        Enable hardware interrupts (STI wrapper)
; 0000:10B5   dmssm_disableInterrupts       Disable hardware interrupts (CLI wrapper)
; 0000:10BB   dmssm_pushState               Push sound state onto internal stack
; 0000:10D3   dmssm_popState                Pop sound state from internal stack
; 0000:10D9   dmssm_saveChipRegisters       Save SN76496 register state
; 0000:10EB   dmssm_loadDataSegment         Load DS with data segment for callbacks
; 0000:10F1   dmssm_restoreDataSegment      Restore DS after callback
; 0000:10F7   dmssm_setupCallback           Set up callback context for sound events
;
; --- TSR Entry / Registration (seg_0122) ---
;
; 0122:0010   dmssm_tsrEntry                TSR entry: register with DM89 host, go resident
; 0122:0057   dmssm_farCallHandler          Far-call handler for DM89 API dispatch
; 0122:006E   dmssm_checkActiveAndCleanup   Check if sound active, cleanup if not
;
; --- Data Segment (seg_012A) ---
;
; 012A:0002   "DMSSM"                       Module name string
; 012A:000B   "DMSSM"                       Internal module name
; 012A:0052   "02.09"                       Version string
; 012A:029A   "DMCSR"                       DMCSR import reference
; 012A:02A4   Video mode compatibility strings (1000, CGA, DDGA, EGA, etc.)
;
; ========================================================================
; HARDWARE I/O
; ========================================================================
;
; Port C0h  - SN76496 sound chip (write-only)
;             Bits 7-5: Channel select + type (0=tone1, 2=tone2, 4=tone3, 6=noise)
;             Bits 4-0: Frequency/attenuation data
;             Used extensively in dmssm_writeToSN76496 and related functions
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; Sound Channel State (at seg_012A BSS area, per-channel):
;   +0x00  frequency_lo    - Low 4 bits of frequency divider
;   +0x01  frequency_hi    - High 6 bits of frequency divider
;   +0x02  volume          - Attenuation (0=max, 0xF=silence)
;   +0x03  active_flag     - 1 if channel playing, 0 if silent
;
; Frequency Table (at 0000:0058, 256 words):
;   Maps note index (0-255) to SN76496 frequency divider value
;   Built by dmssm_buildFrequencyTable at init time
;
; Music Sequence Pointer:
;   [0x30] current_pos     - Current position in SNG data
;   [0x32] current_pos_hi  - High word of position
;   [0x50] interrupt_flag  - Set when sound chip needs servicing
;   [0x51] callback_flag   - Set when callback pending
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Sound engine code (4,640 bytes)
; seg_0122: TSR entry + DM89 dispatcher (128 bytes)
; seg_012A: Data/BSS (752 bytes)
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/dmssm.asm for complete byte-level listing]
