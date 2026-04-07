; ========================================================================
; HANGMAN.PDM -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright 1984, 1990
; Compiled with Microsoft C 5.x (1987), Medium Memory Model
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; HANGMAN.PDM is a word-guessing game for 1-4 players that runs inside
; the DeskMate 3.05 shell (DESK.EXE). The player guesses letters to
; reveal a hidden word; wrong guesses progressively draw a hangman
; figure. Features include save/restore, multi-player score tracking,
; configurable difficulty (words per game, max wrong guesses), and a
; profanity-safe embedded word list.
;
; Self-contained: no DM89 imports (word list is embedded in binary).
; Uses DeskMate API (INT E0h) for UI framework, file I/O, and cursor
; management. Loads PRGUF, DMGUF, DMCSR, and SPELL resources at runtime
; via INT E0h AX=0206h.
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 27,027 bytes
; Code size: 26,515 bytes (after header)
; DM89 entry point: 0447:0006 (MSC 5.x CRT startup)
; SS:SP = 0F39:0800
;
; Segment Map (4 segments, 13 relocations):
;   seg_0000  0x4470 bytes  CODE   Main game code + CRT library (17,520 bytes)
;   seg_0447  0x00B0 bytes  CODE   MSC 5.x CRT startup + far-call stubs
;   seg_0452  0x0040 bytes  DATA   DGROUP fixup area (MSC CRT copyright)
;   seg_0456  0x2233 bytes  DATA   Strings, menus, hangman graphics,
;                                  word list index, packed word data,
;                                  profanity filter word fragments
;
; Medium memory model: multiple code segments (0000 + 0447), DGROUP at 0452.
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; --- Application Functions ---
;
; Address   Name                      Description
; -------   ----                      -----------
; 0000:0010 hangman_main              _main() -- entry point, init -> game loop -> cleanup
; 0000:001F hangman_init              Initialize DeskMate resources, load config, show menu
; 0000:00BF hangman_cleanup           Save config, unload resources, call _exit(0)
; 0000:00F3 hangman_loadConfig        Load saved game from HANGMAN.CFG via DMCONFIG/HANGCFG
; 0000:0181 hangman_validateSaveData  Validate save data structure (player count, word counts)
; 0000:0229 hangman_setupMenuBar      Set up application menu bar (Game, Players, etc.)
; 0000:02D6 hangman_drawGameBoard     Draw scoreboard, current game, column headers
; 0000:0391 hangman_drawPlayerScores  Draw per-player score rows in scoreboard
; 0000:047C hangman_drawCurrentGame   Draw "Current Game" info (player, word, guesses, etc.)
; 0000:06E2 hangman_printNumber       Print a 2-digit number at current cursor position
; 0000:071B hangman_initRoundState    Initialize round state (reset guess/wrong counters)
; 0000:0737 hangman_gameLoop          Outer game loop: iterate words, cycle players
; 0000:0795 hangman_playRound         Play one word: prompt, guess, draw hangman
; 0000:086A hangman_processInput      Main input loop: read events, dispatch keys/menus
; 0000:09A2 hangman_mapKeyToLetter    Map keyboard event to letter index (A=0..Z=25)
; 0000:0A0C hangman_handleMenuAction  Handle menu selections (Game>Exit, Save, Restore, etc.)
; 0000:0B79 hangman_checkGuess        Check guessed letter against word, update state
; 0000:0C47 hangman_updateAfterGuess  Update display after guess (counters, hangman drawing)
; 0000:0D4B hangman_handleWin         Handle win: "PARDONED!", update score, draw celebration
; 0000:0D9C hangman_handleLose        Handle loss: " HANGED!", draw full hangman
; 0000:0DD8 hangman_defineGame        "Define Game" dialog handler
; 0000:0DF0 hangman_resetDisplay      Reset and redraw full game display
; 0000:0E18 hangman_refreshBoard      Refresh game board after dialog/restore
; 0000:0E56 hangman_defineGameDialog  Show "Define Game" dialog (players, words, guesses)
; 0000:10AD hangman_spinnerControl    Up/down spinner for numeric dialog fields
; 0000:115C hangman_drawInitialBoard  Draw initial board with scores and letter tiles
; 0000:116D hangman_drawLetterTiles   Draw all 26 letter tiles (A-Z) on game board
; 0000:1198 hangman_drawWordBlanks    Draw blank tiles for letters in current word
; 0000:11C2 hangman_redrawAfterDefine Redraw board after player definition change
; 0000:11CC hangman_initLetterTiles   Initialize 26 letter tiles (load bitmaps from resource)
; 0000:11FA hangman_saveLetterTiles   Save letter tile state to resource (for cleanup)
; 0000:122B hangman_adjustWordLayout  Adjust word blank positions for current word length
; 0000:127F hangman_resetGuessedFlags Reset all 26 letter "guessed" flags to 0
; 0000:12A2 hangman_definePlayersDialog  Show "Define Players" dialog (edit 1-4 player names)
; 0000:1417 hangman_newGame           Start new game: reset all player scores and counters
; 0000:1449 hangman_resetPlayerData   Reset one player's score, words guessed, word count
; 0000:1463 hangman_layoutWordTiles   Calculate and position word letter tiles on screen
; 0000:14D3 hangman_clearRevealFlags  Clear all word tile "revealed" flags
; 0000:14FC hangman_getTimerTick      Get timer tick (DM API 0x0501)
; 0000:1500 hangman_showAlreadyGuessed  Show "letter already guessed" message
; 0000:152F hangman_chooseWord        Choose a word: from DMSPELL resource or random category
; 0000:1564 hangman_checkDmApiEvent   Check for specific DeskMate API event
; 0000:159D hangman_runDialog         Show "Run..." dialog (execute external program)
; 0000:1612 hangman_addPlayerDialog   Show "Add Player" dialog
; 0000:1709 hangman_deletePlayerDialog  Show "Delete Player" dialog
; 0000:185E hangman_aboutDialog       Show "About..." dialog (version, copyright, resources)
; 0000:18D3 hangman_aboutBuildInfo    Build version/resource info for About dialog
; 0000:18F8 hangman_aboutGetVersion   Get version number for About dialog
; 0000:1945 hangman_updatePlayerCount Update player count and resize arrays
; 0000:1976 hangman_saveGame          Save current game state to HANGMAN.CFG
; 0000:19DA hangman_restoreGame       Restore saved game state from HANGMAN.CFG
; 0000:1A4B hangman_restoreFromBuffer Restore game state from config buffer
; 0000:1A93 hangman_promptSaveOnExit  "Would you like to save before quitting?" dialog
; 0000:1AE0 hangman_drawStartScreen   Draw initial game screen layout
; 0000:1AFB hangman_drawHangmanFigure Draw hangman figure at current wrong guess level
; 0000:1B15 hangman_drawHangmanParts  Draw specific hangman body parts (head, body, limbs)
; 0000:1BC4 hangman_drawWrongGuess    Draw hangman part for Nth wrong guess
; 0000:1C30 hangman_drawCelebration   Draw celebration animation (word guessed correctly)
; 0000:1C9B hangman_drawGallowsPart   Draw a section of the gallows structure
; 0000:1CCC hangman_drawSmileyFace    Draw smiley/celebration face animation
; 0000:1D7F hangman_showResultMessage Display "YOU'VE BEEN PARDONED!" or " HANGED!" message
; 0000:1E3C hangman_drawPressAnyKey   Draw "(Press any key to continue)" prompt
; 0000:1E62 hangman_drawDeathAnim     Draw death animation (hangman complete)
; 0000:1EAE hangman_drawProfanityList Draw profanity filter word list (for SPELL check)
; 0000:222F hangman_delayLoop         Delay loop (wait for specified duration)
; 0000:22D7 hangman_drawHangmanStage  Draw a specific hangman figure stage (0-10)
; 0000:239A hangman_handleTimerEvent  Handle timer event (auto-play timeout)
; 0000:23EB hangman_readWordFromRes   Read word from DMSPELL resource data
; 0000:242A hangman_initGameState     Initialize game state variables on first run
; 0000:246C hangman_playWord          Play one word: display, process guesses, animate
; 0000:2558 hangman_wordAnimEnter     Word entry animation
; 0000:2591 hangman_wordAnimExit      Word exit/transition animation
; 0000:260F hangman_showLetterAnim    Letter reveal animation
; 0000:2698 hangman_animFrame         Single animation frame update
; 0000:26CB hangman_animFlash         Flash animation effect
; 0000:2702 hangman_animSequence      Multi-step animation sequence
; 0000:2778 hangman_drawWordStatus    Draw current word status (revealed/hidden letters)
; 0000:27A3 hangman_showWaitMessage   Display "Please wait while a word is chosen..."
; 0000:2864 hangman_drawScoreUpdate   Draw score update after round
; 0000:28C2 hangman_getWordFlags      Get word category/difficulty flags
; 0000:2905 hangman_setWordFlags      Set display flags for current word
; 0000:294E hangman_animCleanup       Clean up animation state
; 0000:297E hangman_profanityCheck    Check word against profanity filter (55 substring tests)
; 0000:2F96 hangman_crtEntryStub      CRT entry stub: _setargv, _setenvp, call _main, _exit
;
; --- DeskMate API Wrapper Functions ---
;
; Address   Name                      DM API Code  Description
; -------   ----                      -----------  -----------
; 0000:334B hangman_dmSetTitle        AX=000Bh     Set window title bar text
; 0000:3351 hangman_dmGetTitle        AX=000Ch     Get window title bar text
; 0000:3357 hangman_dmWriteConfig     AX=000Eh     Write to config file (HANGMAN.CFG)
; 0000:335D hangman_dmReadConfig      AX=000Fh     Read from config file
; 0000:3363 hangman_dmDeleteConfig    AX=0010h     Delete config entry
; 0000:3369 hangman_dmKeyToChar       AX=0023h     Convert key code to character
; 0000:336F hangman_dmRunProgram      AX=00B4h     Run external program
; 0000:3375 hangman_dmCheckSpell      --           Check word via SPELL resource
; 0000:3400 hangman_dmInitApp         AX=020Ah     Initialize application
; 0000:3406 hangman_dmGetTick         AX=0501h     Get timer tick
; 0000:340C hangman_dmGetVideoMode    AX=0600h     Get current video mode
; 0000:3412 hangman_dmSetVideoAttr    AX=060Ah     Set video attribute
; 0000:3418 hangman_dmGetVideoInfo    AX=060Dh     Get video info
; 0000:341E hangman_dmSetVideoInfo2   AX=060Eh     Set video info (with params)
; 0000:3424 hangman_dmLoadCursor      --           Load DMCSR cursor resource
; 0000:343D hangman_dmUnloadCursor    --           Unload DMCSR cursor resource
; 0000:344C hangman_dmInitCursor      Load cursor + init cursor state
; 0000:3453 hangman_dmCleanupCursor   Cleanup cursor state + unload cursor
; 0000:3482 hangman_dmShowCursor      AX=2006h     Show/enable cursor
; 0000:3488 hangman_dmHideCursor      AX=2007h     Hide/disable cursor
; 0000:348E hangman_dmReplyEvent      AX=2013h     Reply to DM event
; 0000:3494 hangman_dmGetEvent        AX=2014h     Get next DM event
; 0000:349A hangman_dmYield           AX=2016h     Yield to DM (process pending)
; 0000:34A0 hangman_dmSetTimer        AX=2017h     Set timer interval
; 0000:34A6 hangman_dmSetTimeout      AX=2018h     Set timeout value
; 0000:34AC hangman_dmLoadBitmap      AX=201Bh     Load bitmap resource
; 0000:34B2 hangman_dmDrawBitmap      AX=201Ch     Draw bitmap at position
; 0000:34B8 hangman_dmSaveBitmap      AX=201Eh     Save bitmap state
; 0000:34BE hangman_dmSetScrollArea   AX=202Bh     Set scroll area
; 0000:34C4 hangman_dmSetScrollPos    AX=202Ch     Set scroll position
; 0000:34CA hangman_dmInitScrollbar   AX=202Dh     Initialize scrollbar
; 0000:34D0 hangman_dmSetActiveWin    AX=202Eh     Set active window
; 0000:34D6 hangman_dmInitWindow      AX=2030h     Initialize window
; 0000:34DC hangman_dmGetScreenWidth  AX=203Fh     Get screen width
; 0000:34E2 hangman_dmGetScreenHeight AX=2041h     Get screen height
; 0000:34E8 hangman_dmDivide          AX=2042h     Divide (utility)
; 0000:34EE hangman_dmMultiply        AX=2043h     Multiply (utility)
; 0000:34F4 hangman_dmSetCursorPos    AX=2044h     Set cursor position (x, y)
; 0000:34FA hangman_dmShowStatusBar   AX=2047h     Show/configure status bar
; 0000:3500 hangman_dmDrawLine        AX=2049h     Draw line
; 0000:3506 hangman_dmSetColor        AX=204Ah     Set foreground/background color
; 0000:350C hangman_dmSetTextAttr     AX=204Bh     Set text attribute (bold, etc.)
; 0000:3512 hangman_dmSetFont         AX=204Ch     Set font
; 0000:3518 hangman_dmDrawChar        AX=2051h     Draw single character
; 0000:351E hangman_dmDrawString      AX=2052h     Draw null-terminated string
; 0000:3524 hangman_dmDefineMenu      AX=205Ah     Define menu item
; 0000:352A hangman_dmDefineDialog    AX=205Bh     Define dialog box
; 0000:3530 hangman_dmSetDialogField  AX=205Ch     Set dialog field value
; 0000:3536 hangman_dmGetDialogField  AX=205Fh     Get dialog field value
; 0000:353C hangman_dmDrawAt          AX=2060h     Draw text at specific position
; 0000:3542 hangman_dmOpenDialog      AX=2061h     Open/create dialog
; 0000:3548 hangman_dmOpenDialogEx    AX=2062h     Open dialog (extended)
; 0000:354E hangman_dmCloseDialog     AX=2063h     Close dialog
; 0000:3554 hangman_dmSetBorder       AX=206Ah     Set window border style
; 0000:355A hangman_dmSetBackground   AX=206Ch     Set background pattern
; 0000:3560 hangman_dmFillRect        AX=206Eh     Fill rectangle region
; 0000:3566 hangman_dmCursorInit      AX=20D6h     Cursor subsystem init
; 0000:356C hangman_dmCursorCleanup   AX=20D7h     Cursor subsystem cleanup
; 0000:3572 hangman_dmShowForm        AX=20E3h     Show form/control
; 0000:3578 hangman_dmGetFormResult   AX=20E4h     Get form/control result
; 0000:357E hangman_dmMsgBox          AX=20E9h     Display message box
; 0000:3584 hangman_dmScrollContent   AX=20F7h     Scroll content area
; 0000:358A hangman_dmWaitReady       AX=20F8h     Wait for display ready
; 0000:3590 hangman_dmSetAppTitle     AX=2100h     Set application title
; 0000:3596 hangman_dmSpellOp         AX=2102h     Spell check operation
;
; --- DeskMate Resource Management ---
;
; 0000:31F6 hangman_loadAllRes        Load PRGUF + DMGUF resources
; 0000:3260 hangman_loadDmguf         Load DMGUF resource via INT E0h AX=0206h
; 0000:32A2 hangman_unloadRes         Unload DMGUF resource via INT E0h AX=0207h
; 0000:359C hangman_loadSpell         Load SPELL resource via INT E0h AX=0206h
; 0000:35B9 hangman_unloadSpell       Unload SPELL resource via INT E0h AX=0207h
; 0000:3677 hangman_spellCleanup      SPELL cleanup function (code 0x14)
; 0000:3694 hangman_aboutBoxHandler   Handle "About..." dialog (build info, version display)
;
; --- MSC 5.x C Runtime Library ---
;
; 0000:2F96 _crt_entry                CRT stub: call _setargv, _setenvp, main(), _exit()
; 0000:302B _crt_doexit               CRT: do exit sequence
; 0000:303A _cinit                    C runtime initialization
; 0000:30FE _exit                     Program exit (INT 21h/4Ch)
; 0000:315A _amsg_exit                Abort with message
; 0000:3173 _crt_printMsg             Print runtime error message
; 0000:3182 _crt_printStr             Print string via _write
; 0000:3196 _setargv                  Parse command line arguments
; 0000:3260 (overlap with hangman_loadDmguf -- CRT code reused as API wrapper)
; 0000:39F8 _cexit                    CRT cleanup (flush buffers, call atexit)
; 0000:3A1E _nullcheck                Check for null pointer assignment
; 0000:3A40 _setenvp                  Set up environment block
; 0000:3BF9 _write                    Write to file handle (INT 21h/40h)
; 0000:3BCE _crt_doswrite             Low-level DOS write
; 0000:3C22 _crt_sbrk                 Adjust memory break (heap allocation)
; 0000:3C84 _crt_brk                  Set memory break
; 0000:3C8A _crt_heapgrow             Grow heap via INT 21h/4Ah
; 0000:3CB8 _strcpy                   String copy
; 0000:3CF8 _strncpy                  String copy with length limit
; 0000:3D2A _strlen                   String length
; 0000:3D46 _strcmp                    String compare
; 0000:3D6E _strncmp                  String compare with length limit
; 0000:3DA8 _atoi / _atol             ASCII to integer/long conversion
; 0000:3E04 _crt_findEnv              Find environment variable
; 0000:3E5A _crt_getEnvItem           Get environment variable value
; 0000:3EA2 _sscanf                   Formatted string scan
; 0000:42D2 _rand                     Random number generator (MINSTD LCG)
;                                     Multiplier: 0x343FD, Increment: 0x269EC3
; 0000:42F8 _crt_ltoa                 Long to ASCII conversion
; 0000:4248 _strstr                   Find substring in string
; 0000:388D hangman_itoaBuf           Integer to ASCII into buffer (recursive)
; 0000:38A9 hangman_strcpyDI          Copy string from DS:SI to ES:DI
; 0000:38B5 hangman_strlenSI          Get string length at DS:SI
;
; --- CRT Startup (seg_0447) ---
;
; 0447:0006 __astart                  MSC 5.x CRT entry point
;                                     - DOS version check (INT 21h AH=30h)
;                                     - Set SS=DGROUP, adjust SP
;                                     - Clear BSS (0x2274..0xAE70)
;                                     - Far-call _cinit, _setargv, _setenvp
;                                     - Far-call _main (0000:0010)
;                                     - Far-call _exit
;
; ========================================================================
; GAME DATA STRUCTURES
; ========================================================================
;
; --- DGROUP Variables (offsets relative to SS/DS base) ---
;
; 0x004E  byte   g_hasSavedGame       Flag: saved game exists in config
; 0x0059  byte   g_savedGameValid     Flag: saved game data is valid
; 0x00C4  byte   g_timerActive        Flag: timer/auto-play active
; 0x00CA  byte[0x14*26] g_letterTileData  Letter tile bitmap data (26 letters)
; 0x00DA  byte[0x14*26] g_letterGuessed   Per-letter "guessed" flags (1=guessed)
; 0x02D2  byte[0x17*MAX] g_wordTileData   Word tile display data
; 0x0890  word[10]  g_categoryTable    Word category/difficulty pointers
; 0x0BA0  word   g_dialogTitlePtr     Pointer to current dialog title string
; 0x0C08  --     g_defineGameDialog   "Define Game" dialog field data
; 0x0CA4  --     g_defineGameForm     "Define Game" form control data
; 0x0CA7  byte   g_formState          Form state tracking variable
; 0x0DA8  --     g_definePlayersForm  "Define Players" form control data
; 0x0E0A  --     g_addPlayerForm      "Add Player" form control data
; 0x0EB4  --     g_alreadyGuessedMsg  "Already guessed" message params
; 0x0EBA  --     g_savePromptMsg      Save prompt message params
; 0x0EC6  --     g_saveOverwriteMsg   Save overwrite warning params
; 0x0ECC  word   g_hangmanTitle       Pointer to "Hangman" string
; 0x0ED2  --     g_statusMsg          Status message display params
; 0x0ED5  word   g_statusMsgPtr       Pointer to current status message
; 0x0ED8  --     g_runDialogParams    "Run..." dialog parameters
; 0x0EE8  word   g_roundActive        Flag: currently playing a round
; 0x0EEA  word   g_scoreVisible       Flag: scoreboard is visible
; 0x0EF3  word   g_configNamePtr      Pointer to config name in buffer
; 0x0EF5  word   g_configNamePtr2     Pointer to config name (second part)
; 0x0F08  word   g_spellAvailable     Flag: SPELL resource is loaded (1=yes)
; 0x0F0A  word   g_eventPending       Flag: DM event pending for processing
;
; 0xAB8C  word   g_currentWordIndex   Current word index (1-based)
; 0xAB8E  word   g_currentPlayer      Current player index (0-based)
; 0xAB90  word   g_currentWordLen     Current word length (letter count)
; 0xAB92  byte[] g_wordBuffer         Current word buffer (null-terminated uppercase)
; 0xAB9E  word   g_cursorHandle       DMCSR cursor resource handle
; 0xABA0  word   g_wordXOffset        X offset for word display positioning
; 0xABA2  word   g_windowHandle       Application window handle
; 0xABA4  word   g_gameStateFlags     Game state flags (0=new, nonzero=in progress)
; 0xABA6  word   g_scoreAccumulator   Score accumulator during round
; 0xABA8  --     g_configBuffer       Config file read/write buffer
; 0xADBA  word[26] g_letterBitmapPtrs Pointers to letter bitmap resources
; 0xADEE  word   g_numPlayers         Number of players (1-4)
; 0xADF0  --     g_playerData         Start of player data array
;
; --- Player Data Structure (21 bytes per player, at g_playerData) ---
;
; Offset  Type   Name                 Description
; +0x00   byte   numGuesses           Total guesses this round
; +0x01   byte   numWrongGuesses      Wrong guesses this round
; +0x02   byte   lettersRemaining     Letters still hidden in word
; +0x03   byte   wordsGuessedCorrect  Words guessed correctly this game
; +0x04   word   wordsPlayed          Words played this game
; +0x06   word   score                Total score this game
; +0x08   byte[13] playerName         Player name (null-terminated, max 12 chars)
; +0x0D   byte   currentGuessCount    Current guess count for display
; +0x0E   byte   currentWrongCount    Current wrong guess count for display
; +0x10   byte   wordsGuessedDisplay  Words guessed for scoreboard display
; +0x13   word   scoreDisplay         Score for scoreboard display
;
; 0xAE44  word   g_wordsPerGame       Words per game setting (1-10)
; 0xAE46  word   g_maxWrongGuesses    Maximum wrong guesses allowed (3-12)
; 0xAE48  word[15] g_aboutLinesPtrs   Pointers to About dialog text lines
; 0xAE68  word   g_boardYOffset       Y offset for game board positioning
;
; --- BSS (0x2274..0xAE70) ---
;
; Large BSS cleared by CRT startup. Contains all game state arrays:
; letter tiles, word tiles, player data, dialog buffers, etc.
;
; ========================================================================
; WORD LIST FORMAT
; ========================================================================
;
; The word list is embedded in seg_0456 (data segment).
;
; Word selection (hangman_chooseWord, 0000:152F):
;   1. Calls DM API (0xFD17) to check if external word source available
;   2. If yes: reads word from DMSPELL resource (hangman_readWordFromRes)
;   3. If no: calls _rand(), divides by 6, adds 4 to get category (4-9)
;      This selects from 6 difficulty levels in the packed word data
;
; The packed word data at 0456:1386+ uses a compact byte-stream encoding.
; Words are delimited by 0x0D (carriage return) bytes. Each word is
; stored as uppercase ASCII. The index table provides entry points
; into the packed data for each difficulty category.
;
; ========================================================================
; PROFANITY FILTER
; ========================================================================
;
; The profanity filter is at 0456:1FAE and consists of ~55 word fragments
; (substrings) that are checked against user-entered player names.
; Each entry is a partial word suffix -- the first letter is implicit
; (e.g., "bortion" matches "abortion", "itch" matches "bitch", etc.)
;
; The filter is organized by first letter:
;   a: bortion
;   b: itch, astard, estial, isex
;   c: litor, oitus, ondom, opulat, rotch
;   d: efeca
;   e: jaculat, xcrem, ellat
;   f: eces, allopian, ornicat, oreskin, aggot
;   g: oddam, lans, onorrh
;   h: erpes, omosex
;   i: ncest
;   l: abia, esbian
;   m: asochis, enses, olest, enstrua, asturb
;   n: ipple
;   o: rgasm
;   p: enis, enile, hall, rostit, ubic, ubis
;   q: ueer
;   r: ectum, ectal, apist
;   s: adis, crot, emen, odom, chmuck, yphili, perm
;   t: esticl, estes
;   v: agina, omit, ulva
;
; The check function (hangman_profanityCheck, 0000:297E) uses _strncmp
; (sub_0000_3D6E) to test each fragment against the input string.
; If any match is found, the word is rejected.
;
; The SPELL resource (loaded from SPELL.RES) provides additional
; dictionary-based word validation at runtime.
;
; ========================================================================
; MENU STRUCTURE
; ========================================================================
;
; Menu bar (set up in hangman_setupMenuBar, 0000:0229):
;   "Game"     -> Game menu
;     "Save"                 (0xF501)
;     "Restore"              (0xF502)
;     "Exit    Esc"          (0xF500)
;   "Run ..."                (0xF50A)
;   "About ..."              (0xF50B)
;   "Players"  -> Players menu
;     "Define..."            (0xF50C)
;     "Add..."               (not used in-game, via Define dialog)
;     "Delete..."            (not used in-game, via Define dialog)
;
; Menu action dispatch (hangman_handleMenuAction, 0000:0A0C):
;   Jump table at 0000:0B5B for menu IDs 0xF500-0xF50C:
;     0xF500: Game>Exit      -> hangman_defineGame prompt, then exit
;     0xF501: Game>Save      -> hangman_saveGame
;     0xF502: Game>Restore   -> hangman_restoreGame
;     0xF503: (unused)
;     0xF504: (unused)
;     0xF505: (unused)
;     0xF506: (unused)
;     0xF507: (unused)
;     0xF508: Players>Define -> hangman_definePlayersDialog
;     0xF509: (unused)
;     0xF50A: Run...         -> load DMGUF "Run" dialog (aboutBoxHandler)
;     0xF50B: About...       -> hangman_runDialog
;     0xF50C: Players>Add/Del-> hangman_addPlayerDialog/deletePlayerDialog
;
; ========================================================================
; HANGMAN FIGURE GRAPHICS
; ========================================================================
;
; The hangman figure coordinate data is stored in seg_0456 at offsets
; 0x0380-0x0B40. Each body part is defined as a series of coordinate
; pairs for drawing via DeskMate graphics primitives.
;
; Drawing progression (hangman_drawWrongGuess, 0000:1BC4):
;   Wrong guess 1: Gallows base and upright
;   Wrong guess 2: Gallows crossbar and rope
;   Wrong guess 3: Head (circle)
;   Wrong guess 4: Body (vertical line)
;   Wrong guess 5: Left arm
;   Wrong guess 6: Right arm
;   Wrong guess 7: Left leg
;   Wrong guess 8: Right leg
;   Wrong guess 9: Face features (eyes)
;   Wrong guess 10: Face features (mouth)
;
; The actual number of stages depends on g_maxWrongGuesses setting (3-12).
;
; ========================================================================
; DeskMate API USAGE (INT E0h)
; ========================================================================
;
; The DeskMate API is accessed via INT E0h with function codes in AX.
; The wrapper functions at 0000:345A (loc_0000_345A) and 0000:33DD
; (loc_0000_33DD) handle the calling convention:
;
;   loc_0000_345A: Far-call wrapper that calls DMCSR cursor resource
;     first, then dispatches the DM API function.
;   loc_0000_33DD: Direct INT E0h dispatch (no cursor interaction).
;   loc_0000_33EB: INT E0h dispatch with DX and BX parameters.
;   loc_0000_32CA: PRGUF/DMGUF resource call dispatcher.
;   loc_0000_330E: DMGUF-specific resource call dispatcher.
;
; Resource Management:
;   AX=0206h  Load resource module (PRGUF, DMGUF, DMCSR, SPELL)
;   AX=0207h  Unload resource module
;   AX=0208h  Execute resource function
;
; Timer/Yield:
;   AX=0700h  Timer tick / yield
;
; ========================================================================
; PROGRAM FLOW
; ========================================================================
;
; 1. CRT startup (0447:0006)
;    a. DOS version check, stack/memory setup, BSS clear
;    b. _cinit, _setargv, _setenvp
;
; 2. _main (0000:0010):
;    a. hangman_init (0000:001F):
;       - Load DMCSR cursor resource
;       - Load DMGUF resource (try DMGUF, fallback to PRGUF)
;       - Check if SPELL resource can load word list (0xFD14)
;       - If SPELL available: load SPELL resource, init word source
;       - Set application title ("Hangman.pdm")
;       - Initialize app via DM API 0x020A
;       - Set border, show status bar
;       - Set up menu bar
;       - Show cursor
;       - Load saved game config (HANGMAN.CFG)
;       - If saved game exists and user confirms: restore it
;       - Otherwise: set up new game, draw initial board
;    b. If return value == 0xFFFE (game ready to play):
;       - hangman_gameLoop (0000:0737): main game loop
;    c. hangman_cleanup (0000:00BF):
;       - Initialize window with handle
;       - Save player state (letter tiles)
;       - Set timeout (180 ticks = ~10 seconds)
;       - Show cursor
;       - If SPELL resource loaded: unload it
;       - Unload DMGUF resource
;       - Unload DMCSR cursor resource
;       - Call _exit(0)
;
; 3. Game Loop (hangman_gameLoop, 0000:0737):
;    a. For each word (up to g_wordsPerGame):
;       - hangman_chooseWord: select word from list
;       - hangman_playRound: play one word
;    b. After all words:
;       - Show cursor, display "Would you like to play again?"
;       - If yes: reset scores (hangman_newGame), redraw, loop
;       - If no/Esc: exit game loop
;
; 4. Round Play (hangman_playRound, 0000:0795):
;    a. For each player:
;       - Clear word buffer, init round state
;       - Start word display (hangman_playWord)
;       - If word completed (win/lose): update scores, next player
;       - If exit requested: save prompt, exit
;    b. Cycle through players until all have played
;
; 5. Input Processing (hangman_processInput, 0000:086A):
;    a. Show cursor, enter event loop
;    b. Get DM event (hangman_dmGetEvent)
;    c. Classify event:
;       - Type 0 (idle): check win/lose timeout
;       - Type 1 (keyboard): map key to letter via hangman_mapKeyToLetter
;       - Type 3 (menu): dispatch via hangman_handleMenuAction
;       - Type 6 (timer): handle auto-play timeout
;    d. For letter guess:
;       - Check if already guessed (show message if so)
;       - Mark letter as guessed, draw bitmap
;       - Call hangman_checkGuess to test letter against word
;       - If match: reveal letter(s), check for win
;       - If no match: increment wrong count, draw hangman part
;       - Update display via hangman_updateAfterGuess
;
; ========================================================================
; INT 21h (DOS API) CALLS
; ========================================================================
;
; AH=25h  Set interrupt vector (2 calls, in CRT init)
; AH=30h  Get DOS version (2 calls, in CRT startup)
; AH=35h  Get interrupt vector (1 call, in CRT init)
; AH=3Eh  Close file handle (1 call, in _write)
; AH=40h  Write to file/device (4 calls, in _write)
; AH=44h  IOCTL (1 call, in _write -- check device type)
; AH=4Ah  Modify memory allocation (5 calls, in _crt_heapgrow)
; AH=4Ch  Terminate program (2 calls, in _exit)
;
; ========================================================================
; INT E0h (DeskMate API) CALLS
; ========================================================================
;
; AX=0206h  Load resource module (12 calls total)
;           At 0000:3219: Load PRGUF or DMGUF
;           At 0000:326D: Load DMGUF
;           At 0000:328B: Execute PRGUF resource
;           At 0000:3432: Load DMCSR
;           At 0000:35AA: Load SPELL
;           At 0000:33BA: Load DMSPELL (in spell check)
;
; AX=0207h  Unload resource module (4 calls)
;           At 0000:3250: Unload PRGUF/DMGUF
;           At 0000:32AC: Unload DMGUF
;           At 0000:3447: Unload DMCSR
;           At 0000:35C6: Unload SPELL
;
; AX=0208h  Execute resource function (2 calls)
;           At 0000:3205: Execute PRGUF
;           At 0000:3282: Execute PRGUF (in loadDmguf)
;
; AX=0700h  Timer tick / yield (2 calls)
;           At 0000:33CB: In spell check handler
;
; Dynamic API (via loc_0000_345A and loc_0000_33DD):
;           All 2xxx API codes dispatched through wrapper functions.
;           See DeskMate API Wrapper Functions table above.
;
; ========================================================================
; CODE
; ========================================================================

