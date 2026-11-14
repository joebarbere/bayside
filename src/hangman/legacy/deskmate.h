/* ========================================================================
 * deskmate.h -- DeskMate INT E0h API abstraction for PDM applications
 * ========================================================================
 * Provides C function wrappers around the DeskMate shell API (INT E0h).
 * All PDM applications communicate with DESK.EXE exclusively through
 * these services. This header covers the subset used by HANGMAN.PDM.
 *
 * Reference: /disassembly/annotated/hangman.asm (wrapper functions)
 *            /research/docs/int-e0h-api-reference.md
 * ========================================================================
 */

#ifndef DESKMATE_H
#define DESKMATE_H

/* ---- Return codes ---------------------------------------------------- */
#define DM_OK           0
#define DM_ERROR        0xFFFF
#define DM_GAME_READY   0xFFFE

/* ---- Event types (from hangman_processInput dispatch) ---------------- */
#define DM_EVENT_IDLE       0
#define DM_EVENT_KEYPRESS   1
#define DM_EVENT_MENU       3
#define DM_EVENT_TIMER      6

/* ---- Message box button return codes --------------------------------- */
#define DM_BTN_NO           0xF702
#define DM_BTN_YES          0xF703
#define DM_BTN_CANCEL       0xF704

/* ---- Menu action IDs (0xF500-0xF50C) -------------------------------- */
#define DM_MENU_EXIT        0xF500
#define DM_MENU_SAVE        0xF501
#define DM_MENU_RESTORE     0xF502
#define DM_MENU_PLAYERS_DEF 0xF508
#define DM_MENU_RUN         0xF50A
#define DM_MENU_ABOUT       0xF50B
#define DM_MENU_PLAYERS_ADD 0xF50C

/* ---- DM API event codes --------------------------------------------- */
#define DM_EVENT_WORD_LIST  0xFD14
#define DM_EVENT_WORD_SRC   0xFD17

/* ---- INT E0h AX service codes --------------------------------------- */
#define DM_SVC_SET_TITLE    0x000B
#define DM_SVC_GET_TITLE    0x000C
#define DM_SVC_WRITE_CONFIG 0x000E
#define DM_SVC_READ_CONFIG  0x000F
#define DM_SVC_DELETE_CONFIG 0x0010
#define DM_SVC_KEY_TO_CHAR  0x0023
#define DM_SVC_RUN_PROGRAM  0x00B4
#define DM_SVC_LOAD_RES     0x0206
#define DM_SVC_UNLOAD_RES   0x0207
#define DM_SVC_EXEC_RES     0x0208
#define DM_SVC_INIT_APP     0x020A
#define DM_SVC_GET_TICK     0x0501
#define DM_SVC_GET_VIDMODE  0x0600
#define DM_SVC_SET_VIDATTR  0x060A
#define DM_SVC_GET_VIDINFO  0x060D
#define DM_SVC_SET_VIDINFO2 0x060E
#define DM_SVC_SHOW_CURSOR  0x2006
#define DM_SVC_HIDE_CURSOR  0x2007
#define DM_SVC_REPLY_EVENT  0x2013
#define DM_SVC_GET_EVENT    0x2014
#define DM_SVC_YIELD        0x2016
#define DM_SVC_SET_TIMER    0x2017
#define DM_SVC_SET_TIMEOUT  0x2018
#define DM_SVC_LOAD_BITMAP  0x201B
#define DM_SVC_DRAW_BITMAP  0x201C
#define DM_SVC_SAVE_BITMAP  0x201E
#define DM_SVC_SET_SCROLL   0x202B
#define DM_SVC_SET_SCROLLP  0x202C
#define DM_SVC_INIT_SCROLL  0x202D
#define DM_SVC_SET_ACTIVE   0x202E
#define DM_SVC_INIT_WINDOW  0x2030
#define DM_SVC_GET_SCRW     0x203F
#define DM_SVC_GET_SCRH     0x2041
#define DM_SVC_DIVIDE       0x2042
#define DM_SVC_MULTIPLY     0x2043
#define DM_SVC_SET_CURPOS   0x2044
#define DM_SVC_SHOW_STATUS  0x2047
#define DM_SVC_DRAW_LINE    0x2049
#define DM_SVC_SET_COLOR    0x204A
#define DM_SVC_SET_TEXTATTR 0x204B
#define DM_SVC_SET_FONT     0x204C
#define DM_SVC_DRAW_CHAR    0x2051
#define DM_SVC_DRAW_STRING  0x2052
#define DM_SVC_DEF_MENU     0x205A
#define DM_SVC_DEF_DIALOG   0x205B
#define DM_SVC_SET_DLGFLD   0x205C
#define DM_SVC_GET_DLGFLD   0x205F
#define DM_SVC_DRAW_AT      0x2060
#define DM_SVC_OPEN_DLG     0x2061
#define DM_SVC_OPEN_DLGEX   0x2062
#define DM_SVC_CLOSE_DLG    0x2063
#define DM_SVC_SET_BORDER   0x206A
#define DM_SVC_SET_BKGND    0x206C
#define DM_SVC_FILL_RECT    0x206E
#define DM_SVC_CURSOR_INIT  0x20D6
#define DM_SVC_CURSOR_CLEAN 0x20D7
#define DM_SVC_SHOW_FORM    0x20E3
#define DM_SVC_GET_FORMRES  0x20E4
#define DM_SVC_MSGBOX       0x20E9
#define DM_SVC_SCROLL_CONT  0x20F7
#define DM_SVC_WAIT_READY   0x20F8
#define DM_SVC_SET_APPTITLE 0x2100
#define DM_SVC_SPELL_OP     0x2102
#define DM_SVC_YIELD_TICK   0x0700

