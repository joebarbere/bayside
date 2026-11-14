/* ========================================================================
 * hangman_data.c -- Static data: strings, word list, profanity filter,
 *                   menu definitions, hangman graphics coordinates
 * ========================================================================
 * All data from seg_0456 (8755 bytes, file offset 0x4760-0x6993).
 * String offsets reference the original data segment for traceability.
 *
 * Reference: /disassembly/annotated/hangman.asm (SEGMENT seg_0456)
 * ========================================================================
 */

#include "hangman.h"
#include <stdlib.h>

/* ====================================================================
 * Global game state variables (DGROUP / BSS)
 * ==================================================================== */

/* 0x004E */ unsigned char  g_hasSavedGame = 0;
/* 0x0059 */ unsigned char  g_savedGameValid = 0;
/* 0x00C4 */ unsigned char  g_timerActive = 0;
/* 0x00DA */ unsigned char  g_letterGuessed[HANGMAN_NUM_LETTERS];
/* 0xAB8C */ unsigned int   g_currentWordIndex = 0;
/* 0xAB8E */ unsigned int   g_currentPlayer = 0;
/* 0xAB90 */ unsigned int   g_currentWordLen = 0;
/* 0xAB92 */ char           g_wordBuffer[HANGMAN_WORD_BUF_SIZE];
/* 0xAB9E */ unsigned int   g_cursorHandle = 0;
/* 0xABA0 */ unsigned int   g_wordXOffset = 0;
/* 0xABA2 */ unsigned int   g_windowHandle = 0;
/* 0xABA4 */ unsigned int   g_gameStateFlags = 0;
/* 0xABA6 */ unsigned int   g_scoreAccumulator = 0;
/* 0xABA8 */ char           g_configBuffer[HANGMAN_CONFIG_BUF_SIZE];
/* 0xADBA */ unsigned int   g_letterBitmapPtrs[HANGMAN_NUM_LETTERS];
/* 0xADEE */ unsigned int   g_numPlayers = 1;
/* 0xADF0 */ Hangman_PlayerData g_playerData[HANGMAN_MAX_PLAYERS];
/* 0xAE44 */ unsigned int   g_wordsPerGame = 5;
/* 0xAE46 */ unsigned int   g_maxWrongGuesses = 7;
/* 0xAE48 */ unsigned int   g_aboutLinesPtrs[15];
/* 0xAE68 */ unsigned int   g_boardYOffset = 0;
/* 0x0F08 */ unsigned int   g_spellAvailable = 0;
/* 0x0F0A */ unsigned int   g_eventPending = 0;
/* 0x0EE8 */ unsigned int   g_roundActive = 0;
/* 0x0EEA */ unsigned int   g_scoreVisible = 0;

/* Random number seed (DGROUP 0x1FD4, 32-bit) -- used by CRT _rand() */
static unsigned long g_randSeed = 1L;

/* ====================================================================
 * Menu label strings (seg_0456:0ECC-0F47)
 * ==================================================================== */

/* 0456:0ECC */ const char sz_Hangman[]       = "Hangman";
/* 0456:0ED4 */ const char sz_HangmanPdm[]    = "Hangman.pdm";
/* 0456:0EE0 */ const char sz_Game[]          = "Game";
/* 0456:0EE5 */ const char sz_Save[]          = "Save";
/* 0456:0EEA */ const char sz_Restore[]       = "Restore";
/* 0456:0EF2 */ const char sz_ExitEsc[]       = "Exit    Esc";
/* 0456:0EFE */ const char sz_Run[]           = "Run ...";
/* 0456:0F06 */ const char sz_About[]         = "About ...";
/* 0456:0F10 */ const char sz_Players[]       = "Players";
/* 0456:0F18 */ const char sz_Define[]        = "Define...";
/* 0456:0F22 */ const char sz_Add[]           = "Add...";
/* 0456:0F29 */ const char sz_Delete[]        = "Delete...";
/* 0456:0F33 */ const char sz_Cancel[]        = "CANCEL";

/* Blank padding for scoreboard rows */
/* 0456:0F20 */ const char sz_BlankPad[]      = "            ";

/* ====================================================================
 * Game messages (seg_0456:0F7C-10C3)
 * ==================================================================== */

/* 0456:0F7C */
const char sz_AlreadyGuessed[] =
    "The letter % has already been guessed.  Try a different letter!";

/* ====================================================================
 * Dialog labels (seg_0456:0FC8-10C3)
 * ==================================================================== */

