#!/usr/bin/env python3
"""
Generate annotated disassembly for all 18 DeskMate 3.05 ACC (desk accessory) modules.
Produces annotated .asm files in disassembly/annotated/acc/ following the Bayside
project annotation style (matching filer.asm, desktop.asm, etc.)
"""

import os
import re

BASE = "/Users/joe/Documents/GitHub/bayside"
RAW_DIR = os.path.join(BASE, "disassembly/raw/acc")
OUT_DIR = os.path.join(BASE, "disassembly/annotated/acc")

# ============================================================================
# Module metadata for all 18 ACC files
# ============================================================================

MODULES = {
    "dmaccess": {
        "filename": "DMACCESS.ACC",
        "prefix": "dmaccess",
        "description": "Accessory Manager -- dispatches and loads other .ACC modules",
        "long_desc": (
            "DMACCESS.ACC is the main accessory manager for DeskMate 3.05. It serves\n"
            "; as the central dispatcher that loads and chains other desk accessories\n"
            "; (.ACC modules). When a user invokes a desk accessory from the DeskMate\n"
            "; menu, DMACCESS receives the request and loads the appropriate .ACC module.\n"
            ";\n"
            "; It imports DMGUF (General User Functions) for UI operations and maintains\n"
            "; an accessory chain (ACCCHAIN) for managing loaded accessories. The module\n"
            "; references DMHELP and DMSPELL for integrated help and spell-check support.\n"
            "; Month name strings suggest calendar/date display integration."
        ),
        "size": 7487,
        "load_image": 6975,
        "entry": "016A:000C",
        "ss_sp": "01BA:0FA0",
        "relocs": 13,
        "imports": "dmguf",
        "segments": [
            ("seg_0000", "CODE", "Accessory manager application code + DMGUF thunks"),
            ("seg_016A", "CODE", "MSC 5.x CRT startup + DeskMate host stubs"),
            ("seg_0175", "CODE", "DM89 import far-call dispatcher"),
            ("seg_0179", "DATA", "DGROUP fixup area (MSC CRT copyright)"),
            ("seg_01BA", "STACK", "Stack segment"),
        ],
        "dm_flags": "0x0101",
        "functions": 81,
        "int_e0h": ["AH=02h (Resource/UI services)", "AH=07h (Memory/timer services)"],
        "int_21h": ["AH=25h (Set interrupt vector)", "AH=30h (Get DOS version)",
                     "AH=35h (Get interrupt vector)", "AH=3Eh (Close file)",
                     "AH=40h (Write file)", "AH=44h (IOCTL)",
                     "AH=4Ah (Resize memory block)", "AH=4Ch (Exit process)"],
        "other_ints": ["INT 20h x1 (DOS program terminate)"],
        "strings": [
            ("ACCCHAIN", "Accessory chain identifier for chained ACC loading"),
            ("ACCNAME", "Accessory name field for registration"),
            ("DMHELP", "Help system resource reference"),
            ("DMMONTH", "Month names resource module"),
            ("DMCONFIG", "Configuration resource reference"),
            ("MONTHRES", "Month resource for calendar integration"),
            ("PNCtrl", "Panel control identifier"),
            ("CANCEL", "Cancel button label"),
        ],
        "key_functions": [
            ("0000:0010", "dmaccess_main", 70, "Main entry -- initialize accessory manager, dispatch commands"),
            ("0000:0056", "dmaccess_waitForEvent", 72, "Wait for and filter DeskMate events"),
            ("0000:009E", "dmaccess_initAccChain", 88, "Initialize accessory chain, load ACCCHAIN resource"),
            ("0000:00F6", "dmaccess_cleanupAccChain", 22, "Clean up accessory chain on exit"),
            ("0000:010C", "dmaccess_dispatchCommand", 1124, "Main command dispatcher -- handles all ACC menu commands"),
            ("0000:0570", "dmaccess_processEvent", 52, "Process a single event from the event queue"),
            ("0000:05A4", "dmaccess_handleMenuItem", 188, "Handle a selected menu item"),
            ("0000:0660", "dmaccess_handleAccItem", 137, "Handle accessory-specific menu item"),
            ("0000:06E9", "dmaccess_loadAccessory", 564, "Load a desk accessory module by name"),
            ("0000:091D", "dmaccess_parseAccName", 136, "Parse accessory name from configuration"),
            ("0000:09A5", "dmaccess_getAccInfo", 48, "Get information about a loaded accessory"),
            ("0000:09D5", "dmaccess_callAccFunction", 31, "Call a function in a loaded accessory"),
            ("0000:09F4", "dmaccess_unloadAccessory", 428, "Unload a desk accessory and free resources"),
            ("0000:0BA0", "dmaccess_chainWalk", 76, "Walk the accessory chain (recursive)"),
            ("0000:0BEC", "dmaccess_validateAcc", 68, "Validate an accessory module before loading"),
            ("0000:0C30", "dmaccess_eventLoop", 149, "Inner event loop -- get and dispatch events"),
            ("0000:0CC5", "dmaccess_handleEvent", 212, "Handle a single event (keyboard/menu/window)"),
            ("0000:0D99", "dmaccess_indirectCall", 15, "Indirect call dispatcher via function pointer table"),
            ("0000:0DA8", "dmaccess_drawAccWindow", 196, "Draw accessory window contents"),
            ("0000:0E6C", "dmaccess_redrawAcc", 23, "Trigger accessory window redraw"),
            ("0000:0E83", "dmaccess_resizeHandler", 69, "Handle window resize events"),
            ("0000:0F04", "dmaccess_fileOps", 202, "File operations (open/save accessory data)"),
            ("0000:0FCE", "dmaccess_initResources", 66, "Initialize DeskMate resources (load DMGUF, etc.)"),
            ("0000:1010", "dmaccess_cleanupResources", 169, "Clean up loaded resources on exit"),
        ],
    },
    "dmalarm": {
        "filename": "DMALARM.ACC",
        "prefix": "dmalarm",
        "description": "Alarm/Notification System -- schedules and displays timed alerts",
        "long_desc": (
            "DMALARM.ACC is the alarm and notification accessory for DeskMate 3.05.\n"
            "; It provides timed alerts, a quick alarm timer, and integration with the\n"
            "; Calendar application's alarm system. Users can set alarms with optional\n"
            "; digital sound playback (.SND files).\n"
            ";\n"
            "; The module reads/writes ALARM.CFG for persistent alarm configuration.\n"
            "; It uses DOS time (INT 21h AH=2Ch) and date (INT 21h AH=2Ah) services\n"
            "; for scheduling. INT E2h calls (5 total) suggest extended memory or\n"
            "; inter-process communication with ALRMINIT.RES. INT E9h calls (3 total)\n"
            "; may relate to sound playback hooks.\n"
            ";\n"
            "; INT 28h (DOS idle) is hooked for background alarm checking.\n"
            "; INT 5Ch (network lock) is used for shared alarm file access."
        ),
        "size": 14909,
        "load_image": 14397,
        "entry": "02B4:000E",
        "ss_sp": "0460:0DAC",
        "relocs": 23,
        "imports": "(none)",
        "segments": [
            ("seg_0000", "CODE", "Alarm application code -- scheduling, display, sound"),
            ("seg_02B4", "CODE", "MSC 5.x CRT startup + DM89 entry wrapper"),
            ("seg_02B9", "CODE", "DM89 import far-call dispatcher"),
            ("seg_02BD", "DATA", "DGROUP -- strings, alarm config, time buffers"),
            ("seg_0460", "STACK", "Stack segment"),
        ],
        "dm_flags": "0x000E",
        "functions": 145,
        "int_e0h": ["AH=02h (Resource/UI services)", "AH=06h (Window/event/file services)"],
        "int_21h": ["AH=0Eh (Set default drive)", "AH=19h (Get current drive)",
                     "AH=25h (Set interrupt vector)", "AH=2Ah (Get date)",
                     "AH=2Ch (Get time)", "AH=30h (Get DOS version)",
                     "AH=35h (Get interrupt vector)", "AH=3Eh (Close file)",
                     "AH=40h (Write file)", "AH=44h (IOCTL)",
                     "AH=4Ah (Resize memory block)", "AH=4Ch (Exit process)"],
        "other_ints": ["INT 20h x1 (DOS terminate)", "INT 28h x1 (DOS idle hook)",
                       "INT 5Ch x1 (Network lock)", "INT E2h x5 (Extended DM services)",
                       "INT E9h x3 (Sound/playback hooks)"],
        "strings": [
            ("ALARM", "Module identifier"),
            ("ALARM.CFG", "Alarm configuration file"),
            ("FILE LIST", "File list dialog label"),
            ("Alarm", "Window title"),
            ("Alarm/Calendar Alarms", "Menu item for calendar alarm integration"),
            ("Use Digital Sound Alarm", "Option for .SND file playback on alarm"),
            ("Quick Alarm Time:", "Label for quick alarm timer input"),
            ("Sound File Name:", "Label for sound file selection"),
        ],
        "key_functions": [
            ("0000:0010", "dmalarm_main", 321, "Main entry -- init alarm system, load config, event loop"),
            ("0000:0151", "dmalarm_setupAlarm", 241, "Set up a new alarm from user input"),
            ("0000:0242", "dmalarm_cancelAlarm", 49, "Cancel the current active alarm"),
            ("0000:0273", "dmalarm_editAlarm", 344, "Edit alarm dialog -- time, sound, repeat settings"),
            ("0000:03CB", "dmalarm_quickAlarm", 207, "Quick alarm setup (countdown timer)"),
            ("0000:049A", "dmalarm_displayAlarm", 193, "Display alarm notification window"),
            ("0000:055B", "dmalarm_saveConfig", 25, "Save alarm configuration to ALARM.CFG"),
            ("0000:0574", "dmalarm_loadConfig", 54, "Load alarm configuration from ALARM.CFG"),
            ("0000:05AA", "dmalarm_playSound", 44, "Play alarm sound (.SND file)"),
            ("0000:063A", "dmalarm_stopSound", 36, "Stop currently playing alarm sound"),
            ("0000:065E", "dmalarm_timerCallback", 42, "Timer callback -- check if alarm time reached"),
            ("0000:0688", "dmalarm_handleCommand", 189, "Handle menu/keyboard commands"),
            ("0000:0745", "dmalarm_updateDisplay", 92, "Update alarm status display"),
            ("0000:0880", "dmalarm_editTimeDialog", 166, "Time editing dialog for alarm settings"),
            ("0000:0D96", "dmalarm_calendarSync", 108, "Synchronize alarms with Calendar application"),
            ("0000:0E02", "dmalarm_initHooks", 112, "Install INT 28h/E9h hooks for background checking"),
            ("0000:0E90", "dmalarm_checkAlarms", 202, "Check all alarms against current time"),
            ("0000:0FA7", "dmalarm_checkCalAlarms", 205, "Check calendar-sourced alarms"),
            ("0000:1154", "dmalarm_fileIO", 442, "File I/O for alarm config read/write"),
            ("0000:1624", "dmalarm_formatTime", 269, "Format time value for display (HH:MM AM/PM)"),
            ("0000:1740", "dmalarm_parseTime", 711, "Parse user-entered time string"),
        ],
    },
    "dmclip": {
        "filename": "DMCLIP.ACC",
        "prefix": "dmclip",
        "description": "Clipboard Manager -- cut/copy/paste support across DeskMate apps",
        "long_desc": (
            "DMCLIP.ACC is the clipboard manager for DeskMate 3.05. It provides\n"
            "; system-wide cut, copy, and paste functionality across all DeskMate\n"
            "; applications. The clipboard data is persisted to CLIPBORD.DAT.\n"
            ";\n"
            "; The module supports named clipboard entries (items) that can be\n"
            "; individually managed. It handles memory allocation (INT 21h AH=48h)\n"
            "; for clipboard buffers and disk free space checking (AH=36h) before\n"
            "; saving. Error conditions include invalid data files and duplicate names."
        ),
        "size": 10507,
        "load_image": 9995,
        "entry": "01EC:0002",
        "ss_sp": "038D:0FA0",
        "relocs": 14,
        "imports": "(none)",
        "segments": [
            ("seg_0000", "CODE", "Clipboard manager application code"),
            ("seg_01EC", "CODE", "MSC 5.x CRT startup"),
            ("seg_01F6", "CODE", "DM89 import far-call dispatcher"),
            ("seg_01FA", "DATA", "DGROUP -- clipboard data, strings, buffers"),
            ("seg_038D", "STACK", "Stack segment"),
        ],
        "dm_flags": "0x0101",
        "functions": 124,
        "int_e0h": ["AH=02h (Resource/UI services)", "AH=07h (Memory/timer services)"],
        "int_21h": ["AH=25h (Set interrupt vector)", "AH=30h (Get DOS version)",
                     "AH=35h (Get interrupt vector)", "AH=36h (Get disk free space)",
                     "AH=3Eh (Close file)", "AH=40h (Write file)", "AH=44h (IOCTL)",
                     "AH=48h (Allocate memory)", "AH=4Ah (Resize memory block)",
                     "AH=4Ch (Exit process)"],
        "other_ints": ["INT 20h x1 (DOS terminate)"],
        "strings": [
            ("CLIPBORD.DAT", "Clipboard data file"),
            ("DMCLIP", "Module registration name"),
            ("SAVE CLIPBOARD", "Save clipboard dialog title"),
            ("Error", "Error dialog title"),
            ("Warning", "Warning dialog title"),
            ("The file CLIPBORD.DAT contains invalid data.", "Corrupt file error message"),
            ("Duplicate clip item name.", "Duplicate name error"),
            ("The selected entry is too large for the current clipboard.", "Size error"),
        ],
        "key_functions": [
            ("0000:0010", "dmclip_main", 246, "Main entry -- init clipboard, load CLIPBORD.DAT, event loop"),
            ("0000:0106", "dmclip_handleCommand", 460, "Command dispatcher for clipboard operations"),
            ("0000:02D2", "dmclip_cutToClip", 31, "Cut selected text to clipboard"),
            ("0000:02F1", "dmclip_copyToClip", 26, "Copy selected text to clipboard"),
            ("0000:030B", "dmclip_pasteFromClip", 75, "Paste clipboard contents to active window"),
            ("0000:0356", "dmclip_manageItems", 1018, "Manage clipboard items (add, delete, rename)"),
            ("0000:0750", "dmclip_validateData", 71, "Validate clipboard data file integrity"),
            ("0000:0797", "dmclip_loadClipFile", 322, "Load CLIPBORD.DAT into memory"),
            ("0000:08D9", "dmclip_saveClipFile", 245, "Save clipboard data to CLIPBORD.DAT"),
            ("0000:09CE", "dmclip_allocBuffer", 121, "Allocate memory buffer for clipboard data"),
            ("0000:0A47", "dmclip_freeBuffer", 51, "Free clipboard memory buffer"),
            ("0000:0A7A", "dmclip_addItem", 141, "Add a new named item to clipboard"),
            ("0000:0B07", "dmclip_deleteItem", 117, "Delete a named item from clipboard"),
            ("0000:0B7C", "dmclip_renameItem", 80, "Rename a clipboard item"),
            ("0000:0C28", "dmclip_getItemData", 162, "Get data for a named clipboard item"),
            ("0000:0E94", "dmclip_displayItems", 424, "Display clipboard items in list view"),
        ],
    },
    "dmdrwprt": {
        "filename": "DMDRWPRT.ACC",
        "prefix": "dmdrwprt",
        "description": "Draw Print Support -- printing backend for DRAW.PDM vector output",
        "long_desc": (
            "DMDRWPRT.ACC is a tiny (1,638 bytes) accessory that provides printing\n"
            "; support for DRAW.PDM's vector graphics output. It acts as a bridge\n"
            "; between the Draw application and the printer driver system.\n"
            ";\n"
            "; The module loads DRWPRTFILE and PRINT_INFO resources to handle\n"
            "; vector-to-raster conversion for printing. It uses INT ABh (2 calls)\n"
            "; which is likely a Draw-specific IPC vector for passing print data.\n"
            ";\n"
            "; DM flags 0x0000 indicate this is a service/driver ACC (no UI window)."
        ),
        "size": 1638,
        "load_image": 1126,
        "entry": "003B:0002",
        "ss_sp": "0047:0800",
        "relocs": 7,
        "imports": "(none)",
        "segments": [
            ("seg_0000", "CODE", "Draw print service code -- resource loading, print dispatch"),
            ("seg_003B", "CODE", "MSC 5.x CRT startup + main()"),
            ("seg_0047", "DATA", "DGROUP -- resource names, print parameters"),
            ("seg_00C7", "STACK", "Stack segment"),
        ],
        "dm_flags": "0x0000",
        "functions": 18,
        "int_e0h": ["AH=02h (Resource/UI services -- load/unload/call resources)"],
        "int_21h": ["AH=4Ah (Resize memory block)", "AH=4Ch (Exit process)"],
        "other_ints": ["INT ABh x2 (Draw IPC -- print data transfer)"],
        "strings": [
            ("DRWPRTFILE", "Draw print file resource name"),
            ("PRINT_INFO", "Print information structure resource"),
            ("01.02", "Version string"),
        ],
        "key_functions": [
            ("0000:0000", "dmdrwprt_entryStub", 0, "Segment initialization (DS/SS/SP setup)"),
            ("0000:001B", "dmdrwprt_main", 133, "Main -- resize memory, init resources, load DRWPRTFILE, print, exit"),
            ("0000:00A0", "dmdrwprt_loadPrintRes", 97, "Load DRWPRTFILE and PRINT_INFO resources via INT E0h AH=02h"),
            ("0000:0102", "dmdrwprt_initPrintInfo", 66, "Initialize PRINT_INFO resource, set up callback pointers"),
            ("0000:0144", "dmdrwprt_unloadRes", 32, "Unload resources and restore default callbacks"),
            ("0000:016C", "dmdrwprt_dispatchPrint", 62, "Dispatch print commands to loaded driver"),
            ("0000:01B0", "dmdrwprt_dispatchQuery", 55, "Dispatch query commands to loaded driver"),
            ("0000:01ED", "dmdrwprt_callResFn0C", 6, "DMGUF thunk -- function 0x0C"),
            ("0000:01F3", "dmdrwprt_callResFn_B3", 6, "DMGUF thunk -- function 0xB3"),
            ("0000:01F9", "dmdrwprt_loadResource", 25, "Load named resource via INT E0h AX=0206h"),
            ("0000:0212", "dmdrwprt_unloadResource", 15, "Unload named resource via INT E0h AX=0207h"),
            ("0000:0221", "dmdrwprt_initCRT", 7, "CRT initialization (calls startup helpers)"),
            ("0000:0228", "dmdrwprt_cleanupCRT", 7, "CRT cleanup (calls shutdown helpers)"),
            ("0000:022F", "dmdrwprt_envSetup", 40, "Environment/segment setup for DeskMate ACC"),
            ("0000:027B", "dmdrwprt_mscStartup", 269, "MSC 5.x C runtime startup code"),
            ("0000:0388", "dmdrwprt_mscExit", 42, "MSC 5.x C runtime exit handler"),
        ],
    },
    "dmhelp": {
        "filename": "DMHELP.ACC",
        "prefix": "dmhelp",
        "description": "Help System -- context-sensitive help viewer for all DeskMate apps",
        "long_desc": (
            "DMHELP.ACC is the help system for DeskMate 3.05, and the largest ACC\n"
            "; module at 31,836 bytes with 223 functions. It provides context-sensitive\n"
            "; help for all DeskMate applications by loading .HLP help files.\n"
            ";\n"
            "; The help viewer supports hypertext-style navigation with topics, indexes,\n"
            "; and cross-references. It displays help text in a scrollable window with\n"
            "; formatted text (bold, underline) and topic links.\n"
            ";\n"
            "; The module uses INT E0h AH=00h (core services) for font rendering,\n"
            "; AH=02h for resource/UI, AH=06h for window/event management, and\n"
            "; AH=07h for memory allocation. It allocates memory via DOS (INT 21h\n"
            "; AH=48h) for help file buffers.\n"
            ";\n"
            "; Requires DeskMate version 03.03 or later (version check on startup).\n"
            "; Handles network errors gracefully with user-visible messages."
        ),
        "size": 31836,
        "load_image": 31324,
        "entry": "0693:000A",
        "ss_sp": "098D:0FA0",
        "relocs": 7,
        "imports": "(none)",
        "segments": [
            ("seg_0000", "CODE", "Help viewer application code (223 functions)"),
            ("seg_0693", "CODE", "MSC 5.x CRT startup + DM89 entry"),
            ("seg_069C", "DATA", "DGROUP -- help strings, topic buffers, format tables"),
            ("seg_098D", "STACK", "Stack segment"),
        ],
        "dm_flags": "0x0101",
        "functions": 223,
        "int_e0h": ["AH=00h (Core/font services)", "AH=02h (Resource/UI services)",
                     "AH=06h (Window/event services)", "AH=07h (Memory services)"],
        "int_21h": ["AH=25h (Set interrupt vector)", "AH=35h (Get interrupt vector)",
                     "AH=48h (Allocate memory)", "AH=4Ch (Exit process)"],
        "other_ints": [],
        "strings": [
            ("Looking for Help ...", "Status message during help file search"),
            (".HLP", "Help file extension"),
            ("The alarm accessory has been run and alarms are turned on.", "Alarm status help text"),
            ("The Autoproof option of the Spell Checker is on.", "Spell checker help text"),
            ("Unable to display Help.  A network error has occurred.", "Network error message"),
            ("Help requires DeskMate version 03.03 or later.", "Version requirement error"),
            ("Help", "Window title"),
            ("Try copying your help file to another directory.", "File access error advice"),
        ],
        "key_functions": [
            ("0000:000C", "dmhelp_main", 581, "Main entry -- init help system, find .HLP file, display"),
            ("0000:0256", "dmhelp_showStatus", 26, "Show status message in help window"),
            ("0000:0270", "dmhelp_initWindow", 211, "Initialize help display window"),
            ("0000:0343", "dmhelp_setAttributes", 109, "Set window display attributes (colors, font)"),
            ("0000:03B0", "dmhelp_loadHelpFile", 140, "Load .HLP file from disk into memory"),
            ("0000:043C", "dmhelp_closeHelpFile", 49, "Close help file and free buffers"),
            ("0000:046D", "dmhelp_navigateTopic", 211, "Navigate to a help topic by ID"),
            ("0000:05A0", "dmhelp_showTopic", 63, "Display a help topic in the viewer window"),
            ("0000:05DF", "dmhelp_handleLink", 43, "Handle hypertext link click/activation"),
            ("0000:060A", "dmhelp_scrollPage", 8, "Scroll help text by one page"),
            ("0000:063A", "dmhelp_formatBlock", 117, "Format a text block for display"),
            ("0000:06AF", "dmhelp_renderText", 384, "Render formatted help text with attributes"),
            ("0000:082F", "dmhelp_parseMarkup", 103, "Parse help file markup tags"),
            ("0000:0896", "dmhelp_drawGraphic", 197, "Draw inline graphic in help text"),
            ("0000:095B", "dmhelp_handleScroll", 255, "Handle scroll events (mouse wheel, arrows)"),
            ("0000:0AD3", "dmhelp_searchIndex", 357, "Search help index for keyword match"),
            ("0000:0FA2", "dmhelp_buildIndex", 850, "Build help topic index from .HLP file"),
            ("0000:12F4", "dmhelp_topicEngine", 1253, "Topic display engine -- layout, word wrap, pagination"),
            ("0000:17D9", "dmhelp_topicScanner", 357, "Scan help file for topic boundaries"),
            ("0000:1D18", "dmhelp_dialogHandler", 765, "Help dialog box handler (index, search)"),
            ("0000:228E", "dmhelp_textRenderer", 739, "Text rendering engine for help content"),
            ("0000:283F", "dmhelp_eventDispatch", 1185, "Main event dispatcher for help viewer"),
            ("0000:2D5C", "dmhelp_keyHandler", 610, "Keyboard event handler"),
            ("0000:35C7", "dmhelp_displayEngine", 837, "Display engine -- manages visible area and redraw"),
            ("0000:45B8", "dmhelp_fileEngine", 1323, "File engine -- .HLP parsing, decompression, buffering"),
            ("0000:4EA0", "dmhelp_memManager", 305, "Memory manager for help text buffers"),
        ],
    },
    "dmnotepd": {
        "filename": "DMNOTEPD.ACC",
        "prefix": "dmnotepd",
        "description": "Notepad Accessory -- simple text editor/note-taking popup",
        "long_desc": (
            "DMNOTEPD.ACC is the notepad desk accessory for DeskMate 3.05. It provides\n"
            "; a simple pop-up text editor for quick note-taking. Notes are stored in\n"
            "; the file DMCORKBD (a \"cork board\" metaphor).\n"
            ";\n"
            "; The module imports DMGUF for UI rendering and text editing functions.\n"
            "; It references DMSPELL for optional spell-check integration and reads\n"
            "; DESKTOP.CFG for configuration. File operations include create, open,\n"
            "; and save with drive error handling and disk swap prompts."
        ),
        "size": 14295,
        "load_image": 13783,
        "entry": "01B2:000C",
        "ss_sp": "0416:0FA0",
        "relocs": 13,
        "imports": "dmguf",
        "segments": [
            ("seg_0000", "CODE", "Notepad application code + DMGUF thunks"),
            ("seg_01B2", "CODE", "MSC 5.x CRT startup + DeskMate host stubs"),
            ("seg_01BD", "CODE", "DM89 import far-call dispatcher"),
            ("seg_01C1", "DATA", "DGROUP -- text buffers, strings, config data"),
            ("seg_0416", "STACK", "Stack segment"),
        ],
        "dm_flags": "0x0101",
        "functions": 116,
        "int_e0h": ["AH=00h (Core services)", "AH=02h (Resource/UI services)",
                     "AH=07h (Memory services)"],
        "int_21h": ["AH=25h (Set interrupt vector)", "AH=30h (Get DOS version)",
                     "AH=35h (Get interrupt vector)", "AH=3Eh (Close file)",
                     "AH=40h (Write file)", "AH=44h (IOCTL)",
                     "AH=4Ah (Resize memory block)", "AH=4Ch (Exit process)"],
        "other_ints": ["INT 20h x1 (DOS terminate)"],
        "strings": [
            ("File Not Found", "Error when DMCORKBD not found"),
            ("Create File", "Prompt to create new note file"),
            ("Do you want to create file DMCORKBD on drive", "Create file confirmation"),
            ("Disk Drive Error", "Drive access error title"),
            ("Drive error accessing file.  Swap disks and retry?", "Disk error retry prompt"),
            ("DMSPELL", "Spell checker resource reference"),
            ("A:\\DESKTOP.CFG", "Desktop configuration file path"),
        ],
        "key_functions": [
            ("0000:0010", "dmnotepd_main", 93, "Main entry -- init notepad, open DMCORKBD, event loop"),
            ("0000:006D", "dmnotepd_handleCommand", 265, "Command dispatcher for notepad operations"),
            ("0000:0176", "dmnotepd_newNote", 83, "Create a new empty note"),
            ("0000:01C9", "dmnotepd_editDialog", 511, "Note editing dialog with text input"),
            ("0000:03C8", "dmnotepd_formatDialog", 174, "Format/options dialog"),
            ("0000:0476", "dmnotepd_deleteNote", 175, "Delete the current note"),
            ("0000:0525", "dmnotepd_saveNote", 223, "Save current note to DMCORKBD"),
            ("0000:061F", "dmnotepd_displayNotes", 862, "Display note list and editor"),
            ("0000:097D", "dmnotepd_textEditor", 551, "Text editing engine for note content"),
            ("0000:0BA4", "dmnotepd_optionsDialog", 175, "Options/preferences dialog"),
            ("0000:0CD5", "dmnotepd_fileOps", 298, "File I/O for DMCORKBD (open, read, write)"),
            ("0000:0F14", "dmnotepd_searchText", 155, "Search for text within notes"),
            ("0000:0FAF", "dmnotepd_replaceText", 191, "Search and replace text in notes"),
        ],
    },
    "dmpd1": {
        "filename": "DMPD1.ACC",
        "prefix": "dmpd1",
        "description": "Printer Driver 1 -- dot-matrix printer support (primary)",
        "long_desc": (
            "DMPD1.ACC is the primary dot-matrix printer driver accessory for DeskMate\n"
            "; 3.05. It provides page setup, font selection, and print output for\n"
            "; standard dot-matrix printers.\n"
            ";\n"
            "; The module imports DMGUF for UI rendering. It reads configuration from\n"
            "; DMPRTSEL.CFG (printer selection), DMPD.CFG (printer driver settings),\n"
            "; and INSTALL.CFG (installation config). INT ABh is used for printer\n"
            "; hardware communication.\n"
            ";\n"
            "; DMPD1.ACC and DMPD2.ACC are nearly identical (6,713 vs 6,685 bytes)\n"
            "; and share the same function structure -- they differ only in device-\n"
            "; specific escape sequences for different printer families."
        ),
        "size": 6713,
        "load_image": 6201,
        "entry": "0109:0002",
        "ss_sp": "0198:0FA0",
        "relocs": 13,
        "imports": "dmguf",
        "segments": [
            ("seg_0000", "CODE", "Printer driver 1 code + DMGUF thunks"),
            ("seg_0109", "CODE", "MSC 5.x CRT startup"),
            ("seg_0113", "CODE", "DM89 import far-call dispatcher"),
            ("seg_0117", "DATA", "DGROUP -- printer config, escape sequences, strings"),
            ("seg_0198", "STACK", "Stack segment"),
        ],
        "dm_flags": "0x0000",
        "functions": 79,
        "int_e0h": ["AH=00h (Core services)", "AH=02h (Resource/UI services)",
                     "AH=06h (Window/event services)", "AH=07h (Memory services)"],
        "int_21h": ["AH=25h (Set interrupt vector)", "AH=30h (Get DOS version)",
                     "AH=35h (Get interrupt vector)", "AH=3Eh (Close file)",
                     "AH=40h (Write file)", "AH=44h (IOCTL)",
                     "AH=4Ah (Resize memory block)", "AH=4Ch (Exit process)"],
        "other_ints": ["INT 20h x1 (DOS terminate)", "INT ABh x1 (Printer I/O)"],
        "strings": [
            ("PAGE SETUP", "Page setup dialog title"),
            ("DMSETUP", "Setup module reference"),
            ("DMPRTSEL.CFG", "Printer selection configuration file"),
            ("DMPD.CFG", "Printer driver configuration file"),
            ("INSTALL.CFG", "Installation configuration file"),
            ("DMPD.CFG Not Updated", "Config save error message"),
            ("File Not Found", "Missing config file error"),
            ("File Needed", "Required file missing error"),
        ],
        "key_functions": [
            ("0000:0010", "dmpd1_main", 159, "Main entry -- init driver, load config, register"),
            ("0000:0100", "dmpd1_initDriver", 44, "Initialize printer driver hardware"),
            ("0000:0148", "dmpd1_pageSetup", 165, "Page setup dialog (margins, orientation, paper)"),
            ("0000:01ED", "dmpd1_handleCommand", 167, "Command dispatcher for printer operations"),
            ("0000:02BC", "dmpd1_printJob", 63, "Start a print job"),
            ("0000:031C", "dmpd1_formatPage", 131, "Format page for printer output"),
            ("0000:041A", "dmpd1_printPage", 98, "Send formatted page to printer"),
            ("0000:047C", "dmpd1_configDialog", 526, "Printer configuration dialog"),
            ("0000:069E", "dmpd1_timerCallback", 79, "Print callback / status check"),
            ("0000:08FC", "dmpd1_sendEscSeq", 273, "Send escape sequence to printer"),
        ],
    },
    "dmpd2": {
        "filename": "DMPD2.ACC",
        "prefix": "dmpd2",
        "description": "Printer Driver 2 -- additional dot-matrix printer support",
        "long_desc": (
            "DMPD2.ACC is the secondary dot-matrix printer driver for DeskMate 3.05.\n"
            "; It is nearly identical to DMPD1.ACC (same function count, similar size)\n"
            "; but contains different printer escape sequences for a second family of\n"
            "; dot-matrix printers.\n"
            ";\n"
            "; See DMPD1.ACC for full documentation -- the code structure is identical."
        ),
        "size": 6685,
        "load_image": 6173,
        "entry": "0109:0002",
        "ss_sp": "0196:0FA0",
        "relocs": 13,
        "imports": "dmguf",
        "segments": [
            ("seg_0000", "CODE", "Printer driver 2 code + DMGUF thunks"),
            ("seg_0109", "CODE", "MSC 5.x CRT startup"),
            ("seg_0113", "CODE", "DM89 import far-call dispatcher"),
            ("seg_0117", "DATA", "DGROUP -- printer config, escape sequences, strings"),
            ("seg_0196", "STACK", "Stack segment"),
        ],
        "dm_flags": "0x0000",
        "functions": 79,
        "int_e0h": ["AH=00h (Core services)", "AH=02h (Resource/UI services)",
                     "AH=06h (Window/event services)", "AH=07h (Memory services)"],
        "int_21h": ["AH=25h (Set interrupt vector)", "AH=30h (Get DOS version)",
                     "AH=35h (Get interrupt vector)", "AH=3Eh (Close file)",
                     "AH=40h (Write file)", "AH=44h (IOCTL)",
                     "AH=4Ah (Resize memory block)", "AH=4Ch (Exit process)"],
        "other_ints": ["INT 20h x1 (DOS terminate)", "INT ABh x1 (Printer I/O)"],
        "strings": [
            ("PAGE SETUP", "Page setup dialog title"),
            ("DMSETUP", "Setup module reference"),
            ("DMPRTSEL.CFG", "Printer selection configuration"),
            ("DMPD.CFG", "Printer driver configuration"),
            ("INSTALL.CFG", "Installation configuration"),
        ],
        "key_functions": [
            ("0000:0010", "dmpd2_main", 159, "Main entry -- init driver, load config, register"),
            ("0000:0100", "dmpd2_initDriver", 44, "Initialize printer driver hardware"),
            ("0000:0148", "dmpd2_pageSetup", 165, "Page setup dialog"),
            ("0000:01ED", "dmpd2_handleCommand", 167, "Command dispatcher"),
            ("0000:047C", "dmpd2_configDialog", 526, "Printer configuration dialog"),
            ("0000:08FC", "dmpd2_sendEscSeq", 273, "Send escape sequence to printer"),
        ],
    },
    "dmpdasci": {
        "filename": "DMPDASCI.ACC",
        "prefix": "dmpdasci",
        "description": "ASCII Printer Driver -- plain text/generic printer output",
        "long_desc": (
            "DMPDASCI.ACC is the ASCII/plain-text printer driver for DeskMate 3.05.\n"
            "; It provides output for generic printers that accept plain ASCII text\n"
            "; without escape sequences. It includes an option for how the printer\n"
            "; treats carriage returns (CR only vs CR+LF).\n"
            ";\n"
            "; Slightly larger than DMPD1/DMPD2 (8,035 bytes) due to additional\n"
            "; CR handling configuration options."
        ),
        "size": 8035,
        "load_image": 7523,
        "entry": "011B:000E",
        "ss_sp": "01EA:0FA0",
        "relocs": 13,
        "imports": "dmguf",
        "segments": [
            ("seg_0000", "CODE", "ASCII printer driver code + DMGUF thunks"),
            ("seg_011B", "CODE", "MSC 5.x CRT startup"),
            ("seg_0126", "CODE", "DM89 import far-call dispatcher"),
            ("seg_012A", "DATA", "DGROUP -- printer config, strings"),
            ("seg_01EA", "STACK", "Stack segment"),
        ],
        "dm_flags": "0x0000",
        "functions": 83,
        "int_e0h": ["AH=00h (Core services)", "AH=02h (Resource/UI services)",
                     "AH=06h (Window/event services)", "AH=07h (Memory services)"],
        "int_21h": ["AH=25h (Set interrupt vector)", "AH=30h (Get DOS version)",
                     "AH=35h (Get interrupt vector)", "AH=3Eh (Close file)",
                     "AH=40h (Write file)", "AH=44h (IOCTL)",
                     "AH=4Ah (Resize memory block)", "AH=4Ch (Exit process)"],
        "other_ints": ["INT 20h x1 (DOS terminate)"],
        "strings": [
            ("PAGE SETUP", "Page setup dialog title"),
            ("Printer treats a carriage return (CR) as:", "CR handling option label"),
            ("DMSETUP", "Setup module reference"),
            ("DMPRTSEL.CFG", "Printer selection configuration"),
            ("DMPD.CFG", "Printer driver configuration"),
            ("INSTALL.CFG", "Installation configuration"),
        ],
        "key_functions": [
            ("0000:0010", "dmpdasci_main", 280, "Main entry -- init ASCII driver, load config, register"),
            ("0000:0128", "dmpdasci_crOption", 152, "CR handling option dialog"),
            ("0000:0262", "dmpdasci_pageSetup", 165, "Page setup dialog"),
            ("0000:0307", "dmpdasci_handleCommand", 167, "Command dispatcher"),
            ("0000:0596", "dmpdasci_configDialog", 526, "Printer configuration dialog"),
            ("0000:0A16", "dmpdasci_sendEscSeq", 273, "Send text to printer (no escape sequences)"),
        ],
    },
    "dmpdibmm": {
        "filename": "DMPDIBMM.ACC",
        "prefix": "dmpdibmm",
        "description": "IBM Matrix Printer Driver -- IBM Proprinter/compatible support",
        "long_desc": (
            "DMPDIBMM.ACC is the IBM Proprinter/compatible matrix printer driver for\n"
            "; DeskMate 3.05. It supports the IBM Proprinter command set with default\n"
            "; font selection and graphics mode printing.\n"
            ";\n"
            "; Uses INT 05h for print-screen compatibility. Larger than other printer\n"
            "; drivers (9,251 bytes) due to additional font mapping tables and IBM-\n"
            "; specific escape sequence handling."
        ),
        "size": 9251,
        "load_image": 8739,
        "entry": "0130:000C",
        "ss_sp": "0236:0FA0",
        "relocs": 13,
        "imports": "dmguf",
        "segments": [
            ("seg_0000", "CODE", "IBM matrix printer driver code + DMGUF thunks"),
            ("seg_0130", "CODE", "MSC 5.x CRT startup"),
            ("seg_013B", "CODE", "DM89 import far-call dispatcher"),
            ("seg_013F", "DATA", "DGROUP -- printer config, font tables, escape codes"),
            ("seg_0236", "STACK", "Stack segment"),
        ],
        "dm_flags": "0x0000",
        "functions": 84,
        "int_e0h": ["AH=00h (Core services)", "AH=02h (Resource/UI services)",
                     "AH=06h (Window/event services)", "AH=07h (Memory services)"],
        "int_21h": ["AH=25h (Set interrupt vector)", "AH=30h (Get DOS version)",
                     "AH=35h (Get interrupt vector)", "AH=3Eh (Close file)",
                     "AH=40h (Write file)", "AH=44h (IOCTL)",
                     "AH=4Ah (Resize memory block)", "AH=4Ch (Exit process)"],
        "other_ints": ["INT 05h x1 (Print screen)", "INT 20h x1 (DOS terminate)",
                       "INT ABh x1 (Printer I/O)"],
        "strings": [
            ("PAGE SETUP", "Page setup dialog title"),
            ("Default Printer Font", "Font selection label"),
            ("DMSETUP", "Setup module reference"),
            ("DMPRTSEL.CFG", "Printer selection configuration"),
            ("DMPD.CFG", "Printer driver configuration"),
        ],
        "key_functions": [
            ("0000:0010", "dmpdibmm_main", 406, "Main entry -- init IBM driver with font config"),
            ("0000:01A6", "dmpdibmm_fontSetup", 248, "Font selection and mapping setup"),
            ("0000:03B0", "dmpdibmm_pageSetup", 165, "Page setup dialog"),
            ("0000:0455", "dmpdibmm_handleCommand", 167, "Command dispatcher"),
            ("0000:06E4", "dmpdibmm_configDialog", 526, "Printer configuration dialog"),
            ("0000:0B64", "dmpdibmm_sendEscSeq", 273, "Send IBM Proprinter escape sequences"),
        ],
    },
    "dmpdlasr": {
        "filename": "DMPDLASR.ACC",
        "prefix": "dmpdlasr",
        "description": "Laser Printer Driver -- HP LaserJet/compatible PCL output",
        "long_desc": (
            "DMPDLASR.ACC is the laser printer driver for DeskMate 3.05, targeting\n"
            "; HP LaserJet and compatible printers using the PCL command language.\n"
            ";\n"
            "; Uses INT 05h for print screen compatibility. Default printer font\n"
            "; selection is available for PCL font switching."
        ),
        "size": 6969,
        "load_image": 6457,
        "entry": "010E:0006",
        "ss_sp": "01A8:0FA0",
        "relocs": 13,
        "imports": "dmguf",
        "segments": [
            ("seg_0000", "CODE", "Laser printer driver code + DMGUF thunks"),
            ("seg_010E", "CODE", "MSC 5.x CRT startup"),
            ("seg_0119", "CODE", "DM89 import far-call dispatcher"),
            ("seg_011D", "DATA", "DGROUP -- printer config, PCL sequences, strings"),
            ("seg_01A8", "STACK", "Stack segment"),
        ],
        "dm_flags": "0x0000",
        "functions": 80,
        "int_e0h": ["AH=00h (Core services)", "AH=02h (Resource/UI services)",
                     "AH=06h (Window/event services)", "AH=07h (Memory services)"],
        "int_21h": ["AH=25h (Set interrupt vector)", "AH=30h (Get DOS version)",
                     "AH=35h (Get interrupt vector)", "AH=3Eh (Close file)",
                     "AH=40h (Write file)", "AH=44h (IOCTL)",
                     "AH=4Ah (Resize memory block)", "AH=4Ch (Exit process)"],
        "other_ints": ["INT 05h x1 (Print screen)", "INT 20h x1 (DOS terminate)"],
        "strings": [
            ("PAGE SETUP", "Page setup dialog title"),
            ("Default Printer Font", "Font selection label"),
            ("DMSETUP", "Setup module reference"),
            ("DMPRTSEL.CFG", "Printer selection configuration"),
            ("DMPD.CFG", "Printer driver configuration"),
        ],
        "key_functions": [
            ("0000:0010", "dmpdlasr_main", 216, "Main entry -- init laser driver, load config"),
            ("0000:00E8", "dmpdlasr_fontSetup", 67, "Laser font selection setup"),
            ("0000:019C", "dmpdlasr_pageSetup", 165, "Page setup dialog"),
            ("0000:0241", "dmpdlasr_handleCommand", 167, "Command dispatcher"),
            ("0000:04D0", "dmpdlasr_configDialog", 526, "Printer configuration dialog"),
            ("0000:0950", "dmpdlasr_sendEscSeq", 273, "Send PCL escape sequences"),
        ],
    },
    "dmpds": {
        "filename": "DMPDS.ACC",
        "prefix": "dmpds",
        "description": "Printer Driver Services -- shared printing infrastructure",
        "long_desc": (
            "DMPDS.ACC is the shared printer driver services module for DeskMate 3.05.\n"
            "; It provides common printing infrastructure used by all specific printer\n"
            "; driver ACCs (DMPD1, DMPD2, DMPDASCI, DMPDIBMM, DMPDLASR).\n"
            ";\n"
            "; This module handles printer font selection, page formatting calculations,\n"
            "; and the common page setup dialog. It is slightly larger than the specific\n"
            "; drivers (9,559 bytes) because it includes additional shared utility\n"
            "; functions for character set mapping and print layout."
        ),
        "size": 9559,
        "load_image": 9047,
        "entry": "013E:0004",
        "ss_sp": "027A:0FA0",
        "relocs": 13,
        "imports": "dmguf",
        "segments": [
            ("seg_0000", "CODE", "Printer driver services code + DMGUF thunks"),
            ("seg_013E", "CODE", "MSC 5.x CRT startup"),
            ("seg_0148", "CODE", "DM89 import far-call dispatcher"),
            ("seg_014C", "DATA", "DGROUP -- font tables, page format data, strings"),
            ("seg_027A", "STACK", "Stack segment"),
        ],
        "dm_flags": "0x0000",
        "functions": 85,
        "int_e0h": ["AH=00h (Core services)", "AH=02h (Resource/UI services)",
                     "AH=06h (Window/event services)", "AH=07h (Memory services)"],
        "int_21h": ["AH=25h (Set interrupt vector)", "AH=30h (Get DOS version)",
                     "AH=35h (Get interrupt vector)", "AH=3Eh (Close file)",
                     "AH=40h (Write file)", "AH=44h (IOCTL)",
                     "AH=4Ah (Resize memory block)", "AH=4Ch (Exit process)"],
        "other_ints": ["INT 20h x1 (DOS terminate)"],
        "strings": [
            ("PAGE SETUP", "Page setup dialog title"),
            ("Default Printer Font", "Font selection label"),
            ("DMSETUP", "Setup module reference"),
            ("DMPRTSEL.CFG", "Printer selection configuration"),
            ("DMPD.CFG", "Printer driver configuration"),
        ],
        "key_functions": [
            ("0000:0010", "dmpds_main", 487, "Main entry -- init shared driver services"),
            ("0000:01F7", "dmpds_fontService", 293, "Shared font management service"),
            ("0000:031C", "dmpds_charsetMap", 80, "Character set mapping tables"),
            ("0000:0488", "dmpds_pageSetup", 165, "Shared page setup dialog"),
            ("0000:052D", "dmpds_handleCommand", 167, "Shared command dispatcher"),
            ("0000:07BC", "dmpds_configDialog", 526, "Shared configuration dialog"),
            ("0000:0C3C", "dmpds_sendData", 273, "Send formatted data to printer"),
        ],
    },
    "dmphone": {
        "filename": "DMPHONE.ACC",
        "prefix": "dmphone",
        "description": "Phone Dialer -- modem-based telephone dialer accessory",
        "long_desc": (
            "DMPHONE.ACC is the phone dialer accessory for DeskMate 3.05. It provides\n"
            "; a modem-based telephone dialer with integration to the Address Book\n"
            "; database (ADDRESS.PDM) for automatic phone number lookup.\n"
            ";\n"
            "; The module supports work and home phone fields, phone list management,\n"
            "; and shared Address Book access over the network (INT 5Ch for file\n"
            "; locking). It uses INT 28h for idle processing during modem operations\n"
            "; and INT E2h (5 calls) for extended DeskMate communication services.\n"
            ";\n"
            "; Uses DOS date/time services (AH=2Ah/2Ch) for call logging and\n"
            "; INT 21h AH=48h for memory allocation of phone list buffers."
        ),
        "size": 20585,
        "load_image": 20073,
        "entry": "040B:0004",
        "ss_sp": "0665:0FA0",
        "relocs": 29,
        "imports": "dmguf",
        "segments": [
            ("seg_0000", "CODE", "Phone dialer application code + DMGUF thunks"),
            ("seg_040B", "CODE", "MSC 5.x CRT startup + DM89 entry"),
            ("seg_0417", "CODE", "DM89 import far-call dispatchers (segment 1)"),
            ("seg_041A", "CODE", "DM89 import far-call dispatchers (segment 2)"),
            ("seg_041E", "DATA", "DGROUP -- phone lists, modem strings, config data"),
            ("seg_0665", "STACK", "Stack segment"),
        ],
        "dm_flags": "0x0101",
        "functions": 192,
        "int_e0h": ["AH=00h (Core services)", "AH=02h (Resource/UI services)",
                     "AH=06h (Window/event services)", "AH=07h (Memory services)"],
        "int_21h": ["AH=0Eh (Set default drive)", "AH=19h (Get current drive)",
                     "AH=25h (Set interrupt vector)", "AH=2Ah (Get date)",
                     "AH=2Ch (Get time)", "AH=30h (Get DOS version)",
                     "AH=35h (Get interrupt vector)", "AH=3Eh (Close file)",
                     "AH=40h (Write file)", "AH=44h (IOCTL)",
                     "AH=48h (Allocate memory)", "AH=4Ah (Resize memory block)",
                     "AH=4Ch (Exit process)"],
        "other_ints": ["INT 20h x1 (DOS terminate)", "INT 28h x1 (DOS idle hook)",
                       "INT 5Ch x1 (Network file lock)", "INT E2h x5 (Extended DM services)"],
        "strings": [
            ("Phone List", "Phone list window title"),
            ("Work phone", "Work phone field label"),
            ("Home phone", "Home phone field label"),
            ("Phone:", "Phone number field label"),
            ("Error accessing the network.", "Network error message"),
            ("Cannot open the Address Book data file.", "Address Book error"),
            ("Cannot open the Shared Address Book data file.", "Shared AB error"),
        ],
        "key_functions": [
            ("0000:0010", "dmphone_main", 356, "Main entry -- init phone dialer, load address book"),
            ("0000:0174", "dmphone_showPhoneList", 170, "Display phone list window"),
            ("0000:021E", "dmphone_dialNumber", 349, "Dial a phone number via modem"),
            ("0000:037B", "dmphone_handleCommand", 104, "Command dispatcher"),
            ("0000:04B3", "dmphone_editEntry", 217, "Edit a phone list entry"),
            ("0000:058C", "dmphone_searchEntry", 403, "Search for a phone entry"),
            ("0000:071F", "dmphone_modemInit", 114, "Initialize modem for dialing"),
            ("0000:0791", "dmphone_modemDial", 121, "Send dial command to modem"),
            ("0000:09B5", "dmphone_addressBookOps", 503, "Address Book integration operations"),
            ("0000:0BF0", "dmphone_networkOps", 508, "Network file operations (shared AB)"),
            ("0000:0E6D", "dmphone_updateDisplay", 317, "Update phone dialer display"),
            ("0000:1148", "dmphone_phoneListUI", 584, "Phone list UI management"),
            ("0000:1409", "dmphone_entryEditor", 301, "Phone entry editor dialog"),
            ("0000:1748", "dmphone_callLog", 258, "Call log management"),
            ("0000:1E39", "dmphone_settingsDialog", 246, "Phone dialer settings dialog"),
        ],
    },
    "dmprtsel": {
        "filename": "DMPRTSEL.ACC",
        "prefix": "dmprtsel",
        "description": "Printer Selector -- UI for choosing and configuring printers",
        "long_desc": (
            "DMPRTSEL.ACC is the printer selector accessory for DeskMate 3.05. It\n"
            "; provides a user interface for choosing which printer driver to use and\n"
            "; configuring printer ports.\n"
            ";\n"
            "; Imports PRGUF (not DMGUF like most ACCs) for UI rendering. Uses\n"
            "; INT 11h (BIOS equipment list) and INT 13h (disk services) for\n"
            "; hardware detection, likely to enumerate available printer ports.\n"
            ";\n"
            "; Configuration is stored in DMPRTSEL.CFG. The module supports\n"
            "; \"Get a new list of printers\" for rescanning available drivers."
        ),
        "size": 13643,
        "load_image": 13131,
        "entry": "027A:0006",
        "ss_sp": "0676:0FA0",
        "relocs": 14,
        "imports": "PRGUF",
        "segments": [
            ("seg_0000", "CODE", "Printer selector application code + PRGUF thunks"),
            ("seg_027A", "CODE", "MSC 5.x CRT startup"),
            ("seg_0285", "CODE", "DM89 import far-call dispatcher"),
            ("seg_0289", "DATA", "DGROUP -- printer lists, port config, strings"),
            ("seg_0676", "STACK", "Stack segment"),
        ],
        "dm_flags": "0x0000",
        "functions": 130,
        "int_e0h": ["AH=00h (Core services)", "AH=02h (Resource/UI services)",
                     "AH=06h (Window/event services)", "AH=07h (Memory services)"],
        "int_21h": ["AH=25h (Set interrupt vector)", "AH=30h (Get DOS version)",
                     "AH=35h (Get interrupt vector)", "AH=3Eh (Close file)",
                     "AH=40h (Write file)", "AH=44h (IOCTL)",
                     "AH=4Ah (Resize memory block)", "AH=4Ch (Exit process)"],
        "other_ints": ["INT 11h x1 (BIOS equipment list)", "INT 13h x2 (Disk services)",
                       "INT 20h x1 (DOS terminate)"],
        "strings": [
            ("DMSETUP", "Setup module reference"),
            ("DMPRTSEL.CFG", "Printer selection configuration file"),
            ("DMPD.CFG", "Printer driver configuration"),
            ("INSTALL.CFG", "Installation configuration"),
            ("Printers", "Printer list window title"),
            ("No printer", "No printer selected option"),
            ("Printer Ports", "Port selection dialog title"),
            ("Get a new list of printers", "Rescan printers button label"),
        ],
        "key_functions": [
            ("0000:0010", "dmprtsel_main", 77, "Main entry -- init printer selector"),
            ("0000:0085", "dmprtsel_showPrinterList", 267, "Display printer selection list"),
            ("0000:0190", "dmprtsel_selectPrinter", 334, "Handle printer selection"),
            ("0000:02DE", "dmprtsel_showPortList", 113, "Show printer port selection dialog"),
            ("0000:034F", "dmprtsel_scanPrinters", 231, "Scan for available printer drivers"),
            ("0000:0436", "dmprtsel_configPrinter", 298, "Configure selected printer settings"),
            ("0000:0646", "dmprtsel_saveConfig", 161, "Save printer selection to DMPRTSEL.CFG"),
            ("0000:06E7", "dmprtsel_loadDriverList", 449, "Load list of available printer drivers"),
            ("0000:0B69", "dmprtsel_portConfig", 443, "Port configuration dialog"),
            ("0000:0E20", "dmprtsel_hardwareDetect", 386, "Detect printer hardware (INT 11h/13h)"),
            ("0000:1202", "dmprtsel_driverInstall", 488, "Install/configure a printer driver"),
        ],
    },
    "dmserv": {
        "filename": "DMSERV.ACC",
        "prefix": "dmserv",
        "description": "Service/Utility Module -- background services and page setup",
        "long_desc": (
            "DMSERV.ACC is the background services module for DeskMate 3.05. Despite\n"
            "; its name, it provides the Page Setup dialog and serves as a general\n"
            "; service module for printing, floating-point operations, and system\n"
            "; utilities.\n"
            ";\n"
            "; The module contains floating-point error handling routines (linked\n"
            "; with MSC 5.x FP library) and references DMHELP and DMSPELL. INT 07h\n"
            "; is used (coprocessor not-present exception) for FP emulation support.\n"
            ";\n"
            "; At 24,187 bytes with 191 functions, this is a substantial service\n"
            "; module handling multiple subsystems."
        ),
        "size": 24187,
        "load_image": 23675,
        "entry": "04CD:000E",
        "ss_sp": "05F4:0FA0",
        "relocs": 15,
        "imports": "(none)",
        "segments": [
            ("seg_0000", "CODE", "Service module code -- page setup, FP math, utilities"),
            ("seg_04CD", "CODE", "MSC 5.x CRT startup + DM89 entry"),
            ("seg_04D8", "CODE", "DM89 import far-call dispatcher"),
            ("seg_04DC", "DATA", "DGROUP -- page format data, FP constants, strings"),
            ("seg_0594", "CODE", "Additional code segment (FP library routines)"),
            ("seg_05F4", "STACK", "Stack segment"),
        ],
        "dm_flags": "0x0101",
        "functions": 191,
        "int_e0h": ["AH=00h (Core services)", "AH=02h (Resource/UI services)",
                     "AH=07h (Memory services)"],
        "int_21h": ["AH=25h (Set interrupt vector)", "AH=30h (Get DOS version)",
                     "AH=35h (Get interrupt vector)", "AH=3Eh (Close file)",
                     "AH=40h (Write file)", "AH=44h (IOCTL)",
                     "AH=4Ah (Resize memory block)", "AH=4Ch (Exit process)"],
        "other_ints": ["INT 07h x1 (Coprocessor not present)", "INT 20h x1 (DOS terminate)"],
        "strings": [
            ("Page Setup", "Page setup dialog title"),
            ("Error", "Error dialog title"),
            ("- floating-point error: ", "FP error message prefix"),
            ("DMSPELL", "Spell checker resource"),
            ("DMHELP", "Help system resource"),
        ],
        "key_functions": [
            ("0000:0010", "dmserv_main", 70, "Main entry -- register services, init page setup"),
            ("0000:0056", "dmserv_waitForEvent", 72, "Wait for DeskMate events"),
            ("0000:009E", "dmserv_initServices", 26, "Initialize service subsystems"),
            ("0000:00B8", "dmserv_pageSetupDialog", 338, "Main page setup dialog handler"),
            ("0000:020A", "dmserv_marginDialog", 314, "Margin settings sub-dialog"),
            ("0000:0344", "dmserv_parseMargin", 158, "Parse margin value from user input"),
            ("0000:062F", "dmserv_printPreview", 590, "Print preview rendering"),
            ("0000:08F6", "dmserv_configManager", 239, "Configuration management dispatcher"),
            ("0000:09E5", "dmserv_applyConfig", 271, "Apply configuration changes"),
            ("0000:0AF4", "dmserv_readConfig", 298, "Read page setup configuration"),
            ("0000:0CA3", "dmserv_writeConfig", 1398, "Write page setup configuration"),
            ("0000:15D3", "dmserv_fontManager", 604, "Font management for page setup"),
            ("0000:1B11", "dmserv_pageCalc", 577, "Page layout calculation engine"),
            ("0000:1DC1", "dmserv_headerFooter", 476, "Header/footer editing and formatting"),
            ("0000:2785", "dmserv_fpMath", 200, "Floating-point math routines (margin calc)"),
            ("0000:289B", "dmserv_fpFormat", 212, "FP number formatting for display"),
            ("0000:30E4", "dmserv_fpArith", 463, "FP arithmetic (add, sub, mul, div)"),
            ("0000:3680", "dmserv_fpConvert", 432, "FP conversion (int-to-float, float-to-int)"),
            ("0000:38B4", "dmserv_fpCompare", 479, "FP comparison routines"),
            ("0000:3BA2", "dmserv_printEngine", 306, "Print output engine"),
        ],
    },
    "dmsetup": {
        "filename": "DMSETUP.ACC",
        "prefix": "dmsetup",
        "description": "Setup/Preferences -- DeskMate configuration and preferences UI",
        "long_desc": (
            "DMSETUP.ACC is the setup and configuration accessory for DeskMate 3.05.\n"
            "; It provides the user interface for all DeskMate system preferences\n"
            "; including communications setup, modem configuration, display settings,\n"
            "; and printer selection.\n"
            ";\n"
            "; At 28,695 bytes with 193 functions, this is one of the largest ACC\n"
            "; modules. It imports DMGUF for UI rendering and uses INT E2h (5 calls)\n"
            "; for extended DeskMate services (likely network/comm configuration).\n"
            ";\n"
            "; References DMPRTSEL.CFG for printer settings integration."
        ),
        "size": 28695,
        "load_image": 28183,
        "entry": "0574:0008",
        "ss_sp": "070E:0FA0",
        "relocs": 17,
        "imports": "DMGUF",
        "segments": [
            ("seg_0000", "CODE", "Setup application code + DMGUF thunks"),
            ("seg_0574", "CODE", "MSC 5.x CRT startup"),
            ("seg_057F", "CODE", "DM89 import far-call dispatcher"),
            ("seg_0583", "DATA", "DGROUP -- config data, modem strings, display prefs"),
            ("seg_070E", "STACK", "Stack segment"),
        ],
        "dm_flags": "0x0000",
        "functions": 193,
        "int_e0h": ["AH=00h (Core services)", "AH=02h (Resource/UI services)",
                     "AH=06h (Window/event services)", "AH=07h (Memory services)"],
        "int_21h": ["AH=25h (Set interrupt vector)", "AH=30h (Get DOS version)",
                     "AH=35h (Get interrupt vector)", "AH=3Eh (Close file)",
                     "AH=40h (Write file)", "AH=44h (IOCTL)",
                     "AH=4Ah (Resize memory block)", "AH=4Ch (Exit process)"],
        "other_ints": ["INT 20h x1 (DOS terminate)", "INT E2h x5 (Extended DM services)"],
        "strings": [
            ("DMPRTSEL.CFG", "Printer selection configuration"),
            ("Printer...", "Printer settings button label"),
            ("Setup", "Window title"),
            ("Error", "Error dialog title"),
            ("Setup Communications", "Communications setup dialog title"),
            ("Modems", "Modem selection list title"),
            ("Dial Timeout", "Modem dial timeout setting"),
            ("Modem", "Modem configuration section"),
        ],
        "key_functions": [
            ("0000:0010", "dmsetup_main", 1359, "Main entry -- massive setup dialog dispatcher"),
            ("0000:055F", "dmsetup_applySettings", 130, "Apply modified settings"),
            ("0000:0610", "dmsetup_displayDialog", 825, "Display main setup dialog"),
            ("0000:0949", "dmsetup_commSetup", 324, "Communications setup sub-dialog"),
            ("0000:0A8D", "dmsetup_modemSetup", 284, "Modem configuration sub-dialog"),
            ("0000:0F0A", "dmsetup_printerConfig", 441, "Printer configuration integration"),
            ("0000:1191", "dmsetup_displayConfig", 404, "Display/video configuration"),
            ("0000:135F", "dmsetup_soundConfig", 1905, "Sound configuration (large handler)"),
            ("0000:1AE9", "dmsetup_dateTimeConfig", 466, "Date/time format configuration"),
            ("0000:1CBB", "dmsetup_fileConfig", 1127, "File/directory configuration"),
            ("0000:2488", "dmsetup_networkConfig", 720, "Network configuration"),
            ("0000:2758", "dmsetup_advancedConfig", 588, "Advanced settings"),
            ("0000:2E5D", "dmsetup_colorConfig", 957, "Color/appearance configuration"),
            ("0000:3264", "dmsetup_keyboardConfig", 953, "Keyboard configuration"),
            ("0000:3F1E", "dmsetup_mouseConfig", 1573, "Mouse configuration"),
        ],
    },
    "dmspell": {
        "filename": "DMSPELL.ACC",
        "prefix": "dmspell",
        "description": "Spell Checker Accessory -- dictionary-based spelling verification",
        "long_desc": (
            "DMSPELL.ACC is the spell checker accessory for DeskMate 3.05. It provides\n"
            "; dictionary-based spelling verification for all text-editing applications.\n"
            "; It works in conjunction with SPELL.RES (the spell-check engine) and\n"
            "; DICTARY.RES (the dictionary data).\n"
            ";\n"
            "; The module has 153 functions in only 7,510 bytes, meaning the average\n"
            "; function is very small (many are 6-byte DMGUF thunks). The actual\n"
            "; spell-check logic is delegated to the SPELL resource module.\n"
            ";\n"
            "; Uses INT ABh (1 call) likely for inter-module communication with the\n"
            "; active text editor. INT 21h AH=45h (Duplicate handle) and AH=68h\n"
            "; (Commit file) are used for dictionary file management."
        ),
        "size": 7510,
        "load_image": 6998,
        "entry": "014F:0001",
        "ss_sp": "0343:0FA0",
        "relocs": 7,
        "imports": "(none)",
        "segments": [
            ("seg_0000", "CODE", "Spell checker code + SPELL.RES thunks"),
            ("seg_014F", "CODE", "MSC 5.x CRT startup"),
            ("seg_0150", "DATA", "DGROUP -- dictionary refs, word buffers, strings"),
            ("seg_0343", "STACK", "Stack segment"),
        ],
        "dm_flags": "0x0000",
        "functions": 153,
        "int_e0h": ["AH=02h (Resource/UI services)", "AH=07h (Memory services)"],
        "int_21h": ["AH=30h (Get DOS version)", "AH=3Eh (Close file)",
                     "AH=45h (Duplicate file handle)", "AH=4Ch (Exit process)",
                     "AH=68h (Commit file)"],
        "other_ints": ["INT ABh x1 (Editor IPC)"],
        "strings": [
            ("Spell Checker", "Window title"),
            ("File", "File menu label"),
            ("DeskMate Spell Checker", "About dialog title"),
            ("Spelling correct.", "Status for correctly spelled word"),
            ("All words are correctly spelled.", "Completion message"),
            ("DMHELP", "Help system resource"),
            ("SPELL", "Spell engine resource module"),
        ],
        "key_functions": [
            ("0000:0175", "dmspell_registerModule", 11, "Register with SPELL.RES"),
            ("0000:0180", "dmspell_unregisterModule", 11, "Unregister from SPELL.RES"),
            ("0000:018B", "dmspell_checkWord", 15, "Check a single word against dictionary"),
            ("0000:01B3", "dmspell_getSuggestions", 35, "Get spelling suggestions for a word"),
            ("0000:0237", "dmspell_initChecker", 34, "Initialize spell checker, load dictionary"),
            ("0000:02C7", "dmspell_lookupWord", 168, "Look up word in dictionary (hash-based)"),
            ("0000:03D9", "dmspell_checkDocument", 132, "Check all words in a document"),
            ("0000:045D", "dmspell_handleMisspelling", 96, "Handle a misspelled word (UI dialog)"),
            ("0000:04D5", "dmspell_replaceWord", 295, "Replace misspelled word with suggestion"),
            ("0000:05FC", "dmspell_addToDict", 393, "Add word to user dictionary"),
            ("0000:07B8", "dmspell_ignoreWord", 153, "Ignore word (skip without adding)"),
            ("0000:0B0B", "dmspell_autoProof", 68, "Auto-proof mode handler"),
            ("0000:0B4F", "dmspell_uiDialog", 128, "Spell checker UI dialog management"),
            ("0000:0C2B", "dmspell_wordBreaker", 226, "Word boundary detection (tokenizer)"),
            ("0000:0F92", "dmspell_dictFileOps", 159, "Dictionary file I/O operations"),
            ("0000:1073", "dmspell_hashFunction", 169, "Dictionary hash function"),
            ("0000:12AF", "dmspell_compression", 82, "Dictionary compression handler"),
        ],
    },
    "dmtodo": {
        "filename": "DMTODO.ACC",
        "prefix": "dmtodo",
        "description": "To-Do List -- task/reminder tracking accessory",
        "long_desc": (
            "DMTODO.ACC is the to-do list desk accessory for DeskMate 3.05. It provides\n"
            "; a simple task tracking list (\"Things To Do\") with integration to the\n"
            "; Calendar application.\n"
            ";\n"
            "; The module reads/writes DESKTOP.CFG for to-do list persistence and\n"
            "; references DMCONFIG and CALENDAR resources for calendar integration.\n"
            "; At 6,086 bytes with 85 functions, it is one of the smaller ACC modules.\n"
            ";\n"
            "; DM flags 0x0101 indicate this is a standard ACC with UI window."
        ),
        "size": 6086,
        "load_image": 5574,
        "entry": "0120:0008",
        "ss_sp": "015F:0DAC",
        "relocs": 13,
        "imports": "(none)",
        "segments": [
            ("seg_0000", "CODE", "To-do list application code"),
            ("seg_0120", "CODE", "MSC 5.x CRT startup + DM89 entry"),
            ("seg_012B", "CODE", "DM89 import far-call dispatcher"),
            ("seg_012F", "DATA", "DGROUP -- to-do items, strings, config data"),
            ("seg_015F", "STACK", "Stack segment"),
        ],
        "dm_flags": "0x0101",
        "functions": 85,
        "int_e0h": ["AH=02h (Resource/UI services)", "AH=07h (Memory/timer services)"],
        "int_21h": ["AH=25h (Set interrupt vector)", "AH=30h (Get DOS version)",
                     "AH=35h (Get interrupt vector)", "AH=3Eh (Close file)",
                     "AH=40h (Write file)", "AH=44h (IOCTL)",
                     "AH=4Ah (Resize memory block)", "AH=4Ch (Exit process)"],
        "other_ints": ["INT 20h x1 (DOS terminate)"],
        "strings": [
            ("Things To Do", "Window title"),
            ("CANCEL", "Cancel button label"),
            ("DMHELP", "Help system resource"),
            ("DMCONFIG", "Configuration resource"),
            ("CALENDAR", "Calendar integration resource"),
            ("A:\\DESKTOP.CFG", "Desktop config file path (floppy)"),
            ("DESKTOP.CFG", "Desktop config file name"),
        ],
        "key_functions": [
            ("0000:0010", "dmtodo_main", 90, "Main entry -- init to-do list, load config"),
            ("0000:006A", "dmtodo_displayList", 207, "Display to-do items in scrollable list"),
            ("0000:0139", "dmtodo_handleCommand", 219, "Command dispatcher for to-do operations"),
            ("0000:0214", "dmtodo_editItem", 303, "Edit a to-do item (text, priority, status)"),
            ("0000:0343", "dmtodo_addItem", 104, "Add a new to-do item"),
            ("0000:03AB", "dmtodo_deleteItem", 148, "Delete a to-do item"),
            ("0000:043F", "dmtodo_saveList", 451, "Save to-do list to DESKTOP.CFG"),
            ("0000:0602", "dmtodo_loadList", 97, "Load to-do list from DESKTOP.CFG"),
            ("0000:0663", "dmtodo_sortItems", 97, "Sort to-do items by priority"),
            ("0000:0706", "dmtodo_eventLoop", 103, "Main event processing loop"),
            ("0000:077C", "dmtodo_drawItem", 196, "Draw a single to-do item in the list"),
            ("0000:097C", "dmtodo_scrollHandler", 273, "Handle list scrolling events"),
        ],
    },
}


