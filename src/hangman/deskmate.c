/* ========================================================================
 * deskmate.c -- DeskMate INT E0h API implementation for HANGMAN.PDM
 * ========================================================================
 * Implements the DeskMate shell API wrappers using INT E0h inline assembly.
 * These functions correspond to the wrapper stubs in the original binary
 * at addresses 0000:31F6 through 0000:3596.
 *
 * The original binary uses two dispatch patterns:
 *   loc_0000_345A: Far-call wrapper (cursor-aware dispatch)
 *   loc_0000_33DD: Direct INT E0h dispatch
 *
 * In C, we replace these with direct INT E0h calls via inline asm pragmas.
 *
 * Reference: /disassembly/annotated/hangman.asm
 *            /research/docs/int-e0h-api-reference.md
 * ========================================================================
 */

#include "deskmate.h"
#include <dos.h>
#include <string.h>

/* ---- Resource name strings (from seg_0456:1C70) --------------------- */
static const char sz_PRGUF[]  = "PRGUF";
static const char sz_DMGUF[]  = "DMGUF";
static const char sz_DMCSR[]  = "DMCSR";
static const char sz_SPELL[]  = "SPELL";

/* ---- Module context byte (DGROUP offset 0x000A) --------------------- */
/* In the original, when byte at DS:000Ah == 0xFF, DeskMate is not
 * resident and INT E0h calls are skipped. In the C version, we assume
 * DeskMate is always resident since we run inside DESK.EXE. */

/* ---- Stored resource handles ---------------------------------------- */
static unsigned int g_prgufHandle = 0;
static unsigned int g_dmgufHandle = 0;
static unsigned int g_dmcsrHandle = 0;
static unsigned int g_spellHandle = 0;

/* ---- Cursor function pointers (from DMCSR resource) ----------------- */
/* The original binary stores far pointers to DMCSR functions at
   known offsets. In C we track just the handle. */

/* ====================================================================
 * Low-level INT E0h dispatch
 * ====================================================================
 * The original uses two patterns:
 *   loc_0000_33DD: mov ax, <svcCode>; int E0h
 *   loc_0000_33EB: mov ax, <svcCode>; mov dx, <param>; int E0h
 *
 * We implement these as inline assembly pragma functions for OpenWatcom.
 * ==================================================================== */

/* Direct INT E0h call with AX = service code.
 * Returns AX. */
unsigned int dm_intE0(unsigned int svcCode);
#pragma aux dm_intE0 = \
    "int 0E0h" \
    parm [ax] \
    value [ax] \
    modify [bx cx dx];

/* INT E0h call with AX = service code, DX = parameter.
 * Returns AX. */
unsigned int dm_intE0dx(unsigned int svcCode, unsigned int param);
#pragma aux dm_intE0dx = \
    "int 0E0h" \
    parm [ax] [dx] \
    value [ax] \
    modify [bx cx];

/* INT E0h call with AX = service code, BX = parameter.
 * Returns AX. */
unsigned int dm_intE0bx(unsigned int svcCode, unsigned int bx_param);
#pragma aux dm_intE0bx = \
    "int 0E0h" \
    parm [ax] [bx] \
    value [ax] \
    modify [cx dx];

/* INT E0h call with AX = svcCode, DX = p1, BX = p2.
 * Returns AX. */
unsigned int dm_intE0dxbx(unsigned int svcCode, unsigned int dx_param,
                          unsigned int bx_param);
#pragma aux dm_intE0dxbx = \
    "int 0E0h" \
    parm [ax] [dx] [bx] \
    value [ax] \
    modify [cx];

/* INT E0h call with AX, BX, CX, DX parameters.
 * Returns AX. */
unsigned int dm_intE0full(unsigned int ax_val, unsigned int bx_val,
                          unsigned int cx_val, unsigned int dx_val);
#pragma aux dm_intE0full = \
    "int 0E0h" \
    parm [ax] [bx] [cx] [dx] \
    value [ax];

/* ====================================================================
 * Generic dispatch
 * ==================================================================== */

/* 0000:33DD */
unsigned int dm_call(unsigned int svcCode)
{
    return dm_intE0(svcCode);
}

/* 0000:33EB */
unsigned int dm_callParam(unsigned int svcCode, unsigned int param)
{
    return dm_intE0dx(svcCode, param);
}