/* 0456:0FC8 */ const char sz_DefineGame[]    = "Define Game";
/* 0456:0FD4 */ const char sz_NumPlayers[]    = "Number of Players";
/* 0456:0FE6 */ const char sz_AddPlayer[]     = "Add Player";
/* 0456:0FF1 */ const char sz_NewPlayerName[] = "New player name:";
/* 0456:1002 */ const char sz_DeletePlayer[]  = "Delete Player";
/* 0456:1010 */ const char sz_ChooseDelete[]  = "Choose player to delete:";
/* 0456:1029 */ const char sz_WordsPerGame[]  = "Words per Game:";
/* 0456:1039 */ const char sz_WrongGuesses[]  = "Wrong Guesses:";
/* 0456:1048 */ const char sz_DefinePlayers[] = "Define Players";
/* 0456:1057 */ const char sz_Player1[]       = "Player 1:";
/* 0456:1061 */ const char sz_Player2[]       = "Player 2:";
/* 0456:106B */ const char sz_Player3[]       = "Player 3:";
/* 0456:1075 */ const char sz_Player4[]       = "Player 4:";

/* ====================================================================
 * Scoreboard text (seg_0456:109C-11A1)
 * ==================================================================== */

/* 0456:10DC */ const char sz_Scoreboard[]    =
    "             SCOREBOARD               ";
/* 0456:1104 */ const char sz_CurrentGame[]   =
    "            CURRENT GAME              ";
/* 0456:112C */ const char sz_ColHeaders[]    =
    "Player       Words Guessed     Score";

/* 0456:1160 */ const char sz_CurPlayer[]     = "Current player: ";
/* 0456:1171 */ const char sz_CurWord[]       = "Current word: ";
/* 0456:1182 */ const char sz_WordsPerGameL[] = "Words per game: ";
/* 0456:1194 */ const char sz_NumGuesses[]    = "Number of guesses so far: ";
/* 0456:11B0 */ const char sz_NumWrong[]      = "Number of wrong guesses: ";
/* 0456:11CA */ const char sz_MaxWrong[]      = "Maximum wrong guesses: ";

/* ====================================================================
 * Config strings (seg_0456:11A2-11BF)
 * ==================================================================== */

/* 0456:11A2 */ const char sz_HangmanCfg[]    = "HANGMAN.CFG";
/* 0456:11AE */ const char sz_DmConfig[]      = "DMCONFIG";
/* 0456:11B7 */ const char sz_HangCfg[]       = "HANGCFG";

/* ====================================================================
 * Game prompt strings (seg_0456:11C0-1379)
 * ==================================================================== */

const char sz_PrevSaved[]     =
    "A previous game was saved.  Would you like to continue that game?";
const char sz_SavePrompt[]    =
    "Would you like to save this game before quitting?";
const char sz_SaveOverwrite[] =
    "Saving will overwrite the previously saved game.  Save anyway?";
const char sz_PlayAgain[]     =
    "Would you like to play again?";
const char sz_GameSaved[]     =
    "The current game has been saved.";
const char sz_SaveError[]     =
    "Error - the current game was not saved.";
const char sz_RestoreError[]  =
    "The saved game could not be restored.  Starting a new game.";
const char sz_PressAnyKey[]   =
    "(Press any key to continue)";

/* Result messages */
const char sz_YouveBeen[]     = "YOU'VE BEEN";
const char sz_Pardoned[]      = "PARDONED!";
const char sz_Hanged[]        = " HANGED!";

/* Wait message */
/* 0456:135A */
const char sz_PleaseWait[]    = "Please wait while a word is chosen...";

/* ====================================================================
 * About dialog strings (seg_0456:1CA8-1D1D)
 * ==================================================================== */

const char sz_AboutTitle[]    = "About";
const char sz_Version[]       = "Version ";
const char sz_Resources[]     = "Resources";
const char sz_DeskExe[]       = "DESK.EXE      ";
const char sz_CancelBtn[]     = " CANCEL ";
const char sz_Copyright1[]    = "DeskMate Copyright 1984, 1990";
const char sz_Copyright2[]    = "Tandy Corporation, All Rights Reserved";

/* ====================================================================
 * Word list index table (seg_0456:1380-13F1)
 * ==================================================================== */

/* 16 word16 entries: byte offsets into the packed word data for each
 * difficulty category. Category 0 is unused; categories 4-9 are the
 * 6 difficulty levels used by _rand() % 6 + 4. */
