#!/usr/bin/env zsh
# setup-watcom.sh — Install and configure OpenWatcom V2 for DOS 16-bit cross-compilation
#
# Target: C89 source -> 16-bit DOS MZ EXE, medium memory model, 8086 real mode
# Host:   macOS (Apple Silicon arm64 or Intel x86_64)
#
# Usage:
#   source scripts/setup-watcom.sh          # set env vars in current shell
#   scripts/setup-watcom.sh --install       # download and install OpenWatcom
#   scripts/setup-watcom.sh --install --dir /opt/watcom
#
# After sourcing this script, compile with:
#   owcc -bdos -mcmodel=m -std=c89 -W4 -o myprogram.exe myprogram.c
# Or with wcc directly:
#   wcc -mm -0 -za -w4 -fo=myprogram.obj myprogram.c
#   wlink system dos name myprogram.exe file myprogram.obj

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

WATCOM_DEFAULT_DIR="$HOME/watcom"
WATCOM_SNAPSHOT_URL="https://github.com/open-watcom/open-watcom-v2/releases/download/Current-build/ow-snapshot.tar.xz"

# Detect host architecture: arm64 (Apple Silicon) or x86_64 (Intel Mac)
HOST_ARCH="$(uname -m)"
case "$HOST_ARCH" in
    arm64)   WATCOM_BIN_DIR="armo64" ;;   # Apple Silicon M1/M2/M3/M4
    x86_64)  WATCOM_BIN_DIR="binm"   ;;   # Intel Mac (64-bit host tools in binm)
    *)
        echo "ERROR: Unknown host architecture: $HOST_ARCH" >&2
        echo "       OpenWatcom provides 'armo64' (ARM64) and 'binm' (x86_64) host toolchains." >&2
        return 1 2>/dev/null || exit 1
        ;;
esac

# ---------------------------------------------------------------------------
# Helper: print usage
# ---------------------------------------------------------------------------
_watcom_usage() {
    cat <<'EOF'
OpenWatcom V2 Setup for Bayside (Tandy DeskMate reconstruction)

USAGE:
  source scripts/setup-watcom.sh              Set env vars only (WATCOM must exist)
  scripts/setup-watcom.sh --install           Download and install to ~/watcom
  scripts/setup-watcom.sh --install --dir DIR Install to DIR instead of /opt/watcom
  scripts/setup-watcom.sh --check             Verify installation and print tool versions
  scripts/setup-watcom.sh --help              Show this message

WHAT GETS INSTALLED:
  The ow-snapshot.tar.xz from the OpenWatcom V2 Current-build release (~145 MB)
  is downloaded and extracted. Only the directories needed for macOS -> DOS 16-bit
  cross-compilation are kept:

    $WATCOM/armo64/   (or binm/ on Intel)  — host compiler/linker executables
    $WATCOM/h/                              — C runtime headers (host-independent)
    $WATCOM/h/sys/                          — POSIX headers
    $WATCOM/lib286/                         — 16-bit DOS libraries
    $WATCOM/lib286/dos/                     — DOS-specific 16-bit libs
    $WATCOM/eddat/                          — Editor/tool support data

COMPILATION (after sourcing this script):

  High-level driver (recommended):
    owcc -bdos -mcmodel=m -std=c89 -W4 -o program.exe program.c

  Low-level (wcc + wlink separately):
    wcc  -mm -0 -za -w4 -fo=program.obj program.c
    wlink system dos name program.exe file program.obj

  Key flags:
    -bdos        target DOS (owcc)
    -mcmodel=m   medium memory model: near data, far code (owcc)
    -mm          medium memory model (wcc)
    -0           generate 8086 instructions only (wcc)
    -za          strict ANSI/C89 (wcc)
    -std=c89     C89 standard (owcc)
    -W4 / -w4    warning level 4

MEMORY MODEL NOTE:
  Medium model (-mm / -mcmodel=m) gives:
    - Near data (64KB DS), far code (multiple code segments)
  This matches the DeskMate .PDM module pattern where code can span segments
  but data is accessed near. For DESK.EXE itself, large model (-ml) may be
  needed once the code grows past one segment.

ENVIRONMENT VARIABLES SET:
  WATCOM    — root of OpenWatcom installation
  PATH      — prepends $WATCOM/$WATCOM_BIN_DIR
  INCLUDE   — $WATCOM/h;$WATCOM/h/sys  (semicolon-separated, DOS convention)
  EDDAT     — $WATCOM/eddat
EOF
}

