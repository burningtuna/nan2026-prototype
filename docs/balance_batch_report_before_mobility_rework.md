# 2v2 Armor Balance Batch Report (Before Mobility Rework)

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

- Restricted mean: **92.8s** (target: 120.0s)
- Median: **120.0s**
- P90: **120.0s**
- Timeouts: **825/1404 (58.8%)**
- Completed wins: 579; draws: 0

### Duration By Weapon Panel

| Panel | Matches | Mean | Median | P90 | Timeout |
| --- | ---: | ---: | ---: | ---: | ---: |
| BALLISTIC | 351 | 117.2s | 120.0s | 120.0s | 86.6% |
| ENERGY | 351 | 105.2s | 120.0s | 120.0s | 60.1% |
| MISSILE | 351 | 116.1s | 120.0s | 120.0s | 87.2% |
| SCATTER | 351 | 32.7s | 26.3s | 60.7s | 1.1% |

## Armor Combination Leaderboard

Win rate excludes timeouts and draws. Score awards 0.5 for a draw or timeout.
Tier order in `H/B/L` is HEAD/BODY/LEGS; `H` means superheavy.

| Rank | H/B/L | N | W-L-D-T | Win rate (95% CI) | Score | Mean time | Most vulnerable panel |
| ---: | --- | ---: | --- | --- | ---: | ---: | --- |
| 1 | L/H/H | 104 | 37-1-0-66 | 97.4% (86.5%-99.5%) | 67.3% | 92.7s | BALLISTIC |
| 2 | M/H/H | 104 | 25-13-0-66 | 65.8% (49.9%-78.8%) | 55.8% | 93.7s | SCATTER |
| 3 | M/M/M | 104 | 25-15-0-64 | 62.5% (47.0%-75.8%) | 54.8% | 94.5s | SCATTER |
| 4 | L/L/H | 104 | 28-19-0-57 | 59.6% (45.3%-72.4%) | 54.3% | 91.7s | SCATTER |
| 5 | M/M/H | 104 | 24-15-0-65 | 61.5% (45.9%-75.1%) | 54.3% | 94.9s | SCATTER |
| 6 | H/H/H | 104 | 25-16-0-63 | 61.0% (45.7%-74.3%) | 54.3% | 94.0s | SCATTER |
| 7 | M/L/H | 104 | 24-17-0-63 | 58.5% (43.4%-72.2%) | 53.4% | 91.8s | ENERGY |
| 8 | H/L/H | 104 | 24-17-0-63 | 58.5% (43.4%-72.2%) | 53.4% | 91.2s | SCATTER |
| 9 | L/M/H | 104 | 25-20-0-59 | 55.6% (41.2%-69.1%) | 52.4% | 91.9s | SCATTER |
| 10 | H/H/M | 104 | 20-16-0-68 | 55.6% (39.6%-70.5%) | 51.9% | 95.1s | SCATTER |
| 11 | H/M/M | 104 | 23-21-0-60 | 52.3% (37.9%-66.2%) | 51.0% | 93.3s | SCATTER |
| 12 | L/M/L | 104 | 24-23-0-57 | 51.1% (37.2%-64.7%) | 50.5% | 90.8s | SCATTER |
| 13 | M/H/L | 104 | 23-22-0-59 | 51.1% (37.0%-65.0%) | 50.5% | 94.1s | SCATTER |
| 14 | H/M/H | 104 | 21-21-0-62 | 50.0% (35.5%-64.5%) | 50.0% | 94.2s | SCATTER |
| 15 | H/L/L | 104 | 21-23-0-60 | 47.7% (33.8%-62.1%) | 49.0% | 92.0s | SCATTER |
| 16 | L/L/L | 104 | 22-26-0-56 | 45.8% (32.6%-59.7%) | 48.1% | 89.9s | SCATTER |
| 17 | L/M/M | 104 | 21-25-0-58 | 45.7% (32.2%-59.8%) | 48.1% | 91.8s | SCATTER |
| 18 | L/H/L | 104 | 20-25-0-59 | 44.4% (30.9%-58.8%) | 47.6% | 91.6s | SCATTER |
| 19 | M/H/M | 104 | 19-24-0-61 | 44.2% (30.4%-58.9%) | 47.6% | 91.7s | SCATTER |
| 20 | H/M/L | 104 | 20-25-0-59 | 44.4% (30.9%-58.8%) | 47.6% | 92.6s | SCATTER |
| 21 | L/L/M | 104 | 18-25-0-61 | 41.9% (28.4%-56.7%) | 46.6% | 96.3s | SCATTER |
| 22 | M/L/L | 104 | 20-29-0-55 | 40.8% (28.2%-54.8%) | 45.7% | 89.9s | SCATTER |
| 23 | M/L/M | 104 | 14-26-0-64 | 35.0% (22.1%-50.5%) | 44.2% | 93.0s | SCATTER |
| 24 | L/H/M | 104 | 15-29-0-60 | 34.1% (21.9%-48.9%) | 43.3% | 91.7s | SCATTER |
| 25 | H/L/M | 104 | 14-28-0-62 | 33.3% (21.0%-48.4%) | 43.3% | 92.1s | SCATTER |
| 26 | H/H/L | 104 | 14-28-0-62 | 33.3% (21.0%-48.4%) | 43.3% | 95.7s | SCATTER |
| 27 | M/M/L | 104 | 13-30-0-61 | 30.2% (18.6%-45.1%) | 41.8% | 93.8s | SCATTER |

