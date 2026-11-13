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

Splicing: every function implemented in C (found in --c-sources by its
`/* address: 0000:XXXX */` comment) is spliced in.
At its original address the blob gets `jmp near _name` instead of the
public label, so original callers land in the C version. C can call any
not-yet-replaced original function through its label (all __cdecl, near).
With an empty --replaced list the linked image is byte-identical to the
original (checked by tools/mkpdm.py --verify).

Usage:
    tools/pdm2wasm.py HANGMAN.PDM --functions funcs.txt [--c-sources DIR]
        [--data-syms a.syms ...] -o orig.asm
funcs.txt / dgroup.syms lines:  XXXX name   (hex offset; '#' comments)
"""

import argparse
import struct
import sys
from pathlib import Path

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
    ap.add_argument("--c-sources", metavar="DIR",
                    help="directory of C files; every function whose definition "
                         "is preceded by an `address: 0000:XXXX` comment is "
                         "spliced in (name must match --functions)")
    ap.add_argument("--data-syms", action="append", default=[])
    ap.add_argument("--c-region", metavar="START:END",
                    help="code range that is entirely C (hex). When every "
                         "function in it is implemented in C, the C code is "
                         "linked INTO this range (original segment map kept "
                         "exactly) instead of after CRT_TEXT")
    ap.add_argument("--pad", type=int, default=0,
                    help="filler bytes after the C code so the rest of _TEXT "
                         "resumes at END (computed by the build from a first link)")
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
    replaced = set()
    if a.c_sources:
        sys.path.insert(0, str(Path(__file__).parent))
        from mkprotos import c_functions
        for name, addr in c_functions(a.c_sources).items():
            if funcs.get(addr) != name:
                sys.exit(f"error: C function {name} claims address {addr:04X}, "
                         f"which functions.txt calls {funcs.get(addr)!r}")
            replaced.add(name)
    dsyms = {}
    for path in a.data_syms:
        for off, name in read_syms(path).items():
            if off in dsyms and dsyms[off] != name:
                sys.exit(f"error: DGROUP {off:04X} named both {dsyms[off]} and {name}")
            dsyms[off] = name
    dup = {n for n in dsyms.values() if list(dsyms.values()).count(n) > 1}
    if dup:
        sys.exit(f"error: data symbols with several offsets: {sorted(dup)}")

    def fix(region_start, region_end):
        out = {}
        for lin, v in zip(relocs, vals):
            if region_start <= lin < region_end:
                out[lin - region_start] = segs[v]
        return out

    code_labels = {o: f"_{n}" for o, n in funcs.items() if n not in replaced}
    code_jumps = {o: f"_{n}" for o, n in funcs.items() if n in replaced}

    inplace = False
    if a.c_region:
        r0, r1 = (int(x, 16) for x in a.c_region.split(":"))
        in_region = {o: n for o, n in funcs.items() if r0 <= o < r1}
        inplace = all(n in replaced for n in in_region.values()) and r0 in code_jumps
        if not inplace:
            missing = sorted(n for n in in_region.values() if n not in replaced)
            print(f"note: {len(missing)} functions in {a.c_region} still original "
                  f"-> C goes after CRT_TEXT (runs in the harness, NOT in real "
                  f"DeskMate)", file=sys.stderr)
        else:
            code_labels = {o: n for o, n in code_labels.items() if not r0 <= o < r1}
    if inplace:
        seg_decls = ("HM_TEXT   segment word public 'CODE'\nHM_TEXT   ends\n"
                     "HM_PAD    segment byte public 'CODE'\nHM_PAD    ends\n"
                     "TEXT2     segment byte public 'CODE'\nTEXT2     ends\n")
        post_crt = ""
        order = "_TEXT, HM_TEXT, HM_PAD, TEXT2, CRT_TEXT"
    else:
        seg_decls = ""
        post_crt = "HM_TEXT   segment word public 'CODE'\nHM_TEXT   ends\n"
        order = "_TEXT, CRT_TEXT, HM_TEXT"

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
; C code placement: either inside the original application code range
; (--c-region, once all of it is C: exact original segment map), or after
; CRT_TEXT. Never between _TEXT and CRT_TEXT: original runtime code
; near-calls into CRT_TEXT by offset from _TEXT's base (e.g. 0000:44A6).
{seg_decls}CRT_TEXT  segment para public 'CODE'
CRT_TEXT  ends
{post_crt}CGROUP    group {order}
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
    if inplace:
        # _TEXT = original bytes up to the region (plus a jmp at its start,
        # which original code calls), then the C code, filler, and the rest
        # of the original _TEXT exactly at region end.
        L.append("\n_TEXT     segment\n        assume cs:CGROUP")
        emit_bytes(L, img, "code", 0, r0, fix(0, r0), code_labels, {})
        L.append(f"        jmp     near ptr {code_jumps[r0]}            ; {r0:04X} -> C")
        L.append("_TEXT     ends\n\nHM_PAD    segment\n        assume cs:CGROUP")
        if a.pad:
            L.append(f"        db      {a.pad} dup (0CCh)     ; filler so TEXT2 starts at {r1:04X}")
        L.append("HM_PAD    ends\n\nTEXT2     segment\n        assume cs:CGROUP")
        L.append(f"_text2_start label near            ; must be at {r1:04X}")
        L.append("        public  _text2_start")
        emit_bytes(L, img, "code", r1, code_end, fix(0, code_end), code_labels, code_jumps)
        L.append("TEXT2     ends")
    else:
        L.append("\n_TEXT     segment\n        assume cs:CGROUP")
        emit_bytes(L, img, "code", 0, code_end, fix(0, code_end), code_labels, code_jumps)
        L.append("_TEXT     ends")
    L.append("\nCRT_TEXT  segment\n        assume cs:CRT_TEXT")
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
