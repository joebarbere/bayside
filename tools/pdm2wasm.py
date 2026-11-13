#!/usr/bin/env python3
"""
pdm2wasm.py -- Re-express an original PDM as linkable OpenWatcom asm so it
can be decompiled one function at a time (the "binary splicing" approach
used by matching-decompilation projects).

Output layout (identical offsets to the original):
    _TEXT     original code segment bytes at offset 0, a public label on
              every known function
    CRT_TEXT  the MSC startup segment (paragraph aligned), directly after
              _TEXT as in the original
    HM_TEXT   C code (wcc -nt=HM_TEXT -g=CGROUP); CGROUP = _TEXT + CRT_TEXT
              + HM_TEXT is one near-call frame
    DGROUP    ORIG_DATA: original initialised data + BSS + stack region at
              their original offsets (0 .. stack top); C data links after
Relocations become symbolic `dw _TEXT` / `dw DGROUP` fixups, so the image
still loads correctly when C code grows _TEXT.

Splicing: every function named in the --replaced file is implemented in C.
At its original address the blob gets `jmp near _name` instead of the
public label, so original callers land in the C version. C can call any
not-yet-replaced original function through its label (all __cdecl, near).
With an empty --replaced list the linked image is byte-identical to the
original (checked by tools/mkpdm.py --verify).

Usage:
    tools/pdm2wasm.py HANGMAN.PDM --functions funcs.txt [--replaced r.txt]
        [--data-syms dgroup.syms] -o orig.asm
funcs.txt / dgroup.syms lines:  XXXX name   (hex offset; '#' comments)
"""

import argparse
import struct
import sys

MASM = lambda v: (f"{v:X}h" if f"{v:X}"[0] not in "ABCDEF" else f"0{v:X}h")


def read_syms(path):
    out = {}
    if not path:
        return out
    for line in open(path):
        line = line.split("#")[0].strip()
        if line:
            addr, name = line.split()[:2]
            out[int(addr, 16)] = name
    return out


