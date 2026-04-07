#!/usr/bin/env python3
"""
Annotate RES module disassembly files for the Bayside project.
Generates fully annotated disassembly with function names, descriptions,
and structural documentation following the filer.asm annotation style.
"""

import re
import sys
import os

# ============================================================================
# Module definitions
# ============================================================================

MODULES = {
    "alarm": {
        "input": "alarm.asm",
        "output": "alarm.asm",
        "title": "ALARM.RES",
        "prefix": "alarm",
        "description": """ALARM.RES is the alarm/timer service for DeskMate 3.05.
; It manages scheduled alarms for the Calendar application and plays alert
; sounds when alarms fire. The module installs as a TSR (Terminate and Stay
; Resident) and hooks several interrupt vectors to monitor system time.
;
; When an alarm time is reached, ALARM.RES triggers an audible alert (bell
; character via INT 10h) and can display notification messages. It maintains
; an ordered list of up to 20 pending alarms sorted by trigger time.
;
; The module reads alarm configuration from ALARM.CFG (located via the
; DESKMATE environment variable) and supports both one-shot and recurring
; alarm types ('A' = add alarm, 'D' = delete alarm, 'C' = clear all).
;
; DM89 imports: INT E0h (DeskMate host API)
; Hooks: INT 00h, INT 1Ch (timer tick), INT 28h (DOS idle), INT 13h (disk),
;        INT 10h (video), INT E9h, INT 1Ah (time of day)""",
        "functions": {
            "sub_0000_0000": ("alarm_interruptVectorTable", "Saved interrupt vector table (00h/1Ch/28h/13h/10h/E9h/1Ah)"),
            "sub_0000_002C": ("alarm_getDTA", "Get current DTA address via INT 21h/2Fh"),
            "sub_0000_0035": ("alarm_checkKeyboard", "Check keyboard buffer, call INT 28h idle if empty"),
            "sub_0000_013B": ("alarm_registerWithHost", "Register ALARM module name with DM89 host via INT E0h/02h"),
            "sub_0000_01CA": ("alarm_saveInterruptVectors", "Save original interrupt vectors (00h,1Ch,28h,13h,10h,E9h,1Ah)"),
            "sub_0000_025D": ("alarm_saveStackContext", "Save SS, DS, and SP for interrupt handler restoration"),
            "sub_0000_028F": ("alarm_beep", "Sound alert beep via INT 10h/0Eh (BEL character)"),
            "sub_0000_02A0": ("alarm_getInDOSFlag", "Get DOS InDOS flag address via INT 21h/34h"),
            "sub_0000_02BA": ("alarm_findResident", "Find resident module via INT E0h/02h name lookup"),
            "sub_0000_031A": ("alarm_readFile", "Read file via INT 21h/3Fh (handle, far ptr, count, bytes_read)"),
            "sub_0000_0337": ("alarm_openFile", "Open file via INT 21h/3Dh (filename, mode, handle_out)"),
            "sub_0000_034F": ("alarm_closeFile", "Close file via INT 21h/3Eh (handle)"),
            "sub_0000_0380": ("alarm_memcpyReverse", "Copy memory block in reverse (overlapping safe, far ptrs)"),
            "sub_0000_03A8": ("alarm_notifyHost", "Notify DeskMate host of alarm event via INT E0h/02h"),
            "sub_0000_03B8": ("alarm_processMessage", "Process incoming alarm message (G=set, c=clear, other=update)"),
            "sub_0000_0493": ("alarm_dispatchCommand", "Dispatch alarm command: A=add, D=delete, C=clear+add"),
            "sub_0000_06EE": ("alarm_installTSR", "Install alarm TSR: register with host, hook vectors, go resident"),
            "sub_0000_07CD": ("alarm_addAlarmFromRecord", "Add alarm from Calendar record (parse time, insert into list)"),
            "sub_0000_0839": ("alarm_insertAlarm", "Insert alarm into sorted alarm list at correct position"),
            "sub_0000_08F1": ("alarm_deleteAlarmByRecord", "Delete alarm matching Calendar record from alarm list"),
            "sub_0000_098D": ("alarm_clearAllAlarms", "Clear all alarms (set alarm count to 0)"),
            "sub_0000_0994": ("alarm_removeAlarmByIndex", "Remove alarm at given index, shift remaining entries"),
            "sub_0000_09DD": ("alarm_encodeTime", "Encode day-of-week + quarter-hour into 32-bit tick count"),
            "sub_0000_0C98": ("alarm_checkAlreadyLoaded", "Check if ALARM.RES is already loaded via INT E9h vector"),
            "sub_0000_0CEB": ("alarm_getEnvVariable", "Get DeskMate environment variable value from environment block"),
            "sub_0000_0D3F": ("alarm_matchEnvKey", "Match environment key=value pair, copy value if found"),
            "sub_0000_0DA0": ("alarm_formatOutput", "Format alarm output string via printf-like formatting"),
            "sub_0000_0F08": ("alarm_unhookAtExit", "Restore original interrupt vectors on exit/unload"),
            "sub_0000_0F21": ("alarm_callInitList", "Call near initialization function list (atexit-style, backward)"),
            "sub_0000_0F30": ("alarm_callFarInitList", "Call far initialization function list (backward)"),
            "sub_0000_0FAC": ("alarm_registerHostCallbacks", "Register alarm callback handlers with DeskMate host"),
            "sub_0000_0FC5": ("alarm_unregisterCallbacks", "Unregister alarm callbacks from DeskMate host"),
            "sub_0000_100A": ("alarm_callHostFunction", "Call DeskMate host function via indirect far call dispatch"),
            "sub_0000_1132": ("alarm_fatalError", "Fatal error handler - write error message, terminate"),
            "sub_0000_1158": ("alarm_verifyChecksum", "Verify code integrity checksum (XOR 0x55 over 0x42 bytes)"),
            "sub_0000_1308": ("alarm_lookupMessage", "Look up error message string by ID in message table"),
            "sub_0000_1333": ("alarm_writeMessage", "Write message string to stderr (handle 2)"),
            "sub_0000_135C": ("alarm_allocNear", "Allocate near memory from heap, resize PSP if needed"),
            "sub_0000_139E": ("alarm_strcat", "String concatenation (append src to dest)"),
            "sub_0000_13DE": ("alarm_strcpy", "String copy (dest, src)"),
            "sub_0000_1410": ("alarm_strcmp", "String comparison (returns 0 if equal, -1/1 otherwise)"),
            "sub_0000_143C": ("alarm_strlen", "String length (returns character count)"),
            "sub_0000_1458": ("alarm_strncpy", "String copy with max length (dest, src, maxlen)"),
            "sub_0000_1480": ("alarm_strncmp", "String comparison with max length (s1, s2, maxlen)"),
            "sub_0000_14BA": ("alarm_printf", "Formatted output (printf-like, writes to stream)"),
            "sub_0000_1524": ("alarm_memcpy", "Memory copy (far src/dest, count) via rep movsb"),
            "sub_0000_1542": ("alarm_getCurrentDateTime", "Get current date/time as 32-bit day+time value"),
            "sub_0000_1594": ("alarm_strchr", "Find character in string (returns pointer or 0)"),
            "sub_0000_15BE": ("alarm_getKey", "Get keyboard input via INT 16h"),
            "sub_0000_15D2": ("alarm_getInterruptVector", "Get interrupt vector via INT 21h/35h"),
            "sub_0000_15E4": ("alarm_terminateResident", "Terminate and stay resident via INT 21h/31h"),
            "sub_0000_15F6": ("alarm_setInterruptVector", "Set interrupt vector via INT 21h/25h"),
            "sub_0000_160C": ("alarm_divSigned32", "Signed 32-bit division (dividend/divisor -> quotient)"),
            "sub_0000_16A8": ("alarm_mulUnsigned32", "Unsigned 32-bit multiplication"),
            "sub_0000_16DC": ("alarm_divUnsigned32", "Unsigned 32-bit division"),
            "sub_0000_173E": ("alarm_fwrite", "Write data to file stream (buffered output)"),
            "sub_0000_187A": ("alarm_flushAndWrite", "Flush stream buffer and write character"),
            "sub_0000_19D0": ("alarm_openStreamBuffer", "Open/initialize stream buffer for writing"),
            "sub_0000_1A54": ("alarm_closeStream", "Close output stream, flush remaining data"),
            "sub_0000_1AEA": ("alarm_dateToTicks", "Convert date (year,month,day,hour,min,sec) to tick count"),
            "sub_0000_1C00": ("alarm_allocStreamBuffer", "Allocate buffer for file stream I/O"),
            "sub_0000_1C6C": ("alarm_flushStream", "Flush stream buffer to disk"),
            "sub_0000_1CDA": ("alarm_seekFile", "Seek file position via INT 21h/42h"),
            "sub_0000_1D54": ("alarm_writeToFile", "Low-level write to file handle (INT 21h/40h)"),
            "sub_0000_1DFA": ("alarm_writeRawBytes", "Write raw bytes to file, handle errors"),
            "sub_0000_1E7C": ("alarm_isDeviceHandle", "Check if file handle is a device (IOCTL flag 0x40)"),
            "sub_0000_1EA0": ("alarm_initAlarmConfig", "Initialize alarm config (parse ALARM.CFG once)"),
            "sub_0000_1EB0": ("alarm_parseAlarmConfig", "Parse ALARM.CFG - read repeat interval and sound file"),
            "sub_0000_1F60": ("alarm_validateLeapYear", "Validate date considering leap year rules"),
            "sub_0000_202A": ("alarm_memcpyForward", "Forward memory copy (aligned, optimized with word moves)"),
            "sub_0000_207C": ("alarm_setDOSError", "Set DOS error code from INT 21h result"),
            "sub_0000_20DC": ("alarm_stackAvail", "Check available stack space"),
            "sub_0000_2100": ("alarm_malloc", "C library malloc - allocate memory from heap"),
            "sub_0000_2146": ("alarm_atol", "Convert ASCII string to long integer (atol)"),
            "sub_0000_2163": ("alarm_heapAlloc", "Internal heap allocator (first-fit free list)"),
            "sub_0000_2246": ("alarm_heapGrow", "Grow heap by allocating more DOS memory"),
            "sub_0000_2280": ("alarm_heapSplit", "Split heap block and update free list"),
            "sub_0000_22A2": ("alarm_sbrk", "sbrk - extend heap via INT 21h/48h or 4Ah"),
            "sub_0000_2316": ("alarm_heapExtend", "Extend heap segment (near or far heap)"),
            "sub_0000_2384": ("alarm_findHeapSegment", "Find heap segment with enough space"),
            "sub_023D_0000": ("alarm_updateHeapTop", "Update heap top pointer after allocation"),
        },
        "globals": {
            "[0x0072]": ("g_alarmCount_word", "Number of alarms (word copy of byte at 0x76)"),
            "[0x0074]": ("g_pendingAlarmCount", "Number of pending alarms in sorted list (max 20)"),
            "[0x0076]": ("g_alarmConfigBuffer", "Alarm configuration buffer (128 bytes from ALARM.CFG)"),
            "[0x0100]": ("g_hostCallbackPtr", "Pointer to host callback function"),
            "[0x0114]": ("g_soundCounter", "Sound repeat counter (cycles 0-8)"),
            "[0x0684]": ("g_currentTicks_lo", "Current system time in ticks (low word)"),
            "[0x0686]": ("g_currentTicks_hi", "Current system time in ticks (high word)"),
            "[0x0892]": ("g_configPathPtr", "Pointer to DESKMATE config path string"),
            "[0x0A98]": ("g_alarmTimeArray", "Array of alarm trigger times (20 entries x 125 bytes)"),
            "[0x16A0]": ("g_savedSS", "Saved SS register for interrupt context"),
            "[0x16A6]": ("g_savedSP", "Saved SP register for interrupt context"),
            "[0x18AE]": ("g_biosTickPtr", "Far pointer to BIOS tick counter (0040:006C)"),
        },
    },
    "alrminit": {
        "input": "alrminit.asm",
        "output": "alrminit.asm",
        "title": "ALRMINIT.RES",
        "prefix": "alrminit",
        "description": """ALRMINIT.RES is the alarm initialization module for DeskMate 3.05.
; It sets up the alarm TSR hooks and timer interrupt handlers that
; ALARM.RES depends on. This module is loaded first to prepare the
; interrupt chain and memory structures before ALARM.RES goes resident.
;
; The module hooks INT vectors for timer tick monitoring, saves original
; vectors for chain-through, and initializes the shared data area that
; ALARM.RES uses for alarm scheduling and notification.
;
; DM89 imports: INT E0h (DeskMate host API)
; Hooks: INT 25h (set vector), INT 35h (get vector)""",
        "functions": {
            "sub_0000_0000": ("alrminit_dispatchTable", "INT E0h dispatch table (3 entry points for host callbacks)"),
            "sub_0000_0010": ("alrminit_initModule", "Initialize alarm module - register with host, set up handlers"),
            "sub_0000_006C": ("alrminit_parseConfig", "Parse alarm configuration from ALARM.CFG"),
            "sub_0000_0095": ("alrminit_setAlarmInterval", "Set alarm check interval (timer tick divisor)"),
            "sub_0000_00B9": ("alrminit_setSoundFile", "Set alarm sound filename for playback"),
            "sub_0000_00E6": ("alrminit_processAlarmEvent", "Process alarm event (check/fire/snooze)"),
            "sub_0000_014B": ("alrminit_installHooks", "Install interrupt hooks and register with DM89 host"),
            "sub_0000_01F1": ("alrminit_uninstallHooks", "Uninstall interrupt hooks, restore original vectors"),
            "sub_0000_0224": ("alrminit_getAlarmList", "Get pointer to current alarm list"),
            "sub_0000_0269": ("alrminit_addAlarm", "Add new alarm entry to the alarm list"),
            "sub_0000_029C": ("alrminit_removeAlarm", "Remove alarm entry from the alarm list"),
            "sub_0000_02DB": ("alrminit_checkAlarmTime", "Check if current time matches any alarm trigger time"),
            "sub_0000_0343": ("alrminit_fireAlarm", "Fire alarm - play sound, show notification"),
            "sub_0000_03A2": ("alrminit_updateTimestamp", "Update last-checked timestamp to current time"),
            "sub_0000_044A": ("alrminit_readConfigFile", "Read and parse alarm configuration file"),
            "sub_0000_04A4": ("alrminit_parseConfigLine", "Parse single line from alarm config file"),
            "sub_0000_0516": ("alrminit_parseTimeString", "Parse time string (HH:MM format) into tick value"),
            "sub_0000_059B": ("alrminit_parseDateString", "Parse date string (MM/DD/YYYY) into day value"),
            "sub_0000_0612": ("alrminit_validateAlarm", "Validate alarm entry (check time range, no duplicates)"),
            "sub_0000_0661": ("alrminit_writeConfigFile", "Write alarm configuration back to file"),
            "sub_0000_0695": ("alrminit_entryPoint", "Module entry point - DM89 RES initialization"),
            "sub_0000_06EC": ("alrminit_mainInit", "Main initialization sequence for ALRMINIT module"),
            "sub_0000_081D": ("alrminit_setupInterrupts", "Set up interrupt vector hooks (timer, idle, disk)"),
            "sub_0000_0992": ("alrminit_hookTimerTick", "Hook INT 1Ch (timer tick) for alarm checking"),
            "sub_0000_09AB": ("alrminit_setVector", "Set interrupt vector (wrapper for INT 21h/25h)"),
            "sub_0000_09BA": ("alrminit_restoreVector", "Restore original interrupt vector"),
            "sub_0000_0A36": ("alrminit_allocSharedArea", "Allocate shared data area for ALARM.RES communication"),
            "sub_0000_0B06": ("alrminit_getModuleInfo", "Get module information structure"),
            "sub_0000_0B0C": ("alrminit_getVersion", "Get ALRMINIT version string"),
            "sub_0000_0B12": ("alrminit_hostCallback", "INT E0h host callback dispatcher (called 10+ times)"),
            "sub_0000_0B5C": ("alrminit_resizeMemory", "Resize memory block via INT 21h/4Ah"),
            "sub_0000_0B6A": ("alrminit_getCurrentTime", "Get current system time (date + time of day)"),
            "sub_0000_0B97": ("alrminit_exitWithCode", "Exit with return code via INT 21h/4Ch"),
            "sub_0000_0BA4": ("alrminit_exitSuccess", "Exit successfully (return code 0)"),
            "sub_0000_0BC7": ("alrminit_allocMemory", "Allocate memory via INT 21h/4Ah"),
            "sub_0000_0BE5": ("alrminit_setupDataSegment", "Set up data segment and BSS initialization"),
            "sub_0000_0D54": ("alrminit_crtStartup", "MSC 5.x CRT startup code (recursive self-call pattern)"),
            "sub_0000_0FB6": ("alrminit_ioctl", "IOCTL call via INT 21h/44h"),
            "sub_0000_10F0": ("alrminit_writeFile", "Write to file via INT 21h/40h"),
            "sub_0000_1116": ("alrminit_intE0hCall", "INT E0h call wrapper (called from 23 locations)"),
            "sub_0000_112C": ("alrminit_closeAndWrite", "Close file and write final data"),
            "sub_0000_12DC": ("alrminit_lookupMessage", "Look up error message by ID"),
            "sub_0000_1307": ("alrminit_writeToStderr", "Write message to stderr (handle 2)"),
            "sub_0000_1330": ("alrminit_seekFile", "Seek file position via INT 21h/42h"),
            "sub_0000_1372": ("alrminit_getEnvValue", "Get environment variable value"),
            "sub_0000_13B2": ("alrminit_getConfigPath", "Get DESKMATE config directory path"),
            "sub_0000_13E4": ("alrminit_buildFilePath", "Build full file path from config dir + filename"),
            "sub_0000_1400": ("alrminit_parseEnvironment", "Parse environment block for PATH= entries"),
            "sub_0000_1494": ("alrminit_dateToTicks", "Convert date components to tick count"),
            "sub_0000_14FC": ("alrminit_timeToTicks", "Convert time components (H:M:S) to tick count"),
            "sub_0000_154E": ("alrminit_strcat", "String concatenation"),
            "sub_0000_1590": ("alrminit_parseTimeField", "Parse time field from config string"),
            "sub_0000_15BC": ("alrminit_getDateTime", "Get current date and time via DOS"),
            "sub_0000_15EE": ("alrminit_exitCleanup", "Exit cleanup - restore vectors, free memory"),
            "sub_0000_15F4": ("alrminit_terminateResident", "Go TSR via INT 21h/31h"),
            "sub_0000_1622": ("alrminit_formatDateTime", "Format date/time components for output"),
            "sub_0000_17CC": ("alrminit_mulUnsigned32", "Unsigned 32-bit multiply"),
            "sub_0000_17DC": ("alrminit_dateToDayCount", "Convert date to absolute day count"),
            "sub_0000_188C": ("alrminit_divUnsigned32", "Unsigned 32-bit divide"),
            "sub_0000_1956": ("alrminit_ticksToTime", "Convert tick count back to time components"),
            "sub_0000_1A6C": ("alrminit_daysInMonth", "Get days in month (leap year aware)"),
            "sub_0000_1A94": ("alrminit_isLeapYear", "Check if year is leap year"),
            "sub_0000_1A98": ("alrminit_divSigned32", "Signed 32-bit divide (called from 4 locations)"),
            "sub_0000_1B34": ("alrminit_modUnsigned32", "Unsigned 32-bit modulo"),
            "sub_0000_1B68": ("alrminit_formatNumber", "Format number as decimal string"),
            "sub_0000_1C0A": ("alrminit_formatField", "Format date/time field with padding"),
        },
        "globals": {},
    },
    "spell": {
        "input": "spell.asm",
        "output": "spell.asm",
        "title": "SPELL.RES",
        "prefix": "spell",
        "description": """SPELL.RES is the spell checker interface module for DeskMate 3.05.
; It provides the user-facing spell checking UI, dictionary management,
; and word validation used by the Text word processor. It also provides
; word list services used by Hangman's profanity filter.
;
; The module manages two dictionaries: DICT.SPL (the main read-only
; dictionary) and USERDICT.SPL (user-added words). It presents dialogs
; for unknown words, suggested corrections ("Alternates"), and options
; to add words to the user dictionary.
;
; SPELL.RES works as a front-end that delegates actual dictionary
; searching to SPL.RES (the core spell engine) via INT 15h/70h calls.
;
; Key UI elements:
;   - "Spell Checker" main dialog
;   - "Spell Checker Correction" dialog with alternates list
;   - "Check Unknown Word" option
;   - "Add to Dictionary" (Ctrl+A)
;   - "Restore Context" (Ctrl+R)
;
; DM89 imports: PRGUF, DMGUF, DMCSR, AUTOLOAD
; Dependencies: SPL.RES (dictionary engine), DICT.SPL, USERDICT.SPL""",
        "functions": {
            "sub_0000_0000": ("spell_dispatchTable", "Spell checker function dispatch table (12 entry points)"),
            "sub_0000_0F7F": ("spell_checkDocument", "Check entire document for spelling - main spell check loop"),
            "sub_0000_0FAF": ("spell_initChecker", "Initialize spell checker state (load dictionaries)"),
            "sub_0000_0FBD": ("spell_registerCallbacks", "Register 3 callback functions with host via INT E0h"),
            "sub_0000_0FE3": ("spell_callHostDispatch", "Call host dispatch entry (INT E0h callback)"),
            "sub_0000_0FEC": ("spell_cleanup", "Clean up spell checker state on exit"),
            "sub_0000_10AD": ("spell_mainEventLoop", "Main spell checking event loop (process words, show dialogs)"),
            "sub_0000_11A6": ("spell_handleAddWord", "Handle 'Add to Dictionary' action"),
            "sub_0000_11C1": ("spell_handleCorrection", "Handle word correction/replacement"),
            "sub_0000_11E1": ("spell_handleSkip", "Handle skip/ignore unknown word"),
            "sub_0000_12E2": ("spell_showAlternates", "Show alternate spelling suggestions dialog"),
            "sub_0000_131B": ("spell_lookupWord", "Look up word in dictionary via SPL.RES"),
            "sub_0000_1326": ("spell_getSuggestions", "Get spelling suggestions for unknown word"),
            "sub_0000_1335": ("spell_validateWord", "Validate a single word against dictionary"),
            "sub_0000_1351": ("spell_callEngine", "Call SPL.RES engine function via INT 15h/70h (3 callers)"),
            "sub_0000_14CE": ("spell_getCallbackA", "Get callback function pointer A"),
            "sub_0000_14D4": ("spell_getCallbackB", "Get callback function pointer B"),
            "sub_0000_14DA": ("spell_getCallbackC", "Get callback function pointer C"),
            "sub_0000_14E0": ("spell_getCallbackD", "Get callback function pointer D"),
            "sub_0000_14EC": ("spell_getCallbackE", "Get callback function pointer E"),
            "sub_0000_14F8": ("spell_getCallbackF", "Get callback function pointer F"),
            "sub_0000_14FE": ("spell_getCallbackG", "Get callback function pointer G"),
            "sub_0000_150A": ("spell_getCallbackH", "Get callback function pointer H"),
            "sub_0000_1510": ("spell_savePSP", "Save/restore PSP segment (INT 21h/50h,51h)"),
            "sub_0000_160A": ("spell_intE0hDispatch", "INT E0h dispatch handler (3 sub-functions)"),
            "sub_0000_169E": ("spell_savePSPContext", "Save PSP context for interrupt safety"),
            "sub_0000_16A4": ("spell_restorePSPContext", "Restore PSP context after callback"),
            "sub_0000_16C2": ("spell_getSystemTime", "Get system time via INT 21h/2Ch"),
            "sub_0000_172A": ("spell_intE0hCall", "INT E0h API call wrapper (4 call sites)"),
            "sub_018A_0000": ("spell_crtResizeMemory", "MSC CRT memory resize (INT 21h/4Ah)"),
            "sub_018A_00B8": ("spell_crtAllocMemory", "MSC CRT allocate memory block"),
            "sub_018A_00CA": ("spell_crtStartup", "MSC 5.x CRT startup sequence for RES module"),
        },
        "globals": {
            "[0x006C]": ("g_wordBuffer", "Current word buffer (108 bytes)"),
            "[0x0091]": ("g_wordLength", "Length of current word"),
            "[0x0093]": ("g_wordOffset", "Offset of current word in document"),
            "[0x0095]": ("g_spellState", "Spell checker state structure"),
            "[0x00A4]": ("g_suggestionCount", "Number of spelling suggestions"),
            "[0x00AA]": ("g_dictFilePtr", "Pointer to dictionary file handle"),
            "[0x00F9]": ("g_checkingActive", "Flag: spell checking is active"),
            "[0x011F]": ("g_backslashStr", "Backslash character string"),
        },
    },
    "spl": {
        "input": "spl.asm",
        "output": "spl.asm",
        "title": "SPL.RES",
        "prefix": "spl",
        "description": """SPL.RES is the spell checker core engine for DeskMate 3.05.
; It implements the actual dictionary search and word suggestion algorithms
; that SPELL.RES calls through INT 15h/70h. This is the largest spell
; checking module, containing the compressed dictionary access routines,
; phonetic matching, and edit-distance suggestion generation.
;
; The dictionary (DICT.SPL) uses a compressed trie/DAG structure to
; minimize disk and memory usage. SPL.RES reads dictionary pages on
; demand via INT 21h/3Fh and caches recently accessed pages in memory.
;
; Key algorithms:
;   - Trie traversal for exact word lookup
;   - Phonetic encoding (Soundex-like) for similar word suggestions
;   - Edit distance calculation for near-miss corrections
;   - User dictionary management (add/remove words)
;
; DM89 imports: INT E0h (host API), INT 6Bh (unknown)
; File I/O: INT 21h/3Fh (read), INT 21h/42h (seek)
; Memory: INT 21h/48h (alloc), INT 21h/49h (free)""",
        "functions": {
            "sub_011D_0000": ("spl_allocDictMemory", "Allocate memory for dictionary page cache"),
            "sub_011D_002B": ("spl_initEngine", "Initialize spell engine (open dict, alloc buffers)"),
            "sub_011D_00A1": ("spl_shutdownEngine", "Shutdown spell engine (close files, free memory)"),
            "sub_011D_00FD": ("spl_decompressPage", "Decompress dictionary page (8 recursive calls - trie expansion)"),
            "sub_011D_024C": ("spl_openDictionary", "Open DICT.SPL dictionary file"),
            "sub_011D_02A0": ("spl_readDictPage", "Read dictionary page from file (recursive page walk)"),
            "sub_011D_0373": ("spl_seekDictOffset", "Seek to offset in dictionary file (2 callers)"),
            "sub_011D_03C6": ("spl_lookupWordExact", "Exact word lookup in dictionary trie (6 callers)"),
            "sub_011D_03CE": ("spl_trieTraverse", "Traverse dictionary trie for word matching"),
            "sub_011D_048D": ("spl_lookupWordPrefix", "Prefix lookup in dictionary (6 callers)"),
            "sub_011D_0495": ("spl_triePrefixWalk", "Walk trie for prefix matching"),
            "sub_011D_0524": ("spl_openUserDict", "Open user dictionary (USERDICT.SPL)"),
            "sub_011D_0683": ("spl_readUserDict", "Read user dictionary entries into memory (3 callers)"),
            "sub_011D_077F": ("spl_compareWords", "Compare two words (case-insensitive, 2 callers)"),
            "sub_011D_0790": ("spl_toLowerCase", "Convert string to lowercase (recursive)"),
            "sub_011D_07FF": ("spl_matchWord", "Match word against dictionary entry (3 callers)"),
            "sub_011D_0821": ("spl_checkWordInDict", "Check if word exists in dictionary (11 callers)"),
            "sub_011D_082B": ("spl_searchDictTrie", "Search dictionary trie for exact match (9 callers)"),
            "sub_011D_0874": ("spl_getCharType", "Get character type/class (letter, digit, punct) - 3 callers"),
            "sub_011D_087C": ("spl_isWordChar", "Check if character is word-constituent"),
            "sub_011D_0884": ("spl_nextDictEntry", "Advance to next dictionary entry (18 callers - most called)"),
            "sub_011D_088C": ("spl_addToSuggestions", "Add word to suggestion list (5 callers)"),
            "sub_011D_08A7": ("spl_addExactMatch", "Add exact match to results (5 callers)"),
            "sub_011D_08C1": ("spl_clearSuggestions", "Clear suggestion list"),
            "sub_011D_0979": ("spl_generateSuggestions", "Generate spelling suggestions (edit distance, 5 callers)"),
            "sub_011D_0A04": ("spl_editDistance", "Calculate edit distance between words"),
            "sub_011D_0ACF": ("spl_trySingleEdits", "Try single-edit corrections (insert/delete/replace/swap)"),
            "sub_011D_0C1E": ("spl_tryDoubleEdits", "Try double-edit corrections"),
            "sub_011D_0C9A": ("spl_tryPhoneticMatch", "Try phonetic matching (Soundex-like)"),
            "sub_011D_0D50": ("spl_phoneticallyEncode", "Phonetically encode word for matching"),
            "sub_011D_1554": ("spl_checkSpelling", "Top-level spell check function (check word, get suggestions)"),
            "sub_011D_1771": ("spl_addToUserDict", "Add word to user dictionary"),
            "sub_011D_181A": ("spl_removeFromUserDict", "Remove word from user dictionary"),
            "sub_011D_18EE": ("spl_getUserDictWords", "Get words from user dictionary (iterate entries)"),
            "sub_011D_210A": ("spl_saveUserDict", "Save user dictionary to disk"),
            "sub_011D_2198": ("spl_mergeUserDict", "Merge user dictionary with main dictionary lookups"),
            "sub_011D_2226": ("spl_checkWordWithUser", "Check word against both main and user dictionaries"),
            "sub_011D_23A6": ("spl_sortSuggestions", "Sort suggestion list by relevance/distance"),
            "sub_011D_2448": ("spl_rankSuggestion", "Rank/score a single suggestion"),
            "sub_011D_24CA": ("spl_getSuggestionAt", "Get suggestion at index from list"),
            "sub_011D_24F1": ("spl_getSuggestionCount", "Get total count of suggestions"),
            "sub_011D_2606": ("spl_int15hHandler", "INT 15h/70h handler - spell engine API entry point"),
            "sub_011D_276C": ("spl_apiDispatch", "API dispatch for spell engine commands"),
        },
        "globals": {},
    },
    "protocol": {
        "input": "protocol.asm",
        "output": "protocol.asm",
        "title": "PROTOCOL.RES",
        "prefix": "protocol",
        "description": """PROTOCOL.RES is the file transfer protocol module for DeskMate 3.05.
; It implements XMODEM and YMODEM file transfer protocols used by the
; Telecom terminal emulator (TELECOM.PDM) for sending and receiving
; files over serial connections.
;
; The module handles the full protocol state machine including:
;   - XMODEM: 128-byte blocks, checksum or CRC-16 error detection
;   - YMODEM: 1024-byte blocks, batch file transfer, CRC-16
;   - Packet framing (SOH/STX/EOT/ACK/NAK/CAN)
;   - Timeout and retry logic
;   - Flow control coordination with the serial port driver
;
; The module communicates with TELECOM.PDM through a callback interface
; for serial I/O operations (send byte, receive byte, check ready).
;
; DM89 imports: INT E0h (DeskMate host API)
; Uses: INT 1Ah (timer), INT 21h for file I/O""",
        "functions": {
            "sub_0000_0000": ("protocol_dispatchTable", "Protocol function dispatch table (7 entries)"),
            "sub_0000_00EE": ("protocol_mainHandler", "Main protocol handler - dispatch send/receive commands"),
            "sub_0000_03E7": ("protocol_initState", "Initialize protocol state machine"),
            "sub_0000_040B": ("protocol_cleanupState", "Clean up protocol state on completion/abort"),
            "sub_0000_0497": ("protocol_getTimerTick", "Get timer tick count via INT 1Ah for timeouts"),
            "sub_0000_049F": ("protocol_waitWithTimeout", "Wait for event with timeout (recursive retry)"),
            "sub_0000_0534": ("protocol_checkTimeout", "Check if timeout has elapsed (2 callers)"),
            "sub_0000_0570": ("protocol_sendFile", "XMODEM/YMODEM send file top-level handler"),
            "sub_0000_065A": ("protocol_sendByte", "Send single byte to serial port (3 callers)"),
            "sub_0000_06A2": ("protocol_setCallback", "Set serial I/O callback function pointer"),
            "sub_0000_06B0": ("protocol_setOptions", "Set protocol options (block size, CRC mode)"),
            "sub_0000_06DA": ("protocol_transferLoop", "Main transfer loop - send/receive blocks (7 callers)"),
            "sub_0000_07A9": ("protocol_buildPacket", "Build XMODEM/YMODEM packet (header + data + checksum)"),
            "sub_0000_0838": ("protocol_validatePacket", "Validate received packet (checksum/CRC, 3 callers)"),
            "sub_0000_0845": ("protocol_receiveFile", "XMODEM/YMODEM receive file handler"),
            "sub_0000_092A": ("protocol_sendACK", "Send ACK byte (0x06) to remote (4 callers)"),
            "sub_0000_0942": ("protocol_sendNAK", "Send NAK byte (0x15) to request retransmit (2 callers)"),
            "sub_0000_0954": ("protocol_sendCAN", "Send CAN byte (0x18) to abort transfer (2 callers)"),
            "sub_0000_098A": ("protocol_receiveByte", "Receive single byte from serial port with timeout"),
            "sub_0000_0A27": ("protocol_receiveBlock", "Receive one data block (128 or 1024 bytes)"),
            "sub_0000_0AA5": ("protocol_writeToFile", "Write received block to output file (2 callers)"),
            "sub_0000_0AE6": ("protocol_handleYmodemBatch", "Handle YMODEM batch header (filename/size block)"),
            "sub_0000_0AFA": ("protocol_readFromFile", "Read next block from input file for sending (4 callers)"),
            "sub_0000_0B48": ("protocol_processBlock", "Process one transfer block (send or receive, 5 callers)"),
            "sub_0000_0CA6": ("protocol_handleRetry", "Handle retry after NAK/timeout (4 callers)"),
            "sub_0000_0CCC": ("protocol_xmodemSendBlock", "XMODEM-specific send block with ACK wait"),
            "sub_0000_0D59": ("protocol_calculateCRC", "Calculate CRC-16 for data block (2 callers)"),
            "sub_0000_0DE2": ("protocol_initXmodem", "Initialize XMODEM protocol parameters"),
            "sub_0000_0E26": ("protocol_crcUpdate", "Update CRC-16 with new data byte"),
            "sub_0000_0EA9": ("protocol_ymodemReceive", "YMODEM receive protocol state machine"),
            "sub_0000_10CA": ("protocol_ymodemSend", "YMODEM send protocol state machine"),
            "sub_0000_1138": ("protocol_setBlockSize128", "Set block size to 128 bytes (XMODEM standard)"),
            "sub_0000_1152": ("protocol_setBlockSize1024", "Set block size to 1024 bytes (YMODEM)"),
            "sub_0000_1175": ("protocol_enableCRC", "Enable CRC-16 mode (vs checksum)"),
            "sub_0000_117C": ("protocol_openOutputFile", "Open output file for received data (2 callers)"),
            "sub_0000_11F3": ("protocol_openInputFile", "Open input file for sending"),
            "sub_0000_1225": ("protocol_closeTransferFile", "Close transfer file handle"),
            "sub_0000_1293": ("protocol_updateProgress", "Update transfer progress display (2 callers)"),
            "sub_0000_131B": ("protocol_calculateChecksum", "Calculate simple checksum for XMODEM"),
            "sub_0000_136C": ("protocol_parseBatchFilename", "Parse YMODEM batch filename from block 0"),
            "sub_0000_1417": ("protocol_getProtocolName", "Get current protocol name string"),
            "sub_0000_1425": ("protocol_getTransferDir", "Get transfer direction string (Send/Receive)"),
            "sub_0000_143C": ("protocol_setStatusMsg", "Set status message for display"),
            "sub_0000_1449": ("protocol_getErrorMsg", "Get error message string"),
            "sub_0000_144F": ("protocol_setErrorState", "Set protocol error state"),
            "sub_0000_1457": ("protocol_clearError", "Clear protocol error state"),
            "sub_0000_145B": ("protocol_serialIO", "Serial I/O wrapper - call Telecom callback (3 callers)"),
            "sub_0000_1512": ("protocol_initXmodemState", "Initialize XMODEM protocol state machine"),
            "sub_0000_1536": ("protocol_initYmodemState", "Initialize YMODEM protocol state machine"),
            "sub_0000_1606": ("protocol_resetTransfer", "Reset transfer state for new transfer"),
            "sub_0000_1614": ("protocol_intE0hDispatch", "INT E0h dispatch table (4 entries)"),
            "sub_0000_1672": ("protocol_getCallbackA", "Get serial callback A (2 callers)"),
            "sub_0000_1678": ("protocol_getCallbackB", "Get serial callback B (2 callers)"),
            "sub_0000_167E": ("protocol_getCallbackC", "Get serial callback C"),
            "sub_0000_1684": ("protocol_getCallbackD", "Get serial callback D"),
            "sub_0000_168A": ("protocol_getCallbackE", "Get serial callback E"),
            "sub_0000_1690": ("protocol_getCallbackF", "Get serial callback F"),
            "sub_0000_17D4": ("protocol_crtInit", "MSC CRT initialization"),
            "sub_0000_1898": ("protocol_crtSetup", "MSC CRT data segment setup"),
            "sub_0000_18F4": ("protocol_crtCloseFiles", "MSC CRT close open file handles"),
            "sub_0000_1921": ("protocol_setIntVector", "Set interrupt vector (INT 21h/25h, 4 callers)"),
            "sub_0000_1930": ("protocol_getIntVector", "Get interrupt vector (INT 21h/35h, 2 callers)"),
            "sub_0000_1944": ("protocol_resizeMemory", "Resize memory block (INT 21h/4Ah, 3 callers)"),
            "sub_0000_1964": ("protocol_exitCleanup", "Exit cleanup and terminate"),
            "sub_0000_1B82": ("protocol_heapTop", "Get/update heap top pointer"),
            "sub_0000_1BAD": ("protocol_allocMemory", "Allocate memory from heap (5 callers)"),
            "sub_0000_1BD6": ("protocol_formatTransferStr", "Format transfer statistics string (3 callers)"),
            "sub_0000_1C28": ("protocol_packetHeader", "Build packet header bytes (2 callers)"),
            "sub_0000_1C54": ("protocol_crcTable", "CRC-16 table lookup (2 callers)"),
            "sub_0000_1C82": ("protocol_packetChecksum", "Compute and append packet checksum/CRC"),
            "sub_0000_1C94": ("protocol_terminateResident", "TSR exit via INT 21h/31h"),
            "sub_0000_1CD6": ("protocol_printf", "Formatted output (printf-like)"),
            "sub_0000_1DEC": ("protocol_flushOutput", "Flush output stream buffer"),
            "sub_0000_1DFC": ("protocol_writeOutput", "Write formatted output to file/device"),
            "sub_0000_1EAC": ("protocol_seekStream", "Seek stream position"),
            "sub_0000_1F76": ("protocol_putChar", "Write single character to output stream (5 callers)"),
            "sub_0000_1FAA": ("protocol_writeString", "Write string to output (2 callers)"),
            "sub_0000_1FD2": ("protocol_writeNewline", "Write newline to output"),
            "sub_0000_1FD6": ("protocol_formatNumber", "Format number for output"),
            "sub_0000_2034": ("protocol_divmod10", "Divide by 10 for decimal formatting (2 callers)"),
            "sub_0000_2050": ("protocol_outputDigit", "Output single decimal digit"),
        },
        "globals": {},
    },
    "dmplay": {
        "input": "dmplay.asm",
        "output": "dmplay.asm",
        "title": "DMPLAY.RES",
        "prefix": "dmplay",
        "description": """DMPLAY.RES is the tutorial/music playback engine for DeskMate 3.05.
; It is used by PLAY.PDM for lesson playback, providing the runtime
; that interprets and plays .SNG music files and tutorial sequences.
;
; The module contains a large data section (the bulk of the file) which
; appears to be tutorial content, lesson text, and music notation data.
; The code section is relatively small, implementing the playback state
; machine and timing engine.
;
; Key features:
;   - .SNG file playback (3-channel music via SN76496/DAC)
;   - Tutorial lesson sequencing
;   - Timing/tempo control via INT 21h/2Ch (system time)
;   - Memory management for lesson/music data (INT 21h/48h,49h)
;
; DM89 imports: INT E0h (DeskMate host API)
; Memory: INT 21h/48h (alloc), INT 21h/49h (free)""",
        "functions": {
            "sub_0000_0000": ("dmplay_apiDispatch", "API dispatch table - route commands to handlers"),
            "sub_0000_0047": ("dmplay_getVersion", "Get DMPLAY version information"),
            "sub_0000_0053": ("dmplay_initEngine", "Initialize playback engine state"),
            "sub_0000_006E": ("dmplay_shutdownEngine", "Shutdown playback engine, free resources"),
            "sub_0000_0201": ("dmplay_allocBuffer", "Allocate playback buffer (INT 21h/48h, 2 callers)"),
            "sub_0000_0215": ("dmplay_loadLesson", "Load lesson/music data into memory"),
            "sub_0000_0D52": ("dmplay_freeBuffer", "Free playback buffer (INT 21h/49h, 2 callers)"),
            "sub_0000_0D6B": ("dmplay_startPlayback", "Start playback of loaded lesson/music"),
            "sub_0000_0D91": ("dmplay_stopPlayback", "Stop current playback (2 callers)"),
            "sub_0000_217E": ("dmplay_timerHandler", "Timer/tempo handler - advance playback position"),
            "sub_0000_2229": ("dmplay_processNote", "Process single note/event in music stream (3 callers)"),
            "sub_0000_4C25": ("dmplay_getCallbackA", "Get engine callback A"),
            "sub_0000_4C2B": ("dmplay_getCallbackB", "Get engine callback B"),
            "sub_0000_4C31": ("dmplay_getCallbackC", "Get engine callback C"),
            "sub_0000_4C57": ("dmplay_intE0hDispatch", "INT E0h dispatch handler (3 entry points)"),
            "sub_0585_0000": ("dmplay_crtResizeMemory", "MSC CRT memory resize (INT 21h/4Ah)"),
        },
        "globals": {},
    },
}


