#!/usr/bin/env python3
"""
Annotate TELECOM.PDM raw disassembly with function names, variable labels,
and inline comments.

Reads the raw disassembly and produces a fully annotated version.
"""

import re
import sys

RAW_PATH = "/Users/joe/Documents/GitHub/bayside/disassembly/raw/telecom.asm"
ANNOTATED_HEADER_PATH = "/Users/joe/Documents/GitHub/bayside/disassembly/annotated/telecom.asm"
OUTPUT_PATH = "/Users/joe/Documents/GitHub/bayside/disassembly/annotated/telecom.asm"

# ============================================================
# Function name mapping: sub_XXXXX -> descriptive_name
# ============================================================
FUNC_NAMES = {
    "sub_00010": "telecom_main",
    "sub_00355": "telecom_initFormFields",
    "sub_00390": "telecom_openPhoneBook",
    "sub_0042F": "telecom_checkAndLoadPB",
    "sub_0048E": "telecom_setupTerminalWindow",
    "sub_00521": "telecom_setWindowTitle",
    "sub_00548": "telecom_parseComSettings",
    "sub_00636": "telecom_drawTerminalFrame",
    "sub_006EB": "telecom_loadPhoneBookData",
    "sub_00BE2": "telecom_parsePhoneBookFields",
    "sub_00DB7": "telecom_mainEventLoop",
    "sub_01472": "telecom_buildStatusLine",
    "sub_014F5": "telecom_handleTimerEvent",
    "sub_01647": "telecom_handleResizeEvent",
    "sub_016B7": "telecom_handleConnectionLost",
    "sub_01792": "telecom_setTimerInterval",
    "sub_017DA": "telecom_handleModemResponse",
    "sub_018B5": "telecom_updateStatusDisplay",
    "sub_0194A": "telecom_savePhoneBookOnExit",
    "sub_01974": "telecom_processEventResult",
    "sub_019AA": "telecom_handleExitRequest",
    "sub_019D6": "telecom_handleHangup",
    "sub_01A45": "telecom_getResourceString",
    "sub_01ACF": "telecom_checkPortErrors",
    "sub_01B0A": "telecom_openComPort",
    "sub_01C0F": "telecom_displayStatusMessage",
    "sub_01C8F": "telecom_displayLineInfo",
    "sub_01CC5": "telecom_drawStatusBar",
    "sub_01DA2": "telecom_printStatusField",
    "sub_01E41": "telecom_getPortStatusByte",
    "sub_01E67": "telecom_editPhoneBookDialog",
    "sub_0205C": "telecom_processIncomingBlock",
    "sub_021B7": "telecom_applyPhoneBookEntry",
    "sub_0221D": "telecom_formatPhoneBookEntry",
    "sub_02390": "telecom_initSession",
    "sub_025AC": "telecom_formatBaudDisplay",
    "sub_025F4": "telecom_processSerialChar",
    "sub_02677": "telecom_handleFlowControl",
    "sub_026A4": "telecom_readAndProcessData",
    "sub_026C8": "telecom_processIncomingData",
    "sub_027A1": "telecom_writeToScrollBuffer",
    "sub_027C7": "telecom_echoCharToTerminal",
    "sub_02843": "telecom_drawTerminalText",
    "sub_02A32": "telecom_scrollTerminalUp",
    "sub_02A83": "telecom_updateCursorPosition",
    "sub_02AF1": "telecom_handleControlChar",
    "sub_02B43": "telecom_processTerminalChar",
    "sub_02C0A": "telecom_processKeyboardInput",
    "sub_02E66": "telecom_handleMouseEvent",
    "sub_02FB5": "telecom_resetCaptureState",
    "sub_03017": "telecom_readPortBuffer",
    "sub_03080": "telecom_sendToPort",
    "sub_03101": "telecom_toggleCaptureFile",
    "sub_03182": "telecom_transferFileBlock",
    "sub_0328A": "telecom_monitorTransferProgress",
    "sub_03309": "telecom_checkTransferTimeout",
    "sub_03370": "telecom_closeTransferFile",
    "sub_033C9": "telecom_handleFileTransfer",
    "sub_03579": "telecom_showTransferDialog",
    "sub_035A8": "telecom_runTransferLoop",
    "sub_0366A": "telecom_updateTerminalDisplay",
    "sub_0376A": "telecom_handleTerminalEscape",
    "sub_039C8": "telecom_parseSettingsTable1",
    "sub_03A34": "telecom_parseSettingsTable2",
    "sub_03BBC": "telecom_parseSettingsTable3",
    "sub_03CBA": "telecom_showErrorDialog",
    "sub_03DB5": "telecom_validateDialString",
    "sub_03FC2": "telecom_redrawAfterDialog",
    "sub_04093": "telecom_handleTerminalAction",
    "sub_045A9": "telecom_processMenuSelection",
    "sub_04877": "telecom_setDialParameters",
    "sub_0488A": "telecom_copyDialString",
    "sub_04910": "telecom_runInputFieldDialog",
    "sub_04CA5": "telecom_showSettingsDialog",
    "sub_04D8F": "telecom_getProtocolName",
    "sub_04D9C": "telecom_handleProtocolAction",
    "sub_04DCB": "telecom_closeCapture",
    "sub_04DEC": "telecom_openCaptureFile",
    "sub_04E72": "telecom_writeCaptureData",
    "sub_04EF0": "telecom_updateScrollPosition",
    "sub_04F51": "telecom_clearInputBuffer",
    "sub_04F7A": "telecom_closeComPort",
    "sub_04FE6": "telecom_getPortStatus",
    "sub_05001": "telecom_handleBreakAction",
    "sub_0504A": "telecom_checkCarrier",
    "sub_05068": "telecom_getCharFromPort",
    "sub_0509E": "telecom_putCharToPort",
    "sub_050D0": "telecom_readPortBlock",
    "sub_0517C": "telecom_initiateFileTransfer",
    "sub_051DD": "telecom_runSendFileDialog",
    "sub_05338": "telecom_formatTransferStatus",
    "sub_0545D": "telecom_runReceiveFileDialog",
    "sub_056CC": "telecom_showProgress1",
    "sub_05721": "telecom_showProgress2",
    "sub_05776": "telecom_recursivePadding",
    "sub_057A7": "telecom_prepareTransferMode",
    "sub_0581A": "telecom_callProgressUpdate",
    "sub_05827": "telecom_sendPortByte",
    "sub_05835": "telecom_transferDataBlock",
    "sub_0588F": "telecom_handleTransferError",
    "sub_059B4": "telecom_runDialDialog",
    "sub_05B19": "telecom_runAnswerDialog",
    "sub_05C43": "telecom_validatePhoneNumber",
    "sub_05C88": "crt_setTimerCallback",
    "sub_05CBA": "crt_resizeMemory",
    "sub_05CFC": "crt_beep",
    "sub_05D05": "crt_startup",
    "sub_05D4B": "crt_callMain",
    "sub_05D5A": "crt_initRuntime",
    "sub_05E1E": "crt_exit",
    "sub_05E35": "crt_closeFiles",
    "sub_05E7A": "crt_restoreVectors",
    "sub_05E93": "crt_indirectCall",
    "sub_05EA2": "crt_getEnvironment",
    "sub_05EB6": "crt_parseCommandLine",
    "sub_05F1E": "telecom_callProtocolRes",
    "sub_05F5A": "telecom_unloadProtocolRes",
    "sub_05F80": "telecom_loadTranslatRes",
    "sub_05FC2": "telecom_unloadTranslatRes",
    "sub_05FE2": "telecom_protocolStubA",
    "sub_05FE6": "telecom_protocolStubB",
    "sub_05FEA": "telecom_charDispatch",
    "sub_0606B": "prguf_closeFile",
    "sub_06071": "prguf_deleteFile",
    "sub_06077": "prguf_openFile",
    "sub_0607D": "prguf_readFile",
    "sub_06083": "prguf_writeFile",
    "sub_06089": "prguf_func200E",
    "sub_0608F": "prguf_func200F",
    "sub_06095": "prguf_func2010",
    "sub_0609B": "prguf_getResourceString",
    "sub_060A1": "prguf_getPortStatus",
    "sub_060A7": "prguf_openPort",
    "sub_060AD": "prguf_checkPortReady",
    "sub_060B3": "prguf_setPortParam",
    "sub_060B9": "prguf_func60B9",
    "sub_060BF": "prguf_getCarrierDetect",
    "sub_060C5": "prguf_compareStrings",
    "sub_060CB": "prguf_openDialDialog",
    "sub_060D1": "telecom_loadResourceByCode",
    "sub_06139": "prguf_initModule",
    "sub_0613F": "prguf_getTimerTick",
    "sub_06145": "telecom_loadTranslat",
    "sub_0615E": "telecom_unloadTranslat",
    "sub_0616D": "telecom_initResources",
    "sub_06174": "telecom_cleanupResources",
    "sub_0617B": "prguf_dispatch",
    "sub_061A3": "prguf_openFile2",
    "sub_061A9": "prguf_readFile2",
    "sub_061AF": "prguf_endUpdate",
    "sub_061B5": "prguf_beginUpdate",
    "sub_061BB": "prguf_getCharAttr",
    "sub_061C1": "prguf_setCharAttr",
    "sub_061C7": "prguf_getEvent",
    "sub_061CD": "prguf_sendEvent",
    "sub_061D3": "prguf_setTimer",
    "sub_061D9": "prguf_showMenuBar",
    "sub_061DF": "prguf_showWaitCursor",
    "sub_061E5": "prguf_hideWaitCursor",
    "sub_061EB": "prguf_createDialog",
    "sub_061F1": "prguf_hideMenuBar",
    "sub_061F7": "prguf_setDialogResult",
    "sub_061FD": "prguf_getDialogField",
    "sub_06203": "prguf_setDialogField",
    "sub_06209": "prguf_restoreWindow",
    "sub_0620F": "prguf_setForeColor",
    "sub_06215": "prguf_refreshScreen",
    "sub_0621B": "prguf_getScreenWidth",
    "sub_06221": "prguf_getScreenHeight",
    "sub_06227": "prguf_setCursorPos",
    "sub_0622D": "prguf_getCursorPos",
    "sub_06233": "prguf_showCursor",
    "sub_06239": "prguf_hideCursor",
    "sub_0623F": "prguf_setTextAttr",
    "sub_06245": "prguf_setColor",
    "sub_0624B": "prguf_setWindowAttr",
    "sub_06251": "prguf_setWindowMode",
    "sub_06257": "prguf_scrollWindow",
    "sub_0625D": "prguf_printString",
    "sub_06263": "prguf_printChar",
    "sub_06269": "prguf_drawHLine",
    "sub_0626F": "prguf_drawVLine",
    "sub_06275": "prguf_drawBox",
    "sub_0627B": "prguf_fillRegion",
    "sub_06281": "prguf_setViewport",
    "sub_06287": "prguf_createWindow",
    "sub_0628D": "prguf_resizeWindow",
    "sub_06293": "prguf_destroyWindow",
    "sub_06299": "prguf_selectWindow",
    "sub_0629F": "prguf_getWindowHandle",
    "sub_062A5": "prguf_setWindowSize",
    "sub_062AB": "prguf_getWindowSize",
    "sub_062B1": "prguf_clearWindow",
    "sub_062B7": "prguf_drawMenuItem",
    "sub_062BD": "prguf_drawMenuSep",
    "sub_062C3": "prguf_setMenuBar",
    "sub_062C9": "prguf_closeDialog",
    "sub_062CF": "prguf_endCapture",
    "sub_062D5": "prguf_openDialFile",
    "sub_062DB": "prguf_closeDialFile",
    "sub_062E1": "prguf_dialDialogAction",
    "sub_062E7": "prguf_getDialStatus",
    "sub_062ED": "prguf_openCaptureFile",
    "sub_062F3": "prguf_writeCaptureData",
    "sub_062F9": "prguf_readConfigFile",
    "sub_062FF": "prguf_writeConfigFile",
    "sub_06305": "prguf_putCharToPort",
    "sub_0630B": "prguf_getPortConfig",
    "sub_06311": "prguf_setFormField",
    "sub_06317": "prguf_getFormField",
    "sub_0631D": "prguf_inputField",
    "sub_06323": "prguf_getProtocol",
    "sub_06329": "prguf_selectProtocol",
    "sub_0632F": "prguf_checkCarrier",
    "sub_06335": "prguf_setDefaultFile",
    "sub_0633B": "prguf_setPageTitle",
    "sub_06341": "prguf_setPageSubtitle",
    "sub_06347": "prguf_getSystemConfig",
    "sub_0634D": "prguf_setFieldValue",
    "sub_06353": "prguf_getComPortConfig",
    "sub_06359": "prguf_setComPortConfig",
    "sub_0635F": "prguf_func208F",
    "sub_06365": "prguf_showMessageDialog",
    "sub_0636B": "prguf_setAppAttributes",
    "sub_06371": "prguf_exitApp",
    "sub_06378": "prguf_formatNumber",
    "sub_06571": "prguf_recursiveFormat",
    "sub_0658D": "prguf_appendDigit",
    "sub_06599": "prguf_padWithSpaces",
    "sub_065AA": "prguf_lowLevelDispatch",
    "sub_065B8": "prguf_funcB0",
    "sub_065BE": "prguf_funcB1",
    "sub_065C4": "prguf_funcB2",
    "sub_065CA": "prguf_funcB5",
    "sub_065D0": "prguf_funcB8",
    "sub_065D6": "prguf_funcB9",
    "sub_065DC": "prguf_setupFuncTable",
    "sub_065E2": "prguf_cleanupFuncTable",
    "sub_065E8": "crt_itoa",
    "sub_066F5": "crt_reverseString",
    "sub_0671F": "crt_strlen",
    "sub_06734": "crt_mainWrapper",
    "sub_0675A": "crt_exitCleanup",
    "sub_0677C": "crt_printf",
    "sub_0690A": "crt_putchar",
    "sub_06935": "crt_flushStdout",
    "sub_0695E": "crt_initHeap",
    "sub_069A0": "crt_freeBlock",
    "sub_069B2": "crt_malloc",
    "sub_069F8": "crt_formatDialogStruct",
    "sub_06A38": "crt_sprintfField",
    "sub_06A6A": "crt_getTimestamp",
    "sub_06A96": "crt_formatDecimal",
    "sub_06AB2": "crt_memcpy",
    "sub_06AE8": "crt_getTickCount",
    "sub_06B40": "crt_atoi",
    "sub_06B6F": "crt_mallocFar",
    "sub_06C52": "crt_reallocFar",
    "sub_06C8C": "crt_freeFar",
    "sub_06CAE": "crt_dosAlloc",
    "sub_06CCE": "crt_writeBuffer",
    "sub_06DE4": "crt_dosRealloc",
    "sub_06E52": "crt_dosAllocPages",
    "sub_06EA8": "crt_heapManager",
    "sub_06F58": "crt_heapWalk",
    "sub_0702C": "crt_paragraphAlign",
    "sub_07060": "crt_addToFreeList",
    "sub_07088": "crt_heapInit2",
    "sub_0708C": "crt_formatOutput",
    "sub_070E2": "crt_writeStderr",
    "sub_0711C": "crt_initFileTable",
    "sub_07170": "start",
    "sub_07435": "crt_initStartupData",
    "sub_07503": "crt_extendedStartup",
    "sub_0E1B9": "crt_farStartupHelper",
}

