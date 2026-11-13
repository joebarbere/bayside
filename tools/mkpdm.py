#!/usr/bin/env python3
"""
mkpdm.py -- Turn an OpenWatcom-linked DOS EXE (from pdm2wasm asm + C) into
a DeskMate PDM: rebuild the MZ header in the original's layout with the
DM89 extension block, and derive SS:SP / memory sizes the way the original
expects.

DM89 layout (identical across all 14 DeskMate 3.05 PDMs):
  1C 'DM89'   20 version 003E   22 type 013E   24 0000
  26 CS  28 IP  2A CS          2C..3B 0 (TEXT.PDM uses 30/32)
  3C flags (0101 for HANGMAN)  3E IP  40 CS     42 relocation table
The header is 0x200 bytes like the original.

Stack/memory: the MSC startup does `mov ss,DGROUP; add sp,<const>` with a
constant baked into the original code, so SS:SP must keep the original
distance from DGROUP. minalloc/maxalloc keep the original slack.

Usage:
    tools/mkpdm.py build.exe --orig HANGMAN.PDM -o HANGMAN.PDM [--verify]
--verify: fail unless the load image equals the original byte-for-byte
(only meaningful while no functions are spliced to C).
"""

import argparse
import struct
import sys


def parse(raw):
    (sig, last, pages, nrel, hdrp, minalloc, maxalloc, ss, sp, csum, ip, cs,
     reloff, ovl) = struct.unpack("<2s13H", raw[:28])
    size = pages * 512 - ((512 - last) if last else 0)
    relocs = [struct.unpack("<HH", raw[reloff + 4 * i: reloff + 4 * i + 4])
              for i in range(nrel)]
    return dict(img=raw[hdrp * 16:size], minalloc=minalloc, maxalloc=maxalloc,
                ss=ss, sp=sp, ip=ip, cs=cs, relocs=relocs, ovl=ovl)


def map_segments(path):
    """segment name -> (linear start, size) from a wlink map."""
    out = {}
    for line in open(path):
        f = line.split()
        if len(f) >= 5 and ":" in f[-2]:
            try:
                seg, off = (int(x, 16) for x in f[-2].split(":"))
                out[f[0]] = (seg * 16 + off, int(f[-1], 16))
            except ValueError:
                pass
    return out


def layout_tools(argv):
    """Small link-layout helpers used by the Makefile (not the PDM writer)."""
    ap = argparse.ArgumentParser()
    ap.add_argument("--map", required=True)
    ap.add_argument("--pad-for", metavar="END")
    ap.add_argument("--check-at", metavar="SEG=OFF")
    a = ap.parse_args(argv)
    segs = map_segments(a.map)
    if a.pad_for:
        start, size = segs["HM_TEXT"]
        pad = int(a.pad_for, 16) - (start + size)
        if pad < 0:
            sys.exit(f"error: C code is {-pad} bytes too big for the region ending {a.pad_for}")
        print(pad)
    if a.check_at:
        name, off = a.check_at.split("=")
        if segs[name][0] != int(off, 16):
            sys.exit(f"error: {name} at {segs[name][0]:#x}, expected {off}")


