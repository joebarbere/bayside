#!/bin/bash
# Run the rebuilt C version of DeskMate in DOSBox-X with Tandy emulation
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONF="$SCRIPT_DIR/../configs/deskmate-tandy.conf"

if command -v dosbox-x &> /dev/null; then
    DOSBOX=dosbox-x
elif command -v dosbox &> /dev/null; then
    DOSBOX=dosbox
else
    echo "Error: Neither dosbox-x nor dosbox found in PATH"
    exit 1
fi

# Check that built binaries exist
if [ ! -d "$PROJECT_ROOT/build" ] || [ -z "$(ls -A "$PROJECT_ROOT/build" 2>/dev/null)" ]; then
    echo "Error: No built binaries found in build/"
    echo "Run 'make -C src all' first (requires OpenWatcom)."
    exit 1
fi

echo "Launching rebuilt DeskMate with $DOSBOX (Tandy mode)..."
cd "$PROJECT_ROOT"
# Override autoexec to mount build/ instead of archive/
$DOSBOX -conf "$CONF" -c "mount c ./build" -c "c:" -c "SET DMCONFIG=C:\\" -c "DESK.EXE"