def generate_annotated_header(mod):
    """Generate the annotated file header."""
    lines = []
    lines.append("; ========================================================================")
    lines.append(f"; {mod['title']} -- Fully Annotated Disassembly")
    lines.append("; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987, Microsoft Corp.")
    lines.append("; Compiled with Microsoft C 5.x (1987)")
    lines.append("; Annotated for the Bayside reverse engineering project")
    lines.append("; ========================================================================")
    lines.append(";")
    lines.append(f"; {mod['description']}")
    lines.append(";")
    return "\n".join(lines)


def generate_function_index(mod):
    """Generate the function index section."""
    lines = []
    lines.append("; ========================================================================")
    lines.append("; FUNCTION INDEX")
    lines.append("; ========================================================================")
    lines.append(";")
    lines.append(f"; --- {mod['title']} Functions ---")
    lines.append(";")
    lines.append("; Address          Name                              Description")
    lines.append("; -------          ----                              -----------")

    for raw_name, (label, desc) in sorted(mod["functions"].items(), key=lambda x: x[0]):
        # Extract address from raw name
        addr = raw_name.replace("sub_", "").replace("_", ":")
        if addr.startswith("entry"):
            addr = "entry_point"
        lines.append(f"; {addr:16s} {label:33s} {desc}")

    lines.append(";")
    return "\n".join(lines)


