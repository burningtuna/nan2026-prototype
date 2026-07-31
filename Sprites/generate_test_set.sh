#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
readonly BLACK="#000000"
readonly RED="#AC3232"
readonly DARK_RED="#582525"
readonly HIGHLIGHT="#D95757"
readonly DASH_WHITE="#FFFFFF"
readonly DASH_LIGHT="#BDEBFF"
readonly DASH_BLUE="#55BFFF"
readonly DASH_DARK="#2474C6"

render() {
    local output="$1"
    local size="$2"
    shift 2

    if [[ -e "${SCRIPT_DIR}/${output}" && "${FORCE_SPRITES:-0}" != "1" ]]; then
        return
    fi

    magick -size "$size" xc:none +antialias "$@" -depth 8 "PNG32:${SCRIPT_DIR}/${output}"
}

# Top-down head crown, facing up. It has no front-facing facial features.
render "Head-0001.png" "12x12" \
    -fill "$BLACK" -draw "rectangle 5,0 6,0 rectangle 4,1 7,2 rectangle 3,2 8,3 rectangle 2,4 9,7 rectangle 3,8 8,9 rectangle 4,10 7,10" \
    -fill "$RED" -draw "rectangle 5,1 6,1 rectangle 4,2 7,3 rectangle 3,4 8,7 rectangle 4,8 7,9" \
    -fill "$DARK_RED" -draw "rectangle 4,4 7,7 rectangle 5,8 6,9" \
    -fill "$HIGHLIGHT" -draw "point 5,1 point 4,2 point 3,4 point 8,4" \
    -fill "$BLACK" -draw "rectangle 5,3 6,5"

# Top-down twin ground-thruster pods. There are no feet or walking joints.
render "Legs-0001.png" "12x12" \
    -fill "$BLACK" -draw "rectangle 4,0 7,2 rectangle 2,2 4,9 rectangle 7,2 9,9 rectangle 1,4 4,8 rectangle 7,4 10,8 rectangle 2,9 3,10 rectangle 8,9 9,10" \
    -fill "$RED" -draw "rectangle 4,1 7,2 rectangle 2,3 3,8 rectangle 8,3 9,8 rectangle 3,9 3,9 rectangle 8,9 8,9" \
    -fill "$DARK_RED" -draw "rectangle 3,4 3,7 rectangle 8,4 8,7" \
    -fill "$HIGHLIGHT" -draw "point 2,3 point 8,3"

# Top-down cannon arm. The canonical barrel points right (+X); reuse it for
# either side and rotate around the magenta aim pivot in the anchor mask.
render "Arm-Cannon-0001.png" "24x12" \
    -fill "$BLACK" -draw "rectangle 2,3 8,8 rectangle 6,2 14,9 rectangle 13,4 22,7 rectangle 22,3 23,8" \
    -fill "$RED" -draw "rectangle 3,4 7,7 rectangle 7,3 13,8 rectangle 14,5 21,6 rectangle 23,4 23,7" \
    -fill "$DARK_RED" -draw "rectangle 4,5 8,6 rectangle 9,4 12,7 rectangle 15,6 21,6" \
    -fill "$HIGHLIGHT" -draw "rectangle 8,3 12,3 rectangle 14,5 20,5 point 3,4 point 3,7"

# Wide top-down generator backpack, drawn beneath the torso layer.
render "Backpack-Generator-0001.png" "24x12" \
    -fill "$BLACK" -draw "rectangle 7,1 16,10 rectangle 2,3 7,9 rectangle 16,3 21,9 rectangle 1,5 2,8 rectangle 21,5 22,8" \
    -fill "$RED" -draw "rectangle 8,2 15,9 rectangle 3,4 6,8 rectangle 17,4 20,8" \
    -fill "$DARK_RED" -draw "rectangle 10,3 13,8 rectangle 4,5 5,7 rectangle 18,5 19,7" \
    -fill "$HIGHLIGHT" -draw "rectangle 8,2 14,2 point 3,4 point 17,4" \
    -fill "$BLACK" -draw "rectangle 9,5 14,6"

# Shared ground-boost animation, pointing down. All frames use one canvas.
render "Boost-0001.png" "4x6" \
    -fill "$BLACK" -draw "point 1,0 point 2,0" \
    -fill "$RED" -draw "point 1,1 point 2,1" \
    -fill "$DARK_RED" -draw "point 1,2 point 2,2"

render "Boost-0002.png" "4x6" \
    -fill "$BLACK" -draw "point 1,0 point 2,0 point 0,1 point 3,1" \
    -fill "$RED" -draw "rectangle 1,1 2,2" \
    -fill "$HIGHLIGHT" -draw "point 1,1" \
    -fill "$DARK_RED" -draw "point 1,3 point 2,3"

render "Boost-0003.png" "4x6" \
    -fill "$BLACK" -draw "point 1,0 point 2,0 point 0,1 point 3,1" \
    -fill "$HIGHLIGHT" -draw "point 1,1 point 2,1" \
    -fill "$RED" -draw "rectangle 0,2 3,2 rectangle 1,3 2,3" \
    -fill "$DARK_RED" -draw "point 1,4 point 2,4 point 2,5"

# Short, high-output lateral dash exhaust. The default direction is down and
# the scene rotates it to the side opposite the dash movement.
render "Dash-0001.png" "4x9" \
    -fill "$DASH_WHITE" -draw "point 1,0 point 2,0 point 1,1 point 2,1" \
    -fill "$DASH_LIGHT" -draw "point 1,2 point 2,2 point 1,3 point 2,3" \
    -fill "$DASH_BLUE" -draw "point 1,4 point 2,4 point 1,5 point 2,5" \
    -fill "$DASH_DARK" -draw "point 1,6 point 2,6 point 2,7"

render "Dash-0002.png" "4x9" \
    -fill "$DASH_WHITE" -draw "rectangle 1,0 2,2" \
    -fill "$DASH_LIGHT" -draw "point 0,2 point 3,2 rectangle 1,3 2,4" \
    -fill "$DASH_BLUE" -draw "rectangle 1,5 2,6" \
    -fill "$DASH_DARK" -draw "point 1,7 point 2,7 point 1,8"

render "Dash-0003.png" "4x9" \
    -fill "$DASH_WHITE" -draw "rectangle 1,0 2,1" \
    -fill "$DASH_LIGHT" -draw "rectangle 0,2 3,3" \
    -fill "$DASH_BLUE" -draw "rectangle 1,4 2,6" \
    -fill "$DASH_DARK" -draw "point 1,7 point 2,7 point 2,8"

# Anchor mask palette:
# red parent mount, orange head socket, lime legs socket, yellow left arm,
# green right arm, violet backpack, magenta aim pivot, blue muzzle, cyan boost.
# Body and head anchor masks are hand-authored references and are intentionally
# not regenerated. The head mount also serves as its aiming rotation pivot.

render "Legs-0001.anchors.png" "12x12" \
    -fill "#FF0000" -draw "point 5,0" \
    -fill "#00FFFF" -draw "point 2,11 point 9,11"

render "Arm-Cannon-0001.anchors.png" "24x12" \
    -fill "#FF0000" -draw "point 3,6" \
    -fill "#FF00FF" -draw "point 4,6" \
    -fill "#0000FF" -draw "point 23,5"

render "Backpack-Generator-0001.anchors.png" "24x12" \
    -fill "#FF0000" -draw "point 11,6" \
    -fill "#00FFFF" -draw "point 4,10 point 19,10"

echo "Generated DIRECTIVE//12 test sprites in ${SCRIPT_DIR}"
