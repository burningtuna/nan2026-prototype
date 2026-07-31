# Sprite Test Set

This directory contains the first top-down test mech set for `DIRECTIVE//12`. The head, torso, weapons and backpack are the primary visible surfaces. Standard biped legs use a GTA2-like top view and sit mostly beneath the torso; heavy, quadruped and special legs may extend beyond the torso silhouette.

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
| `Dash-0001.png` | 4×9 | Down |
| `Dash-0002.png` | 4×9 | Down |
| `Dash-0003.png` | 4×9 | Down |

The cannon arm is shared by both arm slots. Rotate it around its aim pivot instead of drawing directional variants. The head is an armored crown seen from above and intentionally has no front-facing face or eyes.

## Palette

| Role | Color |
| --- | --- |
| Outline | `#000000` |
| Armor | `#AC3232` |
| Armor shadow | `#582525` |
| Armor highlight | `#D95757` |
| Dash core | `#FFFFFF` |
| Dash glow | `#BDEBFF` |
| Dash flame | `#55BFFF` |
| Dash tail | `#2474C6` |

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

Marker pixels must use exact opaque RGBA colors without antialiasing. Outer transparent padding is excluded from each part's collision boundary; transparent holes inside that boundary remain hittable.

## Regeneration

Run the generator from the project root:

```bash
bash Sprites/generate_test_set.sh
```

The generator does not overwrite any existing sprite unless `FORCE_SPRITES=1` is set. This protects hand-edited art and anchor masks. The head mount pixel also acts as the head aiming pivot.

## Godot Sample

Run the project or open `res://scenes/sample_assembly.tscn`.

- Move the mouse to aim both cannon arms and rotate the head fire-control unit.
- Use `WASD` to move and turn the lower body in eight directions.
- Hold `Space` while moving to engage high-output boost.
- Press `Z` or `C` to dash along the torso's left or right axis without changing lower-body facing.
- The upper body follows the lower body or mouse aim at 30 degrees per second.
- The scene reads every `.anchors.png` file at runtime and assembles the mech without hard-coded part offsets.
