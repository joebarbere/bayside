/* ========================================================================
 * hangman.h -- HANGMAN.PDM main header
 * ========================================================================
 * DeskMate 3.05 Hangman word-guessing game (1-4 players)
 * Compiled with Microsoft C 5.x (1987), Medium Memory Model
 *
 * This is the transpiled C89 version for OpenWatcom.
 * Reference: /disassembly/annotated/hangman.asm
 * ========================================================================
 */

#ifndef HANGMAN_H
#define HANGMAN_H

#include "deskmate.h"

/* ---- Game constants ------------------------------------------------- */
#define HANGMAN_MAX_PLAYERS     4
#define HANGMAN_MAX_NAME_LEN    12
#define HANGMAN_PLAYER_SIZE     21      /* bytes per player record */
#define HANGMAN_MIN_PLAYERS     1
#define HANGMAN_MIN_WORDS       1
#define HANGMAN_MAX_WORDS       10
#define HANGMAN_MIN_WRONG       3
#define HANGMAN_MAX_WRONG       12
#define HANGMAN_NUM_LETTERS     26
#define HANGMAN_WORD_BUF_SIZE   12
#define HANGMAN_CONFIG_BUF_SIZE 90      /* 0x5A bytes */
#define HANGMAN_MAX_GUESSES     21      /* max total guesses per round */
#define HANGMAN_TIMER_TICKS     180     /* 0xB4 = ~10 seconds */
#define HANGMAN_NUM_CATEGORIES  6       /* word difficulty categories 4-9 */
#define HANGMAN_CATEGORY_BASE   4       /* first category index */
#define HANGMAN_WORD_DELIM      0x0D    /* CR = word delimiter in packed data */

/* ---- Return codes --------------------------------------------------- */
#define HANGMAN_READY           0xFFFE  /* game ready to play */
#define HANGMAN_EXIT            0xFFFF  /* exit requested */
#define HANGMAN_ROUND_OK        0       /* round complete */
#define HANGMAN_ROUND_EXIT      (-1)    /* exit during round */
#define HANGMAN_ROUND_RESTART   (-2)    /* restart game */
#define HANGMAN_ROUND_MENU      (-3)    /* menu redraw needed */

/* ---- UI layout constants (pixel coordinates) ------------------------ */
#define HANGMAN_BASE_WIDTH      0x122   /* 290 */
#define HANGMAN_OFFSET_WIDTH    0x158   /* 344 */
#define HANGMAN_ROW_HEIGHT      0xDC    /* 220 pixels per player row */
#define HANGMAN_SCORE_BASE_Y    0x44C   /* 1100 */
#define HANGMAN_BOARD_X         0x294   /* 660 */
#define HANGMAN_BOARD_Y         0x64    /* 100 */
#define HANGMAN_COL_HDR_X       0x370   /* 880 */
#define HANGMAN_COL_HDR_Y       0xC8    /* 200 */
#define HANGMAN_WORDS_COL_X     0x7D0   /* 2000 */
#define HANGMAN_SCORE_COL_X     0xD48   /* 3400 */
#define HANGMAN_TITLE_X         0x960   /* 2400 */
#define HANGMAN_TITLE_Y         0x24    /* 36 */
#define HANGMAN_GAME_AREA_X     0x4B0   /* 1200 */
#define HANGMAN_GAME_AREA_W     0x9C4   /* 2500 */

/* ---- Player data structure (21 bytes, matching original layout) ----- */
/* DGROUP offset: g_playerData = 0xADF0 */
#pragma pack(push, 1)
typedef struct {
    unsigned char numGuesses;           /* +0x00: total guesses this round */
    unsigned char numWrongGuesses;      /* +0x01: wrong guesses this round */
    unsigned char lettersRemaining;     /* +0x02: letters still hidden */
    unsigned char wordsGuessedCorrect;  /* +0x03: words guessed correctly */
    unsigned int  wordsPlayed;          /* +0x04: words played this game */
    unsigned int  score;                /* +0x06: total score */
    char          playerName[13];       /* +0x08: null-terminated, max 12 chars */
    unsigned char currentGuessCount;    /* +0x0D: display field */
    unsigned char currentWrongCount;    /* +0x0E: display field */
    unsigned char pad0F;                /* +0x0F: padding */
    unsigned char wordsGuessedDisplay;  /* +0x10: display field */
    unsigned char pad11;                /* +0x11: padding */
    unsigned char pad12;                /* +0x12: padding */
    unsigned int  scoreDisplay;         /* +0x13: display field */
} Hangman_PlayerData;
#pragma pack(pop)