# Function descriptions for header comments
FUNC_DESCRIPTIONS = {
    "telecom_main": "Main entry point (argc, argv). Loads resources, initializes COM port, enters event loop.",
    "telecom_initFormFields": "Initialize form field structures with defaults (8N1).",
    "telecom_openPhoneBook": "Open/save phone book file. mode=1 saves, mode=0 checks.",
    "telecom_checkAndLoadPB": "Check phone book state and reload if needed.",
    "telecom_setupTerminalWindow": "Set up terminal window attributes and display.",
    "telecom_setWindowTitle": "Set window title bar text from phone book filename.",
    "telecom_parseComSettings": "Parse COM port settings (baud, data bits, parity, stop bits) from config.",
    "telecom_drawTerminalFrame": "Draw terminal frame with viewport, borders, status area.",
    "telecom_loadPhoneBookData": "Load and parse phone book data from file into memory array.",
    "telecom_parsePhoneBookFields": "Parse individual phone book entry fields from text data.",
    "telecom_mainEventLoop": "Main event dispatch loop. Processes menu, keyboard, serial, mouse, timer events.",
    "telecom_buildStatusLine": "Build the status line text for bottom of terminal.",
    "telecom_handleTimerEvent": "Handle periodic timer tick (check connection, update status).",
    "telecom_handleResizeEvent": "Handle window resize event.",
    "telecom_handleConnectionLost": "Handle lost carrier / connection dropped.",
    "telecom_setTimerInterval": "Set the timer interval for event polling.",
    "telecom_handleModemResponse": "Handle modem response strings (CONNECT, NO CARRIER, etc.).",
    "telecom_updateStatusDisplay": "Update the status display area with current info.",
    "telecom_savePhoneBookOnExit": "Save phone book data before exiting.",
    "telecom_processEventResult": "Process the result code from event loop iteration.",
    "telecom_handleExitRequest": "Handle user exit request (save changes prompt).",
    "telecom_handleHangup": "Handle hang up action (drop DTR, send +++ATH).",
    "telecom_getResourceString": "Get a string from the resource string table.",
    "telecom_checkPortErrors": "Check for COM port errors (framing, overrun, parity).",
    "telecom_openComPort": "Open COM port with current settings.",
    "telecom_displayStatusMessage": "Display a status message in the status bar.",
    "telecom_displayLineInfo": "Display line/connection info in status area.",
    "telecom_drawStatusBar": "Draw the complete status bar at bottom of terminal.",
    "telecom_printStatusField": "Print one field of the status bar.",
    "telecom_getPortStatusByte": "Get the raw port status byte.",
    "telecom_editPhoneBookDialog": "Run the phone book entry edit dialog.",
    "telecom_processIncomingBlock": "Process a block of incoming serial data.",
    "telecom_applyPhoneBookEntry": "Apply phone book entry settings to COM port.",
    "telecom_formatPhoneBookEntry": "Format a phone book entry for display/storage.",
    "telecom_initSession": "Initialize a communication session (open port, set params).",
    "telecom_formatBaudDisplay": "Format baud rate for display in status bar.",
    "telecom_processSerialChar": "Process a single incoming serial character.",
    "telecom_handleFlowControl": "Handle XON/XOFF flow control.",
    "telecom_readAndProcessData": "Read data from port and process it.",
    "telecom_processIncomingData": "Process incoming data stream (buffering, capture, display).",
    "telecom_writeToScrollBuffer": "Write character to scroll-back buffer.",
    "telecom_echoCharToTerminal": "Echo a character to the terminal display.",
    "telecom_drawTerminalText": "Draw text in the terminal viewport.",
    "telecom_scrollTerminalUp": "Scroll terminal display up one line.",
    "telecom_updateCursorPosition": "Update cursor position after text output.",
    "telecom_handleControlChar": "Handle control characters (CR, LF, BS, BEL, etc.).",
    "telecom_processTerminalChar": "Process one character for terminal display.",
    "telecom_processKeyboardInput": "Process keyboard input during terminal session.",
    "telecom_handleMouseEvent": "Handle mouse events in terminal window.",
    "telecom_resetCaptureState": "Reset capture file state.",
    "telecom_readPortBuffer": "Read data from port receive buffer.",
    "telecom_sendToPort": "Send data to COM port.",
    "telecom_toggleCaptureFile": "Toggle capture file on/off.",
    "telecom_transferFileBlock": "Transfer one block during file send/receive.",
    "telecom_monitorTransferProgress": "Monitor file transfer progress.",
    "telecom_checkTransferTimeout": "Check for file transfer timeout.",
    "telecom_closeTransferFile": "Close file transfer and cleanup.",
    "telecom_handleFileTransfer": "Handle file transfer operations (send/receive).",
    "telecom_showTransferDialog": "Show file transfer progress dialog.",
    "telecom_runTransferLoop": "Run the main file transfer loop.",
    "telecom_updateTerminalDisplay": "Update terminal display after text changes.",
    "telecom_handleTerminalEscape": "Handle terminal escape sequences.",
    "telecom_parseSettingsTable1": "Parse settings table (part 1 - basic settings).",
    "telecom_parseSettingsTable2": "Parse settings table (part 2 - extended settings).",
    "telecom_parseSettingsTable3": "Parse settings table (part 3 - validation).",
    "telecom_showErrorDialog": "Show error message dialog.",
    "telecom_validateDialString": "Validate and format a dial string.",
    "telecom_redrawAfterDialog": "Redraw terminal after a dialog closes.",
    "telecom_handleTerminalAction": "Handle terminal session menu/key actions.",
    "telecom_processMenuSelection": "Process specific menu item selections.",
    "telecom_setDialParameters": "Set dial parameters from menu selection.",
    "telecom_copyDialString": "Copy dial string to working buffer.",
    "telecom_runInputFieldDialog": "Run a generic input field dialog.",
    "telecom_showSettingsDialog": "Show communication settings dialog.",
    "telecom_getProtocolName": "Get protocol name string.",
    "telecom_handleProtocolAction": "Handle protocol selection action.",
    "telecom_closeCapture": "Close capture file.",
    "telecom_openCaptureFile": "Open capture file for writing.",
    "telecom_writeCaptureData": "Write data to capture file.",
    "telecom_updateScrollPosition": "Update scroll position in terminal.",
    "telecom_clearInputBuffer": "Clear the input character buffer.",
    "telecom_closeComPort": "Close COM port and release resources.",
    "telecom_getPortStatus": "Get COM port status byte.",
    "telecom_handleBreakAction": "Handle Send Break action.",
    "telecom_checkCarrier": "Check carrier detect signal.",
    "telecom_getCharFromPort": "Get next character from port (PRGUF call).",
    "telecom_putCharToPort": "Put character to port (PRGUF call).",
    "telecom_readPortBlock": "Read block of data from port.",
    "telecom_initiateFileTransfer": "Initiate file send/receive transfer.",
    "telecom_runSendFileDialog": "Run Send File dialog.",
    "telecom_formatTransferStatus": "Format file transfer status display.",
    "telecom_runReceiveFileDialog": "Run Receive File dialog.",
    "telecom_showProgress1": "Show transfer progress (variant 1).",
    "telecom_showProgress2": "Show transfer progress (variant 2).",
    "telecom_recursivePadding": "Recursive number-to-string for padding.",
    "telecom_prepareTransferMode": "Prepare terminal for file transfer mode.",
    "telecom_callProgressUpdate": "Call progress update routine.",
    "telecom_sendPortByte": "Send one byte to port (low-level).",
    "telecom_transferDataBlock": "Transfer one block of data.",
    "telecom_handleTransferError": "Handle file transfer error/completion.",
    "telecom_runDialDialog": "Run the Dial dialog (phone number entry).",
    "telecom_runAnswerDialog": "Run Auto-Answer dialog.",
    "telecom_validatePhoneNumber": "Validate phone number format.",
    "crt_setTimerCallback": "Set timer callback function.",
    "crt_resizeMemory": "Resize DOS memory allocation.",
    "crt_beep": "Output BEL character (beep).",
    "crt_startup": "C runtime startup (_main wrapper).",
    "crt_callMain": "Call main() with argc/argv.",
    "crt_initRuntime": "Initialize C runtime (DOS version, vectors).",
    "crt_exit": "_exit() -- close files, restore vectors, terminate.",
    "crt_closeFiles": "Close all open file handles.",
    "crt_restoreVectors": "Restore saved interrupt vectors.",
    "crt_indirectCall": "Indirect function call via CX register.",
    "crt_getEnvironment": "Get environment block pointer.",
    "crt_parseCommandLine": "Parse command line into argc/argv.",
    "telecom_callProtocolRes": "Call PROTOCOL.RES dispatch function.",
    "telecom_unloadProtocolRes": "Unload PROTOCOL.RES module.",
    "telecom_loadTranslatRes": "Load TRANSLAT.RES resource module via INT E0h.",
    "telecom_unloadTranslatRes": "Unload TRANSLAT.RES resource module.",
    "telecom_protocolStubA": "Stub: return 0xFFFF (no protocol loaded).",
    "telecom_protocolStubB": "Stub: return 0xFFFF (no protocol loaded).",
    "telecom_charDispatch": "Character dispatch through resource module.",
    "prguf_closeFile": "PRGUF 0x2002: Close file.",
    "prguf_deleteFile": "PRGUF 0x2003: Delete file.",
    "prguf_openFile": "PRGUF 0x2004: Open file.",
    "prguf_readFile": "PRGUF 0x2005: Read file.",
    "prguf_writeFile": "PRGUF 0x200D: Write file.",
    "prguf_func200E": "PRGUF 0x200E.",
    "prguf_func200F": "PRGUF 0x200F.",
    "prguf_func2010": "PRGUF 0x2010.",
    "prguf_getResourceString": "PRGUF: Get resource string.",
    "prguf_getPortStatus": "PRGUF 0xAC: Get port status.",
    "prguf_openPort": "PRGUF 0xAA: Open port.",
    "prguf_checkPortReady": "PRGUF 0xAB: Check port ready.",
    "prguf_setPortParam": "PRGUF 0xAD: Set port parameter.",
    "prguf_func60B9": "PRGUF 0xAE.",
    "prguf_getCarrierDetect": "PRGUF 0xAD: Get carrier detect.",
    "prguf_compareStrings": "PRGUF 0xAF: Compare strings.",
    "prguf_openDialDialog": "PRGUF 0xB3: Open dial dialog.",
    "telecom_loadResourceByCode": "Load resource module by code number.",
    "prguf_initModule": "PRGUF 0x020A: Init module.",
    "prguf_getTimerTick": "PRGUF 0x0501: Get timer tick.",
    "telecom_loadTranslat": "Load TRANSLAT.RES (INT E0h AX=0206h).",
    "telecom_unloadTranslat": "Unload TRANSLAT.RES (INT E0h AX=0207h).",
    "telecom_initResources": "Init: load TRANSLAT + PRGUF setup.",
    "telecom_cleanupResources": "Cleanup: unload PRGUF + TRANSLAT.",
    "prguf_dispatch": "PRGUF generic dispatch (far call to PRGUF.RES).",
    "prguf_openFile2": "PRGUF 0x2004: Open file (alternate entry).",
    "prguf_readFile2": "PRGUF 0x2005: Read file (alternate entry).",
    "prguf_endUpdate": "PRGUF 0x2006: End screen update.",
    "prguf_beginUpdate": "PRGUF 0x2007: Begin screen update.",
    "prguf_getCharAttr": "PRGUF 0x2010: Get char+attribute.",
    "prguf_setCharAttr": "PRGUF 0x2011: Set char+attribute.",
    "prguf_getEvent": "PRGUF 0x2013: Get event from queue.",
    "prguf_sendEvent": "PRGUF 0x2015: Send event.",
    "prguf_setTimer": "PRGUF 0x2017: Set timer interval.",
    "prguf_showMenuBar": "PRGUF 0x2018: Show menu bar.",
    "prguf_showWaitCursor": "PRGUF 0x201C: Show wait cursor.",
    "prguf_hideWaitCursor": "PRGUF 0x201E: Hide wait cursor.",
    "prguf_createDialog": "PRGUF 0x2028: Create dialog.",
    "prguf_hideMenuBar": "PRGUF 0x202B: Hide menu bar.",
    "prguf_setDialogResult": "PRGUF 0x202C: Set dialog result.",
    "prguf_getDialogField": "PRGUF 0x202D: Get dialog field value.",
    "prguf_setDialogField": "PRGUF 0x202E: Set dialog field value.",
    "prguf_restoreWindow": "PRGUF 0x2030: Restore window.",
    "prguf_setForeColor": "PRGUF 0x2037: Set foreground color.",
    "prguf_refreshScreen": "PRGUF 0x2039: Refresh screen.",
    "prguf_getScreenWidth": "PRGUF 0x203E: Get screen width.",
    "prguf_getScreenHeight": "PRGUF 0x203F: Get screen height.",
    "prguf_setCursorPos": "PRGUF 0x2044: Set cursor position.",
    "prguf_getCursorPos": "PRGUF 0x2045: Get cursor position.",
    "prguf_showCursor": "PRGUF 0x2046: Show cursor.",
    "prguf_hideCursor": "PRGUF 0x2047: Hide cursor.",
    "prguf_setTextAttr": "PRGUF 0x2049: Set text attribute.",
    "prguf_setColor": "PRGUF 0x204A: Set color pair.",
    "prguf_setWindowAttr": "PRGUF 0x204B: Set window attribute.",
    "prguf_setWindowMode": "PRGUF 0x204C: Set window mode.",
    "prguf_scrollWindow": "PRGUF 0x2051: Scroll window.",
    "prguf_printString": "PRGUF 0x2052: Print string.",
    "prguf_printChar": "PRGUF 0x2053: Print character.",
    "prguf_drawHLine": "PRGUF 0x2055: Draw horizontal line.",
    "prguf_drawVLine": "PRGUF 0x2056: Draw vertical line.",
    "prguf_drawBox": "PRGUF 0x2057: Draw box.",
    "prguf_fillRegion": "PRGUF 0x2059: Fill region.",
    "prguf_setViewport": "PRGUF 0x205A: Set viewport.",
    "prguf_createWindow": "PRGUF 0x2061: Create window.",
    "prguf_resizeWindow": "PRGUF 0x2062: Resize window.",
    "prguf_destroyWindow": "PRGUF 0x2063: Destroy window.",
    "prguf_selectWindow": "PRGUF 0x2064: Select window.",
    "prguf_getWindowHandle": "PRGUF 0x2065: Get window handle.",
    "prguf_setWindowSize": "PRGUF 0x2066: Set window size.",
    "prguf_getWindowSize": "PRGUF 0x2067: Get window size.",
    "prguf_clearWindow": "PRGUF 0x206C: Clear window.",
    "prguf_drawMenuItem": "PRGUF 0x206D: Draw menu item.",
    "prguf_drawMenuSep": "PRGUF 0x206E: Draw menu separator.",
    "prguf_setMenuBar": "PRGUF 0x2071: Set menu bar.",
    "prguf_closeDialog": "PRGUF 0x2072: Close dialog.",
    "prguf_endCapture": "PRGUF 0x2073: End capture.",
    "prguf_openDialFile": "PRGUF 0x2074: Open dial file.",
    "prguf_closeDialFile": "PRGUF 0x2075: Close dial file.",
    "prguf_dialDialogAction": "PRGUF 0x2076: Dial dialog action.",
    "prguf_getDialStatus": "PRGUF 0x2077: Get dial status.",
    "prguf_openCaptureFile": "PRGUF 0x2078: Open capture file.",
    "prguf_writeCaptureData": "PRGUF 0x2079: Write capture data.",
    "prguf_readConfigFile": "PRGUF 0x207D: Read config file.",
    "prguf_writeConfigFile": "PRGUF 0x207E: Write config file.",
    "prguf_putCharToPort": "PRGUF 0x2080: Put char to port.",
    "prguf_getPortConfig": "PRGUF 0x2081: Get port config.",
    "prguf_setFormField": "PRGUF 0x2082: Set form field.",
    "prguf_getFormField": "PRGUF 0x2083: Get form field.",
    "prguf_inputField": "PRGUF 0x2084: Input field.",
    "prguf_getProtocol": "PRGUF 0x2085: Get protocol.",
    "prguf_selectProtocol": "PRGUF 0x2086: Select protocol.",
    "prguf_checkCarrier": "PRGUF 0x2087: Check carrier.",
    "prguf_setDefaultFile": "PRGUF 0x2088: Set default file.",
    "prguf_setPageTitle": "PRGUF 0x2089: Set page title.",
    "prguf_setPageSubtitle": "PRGUF 0x208A: Set page subtitle.",
    "prguf_getSystemConfig": "PRGUF 0x208B: Get system config.",
    "prguf_setFieldValue": "PRGUF 0x208C: Set field value.",
    "prguf_getComPortConfig": "PRGUF 0x208D: Get COM port config.",
    "prguf_setComPortConfig": "PRGUF 0x208E: Set COM port config.",
    "prguf_func208F": "PRGUF 0x208F.",
    "prguf_showMessageDialog": "PRGUF 0x2090: Show message dialog.",
    "prguf_setAppAttributes": "PRGUF 0x2091: Set app attributes.",
    "prguf_exitApp": "PRGUF 0x2105: Exit application.",
    "prguf_formatNumber": "Format number to string.",
    "prguf_recursiveFormat": "Recursive digit formatting.",
    "prguf_appendDigit": "Append one digit to string.",
    "prguf_padWithSpaces": "Pad string with spaces.",
    "prguf_lowLevelDispatch": "Low-level PRGUF dispatch.",
    "prguf_funcB0": "PRGUF func 0xB0.",
    "prguf_funcB1": "PRGUF func 0xB1.",
    "prguf_funcB2": "PRGUF func 0xB2.",
    "prguf_funcB5": "PRGUF func 0xB5.",
    "prguf_funcB8": "PRGUF func 0xB8.",
    "prguf_funcB9": "PRGUF func 0xB9.",
    "prguf_setupFuncTable": "PRGUF setup function table.",
    "prguf_cleanupFuncTable": "PRGUF cleanup function table.",
    "crt_itoa": "Integer to ASCII conversion.",
    "crt_reverseString": "Reverse string in-place.",
    "crt_strlen": "String length.",
    "crt_mainWrapper": "Main function wrapper (argc/argv).",
    "crt_exitCleanup": "Exit cleanup handler.",
    "crt_printf": "Simplified printf (stderr output).",
    "crt_putchar": "Put character to stdout.",
    "crt_flushStdout": "Flush stdout buffer.",
    "crt_initHeap": "Initialize heap.",
    "crt_freeBlock": "Free memory block.",
    "crt_malloc": "Malloc (DOS memory allocation).",
    "crt_formatDialogStruct": "Format dialog structure.",
    "crt_sprintfField": "Sprintf-like field formatting.",
    "crt_getTimestamp": "Get timestamp string.",
    "crt_formatDecimal": "Format decimal number.",
    "crt_memcpy": "Memory copy.",
    "crt_getTickCount": "Get system tick count (32-bit).",
    "crt_atoi": "ASCII to integer.",
    "crt_mallocFar": "Far malloc (paragraph-aligned).",
    "crt_reallocFar": "Far realloc.",
    "crt_freeFar": "Far free.",
    "crt_dosAlloc": "DOS INT 21h AH=48h wrapper.",
    "crt_writeBuffer": "Buffered write to file.",
    "crt_dosRealloc": "DOS INT 21h AH=4Ah realloc wrapper.",
    "crt_dosAllocPages": "DOS page-aligned allocation.",
    "crt_heapManager": "Heap manager (free list).",
    "crt_heapWalk": "Walk heap free list.",
    "crt_paragraphAlign": "Paragraph-align address.",
    "crt_addToFreeList": "Add block to free list.",
    "crt_heapInit2": "Heap init (jump).",
    "crt_formatOutput": "Format output string.",
    "crt_writeStderr": "Write to stderr (fd 2).",
    "crt_initFileTable": "Initialize file handle table.",
    "start": "MSC 5.x CRT startup entry point.",
    "crt_initStartupData": "CRT startup data initialization.",
    "crt_extendedStartup": "CRT extended startup / initialization.",
    "crt_farStartupHelper": "CRT far startup helper.",
}

