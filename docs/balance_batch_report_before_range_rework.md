# 2v2 Armor Balance Batch Report (Before Range Rework)

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

- Restricted mean: **83.6s** (target: 120.0s)
- Median: **107.9s**
- P90: **120.0s**
- Timeouts: **640/1404 (45.6%)**
- Completed wins: 764; draws: 0

### Duration By Weapon Panel

| Panel | Matches | Mean | Median | P90 | Timeout |
| --- | ---: | ---: | ---: | ---: | ---: |
| BALLISTIC | 351 | 117.5s | 120.0s | 120.0s | 87.7% |
| ENERGY | 351 | 102.0s | 120.0s | 120.0s | 54.7% |
| MISSILE | 351 | 91.3s | 102.5s | 120.0s | 39.9% |
| SCATTER | 351 | 23.8s | 18.7s | 47.2s | 0.0% |

## Armor Combination Leaderboard

Win rate excludes timeouts and draws. Score awards 0.5 for a draw or timeout.
Tier order in `H/B/L` is HEAD/BODY/LEGS; `H` means superheavy.

| Rank | H/B/L | N | W-L-D-T | Win rate (95% CI) | Score | Mean time | Most vulnerable panel |
| ---: | --- | ---: | --- | --- | ---: | ---: | --- |
| 1 | M/H/M | 104 | 38-19-0-47 | 66.7% (53.7%-77.5%) | 59.1% | 82.5s | SCATTER |
| 2 | M/M/L | 104 | 34-21-0-49 | 61.8% (48.6%-73.5%) | 56.2% | 85.0s | SCATTER |
| 3 | M/L/L | 104 | 33-23-0-48 | 58.9% (45.9%-70.8%) | 54.8% | 86.2s | SCATTER |
| 4 | H/H/H | 104 | 30-21-0-53 | 58.8% (45.2%-71.2%) | 54.3% | 85.8s | MISSILE |
| 5 | L/L/M | 104 | 30-22-0-52 | 57.7% (44.2%-70.1%) | 53.8% | 86.2s | SCATTER |
| 6 | M/H/L | 104 | 31-24-0-49 | 56.4% (43.3%-68.6%) | 53.4% | 85.0s | SCATTER |
| 7 | H/M/L | 104 | 28-23-0-53 | 54.9% (41.4%-67.7%) | 52.4% | 87.1s | SCATTER |
| 8 | L/L/L | 104 | 32-28-0-44 | 53.3% (40.9%-65.4%) | 51.9% | 83.3s | SCATTER |
| 9 | L/M/L | 104 | 30-28-0-46 | 51.7% (39.2%-64.1%) | 51.0% | 81.7s | SCATTER |
| 10 | L/M/M | 104 | 28-26-0-50 | 51.9% (38.9%-64.6%) | 51.0% | 83.0s | SCATTER |
| 11 | M/H/H | 104 | 32-30-0-42 | 51.6% (39.4%-63.6%) | 51.0% | 81.5s | SCATTER |
| 12 | L/L/H | 104 | 27-26-0-51 | 50.9% (37.9%-63.9%) | 50.5% | 83.7s | SCATTER |
| 13 | L/M/H | 104 | 29-28-0-47 | 50.9% (38.3%-63.4%) | 50.5% | 86.1s | SCATTER |
| 14 | M/L/M | 104 | 29-28-0-47 | 50.9% (38.3%-63.4%) | 50.5% | 82.4s | SCATTER |
| 15 | H/L/H | 104 | 26-25-0-53 | 51.0% (37.7%-64.1%) | 50.5% | 86.2s | SCATTER |
| 16 | L/H/L | 104 | 27-27-0-50 | 50.0% (37.1%-62.9%) | 50.0% | 83.9s | SCATTER |
| 17 | L/H/M | 104 | 28-30-0-46 | 48.3% (35.9%-60.8%) | 49.0% | 82.1s | SCATTER |
| 18 | M/M/H | 104 | 26-30-0-48 | 46.4% (34.0%-59.3%) | 48.1% | 83.6s | SCATTER |
| 19 | M/M/M | 104 | 29-34-0-41 | 46.0% (34.3%-58.2%) | 47.6% | 83.4s | SCATTER |
| 20 | H/L/L | 104 | 26-33-0-45 | 44.1% (32.2%-56.7%) | 46.6% | 84.4s | SCATTER |
| 21 | H/M/M | 104 | 27-34-0-43 | 44.3% (32.5%-56.7%) | 46.6% | 81.3s | SCATTER |
| 22 | H/H/L | 104 | 28-35-0-41 | 44.4% (32.8%-56.7%) | 46.6% | 81.3s | SCATTER |
| 23 | H/M/H | 104 | 24-32-0-48 | 42.9% (30.8%-55.9%) | 46.2% | 81.9s | MISSILE |
| 24 | L/H/H | 104 | 25-35-0-44 | 41.7% (30.1%-54.3%) | 45.2% | 82.3s | MISSILE |
| 25 | M/L/H | 104 | 25-35-0-44 | 41.7% (30.1%-54.3%) | 45.2% | 79.6s | SCATTER |
| 26 | H/L/M | 104 | 21-31-0-52 | 40.4% (28.2%-53.9%) | 45.2% | 86.7s | SCATTER |
| 27 | H/H/M | 104 | 21-36-0-47 | 36.8% (25.5%-49.8%) | 42.8% | 82.7s | SCATTER |