/* ---- Function prototypes -------------------------------------------- */

/* Core API dispatch -- calls INT E0h with AX=svcCode */
unsigned int dm_call(unsigned int svcCode);
unsigned int dm_callParam(unsigned int svcCode, unsigned int param);

/* Window title management */
/* 0000:334B */ unsigned int dm_setTitle(const char *title);
/* 0000:3351 */ unsigned int dm_getTitle(const char *title);

/* Configuration file I/O */
/* 0000:3357 */ unsigned int dm_writeConfig(const char *section, const char *key,
                                            const char *value);
/* 0000:335D */ unsigned int dm_readConfig(const char *section, const char *key,
                                           char *buffer, unsigned int bufSize);
/* 0000:3363 */ unsigned int dm_deleteConfig(const char *section, const char *key);

/* Keyboard */
/* 0000:3369 */ unsigned int dm_keyToChar(unsigned int keyCode);

/* Program execution */
/* 0000:336F */ unsigned int dm_runProgram(const char *progName);

/* Application lifecycle */
/* 0000:3400 */ unsigned int dm_initApp(void);
/* 0000:3406 */ unsigned int dm_getTick(void);

/* Video services */
/* 0000:340C */ unsigned int dm_getVideoMode(void);
/* 0000:3412 */ unsigned int dm_setVideoAttr(unsigned int attr);
/* 0000:3418 */ unsigned int dm_getVideoInfo(void);
/* 0000:341E */ unsigned int dm_setVideoInfo2(unsigned int param);

/* Cursor resource management */
/* 0000:3424 */ unsigned int dm_loadCursor(void);
/* 0000:343D */ unsigned int dm_unloadCursor(void);
/* 0000:344C */ unsigned int dm_initCursor(void);
/* 0000:3453 */ unsigned int dm_cleanupCursor(void);

/* Cursor display */
/* 0000:3482 */ void dm_showCursor(void);
/* 0000:3488 */ void dm_hideCursor(void);

/* Event handling */
/* 0000:348E */ unsigned int dm_replyEvent(unsigned int eventId);
/* 0000:3494 */ unsigned int dm_getEvent(unsigned int *eventBuf);
/* 0000:349A */ void dm_yield(void);

/* Timer */
/* 0000:34A0 */ void dm_setTimer(unsigned int ticks);
/* 0000:34A6 */ void dm_setTimeout(unsigned int ticks);

/* Bitmap operations */
/* 0000:34AC */ unsigned int dm_loadBitmap(unsigned int resId);
/* 0000:34B2 */ void dm_drawBitmap(unsigned int handle, int x, int y);
/* 0000:34B8 */ unsigned int dm_saveBitmap(unsigned int handle);

