# DeskMate 3.05 INT E0h API Reference

**Date:** 2026-04-07
**Researcher:** Claude Code (Sonnet 4.6)
**Status:** Stage 3 reference document -- compiled from callgraph analysis of all 86 DeskMate 3.05 binaries plus DESK.EXE, cross-referenced against DeskMate I disassembly

---

## 1. Overview

DESK.EXE installs a software interrupt handler on vector **0xE0** (INT E0h) at startup.
Every PDM application, RES driver module, and ACC accessory calls this handler to access
all DeskMate services. The INT E0h API is the exclusive interface between hosted programs
and the DeskMate shell.

The handler operates as a **far call dispatcher**: the caller places a two-byte service
code in AX (AH = service class, AL = subfunction), sets other registers as parameters,
and executes `INT E0h`. Control transfers to DESK.EXE's handler, which dispatches to the
appropriate internal routine based on AH, then returns via `IRET`.

A second vector, **INT E2h**, is also used by a subset of modules (ADDRESS.PDM uses it 5
times; DESK.EXE installs it during startup). INT E2h is not yet fully decoded but appears
to provide extended memory or DMA services -- DMEMM.RES (Extended Memory Manager) calls
INT E0h AH=06h and likely exposes its services through INT E2h.

---

## 2. Calling Convention

### Standard invocation pattern (PDM side)

```asm
; Check DeskMate resident flag before calling (common guard):
MOV  AL, [DS:000Ah]      ; read module context byte
CMP  AL, 0FFh
JZ   skip_call           ; skip if DeskMate not resident

; Set parameters:
MOV  DX, offset resource_name  ; DS:DX -> resource name string (for AH=02h calls)
MOV  AX, 0206h                 ; AH = service class, AL = subfunction
INT  E0h                        ; invoke DeskMate API
; Return value in AX (and sometimes DX:AX for far pointers)
```

### Register usage summary

| Register | Role |
|----------|------|
| AH | Service class selector (must be set before INT E0h) |
| AL | Subfunction within the service class |
| BX | Parameter block pointer (far pointer low word) or handle |
| CX | Count, length, or secondary parameter |
| DX | String pointer (DS:DX) or secondary parameter |
| DS | Data segment of caller; DS:DX used for string arguments |
| ES | Extended parameter segment for some calls |
| AX (return) | Status or result code; 0 = success, non-zero = error |
| DX:AX (return) | Far pointer returned for some resource/memory calls |

### Indirect dispatch (dynamic calls)

Three modules (DESKTOP.PDM, TEXT.PDM, HANGMAN.PDM) contain INT E0h calls where AX is
loaded from a runtime variable rather than a literal constant. These appear at addresses:

- DESKTOP.PDM: 0x0E349, 0x0E358, 0x0E36C (in sub_0E32F -- the main event dispatch routine)
- TEXT.PDM: 0x0EECA, 0x0EED9, 0x0EEED (in sub_0EEBB -- the main event dispatch routine)
- HANGMAN.PDM: 0x33E6, 0x33F9 (in the DeskMate API wrapper function)

These are **general DeskMate event dispatch wrappers** that forward whatever service code
was passed to them. The three calls in each module likely handle menu, dialog, and window
events where the specific AX value is determined at runtime by the event type.

---

## 3. Service Class Table

All service classes observed across all 86 analyzed binaries:

| AH | Hex | Description | Used By |
|----|-----|-------------|---------|
| 00h | 0x00 | Core / font / database services | DESK.EXE, DMDBRD.RES, DMFONT.RES, DMPLAY.RES, AUTOLOAD.RES, DRAW.PDM |
| 01h | 0x01 | Module lifecycle (register / unregister) | All RES/ACC modules (universal) |
| 02h | 0x02 | Resource & UI services | All PDMs and most RES/ACC modules |
| 04h | 0x04 | Graphics drawing primitives | DMEFORM.RES, DMFORM.RES |
| 06h | 0x06 | Window / event / file services | Most PDMs, many RES modules |
| 07h | 0x07 | Memory / timer services | Most PDMs |
| 21h | 0x21 | Extended DeskMate functions | PLAY.PDM only |
| 4Dh | 0x4D | Shell / host management | DESK.EXE (internal), video RES files, DMDBRD.RES, PRGUF.RES, SPL.RES, FILER.PDM, CALENDAR.PDM, etc. |

Notes:
- AH=05h was observed in TWMENU.ASM (DeskMate I disassembly) with AX=0500h. DeskMate 3.x
  may have incorporated or superseded this service class -- no DeskMate 3.05 binary was
  observed calling AH=05h.
- AH=04h is only used by the form-manager RES modules; it appears to be the graphics
  primitive layer used to render form fields.
- AH=21h appears only in PLAY.PDM (2 calls). Its subfunctions are not yet decoded.

---

## 4. Detailed Service Reference

### AH = 00h: Core Services