## Armor Tier Effects

These are raw pooled results; tier stats also include mobility, power, sensor, and weight differences.

| Part | Tier | Appearances | Score | Decided win rate | Mean duration | Defeated mechs |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| HEAD | LIGHT | 936 | 50.9% | 52.1% | 92.0s | 509/1872 |
| HEAD | MEDIUM | 936 | 49.8% | 49.5% | 93.0s | 525/1872 |
| HEAD | SUPERHEAVY | 936 | 49.3% | 48.3% | 93.4s | 545/1872 |
| BODY | LIGHT | 936 | 48.7% | 46.8% | 92.0s | 556/1872 |
| BODY | MEDIUM | 936 | 50.1% | 50.1% | 93.1s | 540/1872 |
| BODY | SUPERHEAVY | 936 | 51.3% | 53.2% | 93.4s | 483/1872 |
| LEGS | LIGHT | 936 | 47.1% | 43.4% | 92.3s | 609/1872 |
| LEGS | MEDIUM | 936 | 47.9% | 44.7% | 93.3s | 567/1872 |
| LEGS | SUPERHEAVY | 936 | 55.0% | 62.6% | 92.9s | 403/1872 |

## Weapon Vulnerability By Combination

Each cell is defeated-mech rate / average durability damage per mech.

| H/B/L | BALLISTIC | ENERGY | MISSILE | SCATTER |
| --- | ---: | ---: | ---: | ---: |
| H/H/H | 15.4% / 219.3 | 28.8% / 271.3 | 11.5% / 180.1 | 34.6% / 179.0 |
| H/H/L | 7.7% / 299.7 | 36.5% / 345.2 | 30.8% / 223.7 | 67.3% / 223.0 |
| H/H/M | 3.8% / 287.2 | 30.8% / 364.2 | 11.5% / 195.0 | 53.8% / 185.9 |
| H/L/H | 9.6% / 240.1 | 32.7% / 322.6 | 11.5% / 206.4 | 44.2% / 186.5 |
| H/L/L | 7.7% / 255.2 | 34.6% / 315.8 | 19.2% / 233.1 | 57.7% / 212.5 |
| H/L/M | 17.3% / 307.1 | 40.4% / 338.0 | 21.2% / 230.7 | 69.2% / 200.6 |
| H/M/H | 11.5% / 241.5 | 30.8% / 304.8 | 3.8% / 160.7 | 59.6% / 246.4 |
| H/M/L | 17.3% / 251.8 | 21.2% / 265.3 | 28.8% / 228.2 | 67.3% / 228.9 |
| H/M/M | 11.5% / 324.9 | 36.5% / 382.2 | 11.5% / 140.5 | 50.0% / 194.9 |
| L/H/H | 7.7% / 218.3 | 1.9% / 251.1 | 1.9% / 142.3 | 7.7% / 157.1 |
| L/H/L | 21.2% / 274.2 | 28.8% / 293.2 | 17.3% / 197.2 | 63.5% / 230.5 |
| L/H/M | 13.5% / 309.5 | 44.2% / 349.1 | 11.5% / 205.1 | 65.4% / 249.2 |
| L/L/H | 26.9% / 287.4 | 23.1% / 350.4 | 15.4% / 208.0 | 32.7% / 160.1 |
| L/L/L | 5.8% / 259.4 | 40.4% / 295.0 | 13.5% / 184.7 | 61.5% / 253.4 |
| L/L/M | 7.7% / 260.3 | 28.8% / 324.1 | 19.2% / 218.4 | 61.5% / 227.7 |
| L/M/H | 25.0% / 280.9 | 30.8% / 332.7 | 11.5% / 180.2 | 40.4% / 189.8 |
| L/M/L | 15.4% / 287.2 | 38.5% / 301.4 | 13.5% / 176.8 | 51.9% / 197.6 |
| L/M/M | 28.8% / 352.5 | 26.9% / 316.1 | 17.3% / 213.1 | 57.7% / 203.3 |
| M/H/H | 7.7% / 241.8 | 23.1% / 230.5 | 0.0% / 148.8 | 40.4% / 182.9 |
| M/H/L | 17.3% / 279.2 | 30.8% / 275.0 | 19.2% / 226.0 | 48.1% / 208.6 |
| M/H/M | 19.2% / 286.3 | 32.7% / 377.8 | 21.2% / 244.1 | 51.9% / 205.1 |
| M/L/H | 5.8% / 286.2 | 44.2% / 335.5 | 9.6% / 175.3 | 40.4% / 178.7 |
| M/L/L | 13.5% / 259.2 | 38.5% / 297.7 | 17.3% / 191.2 | 69.2% / 224.5 |
| M/L/M | 17.3% / 285.6 | 42.3% / 327.7 | 13.5% / 186.0 | 55.8% / 219.2 |
| M/M/H | 11.5% / 271.2 | 28.8% / 323.0 | 1.9% / 159.4 | 42.3% / 178.4 |
| M/M/L | 13.5% / 281.1 | 42.3% / 298.1 | 19.2% / 188.6 | 75.0% / 259.6 |
| M/M/M | 11.5% / 321.5 | 28.8% / 352.1 | 15.4% / 223.2 | 40.4% / 187.1 |

## Part Damage By Weapon Panel

Average durability damage per mech across both teams.

| Panel | Head | Body | Legs | Weapon arms | Mech defeat rate |
| --- | ---: | ---: | ---: | ---: | ---: |
| BALLISTIC | 47.7 | 66.9 | 82.6 | 79.4 | 13.7% |
| ENERGY | 62.8 | 98.4 | 70.0 | 85.1 | 32.1% |
| MISSILE | 57.7 | 41.8 | 39.2 | 56.3 | 14.4% |
| SCATTER | 28.6 | 40.3 | 33.0 | 104.4 | 52.2% |

## Interpretation Limits

- Defeat currently occurs when both weapon arms are destroyed, not when HEAD/BODY/LEGS reaches zero.
- Armor tiers share collision artwork, so this measures durability/stat effects rather than silhouette size.
- Penetration, splash radius, and damage-type resistance are not implemented in damage resolution.
- Timeout results are reported separately and counted as 0.5 only in the descriptive score.
- Weapon panels use different arm-part durability and stats, because only real catalog loadouts were allowed.

Raw merged results: `docs/balance_batch_results.json`
