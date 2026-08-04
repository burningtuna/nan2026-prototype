# 2v2 Armor Balance Batch Report

## Experiment

- Matches: 135
- Armor combinations: 27 (HEAD x BODY x LEGS, 3 x 3 x 3)
- Expected appearances per combination: 10
- Teams: two identical chassis per team; one aggressive and one range-keeper AI
- Weapons: two valid identical arm-mounted rapid weapons per mech; same panel on both teams
- Matchup schedule: balanced cyclic sample, 10 opponents per combination
- Timeout: 180 seconds
- Every experimental loadout passed `MechLoadout.is_valid()` before execution

## Duration

- Restricted mean: **159.0s** (target: 120.0s)
- Median: **180.0s**
- P90: **180.0s**
- Timeouts: **100/135 (74.1%)**
- Completed wins: 35; draws: 0
- Physical side wins: team 0 **35**, team 1 **0**

### Duration By Weapon Panel

| Panel | Matches | Mean | Median | P90 | Timeout |
| --- | ---: | ---: | ---: | ---: | ---: |
| BALLISTIC | 34 | 158.2s | 180.0s | 180.0s | 73.5% |
| ENERGY | 34 | 153.2s | 180.0s | 180.0s | 64.7% |
| MISSILE | 34 | 175.2s | 180.0s | 180.0s | 94.1% |
| SCATTER | 33 | 149.2s | 180.0s | 180.0s | 63.6% |

## Armor Combination Leaderboard

Win rate excludes timeouts and draws. Score awards 0.5 for a draw or timeout.
Tier order in `H/B/L` is HEAD/BODY/LEGS; `H` means superheavy.

| Rank | H/B/L | N | W-L-D-T | Win rate (95% CI) | Score | Mean time | Most vulnerable panel |
| ---: | --- | ---: | --- | --- | ---: | ---: | --- |
| 1 | L/M/M | 10 | 2-0-0-8 | 100.0% (34.2%-100.0%) | 60.0% | 165.1s | MISSILE |
| 2 | L/H/L | 10 | 2-0-0-8 | 100.0% (34.2%-100.0%) | 60.0% | 163.8s | BALLISTIC |
| 3 | L/H/H | 10 | 2-1-0-7 | 66.7% (20.8%-93.9%) | 55.0% | 153.0s | ENERGY |
| 4 | M/L/H | 10 | 2-1-0-7 | 66.7% (20.8%-93.9%) | 55.0% | 160.9s | ENERGY |
| 5 | M/M/L | 10 | 1-0-0-9 | 100.0% (20.7%-100.0%) | 55.0% | 178.4s | ENERGY |
| 6 | M/M/H | 10 | 2-1-0-7 | 66.7% (20.8%-93.9%) | 55.0% | 152.8s | BALLISTIC |
| 7 | H/L/L | 10 | 2-1-0-7 | 66.7% (20.8%-93.9%) | 55.0% | 145.0s | SCATTER |
| 8 | H/H/L | 10 | 1-0-0-9 | 100.0% (20.7%-100.0%) | 55.0% | 167.4s | SCATTER |
| 9 | H/H/M | 10 | 3-2-0-5 | 60.0% (23.1%-88.2%) | 55.0% | 137.5s | SCATTER |
| 10 | H/H/H | 10 | 1-0-0-9 | 100.0% (20.7%-100.0%) | 55.0% | 179.1s | SCATTER |
| 11 | L/L/L | 10 | 2-2-0-6 | 50.0% (15.0%-85.0%) | 50.0% | 146.1s | ENERGY |
| 12 | L/M/H | 10 | 2-2-0-6 | 50.0% (15.0%-85.0%) | 50.0% | 135.9s | SCATTER |
| 13 | M/L/M | 10 | 2-2-0-6 | 50.0% (15.0%-85.0%) | 50.0% | 147.9s | MISSILE |
| 14 | M/H/L | 10 | 2-2-0-6 | 50.0% (15.0%-85.0%) | 50.0% | 169.0s | ENERGY |
| 15 | H/L/M | 10 | 1-1-0-8 | 50.0% (9.5%-90.5%) | 50.0% | 168.1s | ENERGY |
| 16 | H/L/H | 10 | 1-1-0-8 | 50.0% (9.5%-90.5%) | 50.0% | 169.6s | SCATTER |
| 17 | H/M/L | 10 | 1-1-0-8 | 50.0% (9.5%-90.5%) | 50.0% | 158.3s | SCATTER |
| 18 | H/M/M | 10 | 1-1-0-8 | 50.0% (9.5%-90.5%) | 50.0% | 159.8s | BALLISTIC |
| 19 | H/M/H | 10 | 2-2-0-6 | 50.0% (15.0%-85.0%) | 50.0% | 150.4s | BALLISTIC |
| 20 | L/L/H | 10 | 1-2-0-7 | 33.3% (6.1%-79.2%) | 45.0% | 144.3s | BALLISTIC |
| 21 | L/M/L | 10 | 1-2-0-7 | 33.3% (6.1%-79.2%) | 45.0% | 167.9s | ENERGY |
| 22 | L/H/M | 10 | 0-1-0-9 | 0.0% (0.0%-79.3%) | 45.0% | 179.9s | ENERGY |
| 23 | M/H/M | 10 | 0-1-0-9 | 0.0% (0.0%-79.3%) | 45.0% | 170.2s | SCATTER |
| 24 | M/H/H | 10 | 0-1-0-9 | 0.0% (0.0%-79.3%) | 45.0% | 171.7s | SCATTER |
| 25 | L/L/M | 10 | 0-2-0-8 | 0.0% (0.0%-65.8%) | 40.0% | 176.6s | BALLISTIC |
| 26 | M/L/L | 10 | 1-3-0-6 | 25.0% (4.6%-69.9%) | 40.0% | 132.1s | SCATTER |
| 27 | M/M/M | 10 | 0-3-0-7 | 0.0% (0.0%-56.2%) | 35.0% | 143.1s | ENERGY |