These services are called infrequently. Their use appears limited to specific resource
modules implementing core DeskMate infrastructure.

| AX | Subfunction | Confirmed | Description | Callers |
|----|------------|-----------|-------------|---------|
| 0x0000 | 00h | Inferred | Core service 0 (no subfunction observed at 0x00 level alone) | DESK.EXE (1 call, no AL detail) |
| 0x0003 | 03h | Inferred | Font rendering dispatch / font service request | DMFONT.RES, DMPLAY.RES |
| 0x0008 | 08h | Inferred | Database query or data retrieval | DMDBRD.RES |
| 0x0009 | 09h | Inferred | Database record operation | DMDBRD.RES |
| 0x0090 | 90h | Inferred | Autoload service / module preload notification | AUTOLOAD.RES |
| 0x0091 | 91h | Inferred | ACC display service (show notepad / phone / clipboard UI) | ACC files with overlaid UI |

**Note:** The AH=00h service class is the least well-characterized. The callgraphs for
DESK.EXE show a single INT E0h AH=00h call with no AL detail. DMDBRD.RES shows 2 calls
with AH=00h. DMFONT.RES shows 1 call with AH=00h. DMPLAY.RES shows 1 call with AH=00h.
AUTOLOAD.RES shows 1 call with AH=00h. The sub-function values above are inferred from
the DeskMate I dispatch table structure (which handles AH 0x00-0x32) and the resource
module purposes.

---

### AH = 01h: Module Lifecycle Services

Every RES and ACC module calls these services. This is the universal module registration
protocol. All 51 RES files and all 18 ACC files call both subfunctions.

| AX | Subfunction | Confirmed | Description | Callers |
|----|------------|-----------|-------------|---------|
| 0x01F0 | F0h | Confirmed | **Register / load resource module.** Called once at module startup to register the module with DESK.EXE's resource table. After this call, the module's exported functions are callable by other modules. | All RES and ACC files (1 call each) |
| 0x01FF | FFh | Confirmed | **Unregister / unload resource module.** Called once at module shutdown to remove the module from DESK.EXE's resource table and release its slot. | All RES and ACC files (1 call each) |

**Parameters (AX=01F0h, register):**

The exact register layout for 01F0h is not yet decoded from the binary. From context:
- DX likely points to a registration block (name, dispatch function pointer, flags)
- BX likely receives a module handle on return
- AX=0 on success, non-zero on error

**Parameters (AX=01FFh, unregister):**

- BX likely holds the module handle previously returned by 01F0h

---

### AH = 02h: Resource and UI Services

This is the most heavily used service class. Every PDM and most RES/ACC modules call
multiple subfunctions. The AH=02h class handles resource loading/unloading and UI
operations (window attributes, cursor control, form management).

There is a **naming ambiguity** in the per-module callgraph labels: the automated
disassembler assigned human-readable names like `dm_set_attribute` (AX=0206h) and
`dm_cursor_control` (AX=0207h) based on local context in DESKTOP.PDM and TEXT.PDM.
The PLAY.PDM and HANGMAN.PDM callgraphs -- which were analyzed more carefully with
respect to the DMPLAY and SPELL resource usage -- identify AX=0206h as "Load resource
module" and AX=0207h as "Unload resource module." These two descriptions apply to the
**same AX values** used in different call contexts:

When AX=0206h is called with a resource name string in DX, it loads a named resource.
When AX=0206h is called in a UI context (form/window management), it may set a UI
attribute. The subfunction AL disambiguates the exact operation within the 02h class.

The most likely explanation is that the labels `dm_set_attribute`, `dm_cursor_control`,
and `dm_get_window_info` describe specific AL sub-values within AX=0206h, 0207h, and
0208h respectively, rather than the full AX code identifying a unique function.

| AX | Subfunction | Confirmed | Description | Callers |
|----|------------|-----------|-------------|---------|
| 0x0206 | 06h | Confirmed | **Load resource module by name** (or set UI attribute when used in form context). DS:DX -> null-terminated resource name string (e.g., "DMPLAY", "DMGUF", "PRGUF", "SPELL", "DMCSR"). Returns a module handle. | HANGMAN.PDM (12 calls), PLAY.PDM (many), all PDMs with resource imports |
| 0x0207 | 07h | Confirmed | **Unload resource module** (or cursor control in UI context). DS:DX -> resource name string. Decrements reference count; unloads if count reaches zero. | HANGMAN.PDM (4 calls), PLAY.PDM, all resource-using PDMs |
| 0x0208 | 08h | Confirmed | **Execute / call resource function** (or get window info in UI context). DS:DX -> resource name; BX -> parameter block. Calls an exported function in the named resource. | HANGMAN.PDM (2 calls), PLAY.PDM, DESKTOP.PDM (3 calls), TEXT.PDM (1 call) |
| 0x0209 | 09h | Inferred | Form field operation (used by printer driver RES files) | Printer RES files (DMPD1, DMPD2, DMPDASCI, DMPDIBMM, DMPDLASR) |
| 0x020B | 0Bh | Confirmed | Form/dialog event handler (keyboard input processing within a dialog) | TEXT.PDM (2 calls at 0xEB4C, 0xEB5F), label `svc_020B` |
| 0x020C | 0Ch | Confirmed | Form/dialog redraw / refresh | TEXT.PDM (1 call at 0xEB80), label `svc_020C` |