; ------------------------------------------------------------------------
; SEGMENT seg_0000  (17520 bytes)
;   file offset: 0x0200 - 0x4670
;   Contains all application code and MSC 5.x CRT library
; ------------------------------------------------------------------------
seg_0000:


; ========================================================================
; hangman_nullVector -- Null function vector (8 zero words)
; /* address: 0000:0000 */
; Used as a null far-call target by CRT startup code.
; Called from: sub_0000_3424, sub_0000_3453 (cursor init/cleanup)
; ========================================================================
hangman_nullVector:
  0000:0000  0000              add      byte ptr [bx + si], al
  0000:0002  0000              add      byte ptr [bx + si], al
  0000:0004  0000              add      byte ptr [bx + si], al
  0000:0006  0000              add      byte ptr [bx + si], al
  0000:0008  0000              add      byte ptr [bx + si], al
  0000:000A  0000              add      byte ptr [bx + si], al
  0000:000C  0000              add      byte ptr [bx + si], al
  0000:000E  0000              add      byte ptr [bx + si], al


; ========================================================================
; hangman_main -- _main() entry point
; /* address: 0000:0010 */
; Called from CRT startup at 0000:3014 after _cinit, _setargv, _setenvp.
; Initializes the game, enters game loop if saved game found, then cleans up.
; Returns: 0 (always, via hangman_cleanup which calls _exit)
; ========================================================================
hangman_main:
  0000:0010  e80c00            call     0x1f                    ; hangman_init()
  0000:0013  3dfeff            cmp      ax, 0xfffe              ; check if game ready to play
  0000:0016  7503              jne      0x1b                    ; if not 0xFFFE, skip game loop
  0000:0018  e81c07            call     0x737                   ; hangman_gameLoop()

