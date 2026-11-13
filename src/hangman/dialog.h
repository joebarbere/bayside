/* Area B (0DD8-1AFA): dialogs, players, tiles, save/restore -- C prototypes */
#ifndef DIALOG_H
#define DIALOG_H

/* ---- Records (-zp1: byte packed, as the original) -------------------- */
/* Letter buttons at 00CA, 0x14 bytes each; the first part is the bitmap
 * descriptor passed to dm_loadBitmap / dm_drawBitmap. */
struct HmLetterTile {
    char          desc[0x10];
    unsigned char guessed;      /* +10 */
    char          rest[3];
};

/* Word tiles at 02D2, 0x17 bytes each (descriptor for dm_drawBitmap). */
struct HmWordTile {
    char          hdr[2];
    unsigned char shown;        /* +02 */
    int           x;            /* +03 */
    int           y;            /* +05 */
    char          pad07[9];
    unsigned char revealed;     /* +10 */
    char          pad11[4];
    int           glyph;        /* +15 */
};

/* struct HmPlayer, struct HmEvent: see game.h (included first by hangman.h) */

/* ---- DGROUP globals (dialog.syms); record layouts above ---------- */
extern struct HmLetterTile g_letterTiles[];
extern struct HmWordTile   g_wordTiles[];
extern char g_playersForm[];
extern char g_addPlayerForm[];
extern char g_delPlayerForm[];
extern char g_saveBuffer[];

/* dialog.c */
int  hangman_defineGame(void);                  /* 0DD8 */
int  hangman_defineGameDialog(void);            /* 0E56 */
int  hangman_spinnerControl(int dir, char *text, int min, int max); /* 10AD */
int  hangman_definePlayersDialog(void);         /* 12A2 */
int  hangman_runDialog(void);                   /* 159D */
int  hangman_addPlayerDialog(void);             /* 1612 */
int  hangman_deletePlayerDialog(void);          /* 1709 */
void hangman_updatePlayerCount(int count);      /* 1945 */
int  hangman_promptSaveOnExit(void);            /* 1A93 */

/* board.c */
void hangman_resetDisplay(void);                /* 0DF0 */
void hangman_refreshBoard(void);                /* 0E18 */
void hangman_drawInitialBoard(void);            /* 115C */
void hangman_drawLetterTiles(void);             /* 116D */
void hangman_drawWordBlanks(void);              /* 1198 */
void hangman_redrawAfterDefine(void);           /* 11C2 */
void hangman_initLetterTiles(void);             /* 11CC */
void hangman_saveLetterTiles(void);             /* 11FA */
void hangman_adjustWordLayout(void);            /* 122B */
void hangman_resetGuessedFlags(void);           /* 127F */
void hangman_layoutWordTiles(void);             /* 1463 */
void hangman_clearRevealFlags(void);            /* 14D3 */
void hangman_drawStartScreen(void);             /* 1AE0 */

/* players.c */
void hangman_newGame(void);                     /* 1417 */
void hangman_resetPlayerData(unsigned char *score);      /* 1449 */
int  hangman_aboutDialog(int index);            /* 185E: really "remove player" */
void hangman_aboutBuildInfo(struct HmPlayer *src, struct HmPlayer *dst); /* 18D3 */
void hangman_aboutGetVersion(unsigned char *src, unsigned char *dst); /* 18F8 */

/* save.c */
int  hangman_getTimerTick(void);                /* 14FC */
int  hangman_showAlreadyGuessed(int letter);    /* 1500 */
int  hangman_chooseWord(void);                  /* 152F */
int  hangman_checkDmApiEvent(int code);         /* 1564 */
int  hangman_saveGame(void);                    /* 1976 */
int  hangman_restoreGame(void);                 /* 19DA */
int  hangman_restoreFromBuffer(void);           /* 1A4B */
#endif