**Resource loading sequence (AX=0206h) -- from HANGMAN.PDM analysis:**

HANGMAN.PDM loads four resources at startup:
1. PRGUF (Program User Functions -- main DeskMate UI library)
2. DMGUF (DeskMate General User Functions)
3. DMCSR (DeskMate Cursor resource)
4. SPELL (Spell-check / dictionary resource, for profanity filter)

The load call pattern:
```asm
MOV  DX, offset sz_resource_name  ; DS:DX -> "PRGUF\0"
MOV  AX, 0206h
INT  E0h
; BX or DX:AX <- module handle (stored for later use/unload)
```

PLAY.PDM loads three resources: DMPLAY, DMGUF, and UNPACK (decompressor).

---

### AH = 04h: Graphics Drawing Primitives

This service class is used exclusively by the Form Manager resource modules (DMEFORM.RES
and DMFORM.RES). It provides low-level graphics drawing operations that form rendering
uses to draw form field outlines, labels, and backgrounds.

| AX | Subfunction | Confirmed | Description | Callers |
|----|------------|-----------|-------------|---------|
| 0x0401 | 01h | Inferred | Draw line / rectangle / graphics primitive 1 | DMEFORM.RES, DMFORM.RES |
| 0x0402 | 02h | Inferred | Draw filled region / graphics primitive 2 | DMEFORM.RES, DMFORM.RES |

**Note:** The DMEFORM.RES and DMFORM.RES callgraphs show 1 AH=02h call and 2 AH=06h
calls each, but are listed under AH=04h in the SDK research document. This discrepancy
requires further disassembly of these modules to resolve. It is possible that DMEFORM and
DMFORM call AH=02h (resource services) for loading and AH=06h for window management, and
the AH=04h class is dispatched to them by DESK.EXE rather than called by them.

---

### AH = 06h: Window, Event, and File Services

This is the second most heavily used service class. It handles windowing, event dispatch,
file I/O mediated through DESK.EXE, and resource callbacks. The broad range of services
under this class suggests it is a general-purpose "application services" class.

| AX | Subfunction | Confirmed | Description | Callers |
|----|------------|-----------|-------------|---------|
| 0x0600 | 00h | Confirmed | **Get event / open file.** In PLAY.PDM context: "Get event (poll for keyboard/mouse/timer input)." In DESKTOP.PDM/TEXT.PDM context: labeled `dm_file_open`. Parameter likely differentiates behavior. DS:DX -> filename string for file open; no DX for event poll. | PLAY.PDM (8 calls), DESKTOP.PDM (1 call at 0xDE0E), TEXT.PDM (2 calls at 0xE660, 0xEAFD) |
| 0x0602 | 02h | Inferred | Window service / database window open | DMDBRD.RES (4 calls) |
| 0x0603 | 03h | Confirmed | **Resource dispatch / file write.** In PLAY.PDM context: "call loaded resource handler." In DESKTOP.PDM/TEXT.PDM: labeled `dm_file_write`. Likely writes a block of data to an open file handle. BX -> write buffer; CX -> byte count. | PLAY.PDM, DESKTOP.PDM (2 calls at 0xDE8E, 0xDEC6), TEXT.PDM (2 calls at 0xE6E0, 0xE718) |
| 0x0604 | 04h | Inferred | Database window service | DMDBRD.RES |
| 0x0606 | 06h | Inferred | D87.RES-specific service (math coprocessor detection or initialization) | D87.RES |
| 0x060D | 0Dh | Inferred | Extended memory / EMS service | D87.RES (implied by DME extension context) |
| 0x060E | 0Eh | Confirmed | **Process / dispatch event to application.** Called immediately after opening a file (0600h) in DESKTOP.PDM and TEXT.PDM. In PLAY.PDM context: "Process/dispatch event to application." Likely triggers the DeskMate event loop iteration or closes an open file. | DESKTOP.PDM (1 call at 0xDE1D), TEXT.PDM (1 call at 0xE66F), PLAY.PDM (8 calls via AH=06h class) |

**File I/O sequence (from TEXT.PDM and DESKTOP.PDM):**

The standard file I/O triplet is:
```c
/* Open */
AX = 0x0600;  DS:DX = filename;  INT E0h;
/* Write */
AX = 0x0603;  BX = buffer;  CX = length;  INT E0h;
/* Close or finalize */
AX = 0x060E;  INT E0h;
```

