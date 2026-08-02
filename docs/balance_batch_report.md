# 2v2 Armor Balance Batch Report

## Experiment

- Matches: 1,404
- Armor combinations: 27 (HEAD x BODY x LEGS, 3 x 3 x 3)
- Expected appearances per combination: 104
- Teams: two identical chassis per team; one aggressive and one range-keeper AI
- Weapons: two valid identical arm-mounted rapid weapons per mech; same panel on both teams
- Matchup schedule: every unordered pair once per weapon panel
- Timeout: 120 seconds
- Every experimental loadout passed `MechLoadout.is_valid()` before execution

## Duration

- Restricted mean: **82.9s** (target: 120.0s)
- Median: **91.0s**
- P90: **120.0s**
- Timeouts: **504/1404 (35.9%)**
- Completed wins: 900; draws: 0

### Duration By Weapon Panel

| Panel | Matches | Mean | Median | P90 | Timeout |
| --- | ---: | ---: | ---: | ---: | ---: |
| BALLISTIC | 351 | 100.4s | 103.8s | 120.0s | 31.6% |
| ENERGY | 351 | 79.7s | 76.9s | 120.0s | 10.8% |
| MISSILE | 351 | 120.0s | 120.0s | 120.0s | 100.0% |
| SCATTER | 351 | 31.6s | 29.2s | 47.0s | 1.1% |

## Armor Combination Leaderboard

Win rate excludes timeouts and draws. Score awards 0.5 for a draw or timeout.
Tier order in `H/B/L` is HEAD/BODY/LEGS; `H` means superheavy.

| Rank | H/B/L | N | W-L-D-T | Win rate (95% CI) | Score | Mean time | Most vulnerable panel |
| ---: | --- | ---: | --- | --- | ---: | ---: | --- |
| 1 | L/L/L | 104 | 44-27-0-33 | 62.0% (50.3%-72.4%) | 58.2% | 80.2s | ENERGY |
| 2 | M/L/L | 104 | 38-30-0-36 | 55.9% (44.1%-67.1%) | 53.8% | 80.0s | ENERGY |
| 3 | M/M/L | 104 | 38-30-0-36 | 55.9% (44.1%-67.1%) | 53.8% | 82.7s | SCATTER |
| 4 | H/M/M | 104 | 38-30-0-36 | 55.9% (44.1%-67.1%) | 53.8% | 83.0s | ENERGY |
| 5 | H/H/L | 104 | 36-28-0-40 | 56.2% (44.1%-67.7%) | 53.8% | 83.4s | SCATTER |
| 6 | L/M/L | 104 | 40-33-0-31 | 54.8% (43.4%-65.7%) | 53.4% | 79.2s | SCATTER |
| 7 | M/M/M | 104 | 39-32-0-33 | 54.9% (43.4%-66.0%) | 53.4% | 80.2s | BALLISTIC |
| 8 | M/H/L | 104 | 37-30-0-37 | 55.2% (43.4%-66.5%) | 53.4% | 82.1s | BALLISTIC |
| 9 | L/M/M | 104 | 37-31-0-36 | 54.4% (42.7%-65.7%) | 52.9% | 83.3s | SCATTER |
| 10 | L/H/H | 104 | 38-32-0-34 | 54.3% (42.7%-65.4%) | 52.9% | 81.8s | SCATTER |
| 11 | L/L/H | 104 | 30-27-0-47 | 52.6% (39.9%-65.0%) | 51.4% | 88.4s | BALLISTIC |
| 12 | L/H/L | 104 | 35-34-0-35 | 50.7% (39.2%-62.2%) | 50.5% | 78.4s | BALLISTIC |
| 13 | L/H/M | 104 | 35-34-0-35 | 50.7% (39.2%-62.2%) | 50.5% | 80.6s | SCATTER |
| 14 | H/L/L | 104 | 33-32-0-39 | 50.8% (38.9%-62.5%) | 50.5% | 84.3s | SCATTER |
| 15 | H/H/M | 104 | 35-34-0-35 | 50.7% (39.2%-62.2%) | 50.5% | 82.4s | SCATTER |
| 16 | L/M/H | 104 | 33-33-0-38 | 50.0% (38.3%-61.7%) | 50.0% | 82.8s | ENERGY |
| 17 | H/M/L | 104 | 35-35-0-34 | 50.0% (38.6%-61.4%) | 50.0% | 80.8s | ENERGY |
| 18 | M/M/H | 104 | 30-34-0-40 | 46.9% (35.2%-58.9%) | 48.1% | 83.0s | SCATTER |
| 19 | M/H/M | 104 | 30-34-0-40 | 46.9% (35.2%-58.9%) | 48.1% | 82.7s | SCATTER |
| 20 | M/H/H | 104 | 32-37-0-35 | 46.4% (35.1%-58.0%) | 47.6% | 83.1s | SCATTER |
| 21 | H/M/H | 104 | 28-33-0-43 | 45.9% (34.0%-58.3%) | 47.6% | 85.1s | BALLISTIC |
| 22 | M/L/M | 104 | 30-39-0-35 | 43.5% (32.4%-55.2%) | 45.7% | 82.4s | ENERGY |
| 23 | H/L/M | 104 | 29-38-0-37 | 43.3% (32.1%-55.2%) | 45.7% | 83.4s | ENERGY |
| 24 | M/L/H | 104 | 26-36-0-42 | 41.9% (30.5%-54.3%) | 45.2% | 86.0s | SCATTER |
| 25 | H/L/H | 104 | 26-36-0-42 | 41.9% (30.5%-54.3%) | 45.2% | 88.7s | ENERGY |
| 26 | H/H/H | 104 | 24-39-0-41 | 38.1% (27.1%-50.4%) | 42.8% | 85.9s | SCATTER |
| 27 | L/L/M | 104 | 24-42-0-38 | 36.4% (25.8%-48.4%) | 41.3% | 84.5s | ENERGY |

