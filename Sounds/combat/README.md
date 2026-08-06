# Combat sound effects

These mono, 48 kHz OGG files were prepared from the CC0 collection in
`/home/tuna/다운로드/Sound Effects/` and loudness-normalized for gameplay.

| Asset | Use | Source |
| --- | --- | --- |
| `reload_start.ogg` | All reloads | `equipment_clicks3.wav`, first click |
| `reload_end.ogg` | Reloads lasting at least 5 seconds | `equipment_clicks3.wav`, second click |
| `missile_impact.ogg` | Missile detonation | `yd-Sounds/explode.ogg` |
| `metal_impact_01..05.ogg` | Ballistic and energy impacts | `metal_sheet_01,02,03,04,06.ogg` |
| `part_destroyed.ogg` | Part destruction | `metal_sheet_05.ogg` |
| `missile_flight.ogg` | Three nearest missiles in flight | `sfx_loops/water_flowing.ogg` |

Impacts against non-player mechs play at -6.02 dB (50% linear volume). Player
impacts and environment collisions retain full volume.

UI assets in `../ui/` use `sfx_loops/alarm_02.ogg` for HEAT WARNING,
`sfx_loops/alarm_03.ogg` for HEAT CRITICAL, and `New folder/Wrong Error.wav`
when a player part is destroyed.