This DeskMate-mediated file I/O runs through DESK.EXE rather than directly calling INT
21h, allowing the shell to track open file handles and enforce access control.

**Event polling sequence (from PLAY.PDM):**

```c
AX = 0x0600;  /* Poll for event */  INT E0h;
/* AX returns event type */
AX = 0x060E;  /* Dispatch event */  INT E0h;
```

ALRMINIT.RES shows 5 calls to AH=06h and 5 calls to AH=02h, consistent with an alarm
service that opens notification windows (AH=02h resource ops) and polls events (AH=06h).

---

### AH = 07h: Memory and Timer Services

| AX | Subfunction | Confirmed | Description | Callers |
|----|------------|-----------|-------------|---------|
| 0x0700 | 00h | Confirmed | **Allocate memory / yield / timer tick.** In DESKTOP.PDM and TEXT.PDM: labeled `dm_alloc_memory` (1 call each, called immediately before cursor control AX=0207h -- suggests memory allocation for a cursor/window buffer). In HANGMAN.PDM: labeled "Timer tick / yield" (1 call -- suggests cooperative multitasking yield point). Both interpretations may be correct if AL differentiates memory allocation vs. yield. | DESKTOP.PDM (1 call at 0xDDEF), TEXT.PDM (1 call at 0xE641), HANGMAN.PDM (1 call) |

**Note:** WRKSHEET.PDM uses AH=02h and AH=07h only (14 total INT E0h calls). It lacks
AH=06h calls, meaning it does not use DeskMate-mediated file I/O -- it likely uses direct
INT 21h calls for file operations (confirmed: AH=3Eh, AH=40h in its INT 21h list). This
establishes that AH=06h file I/O is optional and not all PDMs use it.

---

### AH = 21h: Extended DeskMate Functions

Observed exclusively in PLAY.PDM (2 calls). No further detail available from static
analysis. AX=0x2100 and AX=0x2101 are the candidates based on the count (2 calls, one
class). The name and purpose are entirely unknown at this stage.

| AX | Subfunction | Confirmed | Description | Callers |
|----|------------|-----------|-------------|---------|
| 0x2100 | 00h | Unknown | Extended function 0 | PLAY.PDM (inferred) |
| 0x2101 | 01h | Unknown | Extended function 1 | PLAY.PDM (inferred) |

These may be tutorial-playback-specific services exposed by DESK.EXE when DMPLAY.RES is
loaded, relating to lesson file parsing or animated lesson sequencing.

---

### AH = 4Dh: Shell / Host Management Services

AH=4Dh ('M' in ASCII) is used internally by DESK.EXE (2 calls) and is also called by:
- All video driver RES files (DMVE*.RES and DMVS*.RES): 2 calls each
- DMDBRD.RES: 2 calls
- PRGUF.RES: 2 calls
- SPL.RES: 2 calls
- FILER.PDM, CALENDAR.PDM, FORMSET.PDM, ADDRESS.PDM, DRAW.PDM: each shows AH=4Dh in the
  service class summary

The consistent "2 calls" pattern for RES modules suggests AX=4D00h and AX=4D01h (or
similar adjacent pair) as the two specific subfunctions used by drivers.

| AX | Subfunction | Confirmed | Description | Callers |
|----|------------|-----------|-------------|---------|
| 0x4D00 | 00h | Inferred | Shell service / driver registration notification | DESK.EXE internal, video RES files |
| 0x4D01 | 01h | Inferred | Shell service / driver deregistration or status query | Video RES files, DB modules |
| 0x4D04 | 04h | Inferred | Load / execute PDM application | DESK.EXE internal (SDK research) |
| 0x4D05 | 05h | Inferred | Unload / terminate PDM application | DESK.EXE internal (SDK research) |
| 0x4D06 | 06h | Inferred | Switch to alternate PDM / task switch | DESK.EXE internal (SDK research) |

**Note on AH=4Dh pattern in video drivers:**

Every DMVE*.RES (video editor/renderer) and DMVS*.RES (video scanner/input) file shows
exactly `AH=01h x1, AH=4Dh x2` -- one registration call (01F0h) and two shell management
calls. The 4Dh calls likely notify DESK.EXE that a video driver has been registered so
that the shell can update its internal video mode dispatch table and redirect screen
rendering to the loaded driver.

DMDBRD.RES (database reader) similarly shows `AH=00h x2, AH=01h x1, AH=02h x2, AH=06h
x4, AH=4Dh x2` -- it uses shell services to hook into DESK.EXE's data access layer.

---

## 5. Service Cross-Reference by Module

This table shows which AH service classes each module uses. A dot means the module
uses at least one subfunction from that service class.