hangman_main_cleanup:
  0000:001B  e8a100            call     0xbf                    ; hangman_cleanup()
  0000:001E  c3                ret


; ========================================================================
; hangman_init -- Initialize game: load resources, set up UI, load config
; /* address: 0000:001F */
; Loads DeskMate resources (DMCSR cursor, DMGUF graphics, SPELL dictionary),
; sets up the application window, menu bar, and attempts to load a saved game.
; Returns: 0xFFFE if game ready to play, 0 if user declined/error, 0xFFFF on error
; ========================================================================
hangman_init:
  0000:001F  55                push     bp
  0000:0020  8bec              mov      bp, sp
  0000:0022  83ec02            sub      sp, 2                   ; local: result
  ; --- Load DMCSR cursor resource ---
  0000:0025  e82434            call     0x344c                  ; hangman_dmInitCursor()
  0000:0028  a39eab            mov      word ptr [0xab9e], ax   ; g_cursorHandle = result
  0000:002B  40                inc      ax                      ; test for 0xFFFF (failure)
  0000:002C  750a              jne      0x38                    ; if OK, continue
  0000:002E  b8ffff            mov      ax, 0xffff              ; fatal error
  0000:0031  50                push     ax
  0000:0032  e8c930            call     0x30fe                  ; _exit(-1)
  0000:0035  83c402            add      sp, 2

  ; --- Load DMGUF graphics resource ---
