; ========================================================================
; DMVEHERC.RES -- Annotated Disassembly
; DeskMate 3.05, Tandy Corporation
; Enhanced Video Driver: Hercules (720x348, monochrome)
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMVEHERC.RES is the enhanced-mode Hercules video driver for DeskMate 3.05.
; It contains the core drawing primitives for the Hercules Graphics Card,
; operating on the monochrome framebuffer at segment B000h.
;
; The Hercules adapter provides 720x348 monochrome graphics with a unique
; interleaved memory layout: even scanlines at B000:0000 and odd scanlines
; at B000:2000 (with additional banks at B000:4000 and B000:6000 for the
; 4-way interleave in 348-line mode). Each pixel is a single bit.
;
; Video framebuffer: segment B000h
; Resolution: 720x348, monochrome (1-bit per pixel)
; Bytes per scanline: 90 (720/8)
; Memory interleave: 4-way (offsets 0x0000, 0x2000, 0x4000, 0x6000)
; Scan line increment: 0x2000 per bank, wrapping with offset 0x7FA6
;   (visible as: add di, 0x5AA0; jns ...; add di, 0x7FA6 in the code)
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 5378 bytes
; Code+data size: 4866 bytes
; DM89 entry point: 0117:00A2
; SS:SP = 0130:0002
;
; Segment Map (4 segments, 5 relocations):
;   seg_0000  0x1160 bytes  CODE/DATA  Drawing primitives + sine table
;   seg_0116  0x0010 bytes  CODE/DATA  Enhanced driver name string
;   seg_0117  0x0190 bytes  CODE       TSR startup, dispatch, INT E0h interface
;   seg_0130  0x0002 bytes  STACK      Stack segment
;
; ========================================================================
; I/O PORT ACCESS
; ========================================================================
;
; This enhanced driver does not directly access Hercules I/O ports.
; All hardware register programming is done in DMVSHERC.RES.
; The enhanced driver accesses the framebuffer through memory-mapped
; I/O at segment B000h only.
;
; Hercules framebuffer: segment B000h
;   First two bytes of seg_0000: 00 B0 (= 0xB000 little-endian)
;
; Bytes per scanline: 90 (0x5A) -- Hercules 720-pixel-wide mode
;   Visible in code: cmp bx, 0x5A (coordinate boundary check)
;
; Interleaved scan addressing:
;   add di, 0xA05A  (= 0x2000 + 0x805A for next bank with wrap)
;   The 4-way interleave produces scanline offsets:
;     Line 0: 0x0000, Line 1: 0x2000, Line 2: 0x4000, Line 3: 0x6000
;     Line 4: 0x005A, Line 5: 0x205A, etc.
;
; ========================================================================
; INT CALLS
; ========================================================================
;
; INT E0h, AH=06h  -- Query DeskMate host capabilities
;   0117:00AE  Check host mode flags
;
; INT E0h, AH=01h  -- Register enhanced driver with host
;   0117:00C9  CX=seg_0000, AX=0x01F0
;
; INT E0h, AH=4Dh/04  -- Acquire display mutex
;   0117:010D  Before draw calls
;
; INT E0h, AH=4Dh/05  -- Release display mutex
;   0117:013A  After draw calls
;
; INT E0h, AH=02h  -- Register font/resource pointer
;   0117:0178  BX=0x31, DX=0x35
;
; INT 21h, AH=51h  -- Get PSP segment
;   0117:00D4
;
; INT 21h, AH=31h  -- Terminate and Stay Resident
;   0117:00E1
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; The function layout is structurally identical to DMVEVGA.RES, with the
; same dispatch table indices (0x00-0x0C) and the same set of far-call
; thunks. The key differences are:
;
; - Framebuffer segment is B000h instead of A000h
; - Scan line addressing uses 4-way interleave instead of linear
; - Pixel operations work with 1-bit (monochrome) instead of 4-plane
; - Bytes per scanline is 90 instead of 80
; - The thunk far-call target is function 0x42 (Hercules host) vs 0x41 (VGA)
;
; --- Drawing Primitives (seg_0000) ---
;   0000:0000  (data: framebuffer seg)     dw 0xB000
;   0000:0039  dmveherc_setPixel           Plot pixel with clipping
;   0000:016E  dmveherc_clipRect           Clip rectangle to viewport
;   0000:0208  dmveherc_scrollRegion       Scroll rectangular region
;   0000:0255  (thunks to host func 0x42)  22 far-call thunks
;   0000:0430  dmveherc_sineLookup         Sine via lookup table
;   0000:053B  dmveherc_initFont           Initialize font state
;   0000:08D5  dmveherc_calcAspectRatio    Aspect ratio calculation
;   0000:0AA7  dmveherc_renderGlyphBitmap  Glyph rendering
;   0000:1006  dmveherc_hercInterleave     Hercules-specific interleave helpers
;
; --- TSR / Dispatcher (seg_0117) ---
;   0117:00A2  entry_point                 TSR entry
;   0117:00E2  dmveherc_dispatcher         Function dispatcher
;   0117:015A  sub_0117_015A               Font table init
;
; ========================================================================
; NOTES
; ========================================================================
;
; - The Hercules 4-way interleave is the primary difference from VGA.
;   Scanline Y maps to memory address: (Y % 4) * 0x2000 + (Y / 4) * 90
;   The code handles this with bank stepping and wrap-around logic.
;
; - All thunks call host function 0x42 (Hercules display handler) instead
;   of 0x41 (VGA handler), indicating the host dispatches to different
;   backends based on the active display adapter.
;
; - Monochrome operation means pixel masking uses single-bit operations
;   rather than 4-plane manipulation. The fill pattern byte directly
;   maps to 8 horizontal pixels.
;
; ========================================================================