def annotate_file(raw_path, out_path, mod):
    """Read raw disassembly and produce annotated version."""
    with open(raw_path, 'r') as f:
        raw_lines = f.readlines()

    # Build the header + function index
    header = generate_annotated_header(mod)
    func_index = generate_function_index(mod)

    # Process lines - add annotations
    output_lines = []
    output_lines.append(header)
    output_lines.append("")
    output_lines.append(func_index)
    output_lines.append("")

    # Track whether we've inserted the header already (skip raw header)
    in_raw_header = True
    prev_was_blank = False

    for i, line in enumerate(raw_lines):
        stripped = line.rstrip()

        # Skip the raw file's own header (up to the first segment)
        if in_raw_header:
            if stripped.startswith("seg_") and stripped.endswith(":"):
                in_raw_header = False
                # Add separator before first segment
                output_lines.append("")
                output_lines.append(stripped)
                continue
            elif stripped.startswith("; ====") and "CODE / DATA" in stripped:
                in_raw_header = False
                output_lines.append(stripped)
                continue
            elif stripped.startswith("; ---") and "SEGMENT" in stripped:
                in_raw_header = False
                output_lines.append(stripped)
                continue
            # Keep skipping raw header lines
            continue

        # Annotate function labels
        annotated = False
        for raw_name, (label, desc) in mod["functions"].items():
            pattern = raw_name + ":"
            if stripped == pattern:
                # Add blank line before function for readability
                if output_lines and output_lines[-1].rstrip() != "":
                    output_lines.append("")
                output_lines.append(f"; --- {label} ---")
                output_lines.append(f"; {desc}")
                output_lines.append(f"{label}:  ; ({raw_name})")
                annotated = True
                break

        if annotated:
            continue

        # Annotate entry_point
        if stripped == "entry_point:":
            if output_lines and output_lines[-1].rstrip() != "":
                output_lines.append("")
            output_lines.append(f"; --- {mod['prefix']}_entryPoint ---")
            output_lines.append(f"; MSC 5.x CRT startup / DM89 entry point")
            output_lines.append(f"{mod['prefix']}_entryPoint:  ; (entry_point)")
            continue

        # Annotate calls to known functions
        call_match = re.search(r'call\s+0x[0-9a-f]+\s+;\s*->\s*(sub_\w+)', stripped)
        if call_match:
            called_func = call_match.group(1)
            if called_func in mod["functions"]:
                label, desc = mod["functions"][called_func]
                stripped = stripped + f"  ; {label}"

        # Annotate jumps to known functions (jmp -> sub_xxxx)
        jmp_match = re.search(r'(?:jmp|ljmp)\s+0x[0-9a-f]+\s+;\s*->\s*(sub_\w+)', stripped)
        if jmp_match:
            called_func = jmp_match.group(1)
            if called_func in mod["functions"]:
                label, desc = mod["functions"][called_func]
                stripped = stripped + f"  ; {label}"

        # Annotate INT calls with descriptions
        int_descs = {
            "INT 21h/2Fh": "Get DTA address",
            "INT 21h/1Ah": "Set DTA address",
            "INT 21h/25h": "Set interrupt vector",
            "INT 21h/2Ah": "Get system date",
            "INT 21h/2Ch": "Get system time",
            "INT 21h/30h": "Get DOS version",
            "INT 21h/31h": "Terminate and stay resident",
            "INT 21h/34h": "Get InDOS flag",
            "INT 21h/35h": "Get interrupt vector",
            "INT 21h/3Dh": "Open file",
            "INT 21h/3Eh": "Close file",
            "INT 21h/3Fh": "Read from file",
            "INT 21h/40h": "Write to file",
            "INT 21h/42h": "Seek (lseek)",
            "INT 21h/44h": "IOCTL",
            "INT 21h/48h": "Allocate memory",
            "INT 21h/49h": "Free memory",
            "INT 21h/4Ah": "Resize memory block",
            "INT 21h/4Ch": "Exit program",
            "INT 21h/50h": "Set current PSP",
            "INT 21h/51h": "Get current PSP",
            "INT 10h/0Eh": "Write char (teletype)",
            "INT 16h": "Keyboard services",
            "INT 16h/01h": "Check keyboard buffer",
            "INT E0h": "DeskMate host API",
        }

        # Add global variable annotations
        for var_pattern, (var_name, var_desc) in mod.get("globals", {}).items():
            if var_pattern.replace("[", "").replace("]", "") in stripped:
                if ";" not in stripped.split("  ", 1)[-1:][0] if "  " in stripped else True:
                    stripped = stripped + f"  ; {var_name}: {var_desc}"
                    break

        output_lines.append(stripped)

    # Write output
    with open(out_path, 'w') as f:
        f.write("\n".join(output_lines) + "\n")

    return len(output_lines)


def main():
    raw_dir = "/Users/joe/Documents/GitHub/bayside/disassembly/raw/res"
    out_dir = "/Users/joe/Documents/GitHub/bayside/disassembly/annotated/res"

    os.makedirs(out_dir, exist_ok=True)

    for mod_key, mod in MODULES.items():
        raw_path = os.path.join(raw_dir, mod["input"])
        out_path = os.path.join(out_dir, mod["output"])

        if not os.path.exists(raw_path):
            print(f"WARNING: {raw_path} not found, skipping")
            continue

        print(f"Annotating {mod['title']}...")
        line_count = annotate_file(raw_path, out_path, mod)
        print(f"  -> {out_path} ({line_count} lines)")

    print("Done!")


if __name__ == "__main__":
    main()