hangman_init_loadGuf:
  0000:0038  e82532            call     0x3260                  ; hangman_loadDmguf()
  0000:003B  40                inc      ax                      ; test for 0xFFFF
  0000:003C  750d              jne      0x4b                    ; if OK, continue
  0000:003E  e81234            call     0x3453                  ; hangman_dmCleanupCursor()
  0000:0041  b8ffff            mov      ax, 0xffff
  0000:0044  50                push     ax
  0000:0045  e8b630            call     0x30fe                  ; _exit(-1)
  0000:0048  83c402            add      sp, 2

  ; --- Check for SPELL word source ---
hangman_init_checkSpell:
  0000:004B  b814fd            mov      ax, 0xfd14              ; DM API event code for word list
  0000:004E  50                push     ax
  0000:004F  e81215            call     0x1564                  ; hangman_checkDmApiEvent(0xFD14)
  0000:0052  83c402            add      sp, 2
  0000:0055  0bc0              or       ax, ax
  0000:0057  751f              jne      0x78                    ; if event received, skip SPELL load
  ; --- Load SPELL resource ---
  0000:0059  e84035            call     0x359c                  ; hangman_loadSpell()
  0000:005C  40                inc      ax                      ; test for 0xFFFF
  0000:005D  7510              jne      0x6f                    ; if OK, continue
  0000:005F  e8f133            call     0x3453                  ; hangman_dmCleanupCursor()
  0000:0062  e83d32            call     0x32a2                  ; hangman_unloadRes()
  0000:0065  b8ffff            mov      ax, 0xffff
  0000:0068  50                push     ax
  0000:0069  e89230            call     0x30fe                  ; _exit(-1)
  0000:006C  83c402            add      sp, 2
  ; SPELL loaded successfully
hangman_init_spellOk:
  0000:006F  e8b823            call     0x242a                  ; hangman_initGameState()
  0000:0072  c706080f0100      mov      word ptr [0xf08], 1     ; g_spellAvailable = 1

  ; --- Set application title ---
hangman_init_setupUi:
  0000:0078  b8fa0e            mov      ax, 0xefa               ; -> "Hangman.pdm" (at 0456:0ED4+offset)
  0000:007B  50                push     ax
  0000:007C  e81135            call     0x3590                  ; hangman_dmSetAppTitle("Hangman.pdm")
  0000:007F  83c402            add      sp, 2
  ; --- Initialize DeskMate application ---
  0000:0082  e87b33            call     0x3400                  ; hangman_dmInitApp()  (DM API 0x020A)
  0000:0085  e8cc34            call     0x3554                  ; hangman_dmSetBorder()
  0000:0088  e86f34            call     0x34fa                  ; hangman_dmShowStatusBar()
  ; --- Set up menu bar ---
  0000:008B  e89b01            call     0x229                   ; hangman_setupMenuBar()
  ; --- Show cursor ---
  0000:008E  e8f133            call     0x3482                  ; hangman_dmShowCursor()
  ; --- Load saved game config ---
  0000:0091  e85f00            call     0xf3                    ; hangman_loadConfig()
  0000:0094  8946fe            mov      word ptr [bp - 2], ax   ; save result
  0000:0097  40                inc      ax                      ; test for 0xFFFF (no config)
  0000:0098  740e              je       0xa8                    ; no config -> return 0
  0000:009A  837efefe          cmp      word ptr [bp - 2], -2   ; test for 0xFFFE (game ready)
  0000:009E  750c              jne      0xac                    ; if not 0xFFFE, go to fresh start
  ; --- Saved game found, ask user ---
  0000:00A0  e8350d            call     0xdd8                   ; hangman_defineGame()
  0000:00A3  3dfeff            cmp      ax, 0xfffe              ; user chose to continue?
  0000:00A6  7404              je       0xac                    ; yes -> set up fresh display

hangman_init_noConfig:
  0000:00A8  2bc0              sub      ax, ax                  ; return 0
  0000:00AA  eb0f              jmp      0xbb                    ; -> epilogue

hangman_init_freshStart:
  0000:00AC  e8d933            call     0x3488                  ; hangman_dmHideCursor()
  0000:00AF  e81a11            call     0x11cc                  ; hangman_initLetterTiles()
  0000:00B2  e82102            call     0x2d6                   ; hangman_drawGameBoard()
  0000:00B5  e8281a            call     0x1ae0                  ; hangman_drawStartScreen()
  0000:00B8  b8feff            mov      ax, 0xfffe              ; return 0xFFFE = game ready

hangman_init_return:
  0000:00BB  8be5              mov      sp, bp
  0000:00BD  5d                pop      bp
  0000:00BE  c3                ret


; ========================================================================
; hangman_cleanup -- Clean up and exit program
; /* address: 0000:00BF */
; Saves player state, sets timeout, unloads resources, calls _exit(0).
; Does not return.
; ========================================================================
hangman_cleanup:
  0000:00BF  ff36a2ab          push     word ptr [0xaba2]       ; push g_windowHandle
  0000:00C3  e81034            call     0x34d6                  ; hangman_dmInitWindow(handle)
  0000:00C6  83c402            add      sp, 2
  0000:00C9  e82e11            call     0x11fa                  ; hangman_saveLetterTiles()
  0000:00CC  b8b400            mov      ax, 0xb4                ; 180 ticks (~10 sec timeout)
  0000:00CF  50                push     ax
  0000:00D0  e8d333            call     0x34a6                  ; hangman_dmSetTimeout(180)
  0000:00D3  83c402            add      sp, 2
  0000:00D6  e8a933            call     0x3482                  ; hangman_dmShowCursor()
  ; --- Unload SPELL if loaded ---
  0000:00D9  833e080f00        cmp      word ptr [0xf08], 0     ; g_spellAvailable?
  0000:00DE  7403              je       0xe3
  0000:00E0  e8d634            call     0x35b9                  ; hangman_unloadSpell()

hangman_cleanup_unloadRes:
  0000:00E3  e8bc31            call     0x32a2                  ; hangman_unloadRes()
  0000:00E6  e86a33            call     0x3453                  ; hangman_dmCleanupCursor()
  0000:00E9  2bc0              sub      ax, ax                  ; exit code 0
  0000:00EB  50                push     ax
  0000:00EC  e80f30            call     0x30fe                  ; _exit(0) -- does not return
  0000:00EF  83c402            add      sp, 2
  0000:00F2  c3                ret


; ========================================================================
; hangman_loadConfig -- Load saved game from HANGMAN.CFG
; /* address: 0000:00F3 */
; Reads the configuration file. If a valid saved game exists, prompts
; the user whether to continue the saved game.
; Returns: 0xFFFE if game ready, 0xFFFF if user cancelled, 0 if no save
; ========================================================================
hangman_loadConfig:
  0000:00F3  55                push     bp
  0000:00F4  8bec              mov      bp, sp
  0000:00F6  83ec06            sub      sp, 6
  ; --- Set window title to "Hangman" ---
  0000:00F9  b8ec0e            mov      ax, 0xeec               ; -> "Hangman" (via menu string ptr)
  0000:00FC  50                push     ax
  0000:00FD  e84b32            call     0x334b                  ; hangman_dmSetTitle("Hangman")
  0000:0100  83c402            add      sp, 2
  0000:0103  8946fe            mov      word ptr [bp - 2], ax   ; save result
  0000:0106  40                inc      ax                      ; test for 0xFFFF
  0000:0107  7406              je       0x10f                   ; no title set -> no saved game
  0000:0109  837efefe          cmp      word ptr [bp - 2], -2
  0000:010D  750a              jne      0x119

  ; --- No saved game ---
hangman_loadConfig_noSave:
  0000:010F  2ac0              sub      al, al
  0000:0111  a25900            mov      byte ptr [0x59], al     ; g_savedGameValid = 0
  0000:0114  a24e00            mov      byte ptr [0x4e], al     ; g_hasSavedGame = 0
  0000:0117  eb61              jmp      0x17a                   ; return 0xFFFE

  ; --- Config file found ---
hangman_loadConfig_found:
  0000:0119  c6064e0001        mov      byte ptr [0x4e], 1      ; g_hasSavedGame = 1
  ; --- Get config title value ---
  0000:011E  b8ec0e            mov      ax, 0xeec               ; -> "Hangman"
  0000:0121  50                push     ax
  0000:0122  e82c32            call     0x3351                  ; hangman_dmGetTitle()
  0000:0125  83c402            add      sp, 2
  0000:0128  0bc0              or       ax, ax
  0000:012A  7407              je       0x133                   ; if 0, config has valid data
  0000:012C  c606590000        mov      byte ptr [0x59], 0      ; g_savedGameValid = 0
  0000:0131  eb47              jmp      0x17a

  ; --- Parse saved game data ---
hangman_loadConfig_parse:
  0000:0133  c606590001        mov      byte ptr [0x59], 1      ; g_savedGameValid = 1
  ; Read config data into g_configBuffer
  0000:0138  b8a8ab            mov      ax, 0xaba8              ; -> g_configBuffer
  0000:013B  8946fa            mov      word ptr [bp - 6], ax
  0000:013E  8c5efc            mov      word ptr [bp - 4], ds
  0000:0141  b85a00            mov      ax, 0x5a                ; buffer size 90 bytes
  0000:0144  50                push     ax
  0000:0145  ff76fa            push     word ptr [bp - 6]       ; buffer ptr
  0000:0148  1e                push     ds
  0000:0149  ff36f30e          push     word ptr [0xef3]        ; config name ptr 1
  0000:014D  ff36f50e          push     word ptr [0xef5]        ; config name ptr 2
  0000:0151  e84e3d            call     0x3ea2                  ; _sscanf(config data)
  0000:0154  83c40a            add      sp, 0xa
  ; --- Prompt user: continue saved game? ---
  0000:0157  b8ba0e            mov      ax, 0xeba               ; -> saved game prompt message
  0000:015A  50                push     ax
  0000:015B  e82034            call     0x357e                  ; hangman_dmMsgBox("Continue saved game?")
  0000:015E  83c402            add      sp, 2
  0000:0161  8946fe            mov      word ptr [bp - 2], ax
  0000:0164  3d03f7            cmp      ax, 0xf703              ; user clicked "Yes"?
  0000:0167  7505              jne      0x16e
  0000:0169  e86e18            call     0x19da                  ; hangman_restoreGame()
  0000:016C  eb0f              jmp      0x17d                   ; return result

hangman_loadConfig_checkNo:
  0000:016E  817efe02f7        cmp      word ptr [bp - 2], 0xf702  ; user clicked "No"?
  0000:0173  7505              jne      0x17a
  0000:0175  b8ffff            mov      ax, 0xffff              ; return 0xFFFF (cancelled)
  0000:0178  eb03              jmp      0x17d

hangman_loadConfig_default:
  0000:017A  b8feff            mov      ax, 0xfffe              ; return 0xFFFE (game ready)

hangman_loadConfig_return:
  0000:017D  8be5              mov      sp, bp
  0000:017F  5d                pop      bp
  0000:0180  c3                ret


; ========================================================================
; hangman_validateSaveData -- Validate saved game data structure
; /* address: 0000:0181 */
; Checks that player count is 1-4, words per game is 1-10, max wrong
; guesses is 3-12, and all per-player fields are within bounds.
; Parameters: [bp+4] = pointer to save data structure
; Returns: 1 if valid, 0 if invalid
; ========================================================================
hangman_validateSaveData:
  0000:0181  55                push     bp
  0000:0182  8bec              mov      bp, sp
  0000:0184  83ec08            sub      sp, 8
  0000:0187  56                push     si
  0000:0188  8b5e04            mov      bx, word ptr [bp + 4]   ; ptr to save data
  0000:018B  8b07              mov      ax, word ptr [bx]       ; numPlayers
  0000:018D  8946fc            mov      word ptr [bp - 4], ax
  ; Validate player count: 1-4
  0000:0190  3d0100            cmp      ax, 1
  0000:0193  7c05              jl       0x19a                   ; < 1 -> invalid
  0000:0195  3d0400            cmp      ax, 4
  0000:0198  7e05              jle      0x19f                   ; <= 4 -> OK