# Known global variables
GLOBAL_VARS = {
    "0x72": "g_hasPhoneBook",
    "0x145": "g_menuEnabled_hangup",
    "0x150": "g_menuEnabled_sendBreak",
    "0x15b": "g_menuEnabled_capture",
    "0x172": "g_connectionState",
    "0x1dc": "g_comPortHandle",
    "0x1dd": "g_portStatus",
    "0x1fc": "g_receiveBufferSize",
    "0x1fe": "g_receiveBufferSizeCopy",
    "0x200": "g_receiveBufferEnd",
    "0x244": "g_receiveBufferSeg",
    "0x246": "g_comPortOpen",
    "0x2ab6": "g_screenWidth",
    "0x2ab8": "g_screenHeight",
    "0x2aba": "g_windowRight",
    "0x2abc": "g_windowBottom",
    "0x2c1": "g_baudRateIndex",
    "0x2d8": "g_dataBitsIs8",
    "0x2ef": "g_parityMode",
    "0x306": "g_stopBitsMode",
    "0x31d": "g_echoEnabled",
    "0x3ad0": "g_terminalWindowHandle",
    "0x3af4": "g_comSettingsString",
    "0x3a74": "g_modemInitString",
    "0x37d8": "g_phoneBookFilename",
    "0x389c": "g_allocBase",
    "0x389e": "g_terminalDisplayBuffer",
    "0x3b0a": "g_phoneBookBuffer0",
    "0x3b0b": "g_phoneBookEOF",
    "0x3f5": "g_autoLinefeed",
    "0x405": "g_xonxoffMode",
    "0x415": "g_localEcho",
    "0x13c4": "g_menuStructure",
    "0x1f40": "g_menuData",
    "0x990": "g_configMessageBuffer",
    "0x9dc": "g_defaultComSettings",
    "0x9ec": "g_defaultModemInit",
    "0xb42": "g_titleStringActive",
    "0xc28": "g_phoneBookHeader",
    "0xc32": "g_comStatusLabel",
    "0xc42": "g_comSettingsSource",
    "0xc76": "g_modemInitSource",
    "0xce4": "g_cursorPosLabel",
    "0xdf0": "g_titleStringIdle",
    "0xf00": "g_pageTitle",
    "0xf3c": "g_connectionLabel",
    "0xdcc": "g_protocolLabel",
    "0x1210": "g_protocolResBlock",
    "0x121a": "g_protocolResName",
    "0x1220": "g_protocolVariant",
    "0x1221": "g_protocolError",
    "0x122c": "g_translatResBlock",
    "0x1236": "g_translatResName",
    "0x1232": "g_translatDispatch",
    "0x173e": "g_phoneBookEntries",
    "0x41da": "g_defaultFilePtr",
}