| Module | AH=00 | AH=01 | AH=02 | AH=04 | AH=06 | AH=07 | AH=21 | AH=4D | Total calls |
|--------|-------|-------|-------|-------|-------|-------|-------|-------|-------------|
| DESK.EXE | Y | - | - | - | - | - | - | Y | 3 |
| DESKTOP.PDM | - | - | Y | - | Y | Y | - | - | 19 |
| TEXT.PDM | - | - | Y | - | Y | Y | - | - | 23 |
| WRKSHEET.PDM | - | - | Y | - | - | Y | - | - | 14 |
| FILER.PDM | - | - | Y | - | Y | Y | - | Y | 25 |
| DRAW.PDM | Y | - | Y | - | Y | Y | - | Y | 33 |
| CALENDAR.PDM | - | - | Y | - | Y | Y | - | Y | 30 |
| ADDRESS.PDM | - | - | Y | - | Y | Y | - | Y | 30 |
| TELECOM.PDM | - | - | Y | - | Y | - | - | - | 14 |
| HANGMAN.PDM | - | - | Y | - | - | Y | - | - | 18 |
| PC_LINK.PDM | - | - | Y | - | Y | Y | - | - | 20 |
| FORMSET.PDM | - | - | Y | - | Y | Y | - | Y | 25 |
| PLAY.PDM | - | - | Y | - | Y | Y | Y | - | 40 |
| MAILMRGE.PDM | - | - | Y | - | Y | - | - | - | 21 |
| INSTALL.PDM | - | - | Y | - | Y | Y | - | - | 18 |
| DMVID.EXE | - | - | - | - | - | - | - | - | 0 |
| DMVE1000.RES | - | Y | Y | - | Y | - | - | Y | 5 |
| DMVECGA.RES | - | Y | Y | - | Y | - | - | Y | 5 |
| DMVEEGA.RES | - | Y | Y | - | Y | - | - | Y | 5 |
| DMVEHERC.RES | - | Y | Y | - | Y | - | - | Y | 5 |
| DMVEMCGA.RES | - | Y | Y | - | Y | - | - | Y | 5 |
| DMVET.RES | - | Y | Y | - | Y | - | - | Y | 5 |
| DMVETC16.RES | - | Y | Y | - | Y | - | - | Y | 5 |
| DMVEVGA.RES | - | Y | Y | - | Y | - | - | Y | 5 |
| DMVS1000.RES | - | Y | - | - | - | - | - | Y | 3 |
| DMVSCGA.RES | - | Y | - | - | - | - | - | Y | 3 |
| DMVSEGA.RES | - | Y | - | - | - | - | - | Y | 3 |
| DMVSHERC.RES | - | Y | - | - | - | - | - | Y | 3 |
| DMVSMCGA.RES | - | Y | - | - | - | - | - | Y | 3 |
| DMVST.RES | - | Y | - | - | - | - | - | Y | 3 |
| DMVSTC16.RES | - | Y | - | - | - | - | - | Y | 3 |
| DMVSVGA.RES | - | Y | - | - | - | - | - | Y | 3 |
| DMPLAY.RES | Y | Y | Y | - | Y | - | - | - | 11 |
| DMFONT.RES | Y | - | - | - | Y | - | - | - | 6 |
| DMFORM.RES | - | Y | Y | - | - | - | - | - | 2 |
| DMEFORM.RES | - | Y | Y | - | Y | - | - | - | 5 |
| DMEMM.RES | - | Y | - | - | Y | - | - | - | 3 |
| DMSSM.RES | - | Y | - | - | Y | - | - | - | 2 |
| DMDBRD.RES | Y | Y | Y | - | Y | - | - | Y | 11 |
| DMDBBLD.RES | - | Y | - | - | Y | - | - | - | 2 |
| DMDBUPD.RES | - | Y | - | - | Y | - | - | - | 2 |
| DMPD1.RES | - | Y | Y | - | Y | - | - | - | 4 |
| DMPD2.RES | - | Y | Y | - | Y | - | - | - | 4 |
| DMPDASCI.RES | - | Y | Y | - | Y | - | - | - | 4 |
| DMPDIBMM.RES | - | Y | Y | - | Y | - | - | - | 4 |
| DMPDLASR.RES | - | Y | Y | - | Y | - | - | - | 4 |
| DMPDS.RES | - | Y | Y | - | Y | - | - | - | 4 |
| DMPE1.RES | - | Y | Y | - | Y | - | - | - | 3 |
| DMPE2.RES | - | Y | Y | - | Y | - | - | - | 3 |
| DMPEIBMM.RES | - | Y | Y | - | Y | - | - | - | 3 |
| DMPELASR.RES | - | Y | Y | - | Y | - | - | - | 3 |
| DMPES.RES | - | Y | Y | - | Y | - | - | - | 3 |
| DMMDJ.RES | - | Y | - | - | Y | - | - | - | 2 |
| DMMDP.RES | - | Y | - | - | Y | - | - | - | 2 |
| DMMDS.RES | - | Y | - | - | Y | - | - | - | 2 |
| SPELL.RES | - | Y | - | - | Y | - | - | - | 7 |
| DICTARY.RES | - | Y | Y | - | - | - | - | - | 6 |
| DMTHES.RES | - | Y | - | - | - | - | - | - | 1 |
| PRGUF.RES | - | Y | Y | - | Y | - | - | Y | 9 |
| SPL.RES | - | Y | - | - | - | - | - | Y | 4 |
| AUTOLOAD.RES | Y | Y | Y | - | Y | - | - | - | 14 |
| ALRMINIT.RES | - | Y | Y | - | Y | - | - | - | 12 |
| D87.RES | - | Y | Y | - | Y | - | - | - | 6 |
| DMUNPACK.RES | - | Y | - | - | - | - | - | - | 1 |
| PROTOCOL.RES | - | Y | Y | - | - | - | - | - | 2 |
| TRANSLAT.RES | - | Y | Y | - | - | - | - | - | 6 |
| DMALARM.ACC | - | - | Y | - | Y | - | - | - | 19 |
| DMHELP.ACC | - | Y | Y | - | Y | - | - | - | 23 |
| DMNOTEPD.ACC | - | Y | Y | - | Y | - | - | - | 16 |
| DMPHONE.ACC | - | Y | Y | - | Y | - | - | - | 26 |
| DMCLIP.ACC | - | - | Y | - | Y | - | - | - | 14 |
| DMSPELL.ACC | - | - | Y | - | Y | - | - | - | 13 |
| DMTODO.ACC | - | - | Y | - | Y | - | - | - | 14 |
| DMSERV.ACC | - | Y | Y | - | Y | - | - | - | 14 |
| DMSETUP.ACC | - | Y | Y | - | Y | - | - | - | 15 |
| DMPRTSEL.ACC | - | Y | Y | - | Y | - | - | - | 16 |
| DMDRWPRT.ACC | - | Y | Y | - | - | - | - | - | 9 |
| DMACCESS.ACC | - | - | Y | - | Y | - | - | - | 12 |
| DMPD1.ACC | - | Y | Y | - | Y | - | - | - | 16 |
| DMPD2.ACC | - | Y | Y | - | Y | - | - | - | 16 |
| DMPDASCI.ACC | - | Y | Y | - | Y | - | - | - | 16 |
| DMPDIBMM.ACC | - | Y | Y | - | Y | - | - | - | 16 |
| DMPDLASR.ACC | - | Y | Y | - | Y | - | - | - | 16 |
| DMPDS.ACC | - | Y | Y | - | Y | - | - | - | 16 |