## Armor Tier Effects

These are raw pooled results; tier stats also include mobility, power, sensor, and weight differences.

| Part | Tier | Appearances | Score | Decided win rate | Mean duration | Defeated mechs |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| HEAD | LIGHT | 936 | 51.2% | 51.9% | 82.1s | 660/1872 |
| HEAD | MEDIUM | 936 | 49.9% | 49.8% | 82.5s | 695/1872 |
| HEAD | SUPERHEAVY | 936 | 48.9% | 48.2% | 84.1s | 699/1872 |
| BODY | LIGHT | 936 | 48.6% | 47.7% | 84.2s | 704/1872 |
| BODY | MEDIUM | 936 | 51.4% | 52.2% | 82.2s | 658/1872 |
| BODY | SUPERHEAVY | 936 | 50.0% | 50.0% | 82.3s | 692/1872 |
| LEGS | LIGHT | 936 | 53.0% | 54.6% | 81.2s | 632/1872 |
| LEGS | MEDIUM | 936 | 49.1% | 48.6% | 82.5s | 702/1872 |
| LEGS | SUPERHEAVY | 936 | 47.9% | 46.5% | 85.0s | 720/1872 |

## Weapon Vulnerability By Combination

Each cell is defeated-mech rate / average durability damage per mech.

| H/B/L | BALLISTIC | ENERGY | MISSILE | SCATTER |
| --- | ---: | ---: | ---: | ---: |
| H/H/H | 51.9% / 278.2 | 42.3% / 261.9 | 0.0% / 34.3 | 76.9% / 238.2 |
| H/H/L | 40.4% / 320.5 | 34.6% / 255.7 | 0.0% / 36.5 | 61.5% / 223.8 |
| H/H/M | 44.2% / 335.0 | 28.8% / 265.7 | 0.0% / 33.5 | 65.4% / 229.1 |
| H/L/H | 46.2% / 317.7 | 61.5% / 318.1 | 0.0% / 35.1 | 53.8% / 194.0 |
| H/L/L | 34.6% / 301.9 | 48.1% / 272.9 | 0.0% / 39.2 | 63.5% / 231.5 |
| H/L/M | 50.0% / 355.1 | 78.8% / 337.5 | 0.0% / 36.0 | 38.5% / 185.2 |
| H/M/H | 55.8% / 313.3 | 51.9% / 273.9 | 0.0% / 34.7 | 50.0% / 217.0 |
| H/M/L | 46.2% / 325.6 | 48.1% / 269.6 | 0.0% / 36.9 | 46.2% / 184.9 |
| H/M/M | 38.5% / 285.5 | 46.2% / 253.4 | 0.0% / 36.9 | 40.4% / 197.2 |
| L/H/H | 32.7% / 284.0 | 38.5% / 285.2 | 0.0% / 34.2 | 63.5% / 223.3 |
| L/H/L | 57.7% / 298.3 | 42.3% / 253.2 | 0.0% / 37.0 | 50.0% / 198.2 |
| L/H/M | 44.2% / 306.6 | 48.1% / 282.1 | 0.0% / 35.8 | 57.7% / 205.9 |
| L/L/H | 48.1% / 305.5 | 46.2% / 318.3 | 0.0% / 37.0 | 40.4% / 190.0 |
| L/L/L | 19.2% / 261.2 | 53.8% / 251.3 | 0.0% / 38.0 | 34.6% / 161.8 |
| L/L/M | 59.6% / 343.5 | 69.2% / 327.7 | 0.0% / 35.8 | 46.2% / 205.6 |
| L/M/H | 50.0% / 326.2 | 57.7% / 300.2 | 0.0% / 34.5 | 36.5% / 171.5 |
| L/M/L | 42.3% / 300.8 | 38.5% / 230.4 | 0.0% / 37.9 | 53.8% / 194.7 |
| L/M/M | 36.5% / 275.6 | 44.2% / 267.2 | 0.0% / 37.0 | 57.7% / 202.7 |
| M/H/H | 38.5% / 315.6 | 59.6% / 277.2 | 0.0% / 33.3 | 61.5% / 220.2 |
| M/H/L | 48.1% / 320.2 | 36.5% / 224.2 | 0.0% / 37.4 | 48.1% / 206.2 |
| M/H/M | 57.7% / 347.3 | 30.8% / 243.1 | 0.0% / 37.1 | 69.2% / 230.2 |
| M/L/H | 30.8% / 278.3 | 65.4% / 335.7 | 0.0% / 36.1 | 73.1% / 212.5 |
| M/L/L | 32.7% / 287.2 | 65.4% / 292.7 | 0.0% / 37.5 | 32.7% / 176.4 |
| M/L/M | 32.7% / 278.3 | 67.3% / 284.7 | 0.0% / 37.4 | 61.5% / 203.4 |
| M/M/H | 51.9% / 292.6 | 40.4% / 281.8 | 0.0% / 36.0 | 59.6% / 204.6 |
| M/M/L | 42.3% / 287.8 | 42.3% / 250.5 | 0.0% / 38.3 | 51.9% / 222.1 |
| M/M/M | 51.9% / 283.1 | 38.5% / 270.5 | 0.0% / 36.7 | 46.2% / 191.7 |

## Part Damage By Weapon Panel

Average durability damage per mech across both teams.

| Panel | Head | Body | Legs | Weapon arms | Mech defeat rate |
| --- | ---: | ---: | ---: | ---: | ---: |
| BALLISTIC | 43.7 | 70.5 | 87.6 | 102.8 | 43.9% |
| ENERGY | 43.7 | 75.2 | 65.1 | 93.2 | 49.1% |
| MISSILE | 1.0 | 5.6 | 19.1 | 10.6 | 0.0% |
| SCATTER | 25.2 | 37.0 | 40.4 | 101.9 | 53.3% |

## Interpretation Limits

- Defeat currently occurs when both weapon arms are destroyed, not when HEAD/BODY/LEGS reaches zero.
- Armor tiers share collision artwork, so this measures durability/stat effects rather than silhouette size.
- Penetration, splash radius, and damage-type resistance are not implemented in damage resolution.
- Timeout results are reported separately and counted as 0.5 only in the descriptive score.
- Weapon panels use different arm-part durability and stats, because only real catalog loadouts were allowed.

Raw merged results: `docs/balance_batch_results.json`