# Baud rate values
BAUD_RATES = {
    "0x12c": "300 baud",
    "0x258": "600 baud",
    "0x4b0": "1200 baud",
    "0x960": "2400 baud",
    "0x12c0": "4800 baud",
    "0x2580": "9600 baud",
}

# Menu action codes
MENU_CODES = {
    "0xf541": "File>Open",
    "0xf544": "File>Close/Save",
    "0xf546": "Edit>Copy/Receive",
    "0xf550": "Edit>Paste/Send",
    "0xf55a": "Connect>Dial",
    "0xf564": "Connect>Answer",
    "0xf569": "Connect>Hang Up",
    "0xf56c": "Connect>Send Break",
    "0xf56e": "Settings>Phone Book",
    "0xf578": "Settings>Comm",
    "0xf58c": "Settings>Protocol",
    "0xf596": "Settings>Translation",
    "0xf5a0": "Settings>Terminal",
    "0xf5aa": "Settings>Modem",
    "0xf5b4": "Transfer>Send",
    "0xf5be": "Transfer>Receive",
    "0xf5c8": "File>Exit",
    "0xf5d2": "Help",
    "0xf5dc": "About",
    "0xf5e8": "File>Print",
    "0xf5ea": "File>New",
    "0xf702": "Port error",
    "0xf703": "File error",
    "0xfe43": "Session end",
    "0xfffe": "Config error",
    "0xffff": "Not available / error",
}

