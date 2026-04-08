#!/bin/bash
# Capture DeskMate 3.05 screenshots in DOSBox-X
# Usage: ./capture-screenshots.sh
#
# This launches DeskMate in DOSBox-X. Once loaded:
#   1. Press Ctrl+F5 (or Cmd+F5 on Mac) to capture a screenshot
#   2. Navigate to Hangman and capture another screenshot
#   3. Close DOSBox-X when done
#
# Screenshots are saved to research/screenshots/ by DOSBox-X

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONF="$SCRIPT_DIR/../configs/deskmate-tandy.conf"
SCREENSHOT_DIR="$PROJECT_ROOT/research/screenshots"

mkdir -p "$SCREENSHOT_DIR"

if [ ! -f "/Applications/dosbox-x.app/Contents/MacOS/dosbox-x" ]; then
    echo "Error: DOSBox-X not found. Install via: brew install --cask dosbox-x"
    exit 1
fi

if [ ! -f "$PROJECT_ROOT/archive/deskmate-3.05/extracted/DESK.EXE" ]; then
    echo "Error: DeskMate 3.05 files not found in archive/deskmate-3.05/extracted/"
    exit 1
fi

echo "=== DeskMate 3.05 Screenshot Capture ==="
echo ""
echo "DeskMate will launch in DOSBox-X. To capture screenshots:"
echo "  Ctrl+F5 (or Cmd+F5) = Save PNG screenshot"
echo ""
echo "Suggested captures:"
echo "  1. DeskMate Desktop (main screen after boot)"
echo "  2. Hangman game (open from Programs menu)"
echo ""
echo "Screenshots will be saved to DOSBox-X's capture directory."
echo "Copy them to: $SCREENSHOT_DIR"
echo ""

cd "$PROJECT_ROOT"
/Applications/dosbox-x.app/Contents/MacOS/dosbox-x \
    -conf "$CONF" \
    -c "mount c ./archive/deskmate-3.05/extracted" \
    -c "c:" \
    -c "SET DMCONFIG=C:\\" \
    -c "DESK.EXE"

echo ""
echo "DOSBox-X closed. Check for screenshots in ~/capture/ or the DOSBox-X capture directory."
