#!/usr/bin/env python3
"""
resdis.py -- disassemble DeskMate resource services (DMCSR, DMGUF, PRGUF).

A PDM calls these through a far entry point with AX = service code (see
research/docs/dmcsr-services.md). This tool finds the handler for a code
and disassembles it, so the harness models in tools/pdm_trace.py can be
checked against the real code.

Usage:
    tools/resdis.py DMCSR 13 14 16      # handlers for services 0013h..
    tools/resdis.py PRGUF 23            # dm_keyToChar
    tools/resdis.py DMGUF 23            # says it is forwarded to PRGUF
    tools/resdis.py DMCSR --table       # every service -> handler
    tools/resdis.py DMCSR --at 0000:2A31 --len 200

Addresses are image-relative seg:off as in the file (before relocation).
Disassembly stops at the first ret/retf/jmp after --len bytes or at the
first ret when no --len is given. Capstone prints 0x98/0x99 as cwde/cdq.
"""
import argparse
import struct
from pathlib import Path

from capstone import Cs, CS_ARCH_X86, CS_MODE_16

ROOT = Path(__file__).resolve().parent.parent
EXTRACTED = ROOT / "archive/deskmate-3.05/extracted"

# Where each resource keeps its service jump table, found by reading its
# gateway (see the doc for the walk-through):
#   DMCSR  gateway 0FFD:019F -> 0000:046C: AX&0FFF (max 0151h) indexes a
#          word table at DGROUP(1180):0F31, near handlers in segment 0000.
#   DMGUF  gateway 02BE:0084; local services go through 0000:0005 ->
#          0000:0081: word table at seg [DS:0033] (02B5) + 9. Codes 0022h-
#          0035h (not 0036h), 0000h-0017h, 0019h, 001Ah (specially), AEh
#          and B0h are forwarded to PRGUF.
#   PRGUF  gateway 0155:007E -> 0000:000B: word table at seg [DS:002F]
#          (DS = 0163) + 0Dh.
RESOURCES = {
    "DMCSR": {"file": "DMCSR.R89", "table": lambda img: (0x1180 * 16 + 0x0F31), "max": 0x151,
              "mask": 0x0FFF},
    "DMGUF": {"file": "DMGUF.R89", "table": lambda img: w(img, 0x2D3 * 16 + 0x33) * 16 + 9,
              "max": 0x7F, "mask": 0xFFFF},
    "PRGUF": {"file": "PRGUF.RES", "table": lambda img: w(img, 0x163 * 16 + 0x2F) * 16 + 0x0D,
              "max": 0x7F, "mask": 0xFFFF},
}


def w(img, a):
    return struct.unpack("<H", img[a:a + 2])[0]


def dmguf_forwards(code):
    """DMGUF gateway 02BE:008E: None if DMGUF handles the code itself,
    else a note on how it is passed to PRGUF."""
    if code >= 0x80:
        return "same code" if code in (0xAE, 0xB0) else None
    if code == 0x1A:
        return "as service 0000h; returns 1 if PRGUF's AX >= 0, else 0"
    if code < 0x18 or code == 0x19 or (0x22 <= code and code != 0x36):
        return "same code"
    return None


def load(name):
    raw = (EXTRACTED / RESOURCES[name]["file"]).read_bytes()
    return raw[w(raw, 8) * 16:]


def disasm(img, seg, off, length=None):
    md = Cs(CS_ARCH_X86, CS_MODE_16)
    md.skipdata = True
    base = seg * 16
    out = []
    for i in md.disasm(img[base + off:base + off + (length or 0x400)], off):
        mn = {"cwde": "cbw", "cdq": "cwd"}.get(i.mnemonic, i.mnemonic)
        out.append(f"{seg:04X}:{i.address:04X}  {i.bytes.hex():14s} {mn} {i.op_str}")
        if length is None and mn in ("ret", "retf", "iret"):
            break
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("resource", choices=sorted(RESOURCES))
    ap.add_argument("codes", nargs="*", help="service codes (hex)")
    ap.add_argument("--table", action="store_true", help="list every service handler")
    ap.add_argument("--at", help="disassemble at seg:off instead")
    ap.add_argument("--len", type=lambda x: int(x, 0), help="bytes to disassemble")
    a = ap.parse_args()
    r = RESOURCES[a.resource]
    img = load(a.resource)
    tbl = r["table"](img)

    def handler(code):
        return w(img, tbl + 2 * (code & r["mask"]))

    if a.at:
        seg, off = (int(x, 16) for x in a.at.split(":"))
        print("\n".join(disasm(img, seg, off, a.len)))
        return
    if a.table:
        for c in range(r["max"] + 1):
            fwd = a.resource == "DMGUF" and dmguf_forwards(c)
            h = handler(c)
            if fwd:
                print(f"{c:04X}  -> PRGUF ({fwd})")
            elif h:
                print(f"{c:04X}  0000:{h:04X}")
        return
    for spec in a.codes:
        c = int(spec, 16)
        fwd = a.resource == "DMGUF" and dmguf_forwards(c)
        if fwd:
            print(f"; DMGUF {c:04X}h is forwarded to PRGUF ({fwd}): tools/resdis.py PRGUF {0 if c == 0x1A else c:X}\n")
            continue
        if c > r["max"]:
            print(f"; {a.resource} {c:04X}h: out of range (max {r['max']:04X}h)\n")
            continue
        h = handler(c)
        print(f"; ===== {a.resource} service {c:04X}h -> 0000:{h:04X} =====")
        print("\n".join(disasm(img, 0, h, a.len)))
        print()


if __name__ == "__main__":
    main()