# Event types
EVENT_TYPES = {
    "1": "menu/keyboard",
    "2": "mouse",
    "3": "serial char",
    "4": "resize",
    "6": "timer",
}


def rename_call_target(line):
    """Replace sub_XXXXX call targets with descriptive names."""
    for old, new in FUNC_NAMES.items():
        if old in line:
            line = line.replace(old, new)
    # Also handle 'start' label
    return line


def add_variable_comments(line):
    """Add comments for known global variable accesses."""
    comments = []

    # Check for memory references like [0xNNNN] or word ptr [0xNNNN]
    mem_refs = re.findall(r'\[(?:0x)?([0-9a-fA-F]+)\]', line)
    for ref in mem_refs:
        hex_ref = "0x" + ref.lower().lstrip('0')
        if not hex_ref.endswith('x'):  # handle "0x0" case
            if hex_ref in GLOBAL_VARS:
                comments.append(GLOBAL_VARS[hex_ref])

    # Also check for direct references like ptr [bx + 0xNNNN]
    bx_refs = re.findall(r'\[bx \+ (0x[0-9a-fA-F]+)\]', line)
    for ref in bx_refs:
        if ref.lower() in GLOBAL_VARS:
            comments.append(GLOBAL_VARS[ref.lower()])

    # Check for immediate values that are known constants
    # Baud rates only in cmp instructions (not add/sub which are coordinate math)
    baud_vals = re.findall(r'cmp\s+.+?,\s+(0x[0-9a-fA-F]+)', line)
    for val in baud_vals:
        val_lower = val.lower()
        if val_lower in BAUD_RATES:
            comments.append(BAUD_RATES[val_lower])
    # Menu codes in cmp and mov instructions
    menu_vals = re.findall(r'(?:cmp|mov)\s+.+?,\s+(0x[0-9a-fA-F]+)', line)
    for val in menu_vals:
        val_lower = val.lower()
        if val_lower in MENU_CODES:
            comments.append(MENU_CODES[val_lower])

    return comments