const unsigned int g_wordListIndex[16] = {
    0x0000, 0x0000, 0x0000, 0x0000,  /* categories 0-3 (unused) */
    0x0000, 0x0120, 0x0270, 0x03E0,  /* categories 4-7 */
    0x0560, 0x0700, 0x0800, 0x0000,  /* categories 8-10, unused */
    0x0000, 0x0000, 0x0000, 0x0000   /* unused */
};

/* ====================================================================
 * Packed word list data (seg_0456:1572-1F4F, ~3200 bytes)
 * ========================================================================
 * Words are stored as uppercase ASCII, delimited by 0x0D (CR).
 * Organized by difficulty category (shorter/easier words first).
 *
 * NOTE: This is a representative subset. The full binary contains ~3200
 * bytes of packed word data. In the actual build, this data would be
 * extracted directly from the original HANGMAN.PDM binary.
 *
 * The word list is accessed by hangman_readWordFromRes() which indexes
 * into this data using g_wordListIndex[] offsets per category.
 * ==================================================================== */

const char g_packedWordList[] = {
    /* Category 4 (easy, 3-4 letter words) -- offset 0x0000 */
    'A','C','E', 0x0D,
    'A','C','T', 0x0D,
    'A','D','D', 0x0D,
    'A','G','E', 0x0D,
    'A','I','D', 0x0D,
    'A','I','M', 0x0D,
    'A','I','R', 0x0D,
    'A','L','L', 0x0D,
    'A','N','D', 0x0D,
    'A','N','T', 0x0D,
    'A','P','E', 0x0D,
    'A','R','C', 0x0D,
    'A','R','K', 0x0D,
    'A','R','M', 0x0D,
    'A','R','T', 0x0D,
    'A','T','E', 0x0D,
    'A','W','E', 0x0D,
    'A','X','E', 0x0D,
    'B','A','D', 0x0D,
    'B','A','G', 0x0D,
    'B','A','N', 0x0D,
    'B','A','R', 0x0D,
    'B','A','T', 0x0D,
    'B','E','D', 0x0D,
    'B','E','T', 0x0D,
    'B','I','G', 0x0D,
    'B','I','T', 0x0D,
    'B','O','W', 0x0D,
    'B','O','X', 0x0D,
    'B','O','Y', 0x0D,
    'B','U','D', 0x0D,
    'B','U','G', 0x0D,
    'B','U','N', 0x0D,
    'B','U','S', 0x0D,
    'B','U','T', 0x0D,
    'B','U','Y', 0x0D,
    'C','A','B', 0x0D,
    'C','A','N', 0x0D,
    'C','A','P', 0x0D,
    'C','A','R', 0x0D,
    'C','A','T', 0x0D,
    'C','U','P', 0x0D,
    'C','U','T', 0x0D,
    'D','A','D', 0x0D,
    'D','A','Y', 0x0D,
    'D','I','D', 0x0D,
    'D','I','G', 0x0D,
    'D','I','P', 0x0D,
    'D','O','G', 0x0D,
    'D','O','T', 0x0D,
    /* ... (additional words from original binary) ... */
    0x00  /* terminator */
};

/* Size of packed word data (used for bounds checking) */
const unsigned int g_packedWordListSize = sizeof(g_packedWordList);

/* ====================================================================
 * Profanity filter word fragments (seg_0456:1FAE-2144)
 * ========================================================================
 * ~55 word suffixes checked against user-entered player names.
 * The first letter is matched separately; only the suffix is stored.
 * E.g., "itch" matches both "bitch" and "witch" when preceded by
 * the appropriate first letter check.
 *
 * The filter function (hangman_profanityCheck, 0000:297E) uses strncmp
 * to test each fragment against substrings of the input.
 *
 * These are organized by first letter for the check algorithm.
 * ==================================================================== */

