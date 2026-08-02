# 2v2 Armor Balance Batch Report (Before Arm Durability Buff)

## Experiment

- Matches: 1,404
- Armor combinations: 27 (HEAD x BODY x LEGS, 3 x 3 x 3)
- Expected appearances per combination: 104
- Teams: two identical chassis per team; one aggressive and one range-keeper AI
- Weapons: one valid arm-mounted rapid weapon per mech; same panel on both teams
- Matchup schedule: every unordered pair once per weapon panel
- Timeout: 120 seconds
- Every experimental loadout passed `MechLoadout.is_valid()` before execution

## Duration

- Restricted mean: **34.0s** (target: 120.0s)
- Median: **19.8s**
- P90: **94.7s**
- Timeouts: **94/1404 (6.7%)**
- Completed wins: 1306; draws: 4

### Duration By Weapon Panel

| Panel | Matches | Mean | Median | P90 | Timeout |
| --- | ---: | ---: | ---: | ---: | ---: |
| BALLISTIC | 351 | 47.5s | 36.6s | 120.0s | 10.5% |
| ENERGY | 351 | 31.3s | 18.1s | 81.5s | 6.3% |
| MISSILE | 351 | 41.0s | 24.5s | 118.7s | 10.0% |
| SCATTER | 351 | 16.2s | 12.5s | 29.3s | 0.0% |

## Armor Combination Leaderboard

Win rate excludes timeouts and draws. Score awards 0.5 for a draw or timeout.
Tier order in `H/B/L` is HEAD/BODY/LEGS; `H` means superheavy.

| Rank | H/B/L | N | W-L-D-T | Win rate (95% CI) | Score | Mean time | Most vulnerable panel |
| ---: | --- | ---: | --- | --- | ---: | ---: | --- |
| 1 | L/H/M | 104 | 59-41-0-4 | 59.0% (49.2%-68.1%) | 58.7% | 33.5s | MISSILE |
| 2 | L/M/L | 104 | 56-42-0-6 | 57.1% (47.3%-66.5%) | 56.7% | 33.4s | ENERGY |
| 3 | M/H/L | 104 | 54-44-1-5 | 55.1% (45.2%-64.6%) | 54.8% | 29.9s | SCATTER |
| 4 | H/M/M | 104 | 52-42-0-10 | 55.3% (45.3%-65.0%) | 54.8% | 37.1s | SCATTER |
| 5 | M/L/L | 104 | 56-47-0-1 | 54.4% (44.8%-63.7%) | 54.3% | 27.0s | MISSILE |
| 6 | L/M/M | 104 | 50-42-0-12 | 54.3% (44.2%-64.1%) | 53.8% | 40.0s | SCATTER |
| 7 | M/M/M | 104 | 51-44-0-9 | 53.7% (43.7%-63.4%) | 53.4% | 37.8s | MISSILE |
| 8 | M/M/H | 104 | 49-44-1-10 | 52.7% (42.6%-62.5%) | 52.4% | 37.4s | BALLISTIC |
| 9 | H/L/M | 104 | 49-44-0-11 | 52.7% (42.6%-62.5%) | 52.4% | 38.9s | SCATTER |
| 10 | L/L/H | 104 | 50-47-0-7 | 51.5% (41.7%-61.2%) | 51.4% | 32.2s | SCATTER |
| 11 | H/M/L | 104 | 51-48-0-5 | 51.5% (41.8%-61.1%) | 51.4% | 33.5s | BALLISTIC |
| 12 | M/L/H | 104 | 49-48-0-7 | 50.5% (40.7%-60.3%) | 50.5% | 32.8s | MISSILE |
| 13 | H/H/M | 104 | 47-46-0-11 | 50.5% (40.6%-60.5%) | 50.5% | 38.7s | ENERGY |
| 14 | L/H/L | 104 | 48-48-0-8 | 50.0% (40.2%-59.8%) | 50.0% | 32.2s | SCATTER |
| 15 | L/H/H | 104 | 48-48-0-8 | 50.0% (40.2%-59.8%) | 50.0% | 33.0s | ENERGY |
| 16 | L/L/L | 104 | 48-49-0-7 | 49.5% (39.7%-59.3%) | 49.5% | 31.3s | SCATTER |
| 17 | M/H/H | 104 | 48-49-0-7 | 49.5% (39.7%-59.3%) | 49.5% | 35.1s | BALLISTIC |
| 18 | L/L/M | 104 | 46-49-2-7 | 48.4% (38.6%-58.3%) | 48.6% | 34.2s | SCATTER |
| 19 | H/L/L | 104 | 49-52-1-2 | 48.5% (39.0%-58.1%) | 48.6% | 29.5s | MISSILE |
| 20 | M/H/M | 104 | 44-49-1-10 | 47.3% (37.5%-57.4%) | 47.6% | 36.1s | ENERGY |
| 21 | M/L/M | 104 | 47-53-1-3 | 47.0% (37.5%-56.7%) | 47.1% | 31.3s | SCATTER |
| 22 | H/M/H | 104 | 47-53-0-4 | 47.0% (37.5%-56.7%) | 47.1% | 34.4s | MISSILE |
| 23 | M/M/L | 104 | 43-51-1-9 | 45.7% (36.0%-55.8%) | 46.2% | 35.2s | MISSILE |
| 24 | H/H/L | 104 | 43-55-0-6 | 43.9% (34.5%-53.7%) | 44.2% | 32.0s | MISSILE |
| 25 | H/L/H | 104 | 43-56-0-5 | 43.4% (34.1%-53.3%) | 43.8% | 30.9s | MISSILE |
| 26 | H/H/H | 104 | 41-56-0-7 | 42.3% (32.9%-52.2%) | 42.8% | 34.4s | MISSILE |
| 27 | L/M/H | 104 | 38-59-0-7 | 39.2% (30.1%-49.1%) | 39.9% | 35.9s | MISSILE |