## Armor Tier Effects

These are raw pooled results; tier stats also include mobility, power, sensor, and weight differences.

| Part | Tier | Appearances | Score | Decided win rate | Mean duration | Defeated mechs |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| HEAD | LIGHT | 90 | 50.0% | 50.0% | 159.2s | 49/180 |
| HEAD | MEDIUM | 90 | 47.8% | 41.7% | 158.4s | 48/180 |
| HEAD | SUPERHEAVY | 90 | 52.2% | 59.1% | 159.5s | 53/180 |
| BODY | LIGHT | 90 | 48.3% | 44.4% | 154.5s | 62/180 |
| BODY | MEDIUM | 90 | 50.0% | 50.0% | 156.9s | 47/180 |
| BODY | SUPERHEAVY | 90 | 51.7% | 57.9% | 165.7s | 41/180 |
| LEGS | LIGHT | 90 | 51.1% | 54.2% | 158.7s | 46/180 |
| LEGS | MEDIUM | 90 | 47.8% | 40.9% | 160.9s | 56/180 |
| LEGS | SUPERHEAVY | 90 | 51.1% | 54.2% | 157.5s | 48/180 |

## Weapon Vulnerability By Combination

Each cell is defeated-mech rate / average durability damage per mech.

| H/B/L | BALLISTIC | ENERGY | MISSILE | SCATTER |
| --- | ---: | ---: | ---: | ---: |
| H/H/H | 25.0% / 316.0 | 25.0% / 187.1 | 0.0% / 0.6 | 33.3% / 382.7 |
| H/H/L | 0.0% / 54.4 | 16.7% / 212.0 | 0.0% / 152.4 | 33.3% / 311.9 |
| H/H/M | 50.0% / 417.8 | 33.3% / 218.7 | 0.0% / 29.7 | 75.0% / 583.8 |
| H/L/H | 25.0% / 59.4 | 33.3% / 198.3 | 25.0% / 89.3 | 50.0% / 524.4 |
| H/L/L | 50.0% / 103.1 | 0.0% / 34.2 | 50.0% / 136.2 | 50.0% / 438.1 |
| H/L/M | 25.0% / 52.0 | 66.7% / 338.1 | 0.0% / 1.3 | 33.3% / 87.9 |
| H/M/H | 50.0% / 237.8 | 33.3% / 161.9 | 0.0% / 0.0 | 50.0% / 187.0 |
| H/M/L | 16.7% / 89.0 | 0.0% / 5.9 | 0.0% / 53.4 | 75.0% / 282.6 |
| H/M/M | 75.0% / 371.4 | 0.0% / 0.3 | 0.0% / 50.4 | 50.0% / 466.8 |
| L/H/H | 33.3% / 275.0 | 33.3% / 284.6 | 0.0% / 0.1 | 0.0% / 0.0 |
| L/H/L | 25.0% / 237.4 | 0.0% / 3.8 | 16.7% / 117.5 | 16.7% / 223.0 |
| L/H/M | 0.0% / 0.0 | 75.0% / 551.0 | 0.0% / 4.6 | 16.7% / 296.0 |
| L/L/H | 50.0% / 168.3 | 33.3% / 111.7 | 0.0% / 13.8 | 25.0% / 80.0 |
| L/L/L | 25.0% / 221.0 | 83.3% / 276.2 | 0.0% / 48.7 | 25.0% / 88.8 |
| L/L/M | 66.7% / 284.5 | 25.0% / 61.3 | 33.3% / 100.0 | 25.0% / 59.6 |
| L/M/H | 0.0% / 6.0 | 16.7% / 83.5 | 0.0% / 0.0 | 83.3% / 358.5 |
| L/M/L | 16.7% / 75.1 | 83.3% / 374.5 | 0.0% / 0.5 | 25.0% / 110.4 |
| L/M/M | 16.7% / 73.6 | 25.0% / 75.0 | 33.3% / 135.5 | 0.0% / 0.0 |
| M/H/H | 0.0% / 0.7 | 0.0% / 159.7 | 16.7% / 149.7 | 50.0% / 304.9 |
| M/H/L | 0.0% / 71.5 | 75.0% / 481.7 | 0.0% / 1.6 | 50.0% / 360.0 |
| M/H/M | 16.7% / 123.2 | 25.0% / 283.1 | 25.0% / 150.2 | 50.0% / 331.5 |
| M/L/H | 0.0% / 0.0 | 75.0% / 285.6 | 0.0% / 1.2 | 33.3% / 82.3 |
| M/L/L | 33.3% / 85.2 | 25.0% / 50.0 | 16.7% / 34.3 | 100.0% / 217.5 |
| M/L/M | 33.3% / 196.0 | 33.3% / 66.7 | 50.0% / 156.3 | 25.0% / 66.2 |
| M/M/H | 75.0% / 226.1 | 0.0% / 113.7 | 33.3% / 105.6 | 25.0% / 97.5 |
| M/M/L | 0.0% / 50.4 | 25.0% / 75.0 | 0.0% / 4.8 | 0.0% / 25.2 |
| M/M/M | 0.0% / 0.0 | 66.7% / 282.6 | 0.0% / 75.0 | 50.0% / 152.3 |

## Part Damage By Weapon Panel

Average durability damage per mech across both teams.

| Panel | Head | Body | Legs | Weapon arms | Mech defeat rate |
| --- | ---: | ---: | ---: | ---: | ---: |
| BALLISTIC | 29.5 | 88.3 | 16.1 | 9.3 | 26.5% |
| ENERGY | 39.9 | 126.7 | 15.6 | 4.7 | 34.6% |
| MISSILE | 11.1 | 42.2 | 7.4 | 1.7 | 11.8% |
| SCATTER | 53.0 | 150.8 | 20.0 | 14.0 | 38.6% |

## Interpretation Limits

- Defeat occurs when BODY is destroyed or every installed weapon is disabled.
- Physical team-side imbalance can confound chassis rankings even when each chassis receives equal side appearances.
- Armor tiers share collision artwork, so this measures durability/stat effects rather than silhouette size.
- Penetration, splash radius, and damage-type resistance are not implemented in damage resolution.
- Timeout results are reported separately and counted as 0.5 only in the descriptive score.
- Weapon panels use different arm-part durability and stats, because only real catalog loadouts were allowed.

Raw merged results: `docs/skirmish_balance_10_results.json`