## Armor Tier Effects

These are raw pooled results; tier stats also include mobility, power, sensor, and weight differences.

| Part | Tier | Appearances | Score | Decided win rate | Mean duration | Defeated mechs |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| HEAD | LIGHT | 936 | 50.3% | 50.6% | 83.6s | 654/1872 |
| HEAD | MEDIUM | 936 | 51.8% | 53.2% | 83.2s | 619/1872 |
| HEAD | SUPERHEAVY | 936 | 47.9% | 46.1% | 84.1s | 670/1872 |
| BODY | LIGHT | 936 | 49.9% | 49.8% | 84.3s | 641/1872 |
| BODY | MEDIUM | 936 | 49.9% | 49.9% | 83.7s | 658/1872 |
| BODY | SUPERHEAVY | 936 | 50.2% | 50.3% | 83.0s | 644/1872 |
| LEGS | LIGHT | 936 | 51.4% | 52.6% | 84.2s | 617/1872 |
| LEGS | MEDIUM | 936 | 49.5% | 49.1% | 83.4s | 645/1872 |
| LEGS | SUPERHEAVY | 936 | 49.0% | 48.2% | 83.4s | 681/1872 |

## Weapon Vulnerability By Combination

Each cell is defeated-mech rate / average durability damage per mech.

| H/B/L | BALLISTIC | ENERGY | MISSILE | SCATTER |
| --- | ---: | ---: | ---: | ---: |
| H/H/H | 13.5% / 257.7 | 19.2% / 286.9 | 38.5% / 344.9 | 36.5% / 136.4 |
| H/H/L | 13.5% / 225.5 | 40.4% / 327.1 | 48.1% / 410.7 | 59.6% / 152.1 |
| H/H/M | 7.7% / 272.4 | 46.2% / 411.3 | 46.2% / 455.9 | 59.6% / 160.1 |
| H/L/H | 9.6% / 265.5 | 38.5% / 391.4 | 26.9% / 372.2 | 55.8% / 154.8 |
| H/L/L | 9.6% / 189.0 | 30.8% / 322.1 | 46.2% / 411.7 | 71.2% / 171.6 |
| H/L/M | 15.4% / 244.8 | 34.6% / 378.7 | 38.5% / 432.9 | 59.6% / 165.8 |
| H/M/H | 17.3% / 273.9 | 48.1% / 366.1 | 51.9% / 411.1 | 38.5% / 130.5 |
| H/M/L | 15.4% / 204.0 | 13.5% / 265.6 | 32.7% / 415.8 | 61.5% / 157.2 |
| H/M/M | 13.5% / 276.8 | 28.8% / 362.5 | 46.2% / 390.2 | 55.8% / 146.3 |
| L/H/H | 25.0% / 297.0 | 26.9% / 315.1 | 59.6% / 430.7 | 51.9% / 148.8 |
| L/H/L | 15.4% / 222.5 | 30.8% / 292.8 | 17.3% / 333.8 | 67.3% / 166.5 |
| L/H/M | 15.4% / 253.2 | 28.8% / 335.3 | 36.5% / 378.3 | 59.6% / 145.5 |
| L/L/H | 19.2% / 266.5 | 36.5% / 440.7 | 40.4% / 382.5 | 55.8% / 143.7 |
| L/L/L | 3.8% / 178.2 | 28.8% / 285.0 | 42.3% / 378.3 | 48.1% / 163.4 |
| L/L/M | 7.7% / 204.4 | 25.0% / 277.1 | 25.0% / 403.5 | 59.6% / 172.4 |
| L/M/H | 26.9% / 284.7 | 46.2% / 395.5 | 38.5% / 394.8 | 51.9% / 145.3 |
| L/M/L | 21.2% / 242.1 | 21.2% / 273.3 | 30.8% / 370.0 | 55.8% / 177.8 |
| L/M/M | 13.5% / 228.8 | 38.5% / 357.4 | 26.9% / 359.7 | 59.6% / 146.4 |
| M/H/H | 13.5% / 244.9 | 40.4% / 338.6 | 44.2% / 341.7 | 50.0% / 148.0 |
| M/H/L | 13.5% / 197.7 | 23.1% / 300.5 | 30.8% / 397.6 | 57.7% / 160.3 |
| M/H/M | 9.6% / 257.7 | 28.8% / 332.7 | 26.9% / 383.7 | 36.5% / 141.1 |
| M/L/H | 9.6% / 260.3 | 32.7% / 386.8 | 50.0% / 421.2 | 57.7% / 148.5 |
| M/L/L | 11.5% / 198.5 | 23.1% / 288.2 | 40.4% / 374.1 | 46.2% / 169.2 |
| M/L/M | 9.6% / 201.7 | 19.2% / 280.4 | 38.5% / 392.7 | 65.4% / 168.4 |
| M/M/H | 15.4% / 259.7 | 34.6% / 352.0 | 32.7% / 387.9 | 55.8% / 149.9 |
| M/M/L | 15.4% / 223.1 | 23.1% / 275.6 | 26.9% / 384.1 | 50.0% / 153.8 |
| M/M/M | 13.5% / 232.6 | 40.4% / 397.8 | 44.2% / 423.7 | 59.6% / 147.8 |

## Part Damage By Weapon Panel

Average durability damage per mech across both teams.

| Panel | Head | Body | Legs | Weapon arms | Mech defeat rate |
| --- | ---: | ---: | ---: | ---: | ---: |
| BALLISTIC | 49.0 | 39.9 | 70.4 | 80.1 | 13.9% |
| ENERGY | 73.1 | 74.3 | 100.9 | 86.3 | 31.4% |
| MISSILE | 87.3 | 121.5 | 91.3 | 91.9 | 38.0% |
| SCATTER | 14.0 | 17.1 | 23.0 | 100.4 | 55.1% |

## Interpretation Limits

- Defeat currently occurs when both weapon arms are destroyed, not when HEAD/BODY/LEGS reaches zero.
- Armor tiers share collision artwork, so this measures durability/stat effects rather than silhouette size.
- Penetration, splash radius, and damage-type resistance are not implemented in damage resolution.
- Timeout results are reported separately and counted as 0.5 only in the descriptive score.
- Weapon panels use different arm-part durability and stats, because only real catalog loadouts were allowed.

Raw merged results: `docs/balance_batch_results.json`
