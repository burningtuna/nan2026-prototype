#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
readonly OUTPUT_DIR="${SCRIPT_DIR}/Environment"

mkdir -p "$OUTPUT_DIR"

# Bright stage 1-3 steel with broad, low-contrast discoloration. Tiled virtual
# pixels are used while blurring so opposite edges remain seamless.
if [[ ! -e "${OUTPUT_DIR}/Stage-01-Steel-Floor.png" || "${FORCE_SPRITES:-0}" == "1" ]]; then
    magick -seed 1206 -size 128x128 xc:gray +noise Random \
        -virtual-pixel tile -blur 0x13 -normalize \
        +level-colors "#727D81,#B9C0C2" \
        -fill "#AEB6B9" -colorize 58 \
        -depth 8 "PNG32:${OUTPUT_DIR}/Stage-01-Steel-Floor.png"
fi

echo "Generated DIRECTIVE//12 environment tiles in ${OUTPUT_DIR}"
