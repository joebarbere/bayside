; ========================================================================
; DMVEMCGA.RES -- Annotated Disassembly
; DeskMate 3.05, Tandy Corporation
; Enhanced Video Driver: MCGA (640x480, 2 colors)
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMVEMCGA.RES is the enhanced-mode MCGA video driver for DeskMate 3.05.
; It contains drawing primitives for the Multi-Color Graphics Array,
; operating on the framebuffer at segment A000h.
;
; MCGA is a subset of VGA found in IBM PS/2 Model 25/30. In DeskMate,
; it is used in 640x480 monochrome mode (mode 11h), providing a high-
; resolution monochrome display with linear framebuffer addressing.
;
; Video framebuffer: segment A000h
; Resolution: 640x480, 2 colors (1-bit per pixel, monochrome)
; Bytes per scanline: 80 (640/8)
; Memory layout: Linear (no interleave)
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 5250 bytes
; Code+data size: 4738 bytes
; DM89 entry point: 010F:00A2
; SS:SP = 0128:0002
;
; Segment Map (3 segments, 5 relocations):
;   seg_0000  0x10F0 bytes  CODE/DATA  Drawing primitives + sine table
;   seg_010F  0x0190 bytes  CODE       TSR startup, dispatch
;   seg_0128  0x0002 bytes  STACK      Stack segment
;
; Note: Only 3 segments (no separate name segment), indicating a slightly
; different build configuration. The DM89 header encodes the name inline.
;
; ========================================================================
; I/O PORT ACCESS
; ========================================================================
;
; This enhanced driver does not directly access MCGA I/O ports.
; The framebuffer is at segment A000h (same as VGA).
;
; MCGA framebuffer: segment A000h
;   First two bytes of seg_0000: 00 A0 (= 0xA000)
;
; Bytes per scanline: 80 (0x50)
;   Visible in the scan line increment: add di, 0x50
;
; Unlike the Hercules and Tandy enhanced drivers, MCGA uses linear
; (non-interleaved) addressing, same as VGA.
;
; ========================================================================
; INT CALLS
; ========================================================================
;
; INT E0h, AH=06h  -- Query host capabilities
;   010F:00AE
;
; INT E0h, AH=01h  -- Register enhanced driver
;   010F:00C9  CX=seg_0000, AX=0x01F0
;
; INT E0h, AH=4Dh/04 / 05  -- Display mutex
;   010F:010D, 010F:013A
;
; INT E0h, AH=02h  -- Register font/resource
;   010F:0178
;
; INT 21h, AH=51h  -- Get PSP
;   010F:00D4
;
; INT 21h, AH=31h  -- TSR
;   010F:00E1
;
; ========================================================================
; FUNCTION INDEX
; ========================================================================
;
; Structurally identical to DMVEVGA.RES with these differences:
;
; - Monochrome mode: 1-bit per pixel instead of 4-plane VGA
; - All thunks call host function 0x42 (same as Hercules/Tandy)
;   rather than 0x41 (VGA), indicating MCGA uses the monochrome
;   host display backend
; - Linear addressing (same as VGA, unlike Hercules/Tandy interleave)
; - Slightly smaller code (4738 vs 4914 bytes for VGA enhanced)
;
; --- Drawing Primitives (seg_0000) ---
;   0000:0000  (data: framebuffer seg)    dw 0xA000
;   0000:0039  dmvemcga_setPixel          Plot pixel (1-bit)
;   0000:0160  dmvemcga_clipRect          Clip rectangle
;   0000:01FA  dmvemcga_scrollRegion      Scroll region
;   0000:0247  (thunks to host func 0x42)
;   0000:0422  dmvemcga_sineLookup        Sine lookup
;   0000:052D  dmvemcga_initFont          Init font state
;   0000:0FC1  dmvemcga_mcgaDisplayHelpers  MCGA-specific display helpers
;
; --- TSR / Dispatcher (seg_010F) ---
;   010F:00A2  entry_point
;   010F:00E2  dmvemcga_dispatcher
;
; ========================================================================
; NOTES
; ========================================================================
;
; - MCGA mode 11h provides 640x480 at 2 colors, making it resolution-
;   compatible with VGA mode 12h but without color. This means the
;   coordinate system and clipping logic match VGA exactly.
;
; - The code at 0x0FC1+ contains MCGA-specific helpers that use
;   ES segment override with &-prefixed memory accesses, similar to
;   the Hercules interleave helpers but for linear monochrome.
;
; - The 3-segment layout (vs 4 for other enhanced drivers) suggests
;   the driver name string is embedded directly in the DM89 header
;   or in seg_0000 rather than having its own segment.
;
; ========================================================================