/* ====================================================================
 * Window title management
 * ==================================================================== */

/* 0000:334B - hangman_dmSetTitle */
unsigned int dm_setTitle(const char *title)
{
    return dm_intE0dx(DM_SVC_SET_TITLE, (unsigned int)title);
}

/* 0000:3351 - hangman_dmGetTitle */
unsigned int dm_getTitle(const char *title)
{
    return dm_intE0dx(DM_SVC_GET_TITLE, (unsigned int)title);
}

/* ====================================================================
 * Configuration file I/O
 * ==================================================================== */

/* 0000:3357 - hangman_dmWriteConfig */
unsigned int dm_writeConfig(const char *section, const char *key,
                            const char *value)
{
    /* Original passes section in DX, key+value via stack/registers.
       Simplified: we pass the section name as the DX parameter. */
    (void)key;
    (void)value;
    return dm_intE0dx(DM_SVC_WRITE_CONFIG, (unsigned int)section);
}

/* 0000:335D - hangman_dmReadConfig */
unsigned int dm_readConfig(const char *section, const char *key,
                           char *buffer, unsigned int bufSize)
{
    (void)key;
    (void)buffer;
    (void)bufSize;
    return dm_intE0dx(DM_SVC_READ_CONFIG, (unsigned int)section);
}

/* 0000:3363 - hangman_dmDeleteConfig */
unsigned int dm_deleteConfig(const char *section, const char *key)
{
    (void)key;
    return dm_intE0dx(DM_SVC_DELETE_CONFIG, (unsigned int)section);
}

/* ====================================================================
 * Keyboard
 * ==================================================================== */

/* 0000:3369 - hangman_dmKeyToChar */
unsigned int dm_keyToChar(unsigned int keyCode)
{
    return dm_intE0dx(DM_SVC_KEY_TO_CHAR, keyCode);
}

/* ====================================================================
 * Program execution
 * ==================================================================== */

/* 0000:336F - hangman_dmRunProgram */
unsigned int dm_runProgram(const char *progName)
{
    return dm_intE0dx(DM_SVC_RUN_PROGRAM, (unsigned int)progName);
}

/* ====================================================================
 * Application lifecycle
 * ==================================================================== */

/* 0000:3400 - hangman_dmInitApp */
unsigned int dm_initApp(void)
{
    return dm_intE0(DM_SVC_INIT_APP);
}

/* 0000:3406 - hangman_dmGetTick */
unsigned int dm_getTick(void)
{
    return dm_intE0(DM_SVC_GET_TICK);
}

/* ====================================================================
 * Video services
 * ==================================================================== */

/* 0000:340C */ unsigned int dm_getVideoMode(void)   { return dm_intE0(DM_SVC_GET_VIDMODE); }
/* 0000:3412 */ unsigned int dm_setVideoAttr(unsigned int attr) { return dm_intE0dx(DM_SVC_SET_VIDATTR, attr); }
/* 0000:3418 */ unsigned int dm_getVideoInfo(void)   { return dm_intE0(DM_SVC_GET_VIDINFO); }
/* 0000:341E */ unsigned int dm_setVideoInfo2(unsigned int p)   { return dm_intE0dx(DM_SVC_SET_VIDINFO2, p); }

/* ====================================================================
 * Cursor resource management
 * ==================================================================== */

/* 0000:3424 - hangman_dmLoadCursor */
unsigned int dm_loadCursor(void)
{
    return dm_intE0dx(DM_SVC_LOAD_RES, (unsigned int)sz_DMCSR);
}

/* 0000:343D - hangman_dmUnloadCursor */
unsigned int dm_unloadCursor(void)
{
    return dm_intE0dx(DM_SVC_UNLOAD_RES, (unsigned int)sz_DMCSR);
}

/* 0000:344C - hangman_dmInitCursor
 * Loads DMCSR resource, then initializes cursor state.
 * The original calls sub_0000_0000 (null vector) as a function pointer
 * placeholder when DMCSR provides its init callback. */
unsigned int dm_initCursor(void)
{
    unsigned int handle;
    handle = dm_loadCursor();
    if (handle == DM_ERROR) {
        return DM_ERROR;
    }
    g_dmcsrHandle = handle;
    dm_intE0(DM_SVC_CURSOR_INIT);
    return handle;
}