def emit_bytes(lines, buf, base, start, end, fixups, labels, jumps=None):
    """Emit buf[start:end] as db lines, with labels, reloc fixups and
    optional splice jumps. fixups: {offset: symbol}; labels: {offset: name}
    jumps: {offset: target} (3-byte near jmp replaces original bytes)."""
    jumps = jumps or {}
    pos = start
    cuts = sorted(set(list(fixups) + list(labels) + list(jumps)) | {end})
    while pos < end:
        if pos in labels:
            lines.append(f"{labels[pos]} label near" if base == "code"
                         else f"{labels[pos]} label byte")
        if pos in jumps:
            # E9 rel16: exactly 3 bytes, so everything after stays in place
            lines.append(f"        jmp     near ptr {jumps[pos]}"
                         f"            ; {pos:04X} spliced -> C")
            pos += 3
            continue
        if pos in fixups:
            lines.append(f"        dw      {fixups[pos]}            ; {pos:04X} reloc")
            pos += 2
            continue
        nxt = min(c for c in cuts if c > pos)
        chunk = buf[pos:nxt]
        for k in range(0, len(chunk), 16):
            part = chunk[k:k + 16]
            lines.append("        db      " + ",".join(MASM(b) for b in part)
                         + f"   ; {pos + k:04X}")
        pos = nxt


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("pdm")
    ap.add_argument("--functions", required=True)
    ap.add_argument("--replaced")
    ap.add_argument("--data-syms")
    ap.add_argument("-o", "--out", required=True)
    a = ap.parse_args()

    raw = open(a.pdm, "rb").read()
    (_sig, last, pages, nrel, hdrp, minalloc, maxalloc, ss, sp, _c, ip, cs,
     reloff, _o) = struct.unpack("<2s13H", raw[:28])
    size = pages * 512 - ((512 - last) if last else 0)
    img = raw[hdrp * 16:size]
    if raw[0x1C:0x20] == b"DM89":
        cs, ip = struct.unpack("<HH", raw[0x26:0x2A])

    # Segment map (paragraphs). HANGMAN: code 0000, CRT 0447, DGROUP 0452.
    # Derived: DGROUP = most common reloc value != 0; CRT = entry CS.
    vals = []
    relocs = []
    for i in range(nrel):
        off, seg = struct.unpack("<HH", raw[reloff + 4 * i: reloff + 4 * i + 4])
        lin = seg * 16 + off
        relocs.append(lin)
        vals.append(struct.unpack("<H", img[lin:lin + 2])[0])
    dgroup = max(set(v for v in vals if v), key=vals.count)
    crt = cs
    segs = {0: "_TEXT", crt: "CRT_TEXT", dgroup: "DGROUP"}
    for v in vals:
        if v not in segs:
            sys.exit(f"error: relocation to unknown segment {v:04X}")

    code_end, crt_end = crt * 16, dgroup * 16
    data_init_end = len(img) - crt_end              # initialised DGROUP bytes
    # Uninitialised extent: MZ min alloc covers BSS + stack beyond image.
    dgroup_total = (ss - dgroup) * 16 + sp          # original stack top
    if dgroup_total > 0x10000:
        sys.exit("error: DGROUP exceeds 64K")

    funcs = read_syms(a.functions)
    replaced = set(read_syms(a.replaced).values()) if a.replaced else set()
    unknown = replaced - set(funcs.values())
    if unknown:
        sys.exit(f"error: replaced functions not in --functions: {sorted(unknown)}")
    dsyms = read_syms(a.data_syms)

    def fix(region_start, region_end):
        out = {}
        for lin, v in zip(relocs, vals):
            if region_start <= lin < region_end:
                out[lin - region_start] = segs[v]
        return out

    code_labels = {o: f"_{n}" for o, n in funcs.items() if n not in replaced}
    code_jumps = {o: f"_{n}" for o, n in funcs.items() if n in replaced}

    L = []
    L.append(f"""; ========================================================================
; GENERATED by tools/pdm2wasm.py from {a.pdm.split('/')[-1]} -- do not hand-edit.
; The original binary as linkable asm, original offsets preserved.
; Functions implemented in C are spliced in via `jmp near` at their
; original address (see the replaced-functions list).
; Segments: _TEXT 0000-{code_end:04X}  CRT_TEXT {crt:04X}:0000-{crt_end - code_end:04X}
;           DGROUP {dgroup:04X}: init 0000-{data_init_end:04X}, bss+stack to {dgroup_total:04X}
; ========================================================================
        .8086

_TEXT     segment word public 'CODE'
_TEXT     ends
CRT_TEXT  segment para public 'CODE'
CRT_TEXT  ends
; C code goes AFTER the startup segment: original code near-calls into
; CRT_TEXT by offset from _TEXT's base (e.g. 0000:44A6), so nothing may be
; inserted between them. CGROUP makes one near-call frame for all three.
HM_TEXT   segment word public 'CODE'
HM_TEXT   ends
CGROUP    group _TEXT, CRT_TEXT, HM_TEXT
ORIG_DATA segment para public 'DATA'
ORIG_DATA ends
_DATA     segment word public 'DATA'
_DATA     ends
CONST     segment word public 'DATA'
CONST     ends
CONST2    segment word public 'DATA'
CONST2    ends
_BSS      segment word public 'BSS'
_BSS      ends
DGROUP    group ORIG_DATA, _DATA, CONST, CONST2, _BSS
""")
    for o, n in sorted(code_labels.items()):
        L.append(f"        public  {n}")
    for o, n in sorted(dsyms.items()):
        L.append(f"        public  _{n}")
    for n in sorted(set(code_jumps.values())):
        L.append(f"        extrn   {n}:near")
    L.append("\n_TEXT     segment\n        assume cs:CGROUP")
    emit_bytes(L, img, "code", 0, code_end, fix(0, code_end), code_labels, code_jumps)
    L.append("_TEXT     ends\n\nCRT_TEXT  segment\n        assume cs:CRT_TEXT")
    L.append("        public  _crt_start")
    crt_buf = img[code_end:crt_end]
    emit_bytes(L, crt_buf, "code", 0, len(crt_buf), fix(code_end, crt_end),
               {ip: "_crt_start"})
    L.append("CRT_TEXT  ends\n\nORIG_DATA segment")
    data_buf = img[crt_end:]
    emit_bytes(L, data_buf, "data", 0, len(data_buf), fix(crt_end, len(img)),
               {o: f"_{n}" for o, n in dsyms.items() if o < len(data_buf)})
    # BSS + stack: reserve to the original stack top, labels for named syms
    pos = len(data_buf)
    for o in sorted(o for o in dsyms if o >= len(data_buf)) + [dgroup_total]:
        if o > pos:
            L.append(f"        db      {o - pos} dup (?)   ; {pos:04X} bss (not stored in file)")
            pos = o
        if o in dsyms:
            L.append(f"_{dsyms[o]} label byte")
    L.append("ORIG_DATA ends\n\n        end     _crt_start")

    with open(a.out, "w") as f:
        f.write("\n".join(L) + "\n")
    print(f"wrote {a.out}: {len(funcs)} functions ({len(replaced)} in C), "
          f"{nrel} relocs, DGROUP {dgroup_total:#x} bytes", file=sys.stderr)


if __name__ == "__main__":
    main()
