#!/usr/bin/env python3
"""
pdm_trace.py -- Run a DeskMate PDM under Unicorn with a fake DESK.EXE and log
every call it makes across the PDM <-> DeskMate boundary.

Why: a PDM never touches hardware. Everything it does goes through
  * INT E0h            -- DESK.EXE services (load/unload/query resources, ...)
  * far calls          -- into resource entry points (PRGUF, DMGUF, DMCSR,
                          SPELL...) that INT E0h AX=0206h hands back
  * INT 21h            -- plain DOS (memory, files, exit)
If the rebuilt PDM produces the same boundary trace as the original for the
same scripted input, it behaves the same. Diffing traces is fast (seconds),
needs no graphics, and points at the first call where behaviour diverges.

How it works:
  * The MZ image is loaded and relocated like DOS would, with a PSP in front.
  * INT E0h AX=0206h writes a far pointer to a per-resource *trap segment*
    into ES:BX. Each trap segment is filled with `INT F0h; RETF`, so any far
    call into a resource lands in our INT F0h hook (which logs it and sets
    the return value) and then returns to the PDM normally.
  * Return values come from a small policy table (RESOURCE_RETURNS) and an
    optional input script for event-fetch calls. Unknown calls return 0.

Usage:
    tools/pdm_trace.py archive/deskmate-3.05/extracted/HANGMAN.PDM \
        [-o trace.jsonl] [--max-insns N] [--script events.json] [-v]

Output: one JSON object per line (see TraceEvent below); a human-readable
summary goes to stderr.
"""

import argparse
import json
import struct
import sys
from dataclasses import dataclass, field

from unicorn import (Uc, UcError, UC_ARCH_X86, UC_MODE_16,
                     UC_HOOK_INTR, UC_HOOK_CODE)
from unicorn.x86_const import (
    UC_X86_REG_AX, UC_X86_REG_BX, UC_X86_REG_CX, UC_X86_REG_DX,
    UC_X86_REG_SI, UC_X86_REG_DI, UC_X86_REG_BP, UC_X86_REG_SP,
    UC_X86_REG_IP, UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES,
    UC_X86_REG_SS, UC_X86_REG_FLAGS)

MEM_SIZE = 0x100000          # 1 MB real-mode address space
PSP_SEG = 0x1000             # where the fake DOS puts the PSP
ENV_SEG = 0x0F00             # environment block
TOP_OF_MEM = 0x9FFF          # PSP:[2] -- last paragraph available
TRAP_BASE_SEG = 0xE000       # resource trap segments: E000, E100, ...
TRAP_INT = 0xF0
TRAP_SLOTS = 0x400           # INT F0h;RETF stubs per trap segment
CF = 0x0001

REGS = {"ax": UC_X86_REG_AX, "bx": UC_X86_REG_BX, "cx": UC_X86_REG_CX,
        "dx": UC_X86_REG_DX, "si": UC_X86_REG_SI, "di": UC_X86_REG_DI,
        "bp": UC_X86_REG_BP, "sp": UC_X86_REG_SP, "ds": UC_X86_REG_DS,
        "es": UC_X86_REG_ES, "ss": UC_X86_REG_SS}

# Default return values for resource calls, keyed by (resource, AX).
# Anything not listed returns AX=0. Grow this as the trace reveals what the
# PDM needs to make progress -- each entry is a documented fact about the
# DeskMate API, so annotate where it came from.
RESOURCE_RETURNS = {
}

# Where the C-level arguments of a resource call live when control reaches
# the resource, as (register, byte offset) relative to SS.
#   PRGUF/DMGUF gateway (HANGMAN 0000:32CA): push [1cc3]; push ret; push bx;
#     mov bx,sp -> args at SS:BX+6
#   DMCSR gateway (HANGMAN 0000:345A): push bp; mov bp,sp; add bp,4
#     -> args at SS:BP
FRAME_SOURCE = {
    "DMCSR": ("bp", 0),
}
FRAME_WORDS = 8
IDLE_WINDOW = 200
IDLE_KINDS = 4

# INT E0h service return values (AX) not handled specially below.
INT_E0_RETURNS = {
    0x0208: 1,   # query resource: >0 means present (HANGMAN 0000:320B)
}