def annotate_line(line):
    """Add annotations to a single line of disassembly."""
    # Skip empty lines, comments, labels
    stripped = line.strip()
    if not stripped or stripped.startswith(';') or stripped.endswith(':'):
        return line

    # Must be an instruction line (starts with hex address)
    if not re.match(r'\s*[0-9a-fA-F]+\s+[0-9a-fA-F]+', stripped):
        return line

    # Rename call targets
    new_line = rename_call_target(line)

    # Get variable comments
    var_comments = add_variable_comments(line)

    # Check if there's already a comment
    if ';' in new_line:
        # Add variable comment after existing comment
        if var_comments:
            # Only add if not already there
            existing = new_line.split(';', 1)[1]
            for vc in var_comments:
                if vc not in existing:
                    new_line = new_line.rstrip() + "  " + vc
    else:
        # Add new comment
        if var_comments:
            # Pad to align comments
            padding = max(1, 55 - len(new_line.rstrip()))
            new_line = new_line.rstrip() + " " * padding + "; " + ", ".join(var_comments)

    return new_line


def process_raw_disassembly():
    """Read raw disassembly and produce annotated version."""

    # Read the existing annotated header (up to the BEGIN DISASSEMBLY line)
    with open(ANNOTATED_HEADER_PATH, 'r') as f:
        header_lines = f.readlines()

    # Find where the header ends (the BEGIN DISASSEMBLY section)
    header_end = 0
    for i, line in enumerate(header_lines):
        if "BEGIN DISASSEMBLY" in line:
            header_end = i + 2  # include the === line after it
            break

    # Read raw disassembly
    with open(RAW_PATH, 'r') as f:
        raw_lines = f.readlines()

    # Build output
    output = []

    # Write header (everything up to BEGIN DISASSEMBLY)
    for line in header_lines[:header_end]:
        output.append(line.rstrip())

    output.append("")

    # Track current function for context
    current_func = None
    in_data_section = False

    # Process raw disassembly lines
    for i, line in enumerate(raw_lines):
        raw = line.rstrip()

        # Skip the raw file header (first few comment lines)
        if i < 14 and (raw.startswith(';') or raw.strip() == ''):
            continue

        # Function boundary markers
        func_match = re.match(r'; ---- (\w+) ----', raw)
        if func_match:
            func_raw = func_match.group(1)
            func_name = FUNC_NAMES.get(func_raw, func_raw)
            desc = FUNC_DESCRIPTIONS.get(func_name, "")

            output.append("")
            output.append("; " + "=" * 72)
            output.append(f"; {func_name}    /* address: {get_func_addr(func_raw)} */")
            output.append("; " + "=" * 72)
            if desc:
                output.append(f"; {desc}")
            output.append("; " + "-" * 72)

            current_func = func_name
            continue

        # Function label lines
        label_match = re.match(r'(\w+):$', raw)
        if label_match:
            label = label_match.group(1)
            new_label = FUNC_NAMES.get(label, label)
            output.append(f"{new_label}:")
            continue

        # Local label lines (loc_XXXXX:)
        loc_match = re.match(r'(loc_[0-9a-fA-F]+):$', raw)
        if loc_match:
            output.append(raw)
            continue

        # Instruction lines
        if re.match(r'\s*[0-9a-fA-F]+\s+[0-9a-fA-F]+', raw):
            annotated = annotate_line(raw)
            output.append(annotated)
            continue

        # Data lines, empty lines, other comments
        output.append(raw)

    # Write output
    with open(OUTPUT_PATH, 'w') as f:
        for line in output:
            f.write(line + "\n")

    print(f"Wrote {len(output)} lines to {OUTPUT_PATH}")


def get_func_addr(func_raw):
    """Get the segment:offset address for a function."""
    # Extract hex address from sub_XXXXX
    m = re.match(r'sub_0?([0-9a-fA-F]+)', func_raw)
    if m:
        addr = int(m.group(1), 16)
        if addr >= 0x7170:
            seg = "0717"
            off = addr - 0x7170
            return f"{seg}:{off:04X}"
        return f"0000:{addr:04X}"
    if func_raw == "start":
        return "0717:0000"
    return "????:????"


if __name__ == "__main__":
    process_raw_disassembly()
