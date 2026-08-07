#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

compose_backpack() {
    local output="$1"
    local arm_art="$2"

    if [[ -e "${SCRIPT_DIR}/${output}" && "${FORCE_SPRITES:-0}" != "1" ]]; then
        return
    fi

    magick -size 24x12 xc:none \
        \( "${SCRIPT_DIR}/${arm_art}" -filter point -rotate -90 -resize 50% \) \
        -geometry +18+0 -composite \
        -depth 8 "PNG32:${SCRIPT_DIR}/${output}"
}

render_anchors() {
    local output="$1"
    shift

    if [[ -e "${SCRIPT_DIR}/${output}" && "${FORCE_SPRITES:-0}" != "1" ]]; then
        return
    fi

    magick -size 24x12 xc:none +antialias "$@" \
        -depth 8 "PNG32:${SCRIPT_DIR}/${output}"
}

compose_backpack \
    "Backpack-Tempest-Rack-0001.png" \
    "Arm-Rifle-0001.png"
compose_backpack \
    "Backpack-Siege-Rail-0001.png" \
    "Arm-Cannon-0001.png"
compose_backpack \
    "Backpack-Nova-Beam-0001.png" \
    "Arm-Cannon-0001.png"
compose_backpack \
    "Backpack-Longbow-Cruise-0001.png" \
    "Arm-Cannon-0001.png"
compose_backpack \
    "Backpack-Avalanche-Flak-0001.png" \
    "Arm-Shotgun-0001.png"

render_anchors "Backpack-Tempest-Rack-0001.anchors.png" \
    -fill "#FF0000" -draw "point 11,6" \
    -fill "#0000FF" -draw "point 21,3"
render_anchors "Backpack-Siege-Rail-0001.anchors.png" \
    -fill "#FF0000" -draw "point 11,6" \
    -fill "#0000FF" -draw "point 21,3" \
    -fill "#FF0080" -draw "point 23,5"
render_anchors "Backpack-Nova-Beam-0001.anchors.png" \
    -fill "#FF0000" -draw "point 11,6" \
    -fill "#0000FF" -draw "point 21,3" \
    -fill "#FF0080" -draw "point 23,5"
render_anchors "Backpack-Longbow-Cruise-0001.anchors.png" \
    -fill "#FF0000" -draw "point 11,6" \
    -fill "#0000FF" -draw "point 21,3"
render_anchors "Backpack-Avalanche-Flak-0001.anchors.png" \
    -fill "#FF0000" -draw "point 11,6" \
    -fill "#0000FF" -draw "point 21,3" \
    -fill "#FF0080" -draw "point 23,5"

printf 'Generated weapon backpack composites in %s\n' "$SCRIPT_DIR"