def main():
    if "--pad-for" in sys.argv or "--check-at" in sys.argv:
        return layout_tools(sys.argv[1:])
    ap = argparse.ArgumentParser()
    ap.add_argument("exe")
    ap.add_argument("--orig", required=True)
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--map", help="wlink map file (to place the entry point "
                    "in its own segment, e.g. CRT_TEXT)")
    ap.add_argument("--entry-seg", default="CRT_TEXT")
    ap.add_argument("--verify", action="store_true")
    a = ap.parse_args()

    orig_raw = open(a.orig, "rb").read()
    o = parse(orig_raw)
    n = parse(open(a.exe, "rb").read())

    # DGROUP of the original = the reloc value most used besides 0; ours is
    # found the same way (pdm2wasm keeps reloc sites in the same places).
    def dgroup_of(p):
        vals = [struct.unpack("<H", p["img"][s * 16 + f: s * 16 + f + 2])[0]
                for f, s in p["relocs"]]
        return max(set(v for v in vals if v), key=vals.count)
    o_dg, n_dg = dgroup_of(o), dgroup_of(n)

    # wlink reports the entry as frame 0 (e.g. 0000:4476). The original
    # uses the startup segment as CS (0447:0006) and its code relies on
    # offsets relative to that segment, so re-express it.
    cs_, ip_ = n["cs"], n["ip"]
    if a.map:
        for line in open(a.map):
            f = line.split()
            if len(f) >= 4 and f[0] == a.entry_seg and ":" in f[-2]:
                seg, off = (int(x, 16) for x in f[-2].split(":"))
                base = seg * 16 + off
                if base % 16:
                    sys.exit(f"error: {a.entry_seg} not paragraph aligned")
                lin = cs_ * 16 + ip_
                cs_, ip_ = base // 16, lin - base
    n["cs"], n["ip"] = cs_, ip_

    ss = n_dg + (o["ss"] - o_dg)
    sp = o["sp"]
    img = n["img"]
    # Trailing zeros inside the original BSS/stack area need not be stored:
    # the startup zeroes BSS and the stack is scratch. Never trim below the
    # original initialised data, nor past the original stack top (C data
    # placed after it may legitimately be zero-initialised).
    init_end = n_dg * 16 + (len(o["img"]) - o_dg * 16)
    stack_top = ss * 16 + sp
    if len(img) <= stack_top:
        end = len(img)
        while end > init_end and img[end - 1] == 0:
            end -= 1
        img = img[:end]
    need = max(ss * 16 + sp, len(img))            # bytes from load start
    orig_need = o["ss"] * 16 + o["sp"]
    slack_min = o["minalloc"] - (-(-(orig_need - len(o["img"])) // 16))
    minalloc = max(0, -(-(need - len(img)) // 16) + slack_min)
    maxalloc = minalloc + (o["maxalloc"] - o["minalloc"])

    # Relocation table: keep the original's seg:off form and order. Each
    # original entry is matched to the new one at the same offset within the
    # same region (code / startup / DGROUP), its segment shifted by how far
    # that region moved. New relocations (from C code) are appended.
    o_crt = o["cs"]
    regions_o = [(0, 0), (o_crt, 1), (o_dg, 2)]           # (para, id)
    regions_n = {0: 0, 1: n["cs"], 2: n_dg}
    def region(para_list, lin):
        best = None
        for para, rid in para_list:
            if lin >= para * 16:
                best = (para, rid)
        return best
    new_lin = {s_ * 16 + f_ for f_, s_ in n["relocs"]}
    out_relocs = []
    for f_, s_ in o["relocs"]:
        para, rid = region(regions_o, s_ * 16 + f_)
        delta = regions_n[rid] - para
        cand = (s_ + delta) * 16 + f_
        if cand in new_lin:
            out_relocs.append((f_, s_ + delta))
            new_lin.discard(cand)
    for lin in sorted(new_lin):
        para, rid = region([(0, 0), (n["cs"], 1), (n_dg, 2)], lin)
        out_relocs.append((lin - para * 16, para))
    n["relocs"] = out_relocs

    hdr = bytearray(0x200)
    total = 0x200 + len(img)
    struct.pack_into("<2s13H", hdr, 0, b"MZ", total % 512,
                     (total + 511) // 512, len(n["relocs"]), 0x20,
                     minalloc, maxalloc, ss, sp, 0, n["ip"], n["cs"],
                     0x42, o["ovl"])
    hdr[0x1C:0x42] = orig_raw[0x1C:0x42]
    for off, val in ((0x26, n["cs"]), (0x28, n["ip"]), (0x2A, n["cs"]),
                     (0x3E, n["ip"]), (0x40, n["cs"])):
        struct.pack_into("<H", hdr, off, val)
    if 0x42 + 4 * len(n["relocs"]) > 0x200:
        sys.exit("error: too many relocations for a 0x200 header")
    for i, (f, s) in enumerate(n["relocs"]):
        struct.pack_into("<HH", hdr, 0x42 + 4 * i, f, s)

    with open(a.out, "wb") as fo:
        fo.write(bytes(hdr) + img)

    print(f"wrote {a.out}: image {len(img):#x} bytes, entry {n['cs']:04X}:{n['ip']:04X}, "
          f"SS:SP {ss:04X}:{sp:04X}, min/max {minalloc:#x}/{maxalloc:#x}, "
          f"{len(n['relocs'])} relocs", file=sys.stderr)

    if a.verify:
        new_raw = open(a.out, "rb").read()
        if new_raw == orig_raw:
            print("verify: IDENTICAL to original (header + image)", file=sys.stderr)
            return
        if img == o["img"]:
            print("verify: load image identical; header differs", file=sys.stderr)
            for k in range(0x200):
                if new_raw[k] != orig_raw[k]:
                    print(f"  header[{k:#04x}] {orig_raw[k]:02X} -> {new_raw[k]:02X}",
                          file=sys.stderr)
            sys.exit(1)
        diffs = [k for k in range(min(len(img), len(o["img"])))
                 if img[k] != o["img"][k]]
        print(f"verify: image differs at {len(diffs)} bytes "
              f"(len {len(o['img']):#x} -> {len(img):#x}); first: "
              + ", ".join(f"{k:#06x}" for k in diffs[:10]), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