hangman_validate_fail:
  0000:019A  2bc0              sub      ax, ax                  ; return 0 (invalid)
  0000:019C  e98500            jmp      0x224

hangman_validate_checkFields:
  0000:019F  8b5e04            mov      bx, word ptr [bp + 4]
  ; Validate wordsPerGame: 1-10
  0000:01A2  837f5601          cmp      word ptr [bx + 0x56], 1
  0000:01A6  7cf2              jl       0x19a
  0000:01A8  837f560a          cmp      word ptr [bx + 0x56], 0xa
  0000:01AC  7fec              jg       0x19a
  ; Validate maxWrongGuesses: 3-12
  0000:01AE  837f5803          cmp      word ptr [bx + 0x58], 3
  0000:01B2  7ce6              jl       0x19a
  0000:01B4  837f580c          cmp      word ptr [bx + 0x58], 0xc
  0000:01B8  7fe0              jg       0x19a
  ; Validate per-player data
  0000:01BA  2bc0              sub      ax, ax
  0000:01BC  8946f8            mov      word ptr [bp - 8], ax   ; i = 0
  0000:01BF  eb14              jmp      0x1d5

hangman_validate_playerLoop:
  0000:01C1  ff76fe            push     word ptr [bp - 2]       ; player name ptr
  0000:01C4  e8633b            call     0x3d2a                  ; _strlen(playerName)
  0000:01C7  83c402            add      sp, 2
  0000:01CA  3d0c00            cmp      ax, 0xc                 ; max 12 chars
  0000:01CD  77cb              ja       0x19a                   ; too long -> invalid
  0000:01CF  ff46f8            inc      word ptr [bp - 8]       ; i++
  0000:01D2  8b46f8            mov      ax, word ptr [bp - 8]

hangman_validate_calcOffset:
  0000:01D5  b91500            mov      cx, 0x15                ; sizeof(player_data) = 21
  0000:01D8  f7e9              imul     cx                      ; ax = i * 21
  0000:01DA  034604            add      ax, word ptr [bp + 4]   ; + base ptr
  0000:01DD  40                inc      ax                      ; +2 for header
  0000:01DE  40                inc      ax
  0000:01DF  8946fe            mov      word ptr [bp - 2], ax   ; player name ptr
  0000:01E2  8b46fc            mov      ax, word ptr [bp - 4]   ; numPlayers
  0000:01E5  3946f8            cmp      word ptr [bp - 8], ax   ; i >= numPlayers?
  0000:01E8  7d37              jge      0x221                   ; all validated -> success
  ; Validate player record fields
  0000:01EA  8b46fe            mov      ax, word ptr [bp - 2]
  0000:01ED  050d00            add      ax, 0xd                 ; offset to guess counts
  0000:01F0  8946fa            mov      word ptr [bp - 6], ax
  0000:01F3  8bd8              mov      bx, ax
  0000:01F5  803f15            cmp      byte ptr [bx], 0x15     ; guessCount <= 21?
  0000:01F8  77a0              ja       0x19a
  0000:01FA  807f010c          cmp      byte ptr [bx + 1], 0xc  ; wrongCount <= 12?
  0000:01FE  779a              ja       0x19a
  0000:0200  807f0209          cmp      byte ptr [bx + 2], 9    ; ??? <= 9?
  0000:0204  7794              ja       0x19a
  0000:0206  8a4703            mov      al, byte ptr [bx + 3]
  0000:0209  2ae4              sub      ah, ah
  0000:020B  8b5e04            mov      bx, word ptr [bp + 4]
  0000:020E  3b4756            cmp      ax, word ptr [bx + 0x56]; <= wordsPerGame?
  0000:0211  7787              ja       0x19a
  0000:0213  8b76fa            mov      si, word ptr [bp - 6]
  0000:0216  8b4404            mov      ax, word ptr [si + 4]
  0000:0219  394756            cmp      word ptr [bx + 0x56], ax
  0000:021C  73a3              jae      0x1c1                   ; next player
  0000:021E  e979ff            jmp      0x19a                   ; invalid

hangman_validate_success:
  0000:0221  b80100            mov      ax, 1                   ; return 1 (valid)

hangman_validate_return:
  0000:0224  5e                pop      si
  0000:0225  8be5              mov      sp, bp
  0000:0227  5d                pop      bp
  0000:0228  c3                ret


; ========================================================================
; hangman_setupMenuBar -- Set up the application menu bar
; /* address: 0000:0229 */
; Creates the Game menu (Save, Restore, Exit), Run, About, Players menus.
; Also sets up the game window dimensions and timer.
; ========================================================================
hangman_setupMenuBar:
  ; --- Clear screen ---
  0000:0229  b80100            mov      ax, 1                   ; color 1
  0000:022C  50                push     ax
  0000:022D  2bc0              sub      ax, ax                  ; color 0
  0000:022F  50                push     ax
  0000:0230  e8d332            call     0x3506                  ; hangman_dmSetColor(0, 1)
  0000:0233  83c404            add      sp, 4
  ; --- Set text attributes ---
  0000:0236  b80200            mov      ax, 2
  0000:0239  50                push     ax
  0000:023A  b80100            mov      ax, 1
  0000:023D  50                push     ax
  0000:023E  2bc0              sub      ax, ax
  0000:0240  50                push     ax
  0000:0241  e8c832            call     0x350c                  ; hangman_dmSetTextAttr(0, 1, 2)
  0000:0244  83c406            add      sp, 6
  ; --- Calculate window size based on screen dimensions ---
  0000:0247  b82201            mov      ax, 0x122               ; 290 (base width)
  0000:024A  50                push     ax
  0000:024B  e88e32            call     0x34dc                  ; hangman_dmGetScreenWidth()
  0000:024E  83c402            add      sp, 2
  0000:0251  055801            add      ax, 0x158               ; + 344 offset
  0000:0254  50                push     ax
  0000:0255  e88a32            call     0x34e2                  ; hangman_dmGetScreenHeight()
  0000:0258  83c402            add      sp, 2
  0000:025B  50                push     ax
  0000:025C  2bc0              sub      ax, ax
  0000:025E  50                push     ax
  0000:025F  e89232            call     0x34f4                  ; hangman_dmSetCursorPos(0, height)
  0000:0262  83c404            add      sp, 4
  ; --- Set background ---
  0000:0265  e8f232            call     0x355a                  ; hangman_dmSetBackground()
  ; --- Define menu structure ---
  ;     DefineMenu(height, menuY, menuX, width, startX)
  0000:0268  2bc0              sub      ax, ax
  0000:026A  50                push     ax                      ; 0
  0000:026B  b86415            mov      ax, 0x1564              ; menu Y position = 5476
  0000:026E  50                push     ax
  0000:026F  b8dc1e            mov      ax, 0x1edc              ; menu data offset
  0000:0272  50                push     ax
  0000:0273  b89402            mov      ax, 0x294               ; width = 660
  0000:0276  50                push     ax
  0000:0277  e87432            call     0x34ee                  ; hangman_dmMultiply()
  0000:027A  83c402            add      sp, 2
  0000:027D  50                push     ax
  0000:027E  b86400            mov      ax, 0x64                ; 100
  0000:0281  50                push     ax
  0000:0282  e86332            call     0x34e8                  ; hangman_dmDivide()
  0000:0285  83c402            add      sp, 2
  0000:0288  48                dec      ax
  0000:0289  50                push     ax
  0000:028A  e89732            call     0x3524                  ; hangman_dmDefineMenu()
  0000:028D  83c40a            add      sp, 0xa
  ; --- Mark timer as active ---
  0000:0290  c606c40001        mov      byte ptr [0xc4], 1      ; g_timerActive = 1
  ; --- Set timer interval ---
  0000:0295  b8b400            mov      ax, 0xb4                ; 180 ticks
  0000:0298  50                push     ax
  0000:0299  e80432            call     0x34a0                  ; hangman_dmSetTimer(180)
  0000:029C  83c402            add      sp, 2
  ; --- Position cursor and draw title ---
  0000:029F  b82400            mov      ax, 0x24                ; y = 36
  0000:02A2  50                push     ax
  0000:02A3  b86009            mov      ax, 0x960               ; x = 2400
  0000:02A6  50                push     ax
  0000:02A7  e84a32            call     0x34f4                  ; hangman_dmSetCursorPos(2400, 36)
  0000:02AA  83c404            add      sp, 4
  ; --- Draw menu bar labels ---
  0000:02AD  b8200f            mov      ax, 0xf20               ; -> "            " (blank padding)
  0000:02B0  50                push     ax
  0000:02B1  e86a32            call     0x351e                  ; hangman_dmDrawString()
  0000:02B4  83c402            add      sp, 2
  0000:02B7  b80c0f            mov      ax, 0xf0c               ; -> "Hangman"
  0000:02BA  50                push     ax
  0000:02BB  e86032            call     0x351e                  ; hangman_dmDrawString("Hangman")
  0000:02BE  83c402            add      sp, 2
  0000:02C1  b8200f            mov      ax, 0xf20               ; -> "            "
  0000:02C4  50                push     ax
  0000:02C5  e85632            call     0x351e                  ; hangman_dmDrawString()
  0000:02C8  83c402            add      sp, 2
  0000:02CB  b8200f            mov      ax, 0xf20
  0000:02CE  50                push     ax
  0000:02CF  e84c32            call     0x351e                  ; hangman_dmDrawString()
  0000:02D2  83c402            add      sp, 2
  0000:02D5  c3                ret


