#!/usr/bin/env python3
"""
dosbox_run.py -- Headless DOSBox-X runner for DeskMate end-to-end checks.

Builds a throwaway run directory (a copy of the original DeskMate files plus
any overlay files, e.g. a rebuilt HANGMAN.PDM), boots DeskMate in DOSBox-X
with no window, records the session to AVI, and extracts PNG frames at the
requested times. The archive/ tree is never modified.

Usage:
    tools/dosbox_run.py NAME [--overlay SRC=DEST ...] [--autotype KEYS]
                        [--cmd "DESK.EXE"] [--seconds 40] [--frames 10,20,39]

Examples:
    # Boot the original and grab the desktop
    tools/dosbox_run.py original --frames 38

    # Drop the rebuilt Hangman in place of the original
    tools/dosbox_run.py rebuilt --overlay build/hangman/HANGMAN.EXE=HANGMAN.PDM

Output lands in build/run/NAME/ (gitignored): run.log, session.avi, f<t>.png.

Requirements: DOSBox-X as `dosbox-x` on PATH or the com.dosbox_x.DOSBox-X
flatpak, plus ffmpeg. The flatpak sandbox cannot see /tmp, so run
directories live under the repo.
"""

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXTRACTED = ROOT / "archive" / "deskmate-3.05" / "extracted"
CONF = ROOT / "dosbox" / "configs" / "deskmate-tandy.conf"


def dosbox_cmd():
    exe = shutil.which("dosbox-x")
    if exe:
        return [exe]
    if shutil.which("flatpak"):
        r = subprocess.run(["flatpak", "info", "com.dosbox_x.DOSBox-X"],
                           capture_output=True)
        if r.returncode == 0:
            return ["flatpak", "run",
                    "--env=SDL_VIDEODRIVER=dummy",
                    "--env=SDL_AUDIODRIVER=dummy",
                    "com.dosbox_x.DOSBox-X"]
    sys.exit("error: DOSBox-X not found (install dosbox-x or the "
             "com.dosbox_x.DOSBox-X flatpak)")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("name", help="run name; output goes to build/run/NAME")
    ap.add_argument("--overlay", action="append", default=[],
                    metavar="SRC=DEST",
                    help="copy SRC (repo-relative) into the run dir as DEST")
    ap.add_argument("--autotype", default=None,
                    help="AUTOTYPE key list typed after boot (DOSBox-X syntax)")
    ap.add_argument("--autotype-wait", type=float, default=15.0,
                    help="seconds before AUTOTYPE starts typing")
    ap.add_argument("--autotype-pace", type=float, default=1.0,
                    help="seconds between AUTOTYPE keys")
    ap.add_argument("--cmd", default="DESK.EXE", help="DOS command to run")
    ap.add_argument("--seconds", type=int, default=40,
                    help="wall-clock limit before DOSBox-X is stopped")
    ap.add_argument("--frames", default="",
                    help="comma-separated times (s) to extract PNG frames at")
    ap.add_argument("--window", action="store_true",
                    help="show the DOSBox-X window instead of running headless")
    args = ap.parse_args()

    run = ROOT / "build" / "run" / args.name
    if run.exists():
        shutil.rmtree(run)
    disk = run / "c"
    cap = run / "cap"
    disk.mkdir(parents=True)
    cap.mkdir()
    for f in EXTRACTED.iterdir():
        shutil.copy2(f, disk / f.name)
    for spec in args.overlay:
        src, _, dest = spec.partition("=")
        if not dest:
            dest = Path(src).name
        shutil.copy2(ROOT / src, disk / dest.upper())
        print(f"overlay: {src} -> C:\\{dest.upper()}")

    cmd = dosbox_cmd()
    if args.window and cmd[0] == "flatpak":
        cmd = [c for c in cmd if not c.startswith("--env=SDL_")]
    cmd += [
        "-conf", str(CONF), "-noautoexec", "-fastlaunch", "-nogui",
        "-time-limit", str(args.seconds),
        "-set", f"dosbox captures={cap}",
        "-c", f"mount c {disk}", "-c", "c:", "-c", "SET DMCONFIG=C:\\",
    ]
    record = not args.window or bool(args.frames)
    if record:
        cmd += ["-c", "config -avistart"]
    if args.autotype:
        cmd += ["-c", f"autotype -w {args.autotype_wait} "
                      f"-p {args.autotype_pace} {args.autotype}"]
    cmd += ["-c", args.cmd]

    with open(run / "run.log", "w") as log:
        subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT,
                       timeout=args.seconds + 60)

    crash = None
    for line in (run / "run.log").read_text(errors="replace").splitlines():
        if line.startswith("E_Exit:"):
            crash = line
    if crash:
        print(f"CRASH:  DOSBox-X aborted -- {crash}")

    if not record:
        print(f"log:    {run / 'run.log'}")
        sys.exit(2 if crash else 0)
    avis = sorted(cap.glob("*.avi"))
    if not avis:
        sys.exit(f"error: no AVI captured; see {run / 'run.log'}")
    avi = run / "session.avi"
    avis[-1].rename(avi)
    print(f"video:  {avi}")
    for t in filter(None, args.frames.split(",")):
        png = run / f"f{t}.png"
        r = subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", t,
                            "-i", str(avi), "-frames:v", "1", str(png)],
                           capture_output=True)
        if r.returncode == 0 and png.exists():
            print(f"frame:  {png}")
        else:
            print(f"frame:  t={t}s unavailable (session ended early?)")
    print(f"log:    {run / 'run.log'}")
    sys.exit(2 if crash else 0)

if __name__ == "__main__":
    main()
