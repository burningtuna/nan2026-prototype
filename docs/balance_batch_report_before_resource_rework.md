# 2v2 Armor Balance Batch Report (Before Resource Rework)

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

- Restricted mean: **92.2s** (target: 120.0s)
- Median: **120.0s**
- P90: **120.0s**
- Timeouts: **815/1404 (58.0%)**
- Completed wins: 589; draws: 0

### Duration By Weapon Panel

| Panel | Matches | Mean | Median | P90 | Timeout |
| --- | ---: | ---: | ---: | ---: | ---: |
| BALLISTIC | 351 | 117.4s | 120.0s | 120.0s | 90.0% |
| ENERGY | 351 | 101.8s | 120.0s | 120.0s | 52.1% |
| MISSILE | 351 | 117.5s | 120.0s | 120.0s | 89.7% |
| SCATTER | 351 | 32.0s | 26.5s | 55.5s | 0.3% |

## Armor Combination Leaderboard

Win rate excludes timeouts and draws. Score awards 0.5 for a draw or timeout.
Tier order in `H/B/L` is HEAD/BODY/LEGS; `H` means superheavy.

| Rank | H/B/L | N | W-L-D-T | Win rate (95% CI) | Score | Mean time | Most vulnerable panel |
| ---: | --- | ---: | --- | --- | ---: | ---: | --- |
| 1 | L/M/L | 104 | 30-16-0-58 | 65.2% (50.8%-77.3%) | 56.7% | 91.9s | SCATTER |
| 2 | L/H/H | 104 | 24-11-0-69 | 68.6% (52.0%-81.4%) | 56.2% | 95.5s | SCATTER |
| 3 | M/H/H | 104 | 26-14-0-64 | 65.0% (49.5%-77.9%) | 55.8% | 94.3s | SCATTER |
| 4 | H/H/H | 104 | 28-16-0-60 | 63.6% (48.9%-76.2%) | 55.8% | 92.0s | SCATTER |
| 5 | H/H/M | 104 | 22-14-0-68 | 61.1% (44.9%-75.2%) | 53.8% | 94.9s | ENERGY |
| 6 | L/L/H | 104 | 23-16-0-65 | 59.0% (43.4%-72.9%) | 53.4% | 95.5s | SCATTER |
| 7 | H/M/M | 104 | 25-19-0-60 | 56.8% (42.2%-70.3%) | 52.9% | 88.9s | SCATTER |
| 8 | M/H/M | 104 | 24-19-0-61 | 55.8% (41.1%-69.6%) | 52.4% | 91.6s | SCATTER |
| 9 | H/M/H | 104 | 22-18-0-64 | 55.0% (39.8%-69.3%) | 51.9% | 92.3s | ENERGY |
| 10 | M/M/H | 104 | 22-20-0-62 | 52.4% (37.7%-66.6%) | 51.0% | 91.8s | SCATTER |
| 11 | H/L/M | 104 | 22-20-0-62 | 52.4% (37.7%-66.6%) | 51.0% | 91.1s | SCATTER |
| 12 | L/L/M | 104 | 23-22-0-59 | 51.1% (37.0%-65.0%) | 50.5% | 93.0s | SCATTER |
| 13 | L/M/H | 104 | 18-17-0-69 | 51.4% (35.6%-67.0%) | 50.5% | 95.5s | SCATTER |
| 14 | L/H/M | 104 | 21-20-0-63 | 51.2% (36.5%-65.7%) | 50.5% | 94.8s | SCATTER |
| 15 | M/L/H | 104 | 22-22-0-60 | 50.0% (35.8%-64.2%) | 50.0% | 92.5s | SCATTER |
| 16 | H/L/H | 104 | 23-23-0-58 | 50.0% (36.1%-63.9%) | 50.0% | 90.4s | SCATTER |
| 17 | M/H/L | 104 | 18-19-0-67 | 48.6% (33.4%-64.1%) | 49.5% | 93.7s | SCATTER |
| 18 | H/L/L | 104 | 27-31-0-46 | 46.6% (34.3%-59.2%) | 48.1% | 87.4s | ENERGY |
| 19 | H/H/L | 104 | 19-23-0-62 | 45.2% (31.2%-60.1%) | 48.1% | 91.9s | SCATTER |
| 20 | M/M/L | 104 | 21-26-0-57 | 44.7% (31.4%-58.8%) | 47.6% | 93.0s | SCATTER |
| 21 | L/L/L | 104 | 21-27-0-56 | 43.8% (30.7%-57.7%) | 47.1% | 91.4s | SCATTER |
| 22 | L/M/M | 104 | 19-25-0-60 | 43.2% (29.7%-57.8%) | 47.1% | 91.7s | SCATTER |
| 23 | M/L/M | 104 | 20-28-0-56 | 41.7% (28.8%-55.7%) | 46.2% | 91.9s | SCATTER |
| 24 | L/H/L | 104 | 18-27-0-59 | 40.0% (27.0%-54.5%) | 45.7% | 90.9s | SCATTER |
| 25 | M/L/L | 104 | 17-29-0-58 | 37.0% (24.5%-51.4%) | 44.2% | 91.3s | SCATTER |
| 26 | H/M/L | 104 | 19-32-0-53 | 37.3% (25.3%-51.0%) | 43.8% | 88.3s | SCATTER |
| 27 | M/M/M | 104 | 15-35-0-54 | 30.0% (19.1%-43.8%) | 40.4% | 91.3s | SCATTER |