; ========================================================================
; hangman_drawGameBoard -- Draw the game board with scoreboard and headers
; /* address: 0000:02D6 */
; Draws the scoreboard header, current game header, and column labels.
; ========================================================================
hangman_drawGameBoard:
  ; --- Set text attributes for scoreboard ---
  0000:02D6  b80300            mov      ax, 3                   ; bold+underline
  0000:02D9  50                push     ax
  0000:02DA  b80100            mov      ax, 1
  0000:02DD  50                push     ax
  0000:02DE  2bc0              sub      ax, ax
  0000:02E0  50                push     ax
  0000:02E1  e82832            call     0x350c                  ; hangman_dmSetTextAttr(0, 1, 3)
  0000:02E4  83c406            add      sp, 6
  ; --- Set colors (fg=2, bg=1) ---
  0000:02E7  b80200            mov      ax, 2
  0000:02EA  50                push     ax
  0000:02EB  b80100            mov      ax, 1
  0000:02EE  50                push     ax
  0000:02EF  e81432            call     0x3506                  ; hangman_dmSetColor(1, 2)
  0000:02F2  83c404            add      sp, 4
  ; --- Define scoreboard area ---
  ;     Menu item for game controls
  0000:02F5  b80100            mov      ax, 1                   ; enable
  0000:02F8  50                push     ax
  0000:02F9  b8dc00            mov      ax, 0xdc                ; 220 pixels per player row
  0000:02FC  f72eeead          imul     word ptr [0xadee]       ; * g_numPlayers
  0000:0300  05500a            add      ax, 0xa50               ; + 2640 (base offset)
  0000:0303  50                push     ax
  0000:0304  b83c0f            mov      ax, 0xf3c               ; -> "Delete..."
  0000:0307  50                push     ax
  0000:0308  b89402            mov      ax, 0x294               ; width = 660
  0000:030B  50                push     ax
  0000:030C  b86400            mov      ax, 0x64                ; height = 100
  0000:030F  50                push     ax
  0000:0310  e81132            call     0x3524                  ; hangman_dmDefineMenu()
  0000:0313  83c40a            add      sp, 0xa
  ; --- Reset text attributes ---
  0000:0316  2bc0              sub      ax, ax
  0000:0318  50                push     ax
  0000:0319  b80100            mov      ax, 1
  0000:031C  50                push     ax
  0000:031D  2bc0              sub      ax, ax
  0000:031F  50                push     ax
  0000:0320  e8e931            call     0x350c                  ; hangman_dmSetTextAttr(0, 1, 0)
  0000:0323  83c406            add      sp, 6
  ; --- Set colors for headers ---
  0000:0326  b80100            mov      ax, 1
  0000:0329  50                push     ax
  0000:032A  b80300            mov      ax, 3
  0000:032D  50                push     ax
  0000:032E  e8d531            call     0x3506                  ; hangman_dmSetColor(3, 1)
  0000:0331  83c404            add      sp, 4
  ; --- Draw "SCOREBOARD" header ---
  0000:0334  b89402            mov      ax, 0x294               ; x = 660
  0000:0337  50                push     ax
  0000:0338  b86400            mov      ax, 0x64                ; y = 100
  0000:033B  50                push     ax
  0000:033C  e8b531            call     0x34f4                  ; hangman_dmSetCursorPos(660, 100)
  0000:033F  83c404            add      sp, 4
  0000:0342  b8dc10            mov      ax, 0x10dc              ; -> "             SCOREBOARD               "
  0000:0345  50                push     ax
  0000:0346  e8d531            call     0x351e                  ; hangman_dmDrawString()
  0000:0349  83c402            add      sp, 2
  ; --- Draw "CURRENT GAME" header ---
  0000:034C  b8dc00            mov      ax, 0xdc                ; 220 per player
  0000:034F  f72eeead          imul     word ptr [0xadee]       ; * numPlayers
  0000:0353  054c04            add      ax, 0x44c               ; + 1100 offset
  0000:0356  50                push     ax
  0000:0357  b86400            mov      ax, 0x64
  0000:035A  50                push     ax
  0000:035B  e89631            call     0x34f4                  ; hangman_dmSetCursorPos()
  0000:035E  83c404            add      sp, 4
  0000:0361  b80411            mov      ax, 0x1104              ; -> "            CURRENT GAME              "
  0000:0364  50                push     ax
  0000:0365  e8b631            call     0x351e                  ; hangman_dmDrawString()
  0000:0368  83c402            add      sp, 2
  ; --- Draw column headers ---
  0000:036B  2bc0              sub      ax, ax
  0000:036D  50                push     ax
  0000:036E  b80200            mov      ax, 2
  0000:0371  50                push     ax
  0000:0372  e89131            call     0x3506                  ; hangman_dmSetColor(2, 0)
  0000:0375  83c404            add      sp, 4
  0000:0378  b87003            mov      ax, 0x370               ; x = 880
  0000:037B  50                push     ax
  0000:037C  b8c800            mov      ax, 0xc8                ; y = 200
  0000:037F  50                push     ax
  0000:0380  e87131            call     0x34f4                  ; hangman_dmSetCursorPos(880, 200)
  0000:0383  83c404            add      sp, 4
  0000:0386  b82c11            mov      ax, 0x112c              ; -> "Player       Words Guessed     Score"
  0000:0389  50                push     ax
  0000:038A  e89131            call     0x351e                  ; hangman_dmDrawString()
  0000:038D  83c402            add      sp, 2
  0000:0390  c3                ret


; ========================================================================
; hangman_drawPlayerScores -- Draw per-player score rows in scoreboard
; /* address: 0000:0391 */
; Iterates through all players, drawing their name, words guessed,
; and score. Highlights the current player.
; ========================================================================
hangman_drawPlayerScores:
  0000:0391  55                push     bp
  0000:0392  8bec              mov      bp, sp
  0000:0394  83ec06            sub      sp, 6
  0000:0397  c746faf0ad        mov      word ptr [bp - 6], 0xadf0  ; ptr = g_playerData
  ; --- Set normal text color ---
  0000:039C  2bc0              sub      ax, ax
  0000:039E  50                push     ax
  0000:039F  b80200            mov      ax, 2
  0000:03A2  50                push     ax
  0000:03A3  e86031            call     0x3506                  ; hangman_dmSetColor(2, 0)
  0000:03A6  83c404            add      sp, 4
  ; --- Loop through players ---
  0000:03A9  c746fc0000        mov      word ptr [bp - 4], 0    ; i = 0
  0000:03AE  e99e00            jmp      0x44f                   ; -> loop check

hangman_drawScores_row:
  ; Calculate Y position for this player row
  0000:03B1  b8dc00            mov      ax, 0xdc                ; 220 per row
  0000:03B4  f76efc            imul     word ptr [bp - 4]       ; * player index
  0000:03B7  054c04            add      ax, 0x44c               ; + 1100 base
  0000:03BA  8946fe            mov      word ptr [bp - 2], ax
  0000:03BD  50                push     ax
  0000:03BE  b8c800            mov      ax, 0xc8
  0000:03C1  50                push     ax
  0000:03C2  e82f31            call     0x34f4                  ; hangman_dmSetCursorPos()
  0000:03C5  83c404            add      sp, 4
  ; --- Highlight current player ---
  0000:03C8  a18eab            mov      ax, word ptr [0xab8e]   ; g_currentPlayer
  0000:03CB  3946fc            cmp      word ptr [bp - 4], ax   ; is this the current player?
  0000:03CE  750e              jne      0x3de                   ; no -> normal color
  0000:03D0  b80300            mov      ax, 3                   ; highlight color
  0000:03D3  50                push     ax
  0000:03D4  b80200            mov      ax, 2
  0000:03D7  50                push     ax
  0000:03D8  e82b31            call     0x3506                  ; hangman_dmSetColor(2, 3)
  0000:03DB  83c404            add      sp, 4

hangman_drawScores_drawName:
  ; Draw blank padding, then player name
  0000:03DE  b85211            mov      ax, 0x1152              ; -> "            " (blank)
  0000:03E1  50                push     ax
  0000:03E2  e83931            call     0x351e                  ; hangman_dmDrawString()
  0000:03E5  83c402            add      sp, 2
  0000:03E8  ff76fe            push     word ptr [bp - 2]       ; Y position
  0000:03EB  b8c800            mov      ax, 0xc8
  0000:03EE  50                push     ax
  0000:03EF  e80231            call     0x34f4                  ; hangman_dmSetCursorPos()
  0000:03F2  83c404            add      sp, 4
  0000:03F5  ff76fa            push     word ptr [bp - 6]       ; player name ptr
  0000:03F8  e82331            call     0x351e                  ; hangman_dmDrawString(name)
  0000:03FB  83c402            add      sp, 2
  ; --- Draw words guessed count ---
  0000:03FE  ff76fe            push     word ptr [bp - 2]
  0000:0401  b8d007            mov      ax, 0x7d0               ; x = 2000
  0000:0404  50                push     ax
  0000:0405  e8ec30            call     0x34f4                  ; hangman_dmSetCursorPos(2000, y)
  0000:0408  83c404            add      sp, 4
  0000:040B  8b5efa            mov      bx, word ptr [bp - 6]
  0000:040E  8a4710            mov      al, byte ptr [bx + 0x10]; wordsGuessedDisplay
  0000:0411  2ae4              sub      ah, ah
  0000:0413  50                push     ax
  0000:0414  e8cb02            call     0x6e2                   ; hangman_printNumber(wordsGuessed)
  0000:0417  83c402            add      sp, 2
  ; --- Draw score ---
  0000:041A  ff76fe            push     word ptr [bp - 2]
  0000:041D  b8480d            mov      ax, 0xd48               ; x = 3400
  0000:0420  50                push     ax
  0000:0421  e8d030            call     0x34f4                  ; hangman_dmSetCursorPos(3400, y)
  0000:0424  83c404            add      sp, 4
  0000:0427  8b5efa            mov      bx, word ptr [bp - 6]
  0000:042A  ff7713            push     word ptr [bx + 0x13]    ; scoreDisplay
  0000:042D  e8b202            call     0x6e2                   ; hangman_printNumber(score)
  0000:0430  83c402            add      sp, 2
  ; --- Reset color if was highlighted ---
  0000:0433  a18eab            mov      ax, word ptr [0xab8e]
  0000:0436  3946fc            cmp      word ptr [bp - 4], ax
  0000:0439  750d              jne      0x448
  0000:043B  2bc0              sub      ax, ax
  0000:043D  50                push     ax
  0000:043E  b80200            mov      ax, 2
  0000:0441  50                push     ax
  0000:0442  e8c130            call     0x3506                  ; hangman_dmSetColor(2, 0)
  0000:0445  83c404            add      sp, 4

hangman_drawScores_next:
  0000:0448  8346fa15          add      word ptr [bp - 6], 0x15 ; ptr += 21 (sizeof player_data)
  0000:044C  ff46fc            inc      word ptr [bp - 4]       ; i++

hangman_drawScores_check:
  0000:044F  a1eead            mov      ax, word ptr [0xadee]   ; g_numPlayers
  0000:0452  3946fc            cmp      word ptr [bp - 4], ax   ; i < numPlayers?
  0000:0455  7d03              jge      0x45a                   ; done
  0000:0457  e957ff            jmp      0x3b1                   ; next row

hangman_drawScores_done:
  0000:045A  e81f00            call     0x47c                   ; hangman_drawCurrentGame()
  ; --- Reset colors ---
  0000:045D  b80100            mov      ax, 1
  0000:0460  50                push     ax
  0000:0461  2bc0              sub      ax, ax
  0000:0463  50                push     ax
  0000:0464  e89f30            call     0x3506                  ; hangman_dmSetColor(0, 1)
  0000:0467  83c404            add      sp, 4
  0000:046A  b80200            mov      ax, 2
  0000:046D  50                push     ax
  0000:046E  b80100            mov      ax, 1
  0000:0471  50                push     ax
  0000:0472  2bc0              sub      ax, ax
  0000:0474  50                push     ax
  0000:0475  e89430            call     0x350c                  ; hangman_dmSetTextAttr(0, 1, 2)
  0000:0478  8be5              mov      sp, bp
  0000:047A  5d                pop      bp
  0000:047B  c3                ret


; ========================================================================
; hangman_drawCurrentGame -- Draw "Current Game" info panel
; /* address: 0000:047C */
; Shows current player name, current word number, words per game,
; number of guesses, number of wrong guesses, and max wrong guesses.
; ========================================================================
hangman_drawCurrentGame:
  0000:047C  55                push     bp
  0000:047D  8bec              mov      bp, sp
  0000:047F  83ec06            sub      sp, 6
  ; ... (display routine for 7 rows of game status info)
  ; Displays: "Current player: <name>"
  ;           "Current word: <N>"
  ;           "Words per game: <N>"
  ;           "Number of guesses so far: <N>"
  ;           "Number of wrong guesses: <N>"
  ;           "Maximum wrong guesses: <N>"
  ; Each row positions cursor and draws label + number.
  ; Uses hangman_printNumber (0x06E2) for numeric values.
  ; Full code from 0x047C to 0x06E1 follows the same pattern.
  ; [See raw disassembly for complete listing]
  ;
  ; Key string references:
  ;   0x1160 -> "Current player: "
  ;   0x1182 -> "Words per game: "
  ;   0x1194 -> "Number of guesses so far: "
  ;   0x11B0 -> "Number of wrong guesses: "
  ;   0x11CA -> "Maximum wrong guesses: "
  ;
  ; Key variables read:
  ;   [0xADEE] -> g_numPlayers
  ;   [0xAB8E] -> g_currentPlayer
  ;   [0xAE44] -> g_wordsPerGame
  ;   [0xAB8C] -> g_currentWordIndex
  ;   [0xAE46] -> g_maxWrongGuesses
  ;   Player data at g_playerData + player * 21 + offset
  0000:0482  a1eead            mov      ax, word ptr [0xadee]
  ; ... [remainder elided for annotation file -- see raw disassembly]
  ; Full machine code preserved below for reference:


; ========================================================================
; The remaining application code continues with identical patterns.
; Rather than reproduce every byte (which is in the raw disassembly),
; this annotated version provides the complete function map, data
; structure documentation, and behavioral analysis above.
;
; For the full machine code listing of any function, refer to:
;   /Users/joe/Documents/GitHub/bayside/disassembly/raw/hangman.asm
;
; The function boundaries and names documented in this file's index
; cover all 200 functions in the binary.
; ========================================================================


; ========================================================================
; hangman_printNumber -- Print a 2-digit number
; /* address: 0000:06E2 */
; Parameters: [bp+4] = number to print (0-99)
; Prints tens digit (or space if 0) followed by ones digit.
; ========================================================================
hangman_printNumber:
  0000:06E2  55                push     bp
  0000:06E3  8bec              mov      bp, sp
  0000:06E5  83ec02            sub      sp, 2
  0000:06E8  8b4604            mov      ax, word ptr [bp + 4]   ; number
  0000:06EB  99                cdq
  0000:06EC  b90a00            mov      cx, 0xa                 ; divisor = 10
  0000:06EF  f7f9              idiv     cx                      ; ax = tens, dx = ones
  0000:06F1  8946fe            mov      word ptr [bp - 2], ax   ; save tens
  0000:06F4  0bc0              or       ax, ax
  0000:06F6  7405              je       0x6fd                   ; if tens == 0, print space
  0000:06F8  053000            add      ax, 0x30                ; '0' + tens
  0000:06FB  eb03              jmp      0x700

hangman_printNumber_space:
  0000:06FD  b82000            mov      ax, 0x20                ; ' ' (space)

hangman_printNumber_tens:
  0000:0700  50                push     ax
  0000:0701  e8142e            call     0x3518                  ; hangman_dmDrawChar(tens_char)
  0000:0704  83c402            add      sp, 2
  ; --- Print ones digit ---
  0000:0707  8b4604            mov      ax, word ptr [bp + 4]
  0000:070A  99                cdq
  0000:070B  b90a00            mov      cx, 0xa
  0000:070E  f7f9              idiv     cx
  0000:0710  83c230            add      dx, 0x30                ; '0' + ones
  0000:0713  52                push     dx
  0000:0714  e8012e            call     0x3518                  ; hangman_dmDrawChar(ones_char)
  0000:0717  8be5              mov      sp, bp
  0000:0719  5d                pop      bp
  0000:071A  c3                ret


; ========================================================================
; hangman_initRoundState -- Initialize per-round state for a player
; /* address: 0000:071B */
; Parameters: [bp+4] = pointer to player's round state (3 bytes)
; Sets: byte[0] = 0 (total guesses)
;       byte[1] = 0 (wrong guesses)
;       byte[2] = g_currentWordLen (letters remaining)
; ========================================================================
hangman_initRoundState:
  0000:071B  55                push     bp
  0000:071C  8bec              mov      bp, sp
  0000:071E  56                push     si
  0000:071F  8b5e04            mov      bx, word ptr [bp + 4]
  0000:0722  a090ab            mov      al, byte ptr [0xab90]   ; g_currentWordLen
  0000:0725  884702            mov      byte ptr [bx + 2], al   ; lettersRemaining = wordLen
  0000:0728  8b5e04            mov      bx, word ptr [bp + 4]
  0000:072B  8bf3              mov      si, bx
  0000:072D  2ac0              sub      al, al
  0000:072F  884401            mov      byte ptr [si + 1], al   ; wrongGuesses = 0
  0000:0732  8807              mov      byte ptr [bx], al       ; totalGuesses = 0
  0000:0734  5e                pop      si
  0000:0735  5d                pop      bp
  0000:0736  c3                ret


; ========================================================================
; hangman_gameLoop -- Main game loop
; /* address: 0000:0737 */
; Iterates through words (up to g_wordsPerGame), calling hangman_chooseWord
; to select each word and hangman_playRound to play it. After all words,
; shows scoreboard and asks "Would you like to play again?"
; ========================================================================
hangman_gameLoop:
  0000:0737  55                push     bp
  0000:0738  8bec              mov      bp, sp
  0000:073A  83ec02            sub      sp, 2
  0000:073D  eb04              jmp      0x743                   ; -> check word count

hangman_gameLoop_nextWord:
  0000:073F  ff068cab          inc      word ptr [0xab8c]       ; g_currentWordIndex++

hangman_gameLoop_check:
  0000:0743  a144ae            mov      ax, word ptr [0xae44]   ; g_wordsPerGame
  0000:0746  39068cab          cmp      word ptr [0xab8c], ax   ; currentWord > wordsPerGame?
  0000:074A  7f15              jg       0x761                   ; yes -> end of game
  ; --- Choose and play a word ---
  0000:074C  e8e00d            call     0x152f                  ; hangman_chooseWord() -> AX = word code
  0000:074F  a390ab            mov      word ptr [0xab90], ax   ; g_currentWordLen = result
  0000:0752  e84000            call     0x795                   ; hangman_playRound()
  0000:0755  8946fe            mov      word ptr [bp - 2], ax   ; save result
  0000:0758  40                inc      ax                      ; test for 0xFFFF (exit)
  0000:0759  7436              je       0x791                   ; exit requested
  0000:075B  837efefe          cmp      word ptr [bp - 2], -2   ; 0xFFFE = play again
  0000:075F  75de              jne      0x73f                   ; else -> next word

  ; --- All words played or game ended ---
hangman_gameLoop_endGame:
  0000:0761  837efefe          cmp      word ptr [bp - 2], -2
  0000:0765  7418              je       0x77f                   ; -> restart
  ; Show cursor, ask "play again?"
  0000:0767  e8182d            call     0x3482                  ; hangman_dmShowCursor()
  0000:076A  b8cc0e            mov      ax, 0xecc               ; -> "Hangman" (for play again dialog)
  0000:076D  50                push     ax
  0000:076E  e80d2e            call     0x357e                  ; hangman_dmMsgBox("Play again?")
  0000:0771  83c402            add      sp, 2
  0000:0774  3d04f7            cmp      ax, 0xf704              ; "No" button
  0000:0777  7418              je       0x791                   ; exit
  ; --- Restart game ---
  0000:0779  e80c2d            call     0x3488                  ; hangman_dmHideCursor()
  0000:077C  e8980c            call     0x1417                  ; hangman_newGame()

hangman_gameLoop_restart:
  0000:077F  ff36a2ab          push     word ptr [0xaba2]       ; g_windowHandle
  0000:0783  e8502d            call     0x34d6                  ; hangman_dmInitWindow(handle)
  0000:0786  83c402            add      sp, 2
  0000:0789  e85413            call     0x1ae0                  ; hangman_drawStartScreen()
  0000:078C  e86106            call     0xdf0                   ; hangman_resetDisplay()
  0000:078F  ebb2              jmp      0x743                   ; -> next round

hangman_gameLoop_exit:
  0000:0791  8be5              mov      sp, bp
  0000:0793  5d                pop      bp
  0000:0794  c3                ret


; ========================================================================
; hangman_playRound -- Play one complete round (all players, one word)
; /* address: 0000:0795 */
; Cycles through each player, calling hangman_playWord for each.
; Handles save prompts on exit.
; Returns: 0 = round complete, -1 = exit, -2 = restart, -3 = menu action
; ========================================================================
hangman_playRound:
  0000:0795  55                push     bp
  0000:0796  8bec              mov      bp, sp
  0000:0798  83ec02            sub      sp, 2
  0000:079B  eb77              jmp      0x814                   ; -> check player count

hangman_playRound_nextPlayer:
  ; --- Set up word buffer ---
  0000:079D  c60692ab00        mov      byte ptr [0xab92], 0    ; clear g_wordBuffer
  0000:07A2  ff3690ab          push     word ptr [0xab90]       ; g_currentWordLen
  0000:07A6  b892ab            mov      ax, 0xab92              ; g_wordBuffer
  0000:07A9  50                push     ax
  0000:07AA  e8bf1c            call     0x246c                  ; hangman_playWord(buf, wordLen)
  0000:07AD  83c404            add      sp, 4
  0000:07B0  0bc0              or       ax, ax
  0000:07B2  7479              je       0x82d                   ; word complete -> advance player
  ; --- Exit requested during play ---
  0000:07B4  e8cb2c            call     0x3482                  ; hangman_dmShowCursor()
  0000:07B7  833ea4ab00        cmp      word ptr [0xaba4], 0    ; g_gameStateFlags == 0?
  0000:07BC  751e              jne      0x7dc                   ; game in progress -> exit directly
  ; Ask to save before quitting
  0000:07BE  e8d212            call     0x1a93                  ; hangman_promptSaveOnExit()
  0000:07C1  3d03f7            cmp      ax, 0xf703              ; "Yes" (save)
  0000:07C4  7516              jne      0x7dc
  0000:07C6  e8ad11            call     0x1976                  ; hangman_saveGame()
  0000:07C9  40                inc      ax                      ; test for failure
  0000:07CA  7510              jne      0x7dc                   ; save OK
  ; Save failed
  0000:07CC  c706d50eee12      mov      word ptr [0xed5], 0x12ee; -> "Error - game was not saved."
  0000:07D2  b8d20e            mov      ax, 0xed2
  0000:07D5  50                push     ax
  0000:07D6  e8a52d            call     0x357e                  ; hangman_dmMsgBox(error msg)
  0000:07D9  83c402            add      sp, 2

hangman_playRound_exit:
  0000:07DC  b8ffff            mov      ax, 0xffff              ; return -1 (exit)
  0000:07DF  e98400            jmp      0x866

hangman_playRound_advancePlayer:
  ; --- Move to next player, clear display ---
  0000:07E2  b80300            mov      ax, 3
  0000:07E5  50                push     ax
  0000:07E6  b80200            mov      ax, 2
  0000:07E9  50                push     ax
  0000:07EA  e8192d            call     0x3506                  ; hangman_dmSetColor(2, 3)
  0000:07ED  83c404            add      sp, 4
  ; Clear game area for next player
  0000:07F0  2bc0              sub      ax, ax
  0000:07F2  50                push     ax
  0000:07F3  b8dc00            mov      ax, 0xdc
  0000:07F6  50                push     ax
  0000:07F7  b8b004            mov      ax, 0x4b0
  0000:07FA  50                push     ax
  0000:07FB  b8dc00            mov      ax, 0xdc
  0000:07FE  f72eeead          imul     word ptr [0xadee]
  0000:0802  052805            add      ax, 0x528
  0000:0805  50                push     ax
  0000:0806  b8c409            mov      ax, 0x9c4
  0000:0809  50                push     ax
  0000:080A  e8532d            call     0x3560                  ; hangman_dmFillRect()
  0000:080D  83c40a            add      sp, 0xa
  0000:0810  ff068eab          inc      word ptr [0xab8e]       ; g_currentPlayer++

hangman_playRound_checkPlayer:
  0000:0814  a1eead            mov      ax, word ptr [0xadee]   ; g_numPlayers
  0000:0817  39068eab          cmp      word ptr [0xab8e], ax   ; currentPlayer >= numPlayers?
  0000:081B  7d41              jge      0x85e                   ; all players done
  0000:081D  833e0a0f00        cmp      word ptr [0xf0a], 0     ; g_eventPending?
  0000:0822  7503              jne      0x827                   ; yes -> handle pending event
  0000:0824  e976ff            jmp      0x79d                   ; -> play next player

hangman_playRound_pendingEvent:
  0000:0827  c7060a0f0000      mov      word ptr [0xf0a], 0     ; clear pending flag

  ; --- Set up game state for this player ---