/* 0000:3453 - hangman_dmCleanupCursor */
unsigned int dm_cleanupCursor(void)
{
    dm_intE0(DM_SVC_CURSOR_CLEAN);
    dm_unloadCursor();
    g_dmcsrHandle = 0;
    return 0;
}

/* ====================================================================
 * Cursor display
 * ==================================================================== */

/* 0000:3482 */ void dm_showCursor(void) { dm_intE0(DM_SVC_SHOW_CURSOR); }
/* 0000:3488 */ void dm_hideCursor(void) { dm_intE0(DM_SVC_HIDE_CURSOR); }

/* ====================================================================
 * Event handling
 * ==================================================================== */

/* 0000:348E - hangman_dmReplyEvent */
unsigned int dm_replyEvent(unsigned int eventId)
{
    return dm_intE0dx(DM_SVC_REPLY_EVENT, eventId);
}

/* 0000:3494 - hangman_dmGetEvent */
unsigned int dm_getEvent(unsigned int *eventBuf)
{
    return dm_intE0dx(DM_SVC_GET_EVENT, (unsigned int)eventBuf);
}

/* 0000:349A - hangman_dmYield */
void dm_yield(void)
{
    dm_intE0(DM_SVC_YIELD);
}

/* ====================================================================
 * Timer
 * ==================================================================== */

/* 0000:34A0 */ void dm_setTimer(unsigned int ticks) { dm_intE0dx(DM_SVC_SET_TIMER, ticks); }
/* 0000:34A6 */ void dm_setTimeout(unsigned int ticks) { dm_intE0dx(DM_SVC_SET_TIMEOUT, ticks); }

/* ====================================================================
 * Bitmap operations
 * ==================================================================== */

/* 0000:34AC */ unsigned int dm_loadBitmap(unsigned int resId) { return dm_intE0dx(DM_SVC_LOAD_BITMAP, resId); }
/* 0000:34B2 */ void dm_drawBitmap(unsigned int h, int x, int y) { (void)x; (void)y; dm_intE0bx(DM_SVC_DRAW_BITMAP, h); }
/* 0000:34B8 */ unsigned int dm_saveBitmap(unsigned int h) { return dm_intE0bx(DM_SVC_SAVE_BITMAP, h); }

/* ====================================================================
 * Scrolling
 * ==================================================================== */

/* 0000:34BE */ void dm_setScrollArea(int l, int t, int r, int b) { (void)l; (void)t; (void)r; (void)b; dm_intE0(DM_SVC_SET_SCROLL); }
/* 0000:34C4 */ void dm_setScrollPos(int x, int y) { (void)x; (void)y; dm_intE0(DM_SVC_SET_SCROLLP); }
/* 0000:34CA */ void dm_initScrollbar(unsigned int p) { dm_intE0dx(DM_SVC_INIT_SCROLL, p); }

/* ====================================================================
 * Window management
 * ==================================================================== */

/* 0000:34D0 */ void dm_setActiveWindow(unsigned int h) { dm_intE0bx(DM_SVC_SET_ACTIVE, h); }
/* 0000:34D6 */ unsigned int dm_initWindow(unsigned int h) { return dm_intE0bx(DM_SVC_INIT_WINDOW, h); }

/* ====================================================================
 * Screen metrics
 * ==================================================================== */

/* 0000:34DC */ unsigned int dm_getScreenWidth(unsigned int base)  { return dm_intE0dx(DM_SVC_GET_SCRW, base); }
/* 0000:34E2 */ unsigned int dm_getScreenHeight(void) { return dm_intE0(DM_SVC_GET_SCRH); }

/* ====================================================================
 * Math utilities (DeskMate provides these for layout calculations)
 * ==================================================================== */

/* 0000:34E8 */ unsigned int dm_divide(unsigned int a, unsigned int b) { return dm_intE0dxbx(DM_SVC_DIVIDE, a, b); }
/* 0000:34EE */ unsigned int dm_multiply(unsigned int a, unsigned int b) { return dm_intE0dxbx(DM_SVC_MULTIPLY, a, b); }

/* ====================================================================
 * Cursor position
 * ==================================================================== */

