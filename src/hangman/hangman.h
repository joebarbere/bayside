/* ========================================================================
 * hangman.h -- declarations for the HANGMAN.PDM decompilation
 * ========================================================================
 * Build model: the original binary is re-linked from tools/pdm2wasm.py
 * output with every function at its original address; functions listed in
 * replaced.txt are implemented in C and spliced in. Everything here is
 * __cdecl (wcc -ecc), matching the MSC 5.x calling convention the original
 * code uses, so C and original machine code call each other freely.
 *
 * Original functions not yet in C are declared here and resolve to labels
 * in the generated asm. Names come from functions.txt.
 * ======================================================================== */
#ifndef HANGMAN_H
#define HANGMAN_H

#define HM_ERROR    (-1)
#define HM_READY    (-2)            /* 0xFFFE: init done / dialog OK */
#define HM_EVT_WORD_LIST  0xFD14    /* hangman_checkDmApiEvent query */

/* ---- DGROUP access ---------------------------------------------------
 * DGROUP keeps the original layout, so a near pointer constant is the
 * original variable. Use these for bytes/words not yet given a name in
 * dgroup.syms; the address keeps them greppable against the disassembly. */
#define DG8(off)   (*(unsigned char *)(off))
#define DG16(off)  (*(int *)(off))

/* ---- DGROUP globals (dgroup.syms) ------------------------------------ */
extern char g_titleDesc[];
extern int  g_spellLoaded;
extern int  g_cursorHandle;
extern int  g_windowHandle;
extern char g_defGameDlg[];
extern char g_defGameForm[];
extern char g_wordsPerGameText[];
extern char g_wrongGuessText[];
extern char g_dlgSaveArea[];
extern int  g_numPlayers;
extern int  g_wordsPerGame;
extern int  g_maxWrongGuesses;

/* ---- DeskMate SDK glue (hand-written asm in the original) ------------ */
int  dm_initCursor(void);           /* 344C */
void dm_cleanupCursor(void);        /* 3453 */
int  dm_loadDmguf(void);            /* 3260: -1 on failure */
void dm_unloadRes(void);            /* 32A2 */
int  dm_loadSpell(void);            /* 359C: -1 on failure */
void dm_unloadSpell(void);          /* 35B9 */
void dm_setAppTitle(char *desc);    /* 3590 */
void dm_initApp(void);              /* 3400 */
void dm_setBorder(void);            /* 3554 */
void dm_showStatusBar(void);        /* 34FA */
void dm_showCursor(void);           /* 3482 */
void dm_hideCursor(void);           /* 3488 */
void dm_initWindow(int handle);     /* 34D6 */
void dm_setTimeout(int ticks);      /* 34A6 */
void dm_yield(void);                /* 349A */
/* Dialog services. The first four arguments are the same for open/save/
 * close of one dialog; their meaning (geometry vs. pointers) is not yet
 * decoded, so they are passed through as the original does. */
unsigned dm_openDialog(int a, int b, int c, char *dlg);                 /* 3542 */
void dm_openDialogEx(int a, int b, int c, char *dlg, char *save);       /* 3548 */
void dm_closeDialog(int a, int b, int c, char *dlg, char *save);        /* 354E */
void dm_showForm(char *form);       /* 3572 */
unsigned dm_getFormResult(char *form);  /* 3578: control id, F564..F56F */

/* ---- MSC runtime (original code) ------------------------------------- */
void _exit(int status);             /* 30FE */
int  _atoi(char *s);                /* 3DA8 */

/* ---- Hangman functions still running as original code ---------------- */
int  hangman_checkDmApiEvent(unsigned code);    /* 1564 */
void hangman_initGameState(void);               /* 242A */
void hangman_setupMenuBar(void);                /* 0229 */
int  hangman_loadConfig(void);                  /* 00F3 */
void hangman_initLetterTiles(void);             /* 11CC */
void hangman_saveLetterTiles(void);             /* 11FA */
void hangman_drawGameBoard(void);               /* 02D6 */
void hangman_drawStartScreen(void);             /* 1AE0 */
void hangman_gameLoop(void);                    /* 0737 */
int  hangman_spinnerControl(int dir, char *text, int lo, int hi); /* 10AD */
void hangman_updatePlayerCount(int n);          /* 1945 */
void hangman_refreshBoard(void);                /* 0E18 */
int  hangman_definePlayersDialog(void);         /* 12A2 */
void hangman_newGame(void);                     /* 1417 */

/* ---- Implemented in C ------------------------------------------------- */
void hangman_main(void);                        /* 0010 */
int  hangman_init(void);                        /* 001F */
void hangman_cleanup(void);                     /* 00BF */
int  hangman_defineGame(void);                  /* 0DD8 */
int  hangman_defineGameDialog(void);            /* 0E56 */

#endif /* HANGMAN_H */