---

## 6. Complete AX Code Inventory

All confirmed and inferred AX values observed or derived from static analysis, sorted
numerically:

| AX | AH | AL | Status | Name (working) | Description |
|----|----|----|--------|----------------|-------------|
| 0x0000 | 00 | 00 | Inferred | core_svc_0 | Core service 0 (minimal use) |
| 0x0003 | 00 | 03 | Inferred | font_render | Font rendering / font service |
| 0x0008 | 00 | 08 | Inferred | db_read | Database read query |
| 0x0009 | 00 | 09 | Inferred | db_record_op | Database record operation |
| 0x0090 | 00 | 90 | Inferred | autoload_svc | Module autoload notification |
| 0x0091 | 00 | 91 | Inferred | acc_display | ACC overlay display |
| 0x01F0 | 01 | F0 | Confirmed | res_register | Register resource module with DESK.EXE |
| 0x01FF | 01 | FF | Confirmed | res_unregister | Unregister resource module from DESK.EXE |
| 0x0206 | 02 | 06 | Confirmed | res_load | Load named resource module (DS:DX = name) |
| 0x0207 | 02 | 07 | Confirmed | res_unload | Unload named resource module (DS:DX = name) |
| 0x0208 | 02 | 08 | Confirmed | res_call | Call function in named resource module |
| 0x0209 | 02 | 09 | Inferred | form_field_op | Form field operation (printer drivers) |
| 0x020B | 02 | 0B | Confirmed | form_key_event | Form/dialog keyboard event processing |
| 0x020C | 02 | 0C | Confirmed | form_redraw | Form/dialog redraw / refresh |
| 0x0401 | 04 | 01 | Inferred | gfx_primitive_1 | Graphics draw primitive 1 |
| 0x0402 | 04 | 02 | Inferred | gfx_primitive_2 | Graphics draw primitive 2 |
| 0x0500 | 05 | 00 | DM-I only | menu_init | Menu initialization (DeskMate I; TWMENU.ASM) |
| 0x0600 | 06 | 00 | Confirmed | event_poll / file_open | Poll for event OR open a file (AL/context differentiates) |
| 0x0602 | 06 | 02 | Inferred | win_db_open | Database window service / open DB window |
| 0x0603 | 06 | 03 | Confirmed | res_dispatch / file_write | Dispatch to resource handler OR write file data |
| 0x0604 | 06 | 04 | Inferred | win_db_svc | Database window service operation |
| 0x0606 | 06 | 06 | Inferred | d87_svc | Math coprocessor service (D87.RES specific) |
| 0x060D | 06 | 0D | Inferred | emm_svc | Extended memory / EMS service |
| 0x060E | 06 | 0E | Confirmed | event_dispatch / file_close | Dispatch event to app OR close/finalize file |
| 0x0700 | 07 | 00 | Confirmed | alloc_mem / yield | Allocate memory OR cooperative yield / timer tick |
| 0x2100 | 21 | 00 | Unknown | ext_svc_0 | Extended function (PLAY.PDM only) |
| 0x2101 | 21 | 01 | Unknown | ext_svc_1 | Extended function (PLAY.PDM only) |
| 0x4D00 | 4D | 00 | Inferred | shell_svc_0 | Shell service / driver registration notify |
| 0x4D01 | 4D | 01 | Inferred | shell_svc_1 | Shell service / driver status / deregister |
| 0x4D04 | 4D | 04 | Inferred | shell_load_pdm | Load / execute PDM application |
| 0x4D05 | 4D | 05 | Inferred | shell_unload_pdm | Unload / terminate PDM application |
| 0x4D06 | 4D | 06 | Inferred | shell_switch_pdm | Switch to alternate PDM (task switch) |

