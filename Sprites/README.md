# Sprite Test Set

This directory contains the first top-down test mech set for `DIRECTIVE//12`. The head, torso, weapons and backpack are the primary visible surfaces; the legs read as rear ground-thruster pods rather than walking limbs.

## Art Files

| File | Size | Direction |
| --- | ---: | --- |
| `Body-0001.png` | 12×12 | Up |
| `Head-0001.png` | 12×12 | Up |
| `Legs-0001.png` | 12×12 | Up |
| `Arm-Cannon-0001.png` | 24×12 | Right (`+X`) |
| `Backpack-Generator-0001.png` | 24×12 | Up |
| `Boost-0001.png` | 4×6 | Down |
| `Boost-0002.png` | 4×6 | Down |
| `Boost-0003.png` | 4×6 | Down |

The cannon arm is shared by both arm slots. Rotate it around its aim pivot instead of drawing directional variants. The head is an armored crown seen from above and intentionally has no front-facing face or eyes.

## Palette

| Role | Color |
| --- | --- |
| Outline | `#000000` |
| Armor | `#AC3232` |
| Armor shadow | `#582525` |
| Armor highlight | `#D95757` |

## Anchor Masks

Every anchor mask has the same dimensions as its art PNG. Anchor masks are metadata and must not be rendered in the game.

| Color | Meaning |
| --- | --- |
| `#FF0000` | Mount to parent |
| `#FF8000` | Head socket |
| `#80FF00` | Legs socket |
| `#FFFF00` | Left arm socket |
| `#00FF00` | Right arm socket |
| `#8000FF` | Backpack socket |
| `#FF00FF` | Aim pivot |
| `#0000FF` | Muzzle |
| `#00FFFF` | Boost exhaust |

Marker pixels must use exact opaque RGBA colors without antialiasing. Transparent pixels do not count as collision or target area.

## Regeneration

Run the generator from the project root:

```bash
bash Sprites/generate_test_set.sh
```

The generator intentionally does not overwrite `Body-0001.png`, `Body-0001.anchors.png`, or `Head-0001.anchors.png`. These are hand-authored assembly references. The head mount pixel also acts as the head aiming pivot.

## Godot Sample

Run the project or open `res://scenes/sample_assembly.tscn`.

- Move the mouse to aim both cannon arms and rotate the head fire-control unit.
- Press `Space` to toggle the leg boost animation.
- The scene reads every `.anchors.png` file at runtime and assembles the mech without hard-coded part offsets.