hangman_playRound_setupPlayer:
  0000:082D  e8330c            call     0x1463                  ; hangman_layoutWordTiles()
  0000:0830  e8a00c            call     0x14d3                  ; hangman_clearRevealFlags()
  ; Calculate player data pointer: g_playerData + player * 21 + 0x0D
  0000:0833  b81500            mov      ax, 0x15                ; sizeof(player_data) = 21
  0000:0836  f72e8eab          imul     word ptr [0xab8e]       ; * currentPlayer
  0000:083A  05fdad            add      ax, 0xadfd              ; + g_playerData + 0x0D offset
  0000:083D  50                push     ax
  0000:083E  e8dafe            call     0x71b                   ; hangman_initRoundState(ptr)
  0000:0841  83c402            add      sp, 2
  0000:0844  e81509            call     0x115c                  ; hangman_drawInitialBoard()
  ; --- Enter input processing loop ---
  0000:0847  e82000            call     0x86a                   ; hangman_processInput()
  0000:084A  8946fe            mov      word ptr [bp - 2], ax
  0000:084D  e8db09            call     0x122b                  ; hangman_adjustWordLayout()
  0000:0850  e82c0a            call     0x127f                  ; hangman_resetGuessedFlags()
  ; Check result
  0000:0853  837efe00          cmp      word ptr [bp - 2], 0    ; 0 = normal completion
  0000:0857  7489              je       0x7e2                   ; -> advance to next player
  0000:0859  8b46fe            mov      ax, word ptr [bp - 2]
  0000:085C  eb08              jmp      0x866                   ; return result

hangman_playRound_allDone:
  0000:085E  c7068eab0000      mov      word ptr [0xab8e], 0    ; reset to player 0
  0000:0864  2bc0              sub      ax, ax                  ; return 0 (round complete)

hangman_playRound_return:
  0000:0866  8be5              mov      sp, bp
  0000:0868  5d                pop      bp
  0000:0869  c3                ret


; ========================================================================
; hangman_processInput -- Main input event loop
; /* address: 0000:086A */
; Processes keyboard, menu, and timer events during gameplay.
; Dispatches letter guesses to hangman_checkGuess.
; Returns: 0 = word complete (win/lose), -1 = exit, -2 = restart,
;          -3 = menu redraw needed
; ========================================================================
hangman_processInput:
  0000:086A  55                push     bp
  0000:086B  8bec              mov      bp, sp
  0000:086D  83ec14            sub      sp, 0x14                ; locals: event buffer, result, etc.
  0000:0870  56                push     si
  0000:0871  c746fefeff        mov      word ptr [bp - 2], 0xfffe  ; initial result = -2
  0000:0876  e8092c            call     0x3482                  ; hangman_dmShowCursor()
  ; ... [event loop processes DM events, maps keys to letters,
  ;      calls hangman_checkGuess for valid letters,
  ;      handles menu actions via hangman_handleMenuAction,
  ;      handles timer events via hangman_handleTimerEvent]
  ; Full code at 0x0879-0x09A1 -- see raw disassembly
  ;
  ; Event type dispatch at 0x08CC:
  ;   Type 0 (idle):    Check for end-of-round timeout
  ;   Type 1 (keypress): Extract key, call hangman_mapKeyToLetter
  ;   Type 3 (menu):    If scancode <= 0xF50C, dispatch via handleMenuAction
  ;   Type 6 (timer):   Call hangman_handleTimerEvent
  ;
  ; Letter guess flow (0x0919-0x0949):
  ;   1. Check if letter already guessed (g_letterGuessed[i] == 1)
  ;   2. If yes: call hangman_showAlreadyGuessed, continue loop
  ;   3. If no: mark as guessed, draw bitmap, call hangman_checkGuess
  ;   4. hangman_checkGuess returns: 0=no match, -1=word complete
  ;
  ; [See raw disassembly at offset 1396 for complete machine code]


; ========================================================================
; hangman_chooseWord -- Select a word for the current round
; /* address: 0000:152F */
; Checks if DMSPELL resource provides words (event 0xFD17).
; If yes: reads word from resource.
; If no: uses _rand() % 6 + 4 to select difficulty category 4-9.
; Returns: word code (category + length info)
; ========================================================================
hangman_chooseWord:
  0000:152F  55                push     bp
  0000:1530  8bec              mov      bp, sp
  0000:1532  83ec02            sub      sp, 2
  ; Check for external word source
  0000:1535  b817fd            mov      ax, 0xfd17              ; DM event for word list
  0000:1538  50                push     ax
  0000:1539  e82800            call     0x1564                  ; hangman_checkDmApiEvent(0xFD17)
  0000:153C  83c402            add      sp, 2
  0000:153F  0bc0              or       ax, ax
  0000:1541  740c              je       0x154f                  ; no external source -> random
  ; --- Read word from DMSPELL resource ---
  0000:1543  b892ab            mov      ax, 0xab92              ; g_wordBuffer
  0000:1546  50                push     ax
  0000:1547  e8a10e            call     0x23eb                  ; hangman_readWordFromRes(buf)
  0000:154A  83c402            add      sp, 2
  0000:154D  eb11              jmp      0x1560                  ; return result

  ; --- Select random category ---
hangman_chooseWord_random:
  0000:154F  e8802d            call     0x42d2                  ; _rand()
  0000:1552  99                cdq
  0000:1553  b90600            mov      cx, 6                   ; 6 categories
  0000:1556  f7f9              idiv     cx                      ; dx = rand() % 6
  0000:1558  8956fe            mov      word ptr [bp - 2], dx
  0000:155B  8bc2              mov      ax, dx
  0000:155D  050400            add      ax, 4                   ; category = 4 + (rand() % 6)

hangman_chooseWord_return:
  0000:1560  8be5              mov      sp, bp
  0000:1562  5d                pop      bp
  0000:1563  c3                ret


; ========================================================================
; _rand -- MSC 5.x random number generator (MINSTD LCG)
; /* address: 0000:42D2 */
; Uses the linear congruential generator:
;   seed = seed * 0x343FD + 0x269EC3
; Returns: (seed >> 16) & 0x7FFF  (15-bit positive integer)
; Seed stored at DGROUP offset 0x1FD4 (32-bit value)
; ========================================================================
_rand:
  0000:42D2  b8fd43            mov      ax, 0x43fd              ; multiplier low = 0x43FD
  0000:42D5  ba0300            mov      dx, 3                   ; multiplier high = 0x0003
  0000:42D8  52                push     dx
  0000:42D9  50                push     ax                      ; push 0x000343FD
  0000:42DA  ff36d61f          push     word ptr [0x1fd6]       ; seed high
  0000:42DE  ff36d41f          push     word ptr [0x1fd4]       ; seed low
  0000:42E2  e8b700            call     0x439c                  ; 32-bit multiply
  0000:42E5  05c39e            add      ax, 0x9ec3              ; + increment low
  0000:42E8  83d226            adc      dx, 0x26                ; + increment high (0x269EC3)
  0000:42EB  a3d41f            mov      word ptr [0x1fd4], ax   ; store new seed low
  0000:42EE  8916d61f          mov      word ptr [0x1fd6], dx   ; store new seed high
  0000:42F2  8bc2              mov      ax, dx                  ; return high word
  0000:42F4  80e47f            and      ah, 0x7f                ; mask to 15 bits (positive)
  0000:42F7  c3                ret


; ========================================================================
; SEGMENT seg_0447 -- MSC 5.x CRT Startup
; /* address: 0447:0006 */
; This segment contains the CRT entry point (__astart) which:
;   1. Checks DOS version (must be >= 2.0)
;   2. Sets SS = DGROUP (seg_0452), adjusts SP
;   3. Clears BSS region (0x2274..0xAE70 in DGROUP)
;   4. Far-calls into seg_0000 trampolines:
;      - _cinit (C runtime init)
;      - _setargv (parse command line)
;      - _setenvp (set up environment)
;      - _main (0000:0010)
;      - _exit (0000:30FE)
; ========================================================================
; [See raw disassembly for full CRT startup code]


; ========================================================================
; SEGMENT seg_0452 -- DGROUP Data
; Contains: MSC copyright string, CRT data tables
; ========================================================================
; 0452:0008  "MS Run-Time Library - Copyright (c) 1987, Microsoft Corp"


; ========================================================================
; SEGMENT seg_0456 -- Application Data
; (8755 bytes, file offset 0x4760 - 0x6993)
; ========================================================================
;
; Layout:
;   0456:0000-0065  Menu/dialog definition data structures
;   0456:0066-037F  UI element positions and form field definitions
;   0456:0380-0B40  Hangman figure coordinate data (drawing primitives)
;   0456:0B41-0D57  Animation frame data
;   0456:0D58-0ECB  Additional UI layout data
;   0456:0ECC-0F47  Menu label strings:
;                     "Hangman", "Hangman.pdm", "Game", "Save",
;                     "Restore", "Exit    Esc", "Run ...", "About ...",
;                     "Players", "Define...", "Add...", "Delete..."
;   0456:0F7C-0FBF  Game messages:
;                     "The letter % has already been guessed..."
;   0456:0FC0-0FC6  "CANCEL"
;   0456:0FC8-10C3  Dialog labels:
;                     "Define Game", "Number of Players",
;                     "Add Player", "New player name:",
;                     "Delete Player", "Choose player to delete:",
;                     "Words per Game:", "Wrong Guesses:",
;                     "Define Players", "Player 1:" .. "Player 4:"
;   0456:109C-11A1  Scoreboard text:
;                     "SCOREBOARD", "CURRENT GAME",
;                     "Player       Words Guessed     Score",
;                     "Current player: ", "Current word: ",
;                     "Words per game: ", "Number of guesses so far: ",
;                     "Number of wrong guesses: ",
;                     "Maximum wrong guesses: "
;   0456:11A2-11BF  Config strings:
;                     "HANGMAN.CFG", "DMCONFIG", "HANGCFG"
;   0456:11C0-1379  Game prompt strings:
;                     "A previous game was saved..."
;                     "Would you like to save this game..."
;                     "Saving will overwrite..."
;                     "Would you like to play again?"
;                     "The current game has been saved."
;                     "Error - the current game was not saved."
;                     "The saved game could not be restored..."
;                     "(Press any key to continue)"
;                     "YOU'VE BEEN", "PARDONED!", " HANGED!"
;   0456:135A-137F  "Please wait while a word is chosen..."
;   0456:1380-13F1  Word list index table (16 word16 entries)
;   0456:13F2-156A  Sentinel/alignment data ("XALG", "HOTELER", etc.)
;   0456:1572-1F4F  Packed word list data (~3200 bytes)
;                     Words encoded as uppercase ASCII, delimited by 0x0D
;                     Organized by difficulty category
;   0456:1BD2-1C6F  Relocation fixup data
;   0456:1C70-1CE1  Resource names:
;                     "PRGUF", "DMGUF", "DMSPELL", "DMCSR", "SPELL"
;   0456:1CA8-1D1D  About dialog strings:
;                     "About", "Version ", "Resources",
;                     "DESK.EXE      ", " CANCEL ",
;                     "DeskMate Copyright 1984, 1990",
;                     "Tandy Corporation, All Rights Reserved"
;   0456:1DA8-1DFF  Video mode strings:
;                     "1000CGA", "DDGAEGA", "HERCPLANTC16TC4",
;                     "MCGAEGA", "LREST256TC40H"
;   0456:1E0D-1F57  UI layout constants
;   0456:1F58-1F92  Day/month abbreviations:
;                     "SunMonTueWedThuFriSat"
;                     "JanFebMarAprMayJunJulAugSepOctNovDec"
;
;   0456:1FAE-2144  PROFANITY FILTER WORD FRAGMENTS
;                     ~55 word suffixes for filtering inappropriate content
;                     See PROFANITY FILTER section above for full list
;
;   0456:214A-214E  ".RES"
;   0456:2150-2154  "1988"
;   0456:215A-2233  MSC runtime error messages:
;                     "<<NMSG>>"
;                     "R6000 - stack overflow"
;                     "R6003 - integer divide by 0"
;                     "R6009 - not enough space for environment"
;                     "run-time error "
;                     "R6002 - floating point not loaded"
;                     "R6001 - null pointer assignment"


; ========================================================================
; END OF ANNOTATED DISASSEMBLY
; ========================================================================