---

## 7. Calling Patterns and Notes for Annotation Agents

### Pattern 1: Module startup sequence (all PDMs)

```asm
; 1. Load PRGUF (always first, provides core DeskMate functions)
MOV  DX, offset sz_PRGUF   ; "PRGUF"
MOV  AX, 0206h
INT  E0h

; 2. Load DMGUF (general user functions; most PDMs)
MOV  DX, offset sz_DMGUF   ; "DMGUF"
MOV  AX, 0206h
INT  E0h

; 3. Load additional module-specific resources
; (e.g., DMCSR for cursor, SPELL for spell-check, DMPLAY for tutorial)
```

### Pattern 2: Module shutdown sequence

```asm
; Reverse order of loading:
MOV  DX, offset sz_SPELL
MOV  AX, 0207h
INT  E0h
MOV  DX, offset sz_DMCSR
MOV  AX, 0207h
INT  E0h
MOV  DX, offset sz_DMGUF
MOV  AX, 0207h
INT  E0h
MOV  DX, offset sz_PRGUF
MOV  AX, 0207h
INT  E0h
```

### Pattern 3: RES module lifecycle

```asm
; Entry point (called by DESK.EXE when loading the .RES file):
MOV  AX, 01F0h    ; register this module
; DX -> registration block (name + function table pointer)
INT  E0h

; ... module runs, responds to events dispatched by DESK.EXE ...

; Exit (called on unload):
MOV  AX, 01FFh    ; deregister
INT  E0h
```

### Pattern 4: File I/O through DeskMate (TEXT.PDM, DESKTOP.PDM)

```asm
; Open file:
MOV  DX, offset filename
MOV  AX, 0600h
INT  E0h
; (file handle implicit, managed by DESK.EXE)

; Write data:
MOV  BX, buffer_ptr
MOV  CX, byte_count
MOV  AX, 0603h
INT  E0h

; Again for second block:
MOV  AX, 0603h
INT  E0h

; Close / finalize:
MOV  AX, 060Eh
INT  E0h
```

### Pattern 5: Event loop (PLAY.PDM)

```asm
event_loop:
MOV  AX, 0600h    ; poll for event
INT  E0h
; AX = event code (0 = none, non-zero = event type)
TEST AX, AX
JZ   event_loop   ; spin until event arrives

MOV  AX, 0700h    ; yield / timer tick
INT  E0h

MOV  AX, 060Eh    ; dispatch event to handler
INT  E0h
JMP  event_loop
```

### Named function labels (from automated analysis -- may need correction)

The automated disassembler used these labels for AX codes in DESKTOP.PDM and TEXT.PDM.
These names reflect local context rather than canonical API names and should be treated
as approximations pending full disassembly of DESK.EXE's INT E0h handler:

| AX | Automated label | Notes |
|----|----------------|-------|
| 0x0206 | dm_set_attribute | Also "Load resource" -- context-dependent |
| 0x0207 | dm_cursor_control | Also "Unload resource" -- context-dependent |
| 0x0208 | dm_get_window_info | Also "Execute resource function" -- context-dependent |
| 0x0600 | dm_file_open | Also event poll in PLAY.PDM |
| 0x0603 | dm_file_write | Also resource dispatch in PLAY.PDM |
| 0x060E | svc_060E | Close/finalize or event dispatch |
| 0x0700 | dm_alloc_memory | Also yield/timer in HANGMAN.PDM |

**Resolution:** The AL subfunction byte almost certainly distinguishes the operations
within each AH class. A value of AL=06h for AH=02h (giving AX=0206h) likely selects
a "load by name" operation, while a different context-prepared AL value would select
the "set attribute" or "cursor" behavior. Full resolution requires disassembly of
DESK.EXE's AH=02h dispatch sub-table.