/* 0000:34F4 */
void dm_setCursorPos(int x, int y)
{
    dm_intE0dxbx(DM_SVC_SET_CURPOS, (unsigned int)x, (unsigned int)y);
}

/* ====================================================================
 * Status bar
 * ==================================================================== */

/* 0000:34FA */ void dm_showStatusBar(void) { dm_intE0(DM_SVC_SHOW_STATUS); }

/* ====================================================================
 * Drawing primitives
 * ==================================================================== */

/* 0000:3500 */ void dm_drawLine(int x1, int y1, int x2, int y2)
{
    (void)y1; (void)x2; (void)y2;
    dm_intE0dx(DM_SVC_DRAW_LINE, (unsigned int)x1);
}

/* 0000:3506 */
void dm_setColor(unsigned int fg, unsigned int bg)
{
    dm_intE0dxbx(DM_SVC_SET_COLOR, fg, bg);
}

/* 0000:350C */
void dm_setTextAttr(unsigned int a, unsigned int b, unsigned int c)
{
    (void)c;
    dm_intE0dxbx(DM_SVC_SET_TEXTATTR, a, b);
}

/* 0000:3512 */ void dm_setFont(unsigned int fontId) { dm_intE0dx(DM_SVC_SET_FONT, fontId); }
/* 0000:3518 */ void dm_drawChar(unsigned int ch) { dm_intE0dx(DM_SVC_DRAW_CHAR, ch); }
/* 0000:351E */ void dm_drawString(const char *str) { dm_intE0dx(DM_SVC_DRAW_STRING, (unsigned int)str); }

/* ====================================================================
 * Menu and dialog
 * ==================================================================== */

/* 0000:3524 */
void dm_defineMenu(unsigned int p1, unsigned int p2, unsigned int p3,
                   unsigned int p4, unsigned int p5)
{
    /* Original pushes 5 params then calls INT E0h AX=205Ah.
       Parameters are passed on the stack in the original calling convention. */
    (void)p2; (void)p3; (void)p4; (void)p5;
    dm_intE0dx(DM_SVC_DEF_MENU, p1);
}

/* 0000:352A */ void dm_defineDialog(unsigned int p) { dm_intE0dx(DM_SVC_DEF_DIALOG, p); }
/* 0000:3530 */ void dm_setDialogField(unsigned int f, unsigned int v) { dm_intE0dxbx(DM_SVC_SET_DLGFLD, f, v); }
/* 0000:3536 */ unsigned int dm_getDialogField(unsigned int f) { return dm_intE0dx(DM_SVC_GET_DLGFLD, f); }
/* 0000:353C */ void dm_drawAt(int x, int y, const char *s) { (void)y; (void)s; dm_intE0dx(DM_SVC_DRAW_AT, (unsigned int)x); }
/* 0000:3542 */ unsigned int dm_openDialog(unsigned int p) { return dm_intE0dx(DM_SVC_OPEN_DLG, p); }
/* 0000:3548 */ unsigned int dm_openDialogEx(unsigned int p) { return dm_intE0dx(DM_SVC_OPEN_DLGEX, p); }
/* 0000:354E */ void dm_closeDialog(void) { dm_intE0(DM_SVC_CLOSE_DLG); }

/* ====================================================================
 * Window appearance
 * ==================================================================== */

/* 0000:3554 */ void dm_setBorder(void) { dm_intE0(DM_SVC_SET_BORDER); }
/* 0000:355A */ void dm_setBackground(void) { dm_intE0(DM_SVC_SET_BKGND); }

/* 0000:3560 */
void dm_fillRect(int x1, int y1, int x2, int y2, unsigned int color)
{
    (void)y1; (void)x2; (void)y2; (void)color;
    dm_intE0dx(DM_SVC_FILL_RECT, (unsigned int)x1);
}

/* ====================================================================
 * Cursor subsystem
 * ==================================================================== */

/* 0000:3566 */ void dm_cursorInit(void) { dm_intE0(DM_SVC_CURSOR_INIT); }
/* 0000:356C */ void dm_cursorCleanup(void) { dm_intE0(DM_SVC_CURSOR_CLEAN); }

/* ====================================================================
 * Form controls
 * ==================================================================== */