## Armor Tier Effects

These are raw pooled results; tier stats also include mobility, power, sensor, and weight differences.

| Part | Tier | Appearances | Score | Decided win rate | Mean duration | Defeated mechs |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| HEAD | LIGHT | 936 | 51.0% | 51.0% | 34.0s | 1035/1872 |
| HEAD | MEDIUM | 936 | 50.6% | 50.7% | 33.6s | 1065/1872 |
| HEAD | SUPERHEAVY | 936 | 48.4% | 48.3% | 34.4s | 1091/1872 |
| BODY | LIGHT | 936 | 49.6% | 49.5% | 32.0s | 1071/1872 |
| BODY | MEDIUM | 936 | 50.6% | 50.7% | 36.1s | 1047/1872 |
| BODY | SUPERHEAVY | 936 | 49.8% | 49.8% | 33.9s | 1073/1872 |
| LEGS | LIGHT | 936 | 50.6% | 50.7% | 31.6s | 1044/1872 |
| LEGS | MEDIUM | 936 | 51.9% | 52.0% | 36.4s | 1032/1872 |
| LEGS | SUPERHEAVY | 936 | 47.5% | 47.3% | 34.0s | 1115/1872 |

## Weapon Vulnerability By Combination

Each cell is defeated-mech rate / average durability damage per mech.

