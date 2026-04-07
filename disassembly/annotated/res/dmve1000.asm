; ========================================================================
; DMVE1000.RES -- Annotated Disassembly
; DeskMate 3.05, Tandy Corporation
; Enhanced Video Driver: Tandy 1000 (640x200, 4 colors)
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMVE1000.RES is the enhanced-mode Tandy 1000 video driver for DeskMate.
; It contains drawing primitives for the Tandy Graphics Adapter (TGA/TGA2),
; operating on the framebuffer at segment B800h.
;
; The Tandy 1000 provides CGA-compatible plus enhanced modes. DeskMate
; uses the 640x200 4-color mode, which provides 2 bits per pixel in an
; interleaved memory layout similar to CGA.
;
; Video framebuffer: segment B800h
; Resolution: 640x200, 4 colors (2 bits per pixel)
; Bytes per scanline: 160 (640*2/8)
; Memory interleave: 2-way (even lines at +0x0000, odd at +0x2000)
; Scan line increment: 0x2000 per bank, wrapping with offset 0x80A0
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 5314 bytes
; Code+data size: 4802 bytes
; DM89 entry point: 0113:00A2
; SS:SP = 012C:0002
;
; Segment Map (4 segments, 5 relocations):
;   seg_0000  0x1120 bytes  CODE/DATA  Drawing primitives + sine table
;   seg_0112  0x0010 bytes  CODE/DATA  Enhanced driver name string
;   seg_0113  0x0190 bytes  CODE       TSR startup, dispatch
;   seg_012C  0x0002 bytes  STACK      Stack segment
;
; ========================================================================
; I/O PORT ACCESS
; ========================================================================
;
; This enhanced driver does not directly access TGA I/O ports.
; All hardware register programming is done in DMVS1000.RES.
; The enhanced driver accesses the framebuffer at segment B800h.
;
; Tandy framebuffer: segment B800h
;   First two bytes of seg_0000: 00 B8 (= 0xB800 little-endian)
;
; Bytes per scanline: varies by mode, but the interleaved addressing
;   is visible in the code: add di, 0x2000; jns ...; add di, 0x80A0
;
; ========================================================================
; INT CALLS
; ========================================================================
;
; INT E0h, AH=06h  -- Query DeskMate host capabilities
;   0113:00AE
;
; INT E0h, AH=01h  -- Register enhanced driver
;   0113:00C9  CX=seg_0000, AX=0x01F0
;
; INT E0h, AH=4Dh/04 / 05  -- Acquire/release display mutex
;   0113:010D, 0113:013A
;
; INT E0h, AH=02h  -- Register font/resource pointer
;   0113:0178
;
; INT 21h, AH=51h  -- Get PSP
;   0113:00D4
;
; INT 21h, AH=31h  -- TSR
;   0113:00E1
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; Structurally identical to DMVEHERC.RES with these differences:
;
; - Framebuffer at B800h (Tandy TGA video RAM)
; - 2-way interleave instead of 4-way
; - 2 bits per pixel instead of 1 (4 colors vs monochrome)
; - All thunks call host function 0x42 (same as Hercules)
; - Pixel masking uses 2-bit operations for 4-color support
;
; --- Drawing Primitives (seg_0000) ---
;   0000:0000  (data: framebuffer seg)    dw 0xB800
;   0000:0039  dmve1000_setPixel          Plot pixel (2-bit color)
;   0000:016E  dmve1000_clipRect          Clip rectangle
;   0000:0208  dmve1000_scrollRegion      Scroll region
;   0000:0255  (thunks to host func 0x42)
;   0000:0430  dmve1000_sineLookup        Sine lookup
;   0000:053B  dmve1000_initFont          Init font state
;   0000:0FE4  dmve1000_tandyInterleave   Tandy-specific interleave helpers
;
; --- TSR / Dispatcher (seg_0113) ---
;   0113:00A2  entry_point
;   0113:00E2  dmve1000_dispatcher
;   0113:015A  sub_0113_015A
;
; ========================================================================
; NOTES
; ========================================================================
;
; - The Tandy 1000 TGA uses CGA-compatible interleaved addressing but
;   with extended modes. The 2-way interleave (even/odd at 0x0000/0x2000)
;   is the same as CGA 320x200x4 mode.
;
; - DeskMate on Tandy 1000 uses 640x200 4-color mode, which provides
;   higher horizontal resolution than standard CGA while maintaining
;   CGA-compatible memory layout.
;
; - The code at offsets 0x0FE4+ contains Tandy-specific interleave
;   handlers that differ from both VGA (linear) and Hercules (4-way).
;
; ========================================================================