/* ---- Save data structure (for HANGMAN.CFG) -------------------------- */
/* First word is numPlayers, then player data array, then settings */
#pragma pack(push, 1)
typedef struct {
    unsigned int numPlayers;                        /* +0x00 */
    Hangman_PlayerData players[HANGMAN_MAX_PLAYERS]; /* +0x02 */
    unsigned int wordsPerGame;                      /* +0x56 */
    unsigned int maxWrongGuesses;                   /* +0x58 */
} Hangman_SaveData;
#pragma pack(pop)

/* ---- Hangman figure drawing data ------------------------------------ */
typedef struct {
    unsigned int numSegments;
    int coords[40];  /* pairs of (x1,y1,x2,y2) -- max 10 segments */
} Hangman_FigureStage;

/* ---- Profanity filter entry ----------------------------------------- */
typedef struct {
    char firstChar;
    const char *suffix;
} Hangman_ProfanityEntry;

/* ---- Global game state variables ------------------------------------ */
/* These map to DGROUP offsets documented in the annotated disassembly. */

extern unsigned char  g_hasSavedGame;       /* 0x004E */
extern unsigned char  g_savedGameValid;     /* 0x0059 */
extern unsigned char  g_timerActive;        /* 0x00C4 */
extern unsigned char  g_letterGuessed[HANGMAN_NUM_LETTERS]; /* 0x00DA area */
extern unsigned int   g_currentWordIndex;   /* 0xAB8C */
extern unsigned int   g_currentPlayer;      /* 0xAB8E */
extern unsigned int   g_currentWordLen;     /* 0xAB90 */
extern char           g_wordBuffer[HANGMAN_WORD_BUF_SIZE]; /* 0xAB92 */
extern unsigned int   g_cursorHandle;       /* 0xAB9E */
extern unsigned int   g_wordXOffset;        /* 0xABA0 */
extern unsigned int   g_windowHandle;       /* 0xABA2 */
extern unsigned int   g_gameStateFlags;     /* 0xABA4 */
extern unsigned int   g_scoreAccumulator;   /* 0xABA6 */
extern char           g_configBuffer[HANGMAN_CONFIG_BUF_SIZE]; /* 0xABA8 */
extern unsigned int   g_letterBitmapPtrs[HANGMAN_NUM_LETTERS]; /* 0xADBA */
extern unsigned int   g_numPlayers;         /* 0xADEE */
extern Hangman_PlayerData g_playerData[HANGMAN_MAX_PLAYERS]; /* 0xADF0 */
extern unsigned int   g_wordsPerGame;       /* 0xAE44 */
extern unsigned int   g_maxWrongGuesses;    /* 0xAE46 */
extern unsigned int   g_aboutLinesPtrs[15]; /* 0xAE48 */
extern unsigned int   g_boardYOffset;       /* 0xAE68 */
extern unsigned int   g_spellAvailable;     /* 0x0F08 */
extern unsigned int   g_eventPending;       /* 0x0F0A */
extern unsigned int   g_roundActive;        /* 0x0EE8 */
extern unsigned int   g_scoreVisible;       /* 0x0EEA */

/* ---- Function prototypes: hangman.c (main game logic) --------------- */

/* 0000:0010 */ int  hangman_main(void);
/* 0000:001F */ unsigned int hangman_init(void);
/* 0000:00BF */ void hangman_cleanup(void);
/* 0000:00F3 */ unsigned int hangman_loadConfig(void);
/* 0000:0181 */ int  hangman_validateSaveData(Hangman_SaveData *data);
/* 0000:0229 */ void hangman_setupMenuBar(void);
/* 0000:0737 */ void hangman_gameLoop(void);
/* 0000:0795 */ int  hangman_playRound(void);
/* 0000:086A */ int  hangman_processInput(void);
/* 0000:09A2 */ int  hangman_mapKeyToLetter(unsigned int keyCode);
/* 0000:0A0C */ int  hangman_handleMenuAction(unsigned int menuId);
/* 0000:0B79 */ int  hangman_checkGuess(unsigned int letterIndex);
/* 0000:0C47 */ void hangman_updateAfterGuess(void);
/* 0000:0D4B */ void hangman_handleWin(void);
/* 0000:0D9C */ void hangman_handleLose(void);
/* 0000:0DD8 */ unsigned int hangman_defineGame(void);
/* 0000:0DF0 */ void hangman_resetDisplay(void);
/* 0000:0E18 */ void hangman_refreshBoard(void);
/* 0000:071B */ void hangman_initRoundState(unsigned char *roundState);
/* 0000:06E2 */ void hangman_printNumber(int number);
/* 0000:14FC */ unsigned int hangman_getTimerTick(void);
/* 0000:1500 */ void hangman_showAlreadyGuessed(unsigned int letterIndex);
/* 0000:152F */ unsigned int hangman_chooseWord(void);
/* 0000:1417 */ void hangman_newGame(void);
/* 0000:1449 */ void hangman_resetPlayerData(Hangman_PlayerData *player);
/* 0000:1945 */ void hangman_updatePlayerCount(unsigned int newCount);
/* 0000:1976 */ unsigned int hangman_saveGame(void);
/* 0000:19DA */ unsigned int hangman_restoreGame(void);
/* 0000:1A4B */ void hangman_restoreFromBuffer(void);
/* 0000:1A93 */ unsigned int hangman_promptSaveOnExit(void);
/* 0000:23EB */ unsigned int hangman_readWordFromRes(char *buffer);
/* 0000:242A */ void hangman_initGameState(void);
/* 0000:246C */ int  hangman_playWord(char *wordBuf, unsigned int wordLen);
/* 0000:239A */ void hangman_handleTimerEvent(void);
/* 0000:28C2 */ unsigned int hangman_getWordFlags(void);
/* 0000:2905 */ void hangman_setWordFlags(void);
/* 0000:297E */ int  hangman_profanityCheck(const char *word);