| H/B/L | BALLISTIC | ENERGY | MISSILE | SCATTER |
| --- | ---: | ---: | ---: | ---: |
| H/H/H | 69.2% / 156.7 | 69.2% / 124.5 | 73.1% / 149.3 | 51.9% / 46.7 |
| H/H/L | 63.5% / 127.1 | 53.8% / 147.8 | 67.3% / 146.9 | 67.3% / 53.5 |
| H/H/M | 51.9% / 127.7 | 65.4% / 112.2 | 51.9% / 147.9 | 53.8% / 46.9 |
| H/L/H | 42.3% / 128.3 | 67.3% / 114.3 | 76.9% / 122.7 | 61.5% / 46.6 |
| H/L/L | 48.1% / 111.6 | 53.8% / 85.7 | 69.2% / 134.2 | 63.5% / 56.6 |
| H/L/M | 44.2% / 109.4 | 48.1% / 154.0 | 57.7% / 115.6 | 73.1% / 52.1 |
| H/M/H | 51.9% / 173.2 | 50.0% / 88.7 | 69.2% / 124.0 | 69.2% / 50.1 |
| H/M/L | 63.5% / 134.6 | 42.3% / 84.4 | 44.2% / 146.0 | 61.5% / 50.9 |
| H/M/M | 51.9% / 113.9 | 40.4% / 85.9 | 46.2% / 155.0 | 63.5% / 50.2 |
| L/H/H | 50.0% / 123.8 | 73.1% / 101.7 | 57.7% / 97.6 | 42.3% / 41.2 |
| L/H/L | 50.0% / 126.0 | 50.0% / 115.0 | 57.7% / 107.7 | 63.5% / 53.3 |
| L/H/M | 44.2% / 99.3 | 42.3% / 99.2 | 51.9% / 158.1 | 46.2% / 44.1 |
| L/L/H | 38.5% / 114.0 | 61.5% / 100.5 | 61.5% / 160.1 | 65.4% / 45.9 |
| L/L/L | 51.9% / 111.8 | 44.2% / 107.2 | 61.5% / 107.0 | 65.4% / 54.8 |
| L/L/M | 40.4% / 97.6 | 50.0% / 131.1 | 61.5% / 110.3 | 76.9% / 57.3 |
| L/M/H | 63.5% / 171.9 | 63.5% / 123.8 | 75.0% / 164.8 | 57.7% / 48.6 |
| L/M/L | 30.8% / 99.4 | 59.6% / 107.1 | 50.0% / 109.0 | 59.6% / 57.2 |
| L/M/M | 55.8% / 132.5 | 55.8% / 125.4 | 53.8% / 106.7 | 57.7% / 45.1 |
| M/H/H | 67.3% / 183.0 | 67.3% / 120.4 | 38.5% / 99.8 | 61.5% / 47.1 |
| M/H/L | 46.2% / 104.3 | 42.3% / 100.4 | 61.5% / 103.8 | 69.2% / 51.6 |
| M/H/M | 61.5% / 128.5 | 65.4% / 121.1 | 57.7% / 130.8 | 57.7% / 46.8 |
| M/L/H | 46.2% / 178.0 | 55.8% / 112.4 | 73.1% / 91.8 | 46.2% / 43.9 |
| M/L/L | 48.1% / 87.2 | 53.8% / 104.0 | 57.7% / 118.6 | 53.8% / 56.0 |
| M/L/M | 51.9% / 98.8 | 59.6% / 113.3 | 63.5% / 119.0 | 65.4% / 51.4 |
| M/M/H | 57.7% / 155.0 | 57.7% / 93.7 | 57.7% / 93.0 | 53.8% / 46.8 |
| M/M/L | 50.0% / 108.5 | 63.5% / 133.2 | 63.5% / 141.4 | 55.8% / 55.3 |
| M/M/M | 40.4% / 118.5 | 46.2% / 109.2 | 71.2% / 141.1 | 59.6% / 45.7 |

## Part Damage By Weapon Panel

Average durability damage per mech across both teams.

| Panel | Head | Body | Legs | Weapon arm | Mech defeat rate |
| --- | ---: | ---: | ---: | ---: | ---: |
| BALLISTIC | 23.8 | 37.0 | 43.2 | 22.7 | 51.1% |
| ENERGY | 25.9 | 37.7 | 27.4 | 20.7 | 55.6% |
| MISSILE | 19.2 | 63.3 | 23.7 | 19.8 | 60.4% |
| SCATTER | 8.4 | 10.2 | 6.3 | 24.9 | 60.1% |

## Interpretation Limits

- Defeat currently occurs when the sole weapon arm is destroyed, not when HEAD/BODY/LEGS reaches zero.
- Armor tiers share collision artwork, so this measures durability/stat effects rather than silhouette size.
- Penetration, splash radius, and damage-type resistance are not implemented in damage resolution.
- Timeout results are reported separately and counted as 0.5 only in the descriptive score.
- Weapon panels use different arm-part durability and stats, because only real catalog loadouts were allowed.

Raw merged results: `docs/balance_batch_results.json`
