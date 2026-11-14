#!/usr/bin/env python3
"""
disfn.py -- Disassemble original HANGMAN.PDM functions for translation.

Prints each requested function (by name or hex address) from its entry to
the next known function, with call targets resolved to names, data offsets
annotated from the *.syms files, `add sp,N` after calls shown as arg counts,
and jump tables (`jmp cs:[bx+T]`) decoded.

Usage:
    tools/disfn.py hangman_playRound
    tools/disfn.py 0795 0B79 --pdm archive/deskmate-3.05/extracted/HANGMAN.PDM
Notes: Capstone prints 0x98/0x99 as cwde/cdq in 16-bit mode; they are
CBW/CWD. Bytes that are data inside code (jump tables) disassemble as junk;
use the decoded table instead.
"""
import argparse
import re
import struct
from pathlib import Path

from capstone import Cs, CS_ARCH_X86, CS_MODE_16

ROOT = Path(__file__).resolve().parent.parent
HM = ROOT / "src" / "hangman"


def syms(path):
    out = {}
    for line in open(path):
        line = line.split("#")[0].strip()
        if line:
            a, n = line.split()[:2]
            out[int(a, 16)] = n
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("funcs", nargs="+")
    ap.add_argument("--pdm", default=str(ROOT / "archive/deskmate-3.05/extracted/HANGMAN.PDM"))
    a = ap.parse_args()
    raw = open(a.pdm, "rb").read()
    img = raw[struct.unpack("<H", raw[8:10])[0] * 16:]
    funcs = syms(HM / "functions.txt")
    by_name = {v: k for k, v in funcs.items()}
    data = {}
    for f in HM.glob("*.syms"):
        data.update(syms(f))
    addrs = sorted(funcs)
    md = Cs(CS_ARCH_X86, CS_MODE_16)
    md.skipdata = True

    for spec in a.funcs:
        start = by_name[spec] if spec in by_name else int(spec, 16)
        end = next((x for x in addrs if x > start), start + 0x100)
        print(f"; ===== {funcs.get(start, '?')} {start:04X}-{end:04X} =====")
        insns = list(md.disasm(img[start:end], start))
        for k, i in enumerate(insns):
            mn = {"cwde": "cbw", "cdq": "cwd"}.get(i.mnemonic, i.mnemonic)
            ops = i.op_str
            note = ""
            m = re.fullmatch(r"0x([0-9a-f]+)", ops)
            if mn == "call" and m:
                t = int(m.group(1), 16)
                ops = funcs.get(t, ops)
                nxt = insns[k + 1] if k + 1 < len(insns) else None
                if nxt and nxt.mnemonic == "add" and nxt.op_str.startswith("sp, "):
                    note = f"  ({int(nxt.op_str[4:], 0) // 2} args)"
            for v in re.findall(r"0x([0-9a-f]+)", ops):
                if int(v, 16) in data:
                    note += f"  [{int(v,16):04X}={data[int(v,16)]}]"
            m2 = re.search(r"cs:\[bx \+ 0x([0-9a-f]+)\]", ops)
            if mn == "jmp" and m2:
                t = int(m2.group(1), 16)
                ents = []
                for j in range(64):
                    tgt = struct.unpack("<H", img[t + 2 * j: t + 2 * j + 2])[0]
                    if not (start <= tgt < end):
                        break
                    ents.append(f"{j}:{tgt:04X}")
                note += "  table: " + " ".join(ents)
            print(f"{i.address:04X}  {mn} {ops}{note}")
        print()


if __name__ == "__main__":
    main()