## Armor Tier Effects

These are raw pooled results; tier stats also include mobility, power, sensor, and weight differences.

| Part | Tier | Appearances | Score | Decided win rate | Mean duration | Defeated mechs |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| HEAD | LIGHT | 936 | 50.9% | 52.1% | 93.4s | 525/1872 |
| HEAD | MEDIUM | 936 | 48.6% | 46.6% | 92.4s | 567/1872 |
| HEAD | SUPERHEAVY | 936 | 50.6% | 51.4% | 90.8s | 546/1872 |
| BODY | LIGHT | 936 | 48.9% | 47.6% | 91.6s | 581/1872 |
| BODY | MEDIUM | 936 | 49.1% | 47.9% | 91.6s | 562/1872 |
| BODY | SUPERHEAVY | 936 | 52.0% | 55.1% | 93.3s | 495/1872 |
| LEGS | LIGHT | 936 | 47.9% | 45.2% | 91.1s | 608/1872 |
| LEGS | MEDIUM | 936 | 49.4% | 48.6% | 92.1s | 562/1872 |
| LEGS | SUPERHEAVY | 936 | 52.7% | 57.0% | 93.3s | 468/1872 |

## Weapon Vulnerability By Combination

Each cell is defeated-mech rate / average durability damage per mech.

| H/B/L | BALLISTIC | ENERGY | MISSILE | SCATTER |
| --- | ---: | ---: | ---: | ---: |
| H/H/H | 11.5% / 262.8 | 36.5% / 307.6 | 3.8% / 150.4 | 38.5% / 192.4 |
| H/H/L | 15.4% / 275.5 | 40.4% / 312.6 | 13.5% / 172.1 | 57.7% / 204.1 |
| H/H/M | 13.5% / 311.0 | 40.4% / 309.0 | 15.4% / 222.5 | 34.6% / 196.3 |
| H/L/H | 19.2% / 279.1 | 40.4% / 297.4 | 13.5% / 185.7 | 42.3% / 178.9 |
| H/L/L | 13.5% / 262.5 | 61.5% / 307.7 | 9.6% / 185.6 | 53.8% / 214.1 |
| H/L/M | 21.2% / 330.4 | 38.5% / 278.3 | 11.5% / 177.6 | 48.1% / 193.2 |
| H/M/H | 19.2% / 284.2 | 44.2% / 360.2 | 9.6% / 175.5 | 28.8% / 177.4 |
| H/M/L | 11.5% / 276.2 | 44.2% / 293.0 | 21.2% / 184.9 | 71.2% / 222.1 |
| H/M/M | 11.5% / 298.7 | 36.5% / 294.8 | 15.4% / 183.0 | 42.3% / 190.0 |
| L/H/H | 11.5% / 260.5 | 26.9% / 384.9 | 13.5% / 197.3 | 34.6% / 179.5 |
| L/H/L | 19.2% / 286.2 | 34.6% / 304.1 | 9.6% / 181.3 | 76.9% / 253.0 |
| L/H/M | 13.5% / 272.8 | 17.3% / 283.9 | 9.6% / 164.7 | 61.5% / 228.8 |
| L/L/H | 11.5% / 275.8 | 23.1% / 352.0 | 9.6% / 197.4 | 46.2% / 191.2 |
| L/L/L | 21.2% / 276.5 | 32.7% / 246.4 | 11.5% / 179.1 | 69.2% / 258.3 |
| L/L/M | 11.5% / 320.7 | 30.8% / 356.5 | 21.2% / 234.2 | 61.5% / 216.7 |
| L/M/H | 17.3% / 261.2 | 23.1% / 347.4 | 19.2% / 208.0 | 48.1% / 203.6 |
| L/M/L | 23.1% / 284.2 | 23.1% / 274.0 | 15.4% / 191.3 | 38.5% / 205.0 |
| L/M/M | 13.5% / 257.2 | 28.8% / 303.5 | 19.2% / 212.3 | 61.5% / 221.9 |
| M/H/H | 9.6% / 269.0 | 28.8% / 330.8 | 5.8% / 159.7 | 42.3% / 175.0 |
| M/H/L | 15.4% / 265.5 | 32.7% / 297.1 | 5.8% / 161.0 | 57.7% / 204.5 |
| M/H/M | 11.5% / 290.5 | 23.1% / 291.2 | 23.1% / 200.3 | 46.2% / 186.0 |
| M/L/H | 23.1% / 325.8 | 30.8% / 328.4 | 15.4% / 216.1 | 46.2% / 182.5 |
| M/L/L | 13.5% / 274.3 | 42.3% / 301.8 | 17.3% / 187.7 | 67.3% / 239.8 |
| M/L/M | 19.2% / 254.1 | 46.2% / 296.1 | 9.6% / 147.0 | 63.5% / 213.6 |
| M/M/H | 13.5% / 294.8 | 26.9% / 292.0 | 21.2% / 229.3 | 44.2% / 194.0 |
| M/M/L | 19.2% / 273.7 | 42.3% / 302.1 | 11.5% / 161.5 | 55.8% / 207.4 |
| M/M/M | 11.5% / 286.8 | 61.5% / 334.8 | 17.3% / 220.8 | 69.2% / 214.8 |

## Part Damage By Weapon Panel

Average durability damage per mech across both teams.

| Panel | Head | Body | Legs | Weapon arms | Mech defeat rate |
| --- | ---: | ---: | ---: | ---: | ---: |
| BALLISTIC | 48.1 | 64.4 | 87.4 | 81.9 | 15.4% |
| ENERGY | 59.5 | 96.1 | 68.3 | 86.8 | 35.5% |
| MISSILE | 48.7 | 40.6 | 42.9 | 56.2 | 13.7% |
| SCATTER | 25.4 | 42.3 | 33.7 | 104.0 | 52.1% |

## Interpretation Limits

- Defeat currently occurs when both weapon arms are destroyed, not when HEAD/BODY/LEGS reaches zero.
- Armor tiers share collision artwork, so this measures durability/stat effects rather than silhouette size.
- Penetration, splash radius, and damage-type resistance are not implemented in damage resolution.
- Timeout results are reported separately and counted as 0.5 only in the descriptive score.
- Weapon panels use different arm-part durability and stats, because only real catalog loadouts were allowed.

Raw merged results: `docs/balance_batch_results.json`
