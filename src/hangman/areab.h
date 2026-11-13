/* ========================================================================
 * areab.h -- private declarations for area B (0DD8-1AFA): dialogs,
 * players, tiles, save/restore. Included only by area-B C files.
 * ========================================================================
 * Shared game state that other areas also use is reached through the
 * macros below (DG8/DG16 on the original offset) rather than dgroup.syms
 * names, so area B does not claim names for variables owned elsewhere.
 * ======================================================================== */
#ifndef AREAB_H
#define AREAB_H

#include "hangman.h"

/* ---- Shared game state (original DGROUP offsets) --------------------- */
#define CUR_PLAYER      DG16(0xAB8E)    /* index of the player whose turn it is */
#define WORD_NUMBER     DG16(0xAB8C)    /* 1-based word within the game */
#define WORD_LEN        DG16(0xAB90)    /* letters in the current word */
#define WORD_TEXT       ((char *)0xAB92) /* the current word (letter indices) */
#define WORD_OFS_X      DG16(0xABA0)    /* x offset added to the word tiles */
#define WORD_OFS_Y      DG16(0xAE68)    /* y offset added to the word tiles */
#define GAME_SAVED      DG16(0xABA4)    /* 1 once the game was saved */
#define SAVE_EXISTS     DG8(0x0059)     /* 1: a saved game exists in the config */
#define HANGMAN_SHOWN   DG16(0x0EE8)    /* nonzero: board shows the figure screen */
#define ROUND_OVER      DG16(0x0EEA)    /* cleared by Define Game OK */
#define LETTER_GLYPHS   ((int *)0x0890) /* glyph bitmap per letter index */
#define MENU_ADD_ENABLE DG8(0x0090)     /* Add Player menu item enabled */
#define MENU_DEL_ENABLE DG8(0x009B)     /* Delete Player menu item enabled */
#define DLG_FOCUS       DG16(0x0BA0)    /* dialog focus / layout word (set per dialog) */
#define DLG_OK_STATE    DG8(0x0C76)     /* OK button state byte (cleared on OK) */
#define DLG_CANCEL_STATE DG8(0x0C8A)    /* Cancel button state byte */
#define DLG_OK_Y        DG16(0x0C6B)    /* OK button position (moved by Add Player) */
#define DLG_CANCEL_Y    DG16(0x0C7F)    /* Cancel button position */
#define API_EVENT_SEEN  DG16(0x0F0A)    /* set when checkDmApiEvent consumed one */

#define MAX_PLAYERS     4
#define NUM_LETTERS     26
#define NAME_SIZE       13

#endif /* AREAB_H */