/* Scrolling */
/* 0000:34BE */ void dm_setScrollArea(int left, int top, int right, int bottom);
/* 0000:34C4 */ void dm_setScrollPos(int x, int y);
/* 0000:34CA */ void dm_initScrollbar(unsigned int param);

/* Window management */
/* 0000:34D0 */ void dm_setActiveWindow(unsigned int handle);
/* 0000:34D6 */ unsigned int dm_initWindow(unsigned int handle);

/* Screen metrics */
/* 0000:34DC */ unsigned int dm_getScreenWidth(unsigned int baseWidth);
/* 0000:34E2 */ unsigned int dm_getScreenHeight(void);

/* Math utilities (used for layout calculations) */
/* 0000:34E8 */ unsigned int dm_divide(unsigned int dividend, unsigned int divisor);
/* 0000:34EE */ unsigned int dm_multiply(unsigned int a, unsigned int b);

/* Cursor position */
/* 0000:34F4 */ void dm_setCursorPos(int x, int y);

/* Status bar */
/* 0000:34FA */ void dm_showStatusBar(void);

/* Drawing primitives */
/* 0000:3500 */ void dm_drawLine(int x1, int y1, int x2, int y2);
/* 0000:3506 */ void dm_setColor(unsigned int fg, unsigned int bg);
/* 0000:350C */ void dm_setTextAttr(unsigned int a, unsigned int b, unsigned int c);
/* 0000:3512 */ void dm_setFont(unsigned int fontId);
/* 0000:3518 */ void dm_drawChar(unsigned int ch);
/* 0000:351E */ void dm_drawString(const char *str);

/* Menu and dialog */
/* 0000:3524 */ void dm_defineMenu(unsigned int p1, unsigned int p2,
                                   unsigned int p3, unsigned int p4,
                                   unsigned int p5);
/* 0000:352A */ void dm_defineDialog(unsigned int param);
/* 0000:3530 */ void dm_setDialogField(unsigned int fieldId, unsigned int value);
/* 0000:3536 */ unsigned int dm_getDialogField(unsigned int fieldId);
/* 0000:353C */ void dm_drawAt(int x, int y, const char *str);
/* 0000:3542 */ unsigned int dm_openDialog(unsigned int param);
/* 0000:3548 */ unsigned int dm_openDialogEx(unsigned int param);
/* 0000:354E */ void dm_closeDialog(void);

/* Window appearance */
/* 0000:3554 */ void dm_setBorder(void);
/* 0000:355A */ void dm_setBackground(void);
/* 0000:3560 */ void dm_fillRect(int x1, int y1, int x2, int y2, unsigned int color);

/* Cursor subsystem */
/* 0000:3566 */ void dm_cursorInit(void);
/* 0000:356C */ void dm_cursorCleanup(void);

/* Form controls */
/* 0000:3572 */ unsigned int dm_showForm(unsigned int formId);
/* 0000:3578 */ unsigned int dm_getFormResult(unsigned int formId);

/* Message box */
/* 0000:357E */ unsigned int dm_msgBox(unsigned int msgParams);

/* Scrolling/display */
/* 0000:3584 */ void dm_scrollContent(unsigned int param);
/* 0000:358A */ void dm_waitReady(void);

/* Application title */
/* 0000:3590 */ void dm_setAppTitle(const char *title);

/* Spell check */
/* 0000:3596 */ unsigned int dm_spellOp(unsigned int op);

/* Resource loading high-level functions */
/* 0000:31F6 */ unsigned int dm_loadAllRes(void);
/* 0000:3260 */ unsigned int dm_loadDmguf(void);
/* 0000:32A2 */ void dm_unloadRes(void);
/* 0000:359C */ unsigned int dm_loadSpell(void);
/* 0000:35B9 */ void dm_unloadSpell(void);
/* 0000:3677 */ void dm_spellCleanup(void);

/* Check for specific DeskMate API event */
/* 0000:1564 */ unsigned int dm_checkApiEvent(unsigned int eventCode);

#endif /* DESKMATE_H */
