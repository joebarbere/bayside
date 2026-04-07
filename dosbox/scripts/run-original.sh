#!/bin/bash
# Run the original Tandy DeskMate 3.05 in DOSBox-X with Tandy emulation
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONF="$SCRIPT_DIR/../configs/deskmate-tandy.conf"

# Check for DOSBox-X first (better Tandy support), fall back to DOSBox
if command -v dosbox-x &> /dev/null; then
    DOSBOX=dosbox-x
elif command -v dosbox &> /dev/null; then
    DOSBOX=dosbox
else
    echo "Error: Neither dosbox-x nor dosbox found in PATH"
    echo "Install DOSBox-X for best Tandy emulation: https://dosbox-x.com"
    exit 1
fi

# Check that DeskMate files exist
if [ ! -d "$PROJECT_ROOT/archive/deskmate-3.05" ]; then
    echo "Error: DeskMate 3.05 files not found in archive/deskmate-3.05/"
    echo "Place the original DeskMate 3.05 files there first."
    exit 1
fi

echo "Launching DeskMate 3.05 with $DOSBOX (Tandy mode)..."
cd "$PROJECT_ROOT"
$DOSBOX -conf "$CONF"