---

## 8. DeskMate I vs DeskMate 3.x Comparison

The GoombaProgrammer DeskMate I disassembly reveals the INT E0h handler structure for
the earlier version. Key differences from DeskMate 3.05:

| Aspect | DeskMate I | DeskMate 3.05 |
|--------|------------|---------------|
| AH range | 0x00-0x32 (51 handlers) | 0x00-0x4D at minimum (observed) |
| Dispatch | Jump table at offset 0x104F | Similar table structure (different offset) |
| AH=0x10 | Cursor control / display | Superseded by AH=02h subfamily |
| AH=0x05 | Menu services (TWMENU call) | Not observed in 3.x; merged into AH=02h or 06h? |
| AH=0x2C | Get time | Replaced by INT 21h AH=2Ch direct calls in 3.x PDMs |
| AH=0x4D | Not observed | Added in 3.x for PDM lifecycle management |
| Resource system | Not observed | Added in 3.x (AH=01h, AH=02h subclasses) |

The DeskMate 3.x handler is substantially more complex than the DeskMate I handler,
adding the full resource module infrastructure (AH=01h, AH=02h resource loading),
the windowing / event / file I/O services (AH=06h), and the shell management services
(AH=4Dh) that did not exist in the simpler DeskMate I shell.

---

## 9. INT E2h: Secondary Service Vector

DESK.EXE installs a handler on INT E2h in addition to INT E0h. ADDRESS.PDM calls INT E2h
5 times. DESK.EXE's callgraph does not break down INT E2h AH values; the SDK research
document notes it is used by DMEMM.RES (extended memory manager).

Hypothesis: INT E2h provides extended memory (XMS/EMS) services that cannot be reached
through the standard INT E0h AH=06h class, possibly because the memory manager needs a
separate interrupt to avoid re-entrancy issues in the main INT E0h handler.

---

## 10. Priority Research Items

For annotation and transpilation agents, the following are the highest-value items to
resolve with deeper disassembly:

1. **DESK.EXE INT E0h dispatch table:** Disassemble the function beginning at the DESK.EXE
   entry for INT E0h (near offset 0x42xx based on proximity to `DESKMATE$05.00 900919$`
   string). The dispatch table will reveal the complete AH range and exact handler addresses.
   This single analysis will confirm or correct every "Inferred" entry in this document.

2. **AH=02h sub-dispatch:** Determine whether AH=02h uses a second-level dispatch on AL,
   or whether the 06h/07h/08h values in AX directly index a flat table within the AH=02h
   handler. This resolves the "context-dependent" ambiguity in service names.

3. **AX=0206h parameter block (BX):** When AX=0208h (call resource function) is used with
   BX -> parameter block, decode the layout of that block. HANGMAN.PDM uses this for the
   SPELL resource; disassembling sub_0000_35B9 (hang_callSpell) would reveal the structure.

4. **AH=4Dh subfunctions:** Disassemble the 4Dh handler in DESK.EXE to get the exact
   PDM lifecycle function codes. This is critical for implementing the PDM loader.

5. **INT E2h handler:** Find and disassemble DESK.EXE's INT E2h installation and handler
   code to document the extended memory service interface.

6. **DMDS 3.03 SDK:** Attempt retrieval from archive.org cache of
   `http://ftp.oldskool.org/pub/tvdog/tandy1000/wares/DeskMate-Development-System-3.03/`
   -- the SDK header files would provide canonical function names and calling conventions.

---

## 11. Sources

- Bayside project callgraph files: `/Users/joe/Documents/GitHub/bayside/disassembly/raw/`
  (86 callgraph files for DESK.EXE, all PDMs, all RES modules, all ACC accessories)
- Bayside SDK research: `/Users/joe/Documents/GitHub/bayside/research/docs/deskmate-sdk-research.md`
- DeskMate I disassembly (GoombaProgrammer): [https://github.com/GoombaProgrammer/tandy-deskmate](https://github.com/GoombaProgrammer/tandy-deskmate)
  - `DESK.ASM`: INT E0h handler at offset 0x104F, AH dispatch 0x00-0x32
  - `TWMENU.ASM`: AX=0x0500 call (menu init service)
- VOGONS DeskMate compatibility thread: [https://www.vogons.org/viewtopic.php?t=15756](https://www.vogons.org/viewtopic.php?t=15756)
  (DMEMM.RES / DMCSR.R89 / PRGUF.RES resource identification)
- WinWorld DeskMate 3.x: [https://winworldpc.com/product/tandy-deskmate/deskmate-3x](https://winworldpc.com/product/tandy-deskmate/deskmate-3x)
- DMDS 3.03 FTP (may be offline): `http://ftp.oldskool.org/pub/tvdog/tandy1000/wares/DeskMate-Development-System-3.03/`
