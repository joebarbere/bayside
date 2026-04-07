; ========================================================================
; DMUNPACK.RES -- Fully Annotated Disassembly
; DeskMate 3.05, Tandy Corporation, Copyright (c) 1987-1989
; Annotated for the Bayside reverse engineering project
; ========================================================================
;
; DMUNPACK.RES is the Decompression Engine for DeskMate 3.05.
; It provides file decompression services used by the DeskMate
; installer and other modules that need to read compressed data
; files from distribution disks.
;
; The decompression algorithm appears to be a variant of LZW or
; LZSS compression, using:
;   - A dictionary/tree structure (built in seg_0000 init code)
;     with 0x13A entries (314 nodes)
;   - Bit-level I/O with a shift register for variable-width codes
;   - Huffman-like tree traversal for decoding
;   - File I/O through PRGUF/DMGUF imports
;
; The decompression buffer is large: Min/Max alloc = 0x040C paragraphs
; (16,576 bytes), indicating a significant working memory requirement
; for the decompression dictionary and output buffer.
;
; Module name: "DMUNPACK"
;
; DM89 imports: PRGUF, DMGUF
;
; ========================================================================
; BINARY STRUCTURE
; ========================================================================
;
; MZ + DM89 header (512 bytes)
; File size: 3,172 bytes
; Load image: 2,660 bytes (after header)
; DM89 entry point: 0080:0028
; SS:SP = 00A7:0002
; Min/Max alloc: 0x040C paragraphs (16,576 bytes)
;
; Segment Map (5 segments, 4 relocations):
;   seg_0000  2,048 bytes  CODE   Decompression engine: tree init,
;                                 bitstream decode, dictionary lookup,
;                                 output buffering, file I/O
;   seg_0080  64 bytes     CODE   DM89 entry, module name "DMUNPACK"
;   seg_0084  560 bytes    DATA   Dispatch table, import references
;                                 (PRGUF, DMGUF), decompression tables,
;                                 character mapping table
;   seg_00A7  BSS                 Stack
;   seg_04CB  BSS                 Decompression dictionary/buffer (large)
;
; ========================================================================
; FUNCTION INDEX (seg_0000 - Decompression Engine)
; ========================================================================
;
; Address     Name                          Description
; -------     ----                          -----------
; 0000:0000   dmunpack_initTree             Initialize decompression tree (314 entries)
; 0000:006B   dmunpack_readBit              Read single bit from input stream
; 0000:007B   dmunpack_readByte             Read 8 bits (one byte) from stream
; 0000:008D   dmunpack_fillInputBuffer      Refill input buffer from file
; 0000:00F4   dmunpack_rebuildTree          Rebuild/rebalance decompression tree
; 0000:01C3   dmunpack_updateTreeNode       Update tree node after decode
; 0000:0254   dmunpack_decodeSymbol         Decode next symbol from compressed stream
; 0000:027E   dmunpack_decodePair           Decode length/offset pair
; 0000:02AA   dmunpack_decompressBlock      Decompress one block of data
; 0000:03CF   dmunpack_decompressFile       Main: open file, decompress, close
; 0000:0489   dmunpack_readHeader           Read compressed file header
; 0000:058D   dmunpack_setupBuffers         Set up I/O and output buffers
; 0000:05CC   dmunpack_decompressToBuffer   Decompress data to memory buffer
; 0000:05EC   dmunpack_decompressToFile     Decompress data to output file
; 0000:065C   dmunpack_fileIODispatch       File I/O dispatch (read/write/seek)
; 0000:068C   dmunpack_loadImport           Load a DM89 import by name
; 0000:074C   dmunpack_unloadImport         Unload DM89 import
;
; 0080:0028   dmunpack_tsrEntry             DM89 entry: register, init
;
; ========================================================================
; KEY DATA STRUCTURES
; ========================================================================
;
; Decompression Tree (seg_04CB BSS, ~16KB):
;   Array of tree nodes, each containing:
;   +0x00  left_child      - Left child index
;   +0x02  right_child     - Right child index
;   +0x04  parent          - Parent node index
;   +0x06  weight          - Node frequency/weight
;   Total: 314 nodes (0x13A) for Huffman-like coding
;
; Bitstream State (seg_0000 data area):
;   [0x4C44] input_buf_pos  - Position in input buffer
;   [0x4F44] current_char   - Current byte being decoded
;   [0x5244] output_buf_pos - Position in output buffer
;   [0x5444] bit_accumulator - Bit accumulator for variable-width reads
;   [0x5844] bits_remaining - Bits remaining in accumulator
;
; Character Mapping Table (seg_0084:00D6):
;   256-byte table mapping compressed character codes to output bytes
;   "  !!""##$$%%&&''(())**++,,--..//0123456789:;<=>?"
;   (pairs represent compressed -> output mapping)
;
; ========================================================================
; RAW DISASSEMBLY
; ========================================================================

; seg_0000: Decompression engine (2,048 bytes)
; seg_0080: DM89 entry (64 bytes)
; seg_0084: Dispatch + tables (560 bytes)
;
; [Full raw disassembly preserved from disasm_mz.py output]
; [See disassembly/raw/res/dmunpack.asm for complete byte-level listing]