def num(v):
    return int(v, 0) if isinstance(v, str) else int(v)


class Stop(Exception):
    pass


@dataclass
class TraceEvent:
    seq: int
    kind: str                 # "int21" | "inte0" | "call" | "int" | "exit"
    name: str                 # resource name / DOS fn label
    ax: int
    regs: dict
    frame: list = field(default_factory=list)   # words at SS:BX (calls)
    strings: dict = field(default_factory=dict) # decoded string args
    ret: int | None = None
    caller: str = ""          # CS:IP of the far call / INT site


class PdmTracer:
    def __init__(self, path, max_insns, script=None, verbose=False):
        self.path = path
        self.max_insns = max_insns
        self.verbose = verbose
        self.events = []
        self.resources = {}       # trap seg -> name
        self.res_by_name = {}     # name -> trap seg
        self.open_files = {}      # handle -> (name, data, pos)
        self.next_handle = 5
        self.script = list(script or [])
        self.exit_code = None
        self.recent = []
        self.uc = Uc(UC_ARCH_X86, UC_MODE_16)
        self.uc.mem_map(0, MEM_SIZE)
        self._load()
        self.uc.hook_add(UC_HOOK_INTR, self._on_int)

    # ---- memory helpers ------------------------------------------------
    def rd(self, seg, off, n):
        return bytes(self.uc.mem_read(((seg << 4) + off) & 0xFFFFF, n))

    def wr(self, seg, off, data):
        self.uc.mem_write(((seg << 4) + off) & 0xFFFFF, bytes(data))

    def rw(self, seg, off):
        return struct.unpack("<H", self.rd(seg, off, 2))[0]

    def ww(self, seg, off, v):
        self.wr(seg, off, struct.pack("<H", v & 0xFFFF))

    def asciiz(self, seg, off, limit=128):
        raw = self.rd(seg, off, limit)
        end = raw.find(b"\0")
        return raw[: end if end >= 0 else limit]

    def reg(self, r):
        return self.uc.reg_read(REGS[r])

    def setreg(self, r, v):
        self.uc.reg_write(REGS[r], v & 0xFFFF)

    def set_cf(self, on):
        fl = self.uc.reg_read(UC_X86_REG_FLAGS)
        self.uc.reg_write(UC_X86_REG_FLAGS, (fl | CF) if on else (fl & ~CF))

    def snapshot(self):
        return {r: self.reg(r) for r in REGS}

    # ---- loader ----------------------------------------------------------
    def _load(self):
        data = open(self.path, "rb").read()
        (sig, last, pages, nrel, hdrp, minalloc, maxalloc, ss, sp, _csum,
         ip, cs, reloff, _ovl) = struct.unpack("<2s13H", data[:28])
        if sig not in (b"MZ", b"ZM"):
            raise SystemExit(f"{self.path}: not an MZ executable")
        size = pages * 512 - ((512 - last) if last else 0)
        image = data[hdrp * 16: size]
        self.dm89 = data[0x1C:0x20] == b"DM89"
        if self.dm89:
            # DM89 CS:IP at 0x26/0x28 is authoritative (README, DM89 table)
            cs, ip = struct.unpack("<HH", data[0x26:0x2A])
        load = PSP_SEG + 0x10
        self.load_seg = load
        self.wr(load, 0, image)
        for i in range(nrel):
            off, seg = struct.unpack("<HH", data[reloff + 4 * i: reloff + 4 * i + 4])
            self.ww(load + seg, off, self.rw(load + seg, off) + load)

        # PSP
        self.wr(PSP_SEG, 0, b"\xCD\x20")
        self.ww(PSP_SEG, 2, TOP_OF_MEM)
        self.ww(PSP_SEG, 0x2C, ENV_SEG)
        self.wr(PSP_SEG, 0x80, b"\x00\x0D")
        self.wr(ENV_SEG, 0, b"DMCONFIG=C:\\\0COMSPEC=C:\\COMMAND.COM\0\0"
                            b"\x01\x00C:\\HANGMAN.PDM\0")

        # Trap segments are allocated lazily per resource; IVT entry for
        # INT F0h is irrelevant because UC_HOOK_INTR intercepts first.
        self.uc.reg_write(UC_X86_REG_CS, load + cs)
        self.uc.reg_write(UC_X86_REG_IP, ip)
        self.uc.reg_write(UC_X86_REG_SS, load + ss)
        self.uc.reg_write(UC_X86_REG_SP, sp)
        self.uc.reg_write(UC_X86_REG_DS, PSP_SEG)
        self.uc.reg_write(UC_X86_REG_ES, PSP_SEG)
        self.entry = (load + cs, ip)
        print(f"loaded {self.path}: {len(image)} bytes at {load:04X}:0000, "
              f"entry {load + cs:04X}:{ip:04X} (DM89={'yes' if self.dm89 else 'no'}), "
              f"{nrel} relocs", file=sys.stderr)

    def trap_for(self, name):
        if name in self.res_by_name:
            return self.res_by_name[name]
        seg = TRAP_BASE_SEG + 0x100 * len(self.resources)
        stub = b"\xCD" + bytes([TRAP_INT]) + b"\xCB\x90"
        self.wr(seg, 0, stub * TRAP_SLOTS)
        self.resources[seg] = name
        self.res_by_name[name] = seg
        return seg

    # ---- tracing ---------------------------------------------------------
    def caller_addr(self, back=2):
        cs = self.uc.reg_read(UC_X86_REG_CS)
        ip = self.uc.reg_read(UC_X86_REG_IP)
        return f"{cs - self.load_seg:04X}:{(ip - back) & 0xFFFF:04X}"

    def emit(self, ev):
        ev.seq = len(self.events)
        self.events.append(ev)
        if self.verbose:
            print(self.fmt(ev), file=sys.stderr)
        # Idle detection: the last IDLE_WINDOW events use <= IDLE_KINDS
        # distinct calls (e.g. GetEvent/Yield ping-pong waiting for input).
        key = (ev.kind, ev.name, ev.ax, tuple(ev.frame))
        self.recent.append(key)
        if len(self.recent) > IDLE_WINDOW:
            self.recent.pop(0)
            if len(set(self.recent)) <= IDLE_KINDS:
                # trim the idle tail down to one period for a stable golden
                period = len(set(self.recent))
                del self.events[len(self.events) - IDLE_WINDOW + period:]
                raise Stop(f"idle: waiting for input in a {period}-call loop "
                           f"({', '.join(f'{k[1]}:{k[2]:04X}' for k in dict.fromkeys(self.recent))})")

    @staticmethod
    def fmt(ev):
        s = f"[{ev.seq:5d}] {ev.caller:>9s} {ev.kind:5s} {ev.name:8s} AX={ev.ax:04X}"
        if ev.frame:
            s += " frame=" + " ".join(f"{w:04X}" for w in ev.frame)
        if ev.strings:
            s += " " + " ".join(f"{k}={v!r}" for k, v in ev.strings.items())
        if ev.ret is not None:
            s += f" -> {ev.ret:04X}"
        return s

    def string_args(self, seg, words):
        """Heuristic: decode words that look like DS-relative ASCIIZ pointers."""
        out = {}
        for i, w in enumerate(words):
            if w < 0x10:
                continue
            raw = self.asciiz(seg, w, 64)
            starts_string = self.rd(seg, w - 1, 1)[0] == 0
            if starts_string and len(raw) >= 3 and all(32 <= c < 127 for c in raw):
                out[f"s{i}"] = raw.decode("ascii")
        return out

    # ---- interrupt dispatch ---------------------------------------------
    def _on_int(self, uc, intno, _ud):
        try:
            if intno == TRAP_INT:
                self.on_resource_call()
            elif intno == 0xE0:
                self.on_int_e0()
            elif intno == 0x21:
                self.on_int21()
            else:
                ax = self.reg("ax")
                self.emit(TraceEvent(0, "int", f"INT{intno:02X}", ax,
                                     self.snapshot(), caller=self.caller_addr()))
        except Stop as e:
            self.stop_reason = str(e)
            uc.emu_stop()

    def on_resource_call(self):
        cs = self.uc.reg_read(UC_X86_REG_CS)
        ip = self.uc.reg_read(UC_X86_REG_IP)
        name = self.resources.get(cs, f"?{cs:04X}")
        ax, ss = self.reg("ax"), self.reg("ss")
        # Where the PDM-side glue leaves the C arguments differs per gateway
        # (see FRAME_SOURCE). Log the C argument words, not glue scratch.
        reg, skip = FRAME_SOURCE.get(name, ("bx", 6))
        base = self.reg(reg) + skip
        frame = [self.rw(ss, base + 2 * i) for i in range(FRAME_WORDS)]
        # caller = far return address on the stack
        sp = self.reg("sp")
        ret_ip, ret_cs = self.rw(ss, sp), self.rw(ss, sp + 2)
        caller = f"{ret_cs - self.load_seg:04X}:{ret_ip:04X}"
        ev = TraceEvent(0, "call", name, ax, self.snapshot(), frame=frame,
                        strings=self.string_args(self.reg("ds"), frame),
                        caller=caller)
        ev.slot = (ip - 2) // 4
        ret = self.resource_return(name, ax, ev)
        ev.ret = ret
        self.setreg("ax", ret)
        self.emit(ev)

    def resource_return(self, name, ax, ev):
        """Scripted input first (in order), then the static policy table.

        Script steps: {"on": ["DMCSR", "0xE4"], "ret": "0xF56E",
                       "after": 3, "note": "..."}
        A step fires on the (after+1)-th matching call once it reaches the
        head of the script. Numbers may be ints or hex strings.
        """
        if self.script:
            step = self.script[0]
            want_name, want_ax = step["on"]
            if want_name == name and num(want_ax) == ax:
                left = num(step.get("after", 0))
                if left > 0:
                    step["after"] = left - 1
                else:
                    self.script.pop(0)
                    ev.strings["script"] = step.get("note", "")
                    return num(step.get("ret", 0))
        return RESOURCE_RETURNS.get((name, ax), 0)

    def on_int_e0(self):
        ax = self.reg("ax")
        ev = TraceEvent(0, "inte0", "DESK", ax, self.snapshot(),
                        caller=self.caller_addr())
        ret = INT_E0_RETURNS.get(ax, 0)
        if ax in (0x0206, 0x0207, 0x0208):
            name = self.asciiz(self.reg("ds"), self.reg("dx"), 16).decode("ascii", "replace")
            ev.name = name
            ev.strings = {"res": name}
            if ax == 0x0206:
                seg = self.trap_for(name)
                es, bx = self.reg("es"), self.reg("bx")
                self.ww(es, bx, 0)       # offset 0 of the trap segment
                self.ww(es, bx + 2, seg)
                ret = 1
        ev.ret = ret
        self.setreg("ax", ret)
        self.emit(ev)

    # ---- minimal DOS -----------------------------------------------------
    def on_int21(self):
        ah = self.reg("ax") >> 8
        al = self.reg("ax") & 0xFF
        ev = TraceEvent(0, "int21", f"21/{ah:02X}", self.reg("ax"),
                        self.snapshot(), caller=self.caller_addr())
        ret = None
        self.set_cf(False)
        if ah == 0x30:                       # DOS version -> 3.30
            ret = 0x1E03
        elif ah == 0x4A:                     # resize block: always succeeds
            ev.strings = {"paras": f"{self.reg('bx'):04X}"}
        elif ah == 0x48:                     # alloc: deny (no heap model yet)
            ret = 8
            self.setreg("bx", 0)
            self.set_cf(True)
        elif ah in (0x25,):                  # set vector
            pass
        elif ah == 0x35:                     # get vector
            self.setreg("es", 0)
            self.setreg("bx", 0)
        elif ah == 0x2A:                     # date: fixed for reproducibility
            self.setreg("cx", 1990)
            self.setreg("dx", 0x0101)
            ret = (self.reg("ax") & 0xFF00) | 1
        elif ah == 0x2C:                     # time: fixed
            self.setreg("cx", 0x0C00)
            self.setreg("dx", 0)
        elif ah == 0x3D:                     # open: no files yet -> not found
            fn = self.asciiz(self.reg("ds"), self.reg("dx")).decode("ascii", "replace")
            ev.strings = {"file": fn}
            ret = 2
            self.set_cf(True)
        elif ah == 0x40:                     # write
            data = self.rd(self.reg("ds"), self.reg("dx"), self.reg("cx"))
            ev.strings = {"h": self.reg("bx"), "data": data.decode("latin-1")}
            ret = self.reg("cx")
        elif ah == 0x44:                     # ioctl: report char device
            self.setreg("dx", 0x80)
        elif ah == 0x4C:
            self.exit_code = al
            ev.kind = "exit"
            self.emit(ev)
            raise Stop(f"program exited via INT 21h/4Ch code {al}")
        else:
            ev.strings = {"unhandled": True}
        if ret is not None:
            self.setreg("ax", ret)
            ev.ret = ret
        self.emit(ev)

    # ---- run -------------------------------------------------------------
    def run(self):
        self.stop_reason = None
        self.insns = 0

        def count(uc, addr, size, _):
            self.insns += 1
            if self.insns >= self.max_insns:
                self.stop_reason = f"instruction budget ({self.max_insns}) exhausted"
                uc.emu_stop()
        self.uc.hook_add(UC_HOOK_CODE, count)
        cs, ip = self.entry
        try:
            self.uc.emu_start((cs << 4) + ip, 0xFFFFF + 1)
        except UcError as e:
            cs = self.uc.reg_read(UC_X86_REG_CS)
            ip = self.uc.reg_read(UC_X86_REG_IP)
            self.stop_reason = (f"CPU fault {e} at {cs - self.load_seg:04X}:{ip:04X} "
                                f"(abs {cs:04X}:{ip:04X})")
        return self.stop_reason


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("pdm")
    ap.add_argument("-o", "--out", help="write JSONL trace here")
    ap.add_argument("--max-insns", type=int, default=5_000_000)
    ap.add_argument("--script", help="JSON list of scripted resource returns")
    ap.add_argument("-t", "--trace", help="write normalized text trace here "
                    "(diffable golden file)")
    ap.add_argument("--no-frames", dest="frames", action="store_false",
                    help="omit argument frames from the text trace")
    ap.add_argument("-v", "--verbose", action="store_true",
                    help="print every event to stderr as it happens")
    args = ap.parse_args()

    script = json.load(open(args.script)) if args.script else None
    t = PdmTracer(args.pdm, args.max_insns, script, args.verbose)
    reason = t.run()
    print(f"stopped after {t.insns} instructions, {len(t.events)} events: {reason}",
          file=sys.stderr)
    if args.trace:
        with open(args.trace, "w") as f:
            for ev in t.events:
                f.write(normalize(ev, args.frames) + "\n")
            f.write(f"# end: {'exit' if t.exit_code is not None else 'idle' if (reason or '').startswith('idle') else reason}\n")
    if args.out:
        with open(args.out, "w") as f:
            for ev in t.events:
                d = dict(ev.__dict__)
                f.write(json.dumps(d) + "\n")
    if not args.verbose:
        for line in collapse(PdmTracer.fmt(ev) for ev in t.events[-40:]):
            print(line, file=sys.stderr)


def normalize(ev, frames=True):
    """Stable one-line form for golden files: no seq numbers or code
    addresses (those legitimately differ in a rebuilt binary)."""
    s = f"{ev.kind:5s} {ev.name:8s} {ev.ax:04X}"
    if frames and ev.frame:
        s += " [" + " ".join(f"{w:04X}" for w in ev.frame) + "]"
    strs = {k: v for k, v in ev.strings.items() if k != "script"}
    if strs:
        s += " " + " ".join(f"{k}={v!r}" for k, v in strs.items())
    if ev.ret is not None:
        s += f" -> {ev.ret:04X}"
    if "script" in ev.strings:
        s += f"   # script: {ev.strings['script']}"
    return s


def collapse(lines):
    """Fold runs of identical events (ignoring the seq number) into one line."""
    prev, n, first = None, 0, None
    for line in list(lines) + [None]:
        key = line[8:] if line else None
        if key == prev:
            n += 1
            continue
        if first is not None:
            yield first + (f"   (x{n})" if n > 1 else "")
        prev, n, first = key, 1, line


if __name__ == "__main__":
    main()
