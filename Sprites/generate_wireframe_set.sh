#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
readonly OUTPUT_DIR="${SCRIPT_DIR}/Wireframe"
readonly DARK="#43545B"
readonly MID="#94A9AF"
readonly BRIGHT="#E8F5F5"

mkdir -p "$OUTPUT_DIR"

render() {
    local output="$1"
    local size="$2"
    shift 2

    if [[ -e "${OUTPUT_DIR}/${output}" && "${FORCE_SPRITES:-0}" != "1" ]]; then
        return
    fi

    magick -size "$size" xc:none +antialias "$@" -depth 8 "PNG32:${OUTPUT_DIR}/${output}"
}

# Front-view body with sockets for every equipped part.
render "Body-0001.png" "24x24" \
    -fill none -stroke "$DARK" -strokewidth 1 -draw "polygon 5,4 18,4 21,9 18,21 5,21 2,9" \
    -stroke "$MID" -draw "rectangle 6,6 17,18 line 6,10 17,10 line 9,6 9,18 line 14,6 14,18" \
    -stroke "$BRIGHT" -draw "line 5,4 18,4 line 3,9 6,9 line 17,9 20,9 rectangle 10,12 13,15"

render "Body-0001.anchors.png" "24x24" \
    -fill "#FF8000" -draw "point 11,3" \
    -fill "#80FF00" -draw "point 11,21" \
    -fill "#FFFF00" -draw "point 2,8" \
    -fill "#00FF00" -draw "point 21,8" \
    -fill "#8000FF" -draw "point 11,10"

render "Head-0001.png" "16x14" \
    -fill none -stroke "$DARK" -strokewidth 1 -draw "polygon 3,3 6,0 9,0 12,3 13,9 10,12 5,12 2,9" \
    -stroke "$MID" -draw "line 3,5 12,5 line 4,8 11,8 rectangle 6,2 9,3" \
    -stroke "$BRIGHT" -draw "line 5,10 10,10 point 4,4 point 11,4"

render "Head-0001.anchors.png" "16x14" \
    -fill "#FF0000" -draw "point 7,12"

scale_head() {
    local output="$1"
    local scale="$2"

    if [[ -e "${OUTPUT_DIR}/${output}" && "${FORCE_SPRITES:-0}" != "1" ]]; then
        return
    fi

    magick "${OUTPUT_DIR}/Head-0001.png" -filter point -resize "$scale" -depth 8 "PNG32:${OUTPUT_DIR}/${output}"
}

scale_head "Head-Falcon-0001.png" "50%"
scale_head "Head-Bastion-0001.png" "200%x100%"

render "Head-Falcon-0001.anchors.png" "8x7" \
    -fill "#FF0000" -draw "point 3,6"

render "Head-Bastion-0001.anchors.png" "32x14" \
    -fill "#FF0000" -draw "point 15,12"

render "Legs-0001.png" "24x24" \
    -fill none -stroke "$DARK" -strokewidth 1 -draw "polygon 5,1 11,1 10,9 8,22 2,22 3,10 polygon 12,1 18,1 20,10 21,22 15,22 13,9" \
    -stroke "$MID" -draw "line 5,5 10,5 line 13,5 18,5 rectangle 4,10 9,17 rectangle 14,10 19,17" \
    -stroke "$BRIGHT" -draw "line 3,20 8,20 line 15,20 20,20 point 5,3 point 17,3"

render "Legs-0001.anchors.png" "24x24" \
    -fill "#FF0000" -draw "point 11,1"

# One front-view arm asset is reused on both sockets. It is intentionally
# narrow and symmetrical enough to remain readable without aim animation.
render "Arm-Cannon-0001.png" "16x28" \
    -fill none -stroke "$DARK" -strokewidth 1 -draw "polygon 3,2 12,2 14,6 12,17 10,25 5,25 3,17 1,6" \
    -stroke "$MID" -draw "rectangle 4,5 11,14 rectangle 5,16 10,23 line 7,5 7,23" \
    -stroke "$BRIGHT" -draw "line 3,3 12,3 line 5,15 10,15 rectangle 6,19 9,22"

render "Arm-Cannon-0001.anchors.png" "16x28" \
    -fill "#FF0000" -draw "point 7,3"

# Front-view arm variants share the cannon's mount and height. Their width and
# muzzle aperture decrease with caliber because barrel length is not visible.
render "Arm-Shotgun-0001.png" "16x28" \
    -fill none -stroke "$DARK" -strokewidth 1 -draw "polygon 3,2 11,2 13,6 11,17 9,25 5,25 3,17 1,6" \
    -stroke "$MID" -draw "rectangle 4,5 10,14 rectangle 5,16 9,23 line 7,5 7,23" \
    -stroke "$BRIGHT" -draw "line 3,3 11,3 line 5,15 9,15 rectangle 6,19 8,22"

render "Arm-Shotgun-0001.anchors.png" "16x28" \
    -fill "#FF0000" -draw "point 7,3"

render "Arm-Rifle-0001.png" "16x28" \
    -fill none -stroke "$DARK" -strokewidth 1 -draw "polygon 4,2 10,2 12,6 10,17 9,25 5,25 4,17 2,6" \
    -stroke "$MID" -draw "rectangle 5,5 9,14 rectangle 5,16 9,23 line 7,5 7,23" \
    -stroke "$BRIGHT" -draw "line 4,3 10,3 line 5,15 9,15 rectangle 6,20 8,22"

render "Arm-Rifle-0001.anchors.png" "16x28" \
    -fill "#FF0000" -draw "point 7,3"

render "Arm-Pistol-0001.png" "16x28" \
    -fill none -stroke "$DARK" -strokewidth 1 -draw "polygon 5,2 9,2 11,6 9,17 8,25 6,25 5,17 3,6" \
    -stroke "$MID" -draw "rectangle 5,5 9,14 rectangle 6,16 8,23 line 7,5 7,23" \
    -stroke "$BRIGHT" -draw "line 5,3 9,3 line 6,15 8,15 line 7,20 7,22"

render "Arm-Pistol-0001.anchors.png" "16x28" \
    -fill "#FF0000" -draw "point 7,3"

render "Backpack-Generator-0001.png" "32x22" \
    -fill none -stroke "$DARK" -strokewidth 1 -draw "polygon 3,4 11,2 20,2 28,4 30,17 21,19 10,19 1,17" \
    -stroke "$MID" -draw "rectangle 4,6 9,15 rectangle 22,6 27,15 rectangle 11,4 20,17" \
    -stroke "$BRIGHT" -draw "line 5,8 8,8 line 23,8 26,8 rectangle 14,7 17,13"

render "Backpack-Generator-0001.anchors.png" "32x22" \
    -fill "#FF0000" -draw "point 15,10"

echo "Generated SUBJECT//12 front wireframe sprites in ${OUTPUT_DIR}"