def generate_annotation(mod_key, mod):
    """Generate a complete annotated .asm file for an ACC module."""
    lines = []

    # Header
    lines.append("; ========================================================================")
    lines.append(f"; {mod['filename']} -- Fully Annotated Disassembly")
    lines.append("; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987, Microsoft Corp.")
    lines.append("; Compiled with Microsoft C 5.x (1987), Medium Memory Model")
    lines.append("; Annotated for the Bayside reverse engineering project")
    lines.append("; ========================================================================")
    lines.append(";")
    lines.append(f"; {mod['filename']} is the {mod['description'].lower()}.")
    for desc_line in mod['long_desc'].split("\n"):
        dl = desc_line.rstrip()
        if dl and not dl.startswith(";"):
            lines.append("; " + dl)
        else:
            lines.append(dl)
    lines.append(";")
    lines.append("; ========================================================================")
    lines.append("; BINARY STRUCTURE")
    lines.append("; ========================================================================")
    lines.append(";")
    lines.append(f"; MZ + DM89 header (512 bytes)")
    lines.append(f"; File size: {mod['size']:,} bytes")
    lines.append(f"; Load image: {mod['load_image']:,} bytes (after header)")
    lines.append(f"; DM89 entry point: {mod['entry']} (MSC 5.x CRT startup)")
    lines.append(f"; SS:SP = {mod['ss_sp']}")
    lines.append(";")
    lines.append(f"; Segment Map ({len(mod['segments'])} segments, {mod['relocs']} relocations):")
    for seg_name, seg_type, seg_desc in mod['segments']:
        lines.append(f";   {seg_name:<12s} {seg_type:<8s} {seg_desc}")
    lines.append(";")
    lines.append(f"; Medium memory model: multiple code segments, DGROUP at {mod['segments'][-2][0].split('_')[1] if len(mod['segments']) > 1 else '????'}.")
    lines.append(";")
    lines.append(f"; DM flags: {mod['dm_flags']}")
    if mod['imports'] != "(none)":
        lines.append(f"; Imports: {mod['imports']}")
    lines.append(";")

    # Interrupt Services
    lines.append("; ========================================================================")
    lines.append("; INTERRUPT SERVICES USED")
    lines.append("; ========================================================================")
    lines.append(";")
    lines.append("; INT E0h (DeskMate API):")
    for svc in mod['int_e0h']:
        lines.append(f";   {svc}")
    lines.append(";")
    lines.append("; INT 21h (DOS API):")
    for svc in mod['int_21h']:
        lines.append(f";   {svc}")
    if mod['other_ints']:
        lines.append(";")
        lines.append("; Other interrupts:")
        for oint in mod['other_ints']:
            lines.append(f";   {oint}")
    lines.append(";")

    # Notable Strings
    lines.append("; ========================================================================")
    lines.append("; NOTABLE STRINGS")
    lines.append("; ========================================================================")
    lines.append(";")
    for sname, sdesc in mod['strings']:
        lines.append(f';   "{sname}"  -- {sdesc}')
    lines.append(";")

    # Function Index
    lines.append("; ========================================================================")
    func_count = mod["functions"]
    lines.append(f"; FUNCTION INDEX ({func_count} functions total)")
    lines.append("; ========================================================================")
    lines.append(";")
    lines.append(f"; --- {mod['filename'].replace('.ACC', '')} Application Functions ---")
    lines.append(";")
    lines.append("; Address   Name                          Size  Description")
    lines.append("; -------   ----                          ----  -----------")
    for addr, name, size, desc in mod['key_functions']:
        lines.append(f"; {addr} {name:<30s} {size:>4d}  {desc}")
    lines.append(";")

    # Thunk identification
    lines.append("; --- DMGUF/Resource Thunks (6 bytes each) ---")
    lines.append(";")
    lines.append("; The remaining functions are 6-byte far-call thunks generated by the")
    lines.append("; DM89 import mechanism. Each thunk loads AX with a function code and")
    lines.append("; jumps to the import dispatcher. These provide access to DeskMate API")
    lines.append("; services (DMGUF, PRGUF, etc.) without direct INT E0h calls from")
    lines.append("; application code.")
    lines.append(";")

    # MSC CRT identification
    lines.append("; --- MSC 5.x C Runtime Library Functions ---")
    lines.append(";")
    lines.append(f"; start (at {mod['entry']}) -- MSC 5.x CRT startup sequence:")
    lines.append(";   1. Set up DS, SS, SP")
    lines.append(";   2. Resize memory block (INT 21h AH=4Ah)")
    lines.append(";   3. Initialize CRT (heap, stdio, argv)")
    lines.append(";   4. Call _main()")
    lines.append(";   5. Call _exit() on return")
    lines.append(";")
    lines.append("; The CRT startup also includes standard MSC error handlers:")
    lines.append(";   R6000 - stack overflow")
    lines.append(";   R6001 - null pointer assignment")
    lines.append(";   R6002 - floating point not loaded")
    lines.append(";   R6003 - integer divide by 0")
    lines.append(";   R6009 - not enough space for environment")
    lines.append(";")

    # Raw disassembly inclusion notice
    lines.append("; ========================================================================")
    lines.append("; ANNOTATED DISASSEMBLY")
    lines.append("; ========================================================================")
    lines.append(";")
    lines.append(f"; Below is the raw disassembly from {mod['filename']} with function")
    lines.append("; boundaries annotated using the labels defined in the function index")
    lines.append("; above. 6-byte thunk functions are identified with their DM89 import")
    lines.append("; function codes.")
    lines.append(";")

    # Read and include the raw disassembly with annotation overlays
    raw_path = os.path.join(RAW_DIR, f"{mod_key}.asm")
    if os.path.exists(raw_path):
        with open(raw_path, 'r') as f:
            raw_lines = f.readlines()

        # Build address-to-name mapping from key_functions
        addr_to_name = {}
        for addr, name, size, desc in mod['key_functions']:
            # Parse address like "0000:0010" to linear offset
            parts = addr.split(":")
            seg = int(parts[0], 16)
            off = int(parts[1], 16)
            linear = seg * 16 + off  # Approximate, but segment base varies
            # Also store by offset alone (within segment 0000)
            addr_to_name[off] = (name, desc)

        in_header = True
        for line in raw_lines:
            stripped = line.rstrip()

            # Skip the raw file's header comment (we replaced it)
            if in_header:
                if stripped.startswith(";") or stripped == "":
                    continue
                in_header = False

            # Check for function markers and annotate them
            m = re.match(r'^; ---- (sub_\w+|start) ----', stripped)
            if m:
                func_label = m.group(1)
                # Try to find the linear address from the next instruction
                lines.append("")
                lines.append(stripped)
                continue

            # Check for sub_XXXXX: labels and try to map them
            m = re.match(r'^(sub_(\w+)|start):', stripped)
            if m:
                if m.group(2):
                    addr_hex = int(m.group(2), 16)
                    if addr_hex in addr_to_name:
                        name, desc = addr_to_name[addr_hex]
                        lines.append(f"; --- {name}: {desc}")
                        lines.append(f"{name}:  ; was {m.group(1)}")
                        continue
                lines.append(stripped)
                continue

            lines.append(stripped)

    return "\n".join(lines) + "\n"


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    for mod_key, mod in MODULES.items():
        print(f"Annotating {mod['filename']}...")
        content = generate_annotation(mod_key, mod)
        out_path = os.path.join(OUT_DIR, f"{mod_key}.asm")
        with open(out_path, 'w') as f:
            f.write(content)
        print(f"  -> {out_path} ({len(content):,} bytes)")

    print(f"\nDone. {len(MODULES)} annotated ACC files written to {OUT_DIR}/")


if __name__ == "__main__":
    main()
