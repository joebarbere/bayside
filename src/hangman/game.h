/* Area A (0010-0DD7): lifecycle, board, game loop, input -- C prototypes */
#ifndef GAME_H
#define GAME_H

/* Player record, 0x15 bytes (byte packing, -zp1). g_players[] at ADF0 is
 * part of the save record at ADEE: { int numPlayers; HmPlayer players[4];
 * int wordsPerGame; int maxWrongGuesses; } (see hangman_validateSaveData).
 * The game code passes pointers to the stats part (ADFD + 0x15*i). */
typedef struct {
    unsigned char guesses;      /* +0D guesses in the current word */
    unsigned char wrong;        /* +0E wrong guesses in the current word */
    unsigned char lettersLeft;  /* +0F letters still hidden */
    unsigned char wins;         /* +10 words solved */
    unsigned      played;       /* +11 words finished (won or lost) */
    int           score;        /* +13 sum of (max wrong - wrong) per win */
} HmStats;

typedef struct {
    char    name[13];           /* +00 */
    HmStats st;                 /* +0D */
} HmPlayer;

/* Saved-game record (0x5A bytes); the live copy is at ADEE (g_numPlayers,
 * g_players, g_wordsPerGame, g_maxWrongGuesses). */
typedef struct {
    int      numPlayers;        /* +00 */
    HmPlayer players[4];        /* +02 */
    int      wordsPerGame;      /* +56 */
    int      maxWrongGuesses;   /* +58 */
} HmSave;

/* DeskMate event record as filled by dm_getEvent: 8 bytes on the stack in
 * the original. type 0 = none, 1 = key, 3 = menu/control, 6 = timer. */
typedef struct {
    unsigned char type;         /* +0 */
    unsigned      code;         /* +1 key code or control id */
    unsigned char rest[5];      /* +3 */
} HmEvent;

/* ---- DGROUP globals (game.syms) ---- */
extern unsigned char g_configOpen;
extern unsigned char g_haveSavedGame;
extern char     g_configDesc[];
extern int      g_roundOver;
extern int      g_resumeRound;
extern int      g_wordNumber;
extern int      g_curPlayer;
extern int      g_wordLen;
extern char     g_word[];
extern int      g_gameSaved;
extern int      g_letterBitmaps[];
extern HmPlayer g_players[];

void hangman_main(void);                        /* 0010 */
int  hangman_init(void);                        /* 001F */
void hangman_cleanup(void);                     /* 00BF */
int  hangman_loadConfig(void);                  /* 00F3 */
int  hangman_validateSaveData(HmSave *save);    /* 0181 */
void hangman_setupMenuBar(void);                /* 0229 */
void hangman_drawGameBoard(void);               /* 02D6 */
void hangman_drawPlayerScores(void);            /* 0391 */
void hangman_drawCurrentGame(void);             /* 047C */
void hangman_printNumber(int n);                /* 06E2 */
void hangman_initRoundState(HmStats *st);       /* 071B */
void hangman_gameLoop(void);                    /* 0737 */
int  hangman_playRound(void);                   /* 0795 */
int  hangman_processInput(void);                /* 086A */
int  hangman_mapKeyToLetter(HmEvent *prev, HmEvent *ev);  /* 09A2 */
int  hangman_handleMenuAction(unsigned id);     /* 0A0C */
int  hangman_checkGuess(int letter);            /* 0B79 */
void hangman_updateAfterGuess(int result, int wrong);     /* 0C47 */
void hangman_handleWin(HmStats *st);            /* 0D4B */
void hangman_handleLose(void);                  /* 0D9C */
#endif
