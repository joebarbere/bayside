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

/* ---- DGROUP globals (dgroup.syms) ------------------------------------ */
extern char g_titleDesc[];
extern int  g_spellLoaded;
extern int  g_cursorHandle;
extern int  g_windowHandle;

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

/* ---- MSC runtime (original code) ------------------------------------- */
void _exit(int status);             /* 30FE */

/* ---- Hangman functions still running as original code ---------------- */
int  hangman_checkDmApiEvent(unsigned code);    /* 1564 */
void hangman_initGameState(void);               /* 242A */
void hangman_setupMenuBar(void);                /* 0229 */
int  hangman_loadConfig(void);                  /* 00F3 */
int  hangman_defineGame(void);                  /* 0DD8 */
void hangman_initLetterTiles(void);             /* 11CC */
void hangman_saveLetterTiles(void);             /* 11FA */
void hangman_drawGameBoard(void);               /* 02D6 */
void hangman_drawStartScreen(void);             /* 1AE0 */
void hangman_gameLoop(void);                    /* 0737 */

/* ---- Implemented in C ------------------------------------------------- */
void hangman_main(void);                        /* 0010 */
int  hangman_init(void);                        /* 001F */
void hangman_cleanup(void);                     /* 00BF */

#endif /* HANGMAN_H */