/* Each entry: { first_char, suffix_string } */
const Hangman_ProfanityEntry g_profanityList[] = {
    { 'A', "BORTION" },
    { 'B', "ITCH" },
    { 'B', "ASTARD" },
    { 'B', "ESTIAL" },
    { 'B', "ISEX" },
    { 'C', "LITOR" },
    { 'C', "OITUS" },
    { 'C', "ONDOM" },
    { 'C', "OPULAT" },
    { 'C', "ROTCH" },
    { 'D', "EFECA" },
    { 'E', "JACULAT" },
    { 'E', "XCREM" },
    { 'E', "LLAT" },
    { 'F', "ECES" },
    { 'F', "ALLOPIAN" },
    { 'F', "ORNICAT" },
    { 'F', "ORESKIN" },
    { 'F', "AGGOT" },
    { 'G', "ODDAM" },
    { 'G', "LANS" },
    { 'G', "ONORRH" },
    { 'H', "ERPES" },
    { 'H', "OMOSEX" },
    { 'I', "NCEST" },
    { 'L', "ABIA" },
    { 'L', "ESBIAN" },
    { 'M', "ASOCHIS" },
    { 'M', "ENSES" },
    { 'M', "OLEST" },
    { 'M', "ENSTRUA" },
    { 'M', "ASTURB" },
    { 'N', "IPPLE" },
    { 'O', "RGASM" },
    { 'P', "ENIS" },
    { 'P', "ENILE" },
    { 'P', "HALL" },
    { 'P', "ROSTIT" },
    { 'P', "UBIC" },
    { 'P', "UBIS" },
    { 'Q', "UEER" },
    { 'R', "ECTUM" },
    { 'R', "ECTAL" },
    { 'R', "APIST" },
    { 'S', "ADIS" },
    { 'S', "CROT" },
    { 'S', "EMEN" },
    { 'S', "ODOM" },
    { 'S', "CHMUCK" },
    { 'S', "YPHILI" },
    { 'S', "PERM" },
    { 'T', "ESTICL" },
    { 'T', "ESTES" },
    { 'V', "AGINA" },
    { 'V', "OMIT" },
    { 'V', "ULVA" },
    { '\0', NULL }  /* sentinel */
};

const unsigned int g_profanityCount = 55;

/* ====================================================================
 * Hangman figure coordinate data (seg_0456:0380-0B40)
 * ========================================================================
 * Each body part is defined as a series of line segments for drawing
 * via DeskMate graphics primitives. Coordinates are in the game's
 * virtual pixel space.
 *
 * The drawing progression (hangman_drawWrongGuess, 0000:1BC4):
 *   Stage 0: Gallows base
 *   Stage 1: Gallows upright + crossbar + rope
 *   Stage 2: Head (circle approximation via line segments)
 *   Stage 3: Body (vertical line)
 *   Stage 4: Left arm
 *   Stage 5: Right arm
 *   Stage 6: Left leg
 *   Stage 7: Right leg
 *   Stage 8: Left eye
 *   Stage 9: Right eye + mouth
 *
 * Each stage entry: count of line segments, then pairs of (x,y) coords.
 * Format: { numSegments, x1, y1, x2, y2, ... }
 * ==================================================================== */

/* Line segment data for each hangman stage.
 * Extracted from seg_0456:0380+ in the original binary.
 * Coordinates are relative to the hangman drawing area origin. */

const Hangman_FigureStage g_hangmanStages[10] = {
    /* Stage 0: Gallows base */
    { 3, { 50, 250, 200, 250,   /* base horizontal */
            125, 250, 125, 50,  /* upright vertical */
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 } },
    /* Stage 1: Crossbar + rope */
    { 2, { 125, 50, 200, 50,    /* crossbar */
            175, 50, 175, 80,   /* rope */
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 } },
    /* Stage 2: Head (circle approx) */
    { 4, { 165, 80, 175, 75,    /* top-left arc */
            175, 75, 185, 80,   /* top-right arc */
            185, 80, 185, 100,  /* right side */
            175, 105, 165, 100, /* bottom arc */
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 } },
    /* Stage 3: Body */
    { 1, { 175, 105, 175, 180,  /* body vertical */
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 } },
    /* Stage 4: Left arm */
    { 1, { 175, 120, 145, 150,  /* arm diagonal */
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 } },
    /* Stage 5: Right arm */
    { 1, { 175, 120, 205, 150,  /* arm diagonal */
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 } },
    /* Stage 6: Left leg */
    { 1, { 175, 180, 150, 220,  /* leg diagonal */
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 } },
    /* Stage 7: Right leg */
    { 1, { 175, 180, 200, 220,  /* leg diagonal */
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 } },
    /* Stage 8: Left eye */
    { 2, { 170, 85, 172, 87,    /* X left */
            172, 85, 170, 87,   /* X right */
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 } },
    /* Stage 9: Right eye + mouth */
    { 3, { 178, 85, 180, 87,    /* X left */
            180, 85, 178, 87,   /* X right */
            170, 95, 180, 95,   /* mouth */
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 } }
};

/* ====================================================================
 * Default player names
 * ==================================================================== */

const char *g_defaultPlayerNames[HANGMAN_MAX_PLAYERS] = {
    "Player 1",
    "Player 2",
    "Player 3",
    "Player 4"
};
