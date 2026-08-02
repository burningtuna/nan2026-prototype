# Sprite Test Set

This directory contains the first top-down test mech set for `DIRECTIVE//12`. The head, torso, weapons and backpack are the primary visible surfaces. Standard biped legs use a GTA2-like top view and sit mostly beneath the torso; heavy, quadruped and special legs may extend beyond the torso silhouette.

## Art Files

| File | Size | Direction |
| --- | ---: | --- |
| `Body-0001.png` | 12×12 | Up |
| `Head-0001.png` | 12×12 | Up |
| `Legs-0001.png` | 12×12 | Up |
| `Arm-Cannon-0001.png` | 24×12 | Right (`+X`) |
| `Arm-Shotgun-0001.png` | 24×12 | Right (`+X`) |
| `Arm-Rifle-0001.png` | 24×12 | Right (`+X`) |
| `Arm-Pistol-0001.png` | 24×12 | Right (`+X`) |
| `Backpack-Generator-0001.png` | 24×12 | Up |
| `Projectile-0001.svg` | 6×3 | Right (`+X`) |
| `Boost-0001.png` | 4×6 | Down |
| `Boost-0002.png` | 4×6 | Down |
| `Boost-0003.png` | 4×6 | Down |
| `Dash-0001.png` | 4×9 | Down |
| `Dash-0002.png` | 4×9 | Down |
| `Dash-0003.png` | 4×9 | Down |

Arm sprites are shared by both arm slots. Rotate them around their aim pivot instead of drawing directional variants. The shotgun retains the cannon's reach with a thinner silhouette; the rifle and pistol use progressively shorter barrels on the same canvas and pivot. The head is an armored crown seen from above and intentionally has no front-facing face or eyes.

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

The muzzle marker defines spawn position only. Projectile direction is calculated from the logical aim direction, `WeaponSpec.launch_offset_degrees`, and spread; muzzle flashes use the same result. A positive launch offset rotates clockwise in screen coordinates, and a negative offset rotates counterclockwise. Guided weapons may therefore launch sideways before steering toward their target or first waypoint without requiring a directional muzzle marker.

## Regeneration

Run the generator from the project root:

```bash
bash Sprites/generate_test_set.sh
```

Front-view wireframe parts use the same socket and `mount` anchor names with
view-specific coordinates. Their grayscale RGBA art is tinted at runtime for
healthy, damaged, critical and destroyed states.

```bash
bash Sprites/generate_wireframe_set.sh
```

Generated wireframe art and anchor masks are stored under `Sprites/Wireframe/`.
The wireframe is a static status schematic; it does not use top-down arm aim or
movement animation. Cannon, shotgun, rifle and pistol arms share a `16x28`
front-view canvas and mount; only their silhouette width and muzzle aperture
change to communicate caliber.

Stage environment tiles are generated separately:

```bash
bash Sprites/generate_environment_tiles.sh
```

The stage 1-3 test floor is a seamless 128x128 lightly stained steel deck stored under
`Sprites/Environment/`.

The generator does not overwrite any existing sprite unless `FORCE_SPRITES=1` is set. This protects hand-edited art and anchor masks. The head mount pixel also acts as the head aiming pivot.

## Godot Sample

Run the project or open `res://scenes/sample_assembly.tscn`.

- Move the mouse to aim both cannon arms and rotate the head fire-control unit.
- Use `WASD` to move and turn the lower body in eight directions.
- Hold `Space` while moving to engage high-output boost.
- Press `Z` or `C` to dash along the torso's left or right axis without changing lower-body facing.
- The upper body follows the lower body or mouse aim at 30 degrees per second.
- The scene reads every `.anchors.png` file at runtime and assembles the mech without hard-coded part offsets.