/* ---- Function prototypes: hangman_ui.c (drawing/animation) ---------- */

/* 0000:02D6 */ void hangman_drawGameBoard(void);
/* 0000:0391 */ void hangman_drawPlayerScores(void);
/* 0000:047C */ void hangman_drawCurrentGame(void);
/* 0000:115C */ void hangman_drawInitialBoard(void);
/* 0000:116D */ void hangman_drawLetterTiles(void);
/* 0000:1198 */ void hangman_drawWordBlanks(void);
/* 0000:11C2 */ void hangman_redrawAfterDefine(void);
/* 0000:11CC */ void hangman_initLetterTiles(void);
/* 0000:11FA */ void hangman_saveLetterTiles(void);
/* 0000:122B */ void hangman_adjustWordLayout(void);
/* 0000:127F */ void hangman_resetGuessedFlags(void);
/* 0000:1463 */ void hangman_layoutWordTiles(void);
/* 0000:14D3 */ void hangman_clearRevealFlags(void);
/* 0000:1AE0 */ void hangman_drawStartScreen(void);
/* 0000:1AFB */ void hangman_drawHangmanFigure(void);
/* 0000:1B15 */ void hangman_drawHangmanParts(unsigned int parts);
/* 0000:1BC4 */ void hangman_drawWrongGuess(unsigned int wrongNum);
/* 0000:1C30 */ void hangman_drawCelebration(void);
/* 0000:1C9B */ void hangman_drawGallowsPart(unsigned int partId);
/* 0000:1CCC */ void hangman_drawSmileyFace(void);
/* 0000:1D7F */ void hangman_showResultMessage(const char *line1,
                                               const char *line2);
/* 0000:1E3C */ void hangman_drawPressAnyKey(void);
/* 0000:1E62 */ void hangman_drawDeathAnim(void);
/* 0000:1EAE */ void hangman_drawProfanityList(void);
/* 0000:222F */ void hangman_delayLoop(unsigned int duration);
/* 0000:22D7 */ void hangman_drawHangmanStage(unsigned int stage);
/* 0000:2558 */ void hangman_wordAnimEnter(void);
/* 0000:2591 */ void hangman_wordAnimExit(void);
/* 0000:260F */ void hangman_showLetterAnim(unsigned int letterIndex);
/* 0000:2698 */ void hangman_animFrame(void);
/* 0000:26CB */ void hangman_animFlash(void);
/* 0000:2702 */ void hangman_animSequence(void);
/* 0000:2778 */ void hangman_drawWordStatus(void);
/* 0000:27A3 */ void hangman_showWaitMessage(void);
/* 0000:2864 */ void hangman_drawScoreUpdate(void);
/* 0000:294E */ void hangman_animCleanup(void);

/* ---- Function prototypes: hangman_dialog.c (dialog handlers) -------- */

/* 0000:0E56 */ unsigned int hangman_defineGameDialog(void);
/* 0000:10AD */ void hangman_spinnerControl(unsigned int direction);
/* 0000:12A2 */ unsigned int hangman_definePlayersDialog(void);
/* 0000:159D */ unsigned int hangman_runDialog(void);
/* 0000:1612 */ unsigned int hangman_addPlayerDialog(void);
/* 0000:1709 */ unsigned int hangman_deletePlayerDialog(void);
/* 0000:185E */ unsigned int hangman_aboutDialog(void);
/* 0000:18D3 */ void hangman_aboutBuildInfo(void);
/* 0000:18F8 */ unsigned int hangman_aboutGetVersion(void);

#endif /* HANGMAN_H */