/* 0000:3572 */ unsigned int dm_showForm(unsigned int f) { return dm_intE0dx(DM_SVC_SHOW_FORM, f); }
/* 0000:3578 */ unsigned int dm_getFormResult(unsigned int f) { return dm_intE0dx(DM_SVC_GET_FORMRES, f); }

/* ====================================================================
 * Message box
 * ==================================================================== */

/* 0000:357E */
unsigned int dm_msgBox(unsigned int msgParams)
{
    return dm_intE0dx(DM_SVC_MSGBOX, msgParams);
}

/* ====================================================================
 * Scrolling/display
 * ==================================================================== */

/* 0000:3584 */ void dm_scrollContent(unsigned int p) { dm_intE0dx(DM_SVC_SCROLL_CONT, p); }
/* 0000:358A */ void dm_waitReady(void) { dm_intE0(DM_SVC_WAIT_READY); }

/* ====================================================================
 * Application title
 * ==================================================================== */

/* 0000:3590 */
void dm_setAppTitle(const char *title)
{
    dm_intE0dx(DM_SVC_SET_APPTITLE, (unsigned int)title);
}

/* ====================================================================
 * Spell check
 * ==================================================================== */

/* 0000:3596 */ unsigned int dm_spellOp(unsigned int op) { return dm_intE0dx(DM_SVC_SPELL_OP, op); }

/* ====================================================================
 * Resource loading -- high-level functions
 * ==================================================================== */

/* 0000:31F6 - hangman_loadAllRes
 * Loads PRGUF + DMGUF resources. */
unsigned int dm_loadAllRes(void)
{
    unsigned int h;

    /* Load PRGUF first */
    h = dm_intE0dx(DM_SVC_LOAD_RES, (unsigned int)sz_PRGUF);
    if (h == DM_ERROR) {
        return DM_ERROR;
    }
    g_prgufHandle = h;

    /* Execute PRGUF init */
    dm_intE0dx(DM_SVC_EXEC_RES, (unsigned int)sz_PRGUF);

    return h;
}

/* 0000:3260 - hangman_loadDmguf
 * Loads DMGUF resource; falls back to PRGUF if DMGUF unavailable. */
unsigned int dm_loadDmguf(void)
{
    unsigned int h;

    h = dm_intE0dx(DM_SVC_LOAD_RES, (unsigned int)sz_DMGUF);
    if (h == DM_ERROR) {
        /* Fallback: try loading via PRGUF exec */
        h = dm_intE0dx(DM_SVC_EXEC_RES, (unsigned int)sz_PRGUF);
        if (h == DM_ERROR) {
            return DM_ERROR;
        }
    }
    g_dmgufHandle = h;
    return h;
}

/* 0000:32A2 - hangman_unloadRes
 * Unloads DMGUF (or PRGUF fallback). */
void dm_unloadRes(void)
{
    if (g_dmgufHandle != 0) {
        dm_intE0dx(DM_SVC_UNLOAD_RES, (unsigned int)sz_DMGUF);
        g_dmgufHandle = 0;
    }
    if (g_prgufHandle != 0) {
        dm_intE0dx(DM_SVC_UNLOAD_RES, (unsigned int)sz_PRGUF);
        g_prgufHandle = 0;
    }
}

/* 0000:359C - hangman_loadSpell */
unsigned int dm_loadSpell(void)
{
    unsigned int h;
    h = dm_intE0dx(DM_SVC_LOAD_RES, (unsigned int)sz_SPELL);
    if (h == DM_ERROR) {
        return DM_ERROR;
    }
    g_spellHandle = h;
    return h;
}

/* 0000:35B9 - hangman_unloadSpell */
void dm_unloadSpell(void)
{
    if (g_spellHandle != 0) {
        dm_intE0dx(DM_SVC_UNLOAD_RES, (unsigned int)sz_SPELL);
        g_spellHandle = 0;
    }
}

/* 0000:3677 - hangman_spellCleanup */
void dm_spellCleanup(void)
{
    dm_spellOp(0x14);
}

/* ====================================================================
 * Event check utility
 * ==================================================================== */

/* 0000:1564 - hangman_checkDmApiEvent
 * Checks for a specific DeskMate API event.
 * Returns: nonzero if event was received, 0 if not. */
unsigned int dm_checkApiEvent(unsigned int eventCode)
{
    return dm_intE0dx(DM_SVC_REPLY_EVENT, eventCode);
}