# ---------------------------------------------------------------------------
# Helper: download and install
# ---------------------------------------------------------------------------
_watcom_install() {
    local install_dir="$1"

    echo "=== OpenWatcom V2 Installer for macOS ==="
    echo "    Host arch : $HOST_ARCH ($WATCOM_BIN_DIR)"
    echo "    Install to: $install_dir"
    echo ""

    # Create install directory
    if [[ ! -d "$install_dir" ]]; then
        echo "Creating $install_dir ..."
        mkdir -p "$install_dir" 2>/dev/null
        if [[ $? -ne 0 ]]; then
            echo "  Permission denied. Trying with sudo..."
            sudo mkdir -p "$install_dir"
            sudo chown "$(whoami)" "$install_dir"
        fi
    fi

    # Check available disk space (need ~500 MB for extraction, ~200 MB final)
    local free_kb
    free_kb=$(df -k "$install_dir" 2>/dev/null | awk 'NR==2{print $4}')
    if [[ -n "$free_kb" && "$free_kb" -lt 512000 ]]; then
        echo "WARNING: Less than 512 MB free in $install_dir. Extraction may fail." >&2
    fi

    # Download the snapshot
    local snapshot_file="$install_dir/ow-snapshot.tar.xz"
    if [[ -f "$snapshot_file" ]]; then
        echo "Snapshot already downloaded: $snapshot_file"
        echo "  (Delete it to re-download)"
    else
        echo "Downloading OpenWatcom V2 snapshot (~145 MB)..."
        echo "  From: $WATCOM_SNAPSHOT_URL"
        echo "  To  : $snapshot_file"
        if command -v curl >/dev/null 2>&1; then
            curl -L --progress-bar -o "$snapshot_file" "$WATCOM_SNAPSHOT_URL"
        elif command -v wget >/dev/null 2>&1; then
            wget -O "$snapshot_file" "$WATCOM_SNAPSHOT_URL"
        else
            echo "ERROR: Neither curl nor wget found. Install one and retry." >&2
            return 1
        fi
        if [[ $? -ne 0 || ! -s "$snapshot_file" ]]; then
            echo "ERROR: Download failed." >&2
            rm -f "$snapshot_file"
            return 1
        fi
        echo "Download complete."
    fi

    # Probe snapshot root to determine tar path prefix style
    echo ""
    echo "Probing snapshot structure..."
    local snapshot_root
    snapshot_root=$(tar -tJf "$snapshot_file" 2>/dev/null | head -1 | cut -d/ -f1)
    echo "  Snapshot root prefix: '$snapshot_root'"

    # Extract only the directories we need for macOS -> 16-bit DOS cross-compilation.
    # The Current-build snapshot uses a flat layout with a leading './' prefix on each
    # entry (e.g. ./armo64/wcc, ./h/stdio.h, ./lib286/dos/clibc.lib).
    # We pass each needed subtree as a path argument, matching the archive prefix style.
    echo "Extracting needed directories..."
    echo "  ($WATCOM_BIN_DIR, h, lib286, eddat)"

    local need_dirs=("$WATCOM_BIN_DIR" "h" "lib286" "eddat")
    local tar_paths=()

    # Determine whether archive entries start with './' or with the root prefix directly
    local prefix=""
    if [[ "$snapshot_root" == "." ]]; then
        prefix="./"
    elif [[ -n "$snapshot_root" && "$snapshot_root" != "$WATCOM_BIN_DIR" ]]; then
        # Rooted under a single directory — use --strip-components=1 with prefixed paths
        prefix="$snapshot_root/"
    fi

    for d in "${need_dirs[@]}"; do
        tar_paths+=("${prefix}${d}")
    done

    if [[ -n "$snapshot_root" && "$snapshot_root" != "." && "$snapshot_root" != "$WATCOM_BIN_DIR" ]]; then
        tar -xJf "$snapshot_file" --strip-components=1 -C "$install_dir" "${tar_paths[@]}" 2>/dev/null
    else
        tar -xJf "$snapshot_file" -C "$install_dir" "${tar_paths[@]}" 2>/dev/null
    fi

    # Fallback: extract everything if the targeted extract failed
    if [[ ! -d "$install_dir/$WATCOM_BIN_DIR" ]]; then
        echo "  Selective extraction did not find $WATCOM_BIN_DIR/, trying full extract..."
        if [[ -n "$snapshot_root" && "$snapshot_root" != "." && "$snapshot_root" != "$WATCOM_BIN_DIR" ]]; then
            tar -xJf "$snapshot_file" --strip-components=1 -C "$install_dir" 2>/dev/null
        else
            tar -xJf "$snapshot_file" -C "$install_dir" 2>/dev/null
        fi
    fi

    if [[ ! -d "$install_dir/$WATCOM_BIN_DIR" ]]; then
        echo "ERROR: Extraction failed — $install_dir/$WATCOM_BIN_DIR not found." >&2
        echo "       The snapshot structure may have changed. Try manual extraction:" >&2
        echo "         tar -xJf $snapshot_file -C $install_dir" >&2
        echo "       Then find where wcc/owcc landed and update WATCOM_BIN_DIR." >&2
        return 1
    fi

    # Make binaries executable
    chmod +x "$install_dir/$WATCOM_BIN_DIR"/* 2>/dev/null

    # Optionally remove the snapshot archive to save ~145 MB
    echo ""
    echo "Installation complete. Remove snapshot to save ~145 MB?"
    echo "  rm $snapshot_file"

    echo ""
    echo "=== Installation successful ==="
    echo ""
    echo "Now activate the environment:"
    echo "  source scripts/setup-watcom.sh"
    echo ""
    echo "Or add to your shell profile (~/.zshrc):"
    echo "  source /Users/$(whoami)/Documents/GitHub/bayside/scripts/setup-watcom.sh"
}

# ---------------------------------------------------------------------------
# Helper: verify installation
# ---------------------------------------------------------------------------
_watcom_check() {
    local watcom_root="${WATCOM:-$WATCOM_DEFAULT_DIR}"

    echo "=== OpenWatcom V2 Installation Check ==="
    echo "    WATCOM     : ${WATCOM:-<not set>}"
    echo "    Host arch  : $HOST_ARCH ($WATCOM_BIN_DIR)"
    echo ""

    local ok=1

    # Check directories
    for d in "$WATCOM_BIN_DIR" "h" "lib286" "lib286/dos"; do
        if [[ -d "$watcom_root/$d" ]]; then
            echo "  [OK] $watcom_root/$d"
        else
            echo "  [MISSING] $watcom_root/$d"
            ok=0
        fi
    done

    echo ""

    # Check key executables
    for tool in owcc wcc wlink wmake; do
        local tool_path="$watcom_root/$WATCOM_BIN_DIR/$tool"
        if [[ -x "$tool_path" ]]; then
            echo "  [OK] $tool_path"
            # Print version for owcc/wcc
            if [[ "$tool" == "wcc" ]]; then
                "$tool_path" --version 2>/dev/null | head -1 | sed 's/^/         /'
            fi
        else
            echo "  [MISSING] $tool_path"
            ok=0
        fi
    done

    echo ""

    # Check if tools are in PATH
    if command -v wcc >/dev/null 2>&1; then
        echo "  [OK] wcc is in PATH: $(command -v wcc)"
    else
        echo "  [NOTE] wcc not in PATH — run: source scripts/setup-watcom.sh"
    fi

    echo ""
    if [[ $ok -eq 1 ]]; then
        echo "Installation looks good."
    else
        echo "Installation incomplete. Run: scripts/setup-watcom.sh --install"
    fi
}

# ---------------------------------------------------------------------------
# Main: parse arguments
# ---------------------------------------------------------------------------
_watcom_main() {
    local do_install=0
    local do_check=0
    local install_dir="$WATCOM_DEFAULT_DIR"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --install)  do_install=1 ;;
            --check)    do_check=1 ;;
            --help|-h)  _watcom_usage; return 0 ;;
            --dir)      shift; install_dir="$1" ;;
            --dir=*)    install_dir="${1#--dir=}" ;;
            *)
                echo "Unknown option: $1" >&2
                _watcom_usage >&2
                return 1
                ;;
        esac
        shift
    done

    if [[ $do_install -eq 1 ]]; then
        _watcom_install "$install_dir"
        return $?
    fi

    if [[ $do_check -eq 1 ]]; then
        _watcom_check
        return $?
    fi

    # Default action when sourced: set environment variables
    _watcom_setenv
}

# ---------------------------------------------------------------------------
# Core: set environment variables in current shell
# ---------------------------------------------------------------------------
_watcom_setenv() {
    # Determine WATCOM root
    local watcom_root="${WATCOM:-$WATCOM_DEFAULT_DIR}"

    # Verify the directory exists
    if [[ ! -d "$watcom_root" ]]; then
        echo "ERROR: OpenWatcom not found at $watcom_root" >&2
        echo "       Run: scripts/setup-watcom.sh --install" >&2
        echo "       Or set WATCOM to your installation directory before sourcing." >&2
        return 1
    fi

    if [[ ! -d "$watcom_root/$WATCOM_BIN_DIR" ]]; then
        echo "ERROR: Expected binary directory missing: $watcom_root/$WATCOM_BIN_DIR" >&2
        echo "       Host arch is $HOST_ARCH, expected bin dir is $WATCOM_BIN_DIR" >&2
        echo "       Check your OpenWatcom installation." >&2
        return 1
    fi

    # Export WATCOM root
    export WATCOM="$watcom_root"

    # Prepend host binaries to PATH (avoid duplicates)
    local bin_path="$WATCOM/$WATCOM_BIN_DIR"
    if [[ ":$PATH:" != *":$bin_path:"* ]]; then
        export PATH="$bin_path:$PATH"
    fi

    # INCLUDE: semicolon-separated, DOS convention (wcc reads this)
    export INCLUDE="$WATCOM/h;$WATCOM/h/sys"

    # EDDAT: editor/tool data files
    export EDDAT="$WATCOM/eddat"

    # LIB: default library search path for wlink
    # lib286 for 16-bit, lib286/dos for DOS target specifically
    export LIB="$WATCOM/lib286;$WATCOM/lib286/dos"

    echo "OpenWatcom V2 environment set."
    echo "  WATCOM  = $WATCOM"
    echo "  PATH    = $bin_path added"
    echo "  INCLUDE = $INCLUDE"
    echo "  LIB     = $LIB"
    echo ""
    echo "Compile for 16-bit DOS medium model:"
    echo "  owcc -bdos -mcmodel=m -std=c89 -W4 -o program.exe program.c"
}

# ---------------------------------------------------------------------------
# When sourced (not executed), just set env vars.
# When executed with arguments, parse them.
# ---------------------------------------------------------------------------

# Detect if we are being sourced or executed
if [[ "${(%):-%x}" == "$0" ]] || [[ "${BASH_SOURCE[0]:-}" == "$0" ]]; then
    # Being executed as a script
    _watcom_main "$@"
else
    # Being sourced — set environment variables
    if [[ $# -gt 0 ]]; then
        _watcom_main "$@"
    else
        _watcom_setenv
    fi
fi
