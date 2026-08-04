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

- Restricted mean: **159.7s** (target: 120.0s)
- Median: **180.0s**
- P90: **180.0s**
- Timeouts: **104/135 (77.0%)**
- Completed wins: 31; draws: 0
- Physical side wins: team 0 **31**, team 1 **0**

### Duration By Weapon Panel

| Panel | Matches | Mean | Median | P90 | Timeout |
| --- | ---: | ---: | ---: | ---: | ---: |
| BALLISTIC | 34 | 163.0s | 180.0s | 180.0s | 79.4% |
| ENERGY | 34 | 151.9s | 180.0s | 180.0s | 64.7% |
| MISSILE | 34 | 175.1s | 180.0s | 180.0s | 94.1% |
| SCATTER | 33 | 148.6s | 180.0s | 180.0s | 69.7% |

## Armor Combination Leaderboard

Win rate excludes timeouts and draws. Score awards 0.5 for a draw or timeout.
Tier order in `H/B/L` is HEAD/BODY/LEGS; `H` means superheavy.

| Rank | H/B/L | N | W-L-D-T | Win rate (95% CI) | Score | Mean time | Most vulnerable panel |
| ---: | --- | ---: | --- | --- | ---: | ---: | --- |
| 1 | L/M/M | 10 | 2-0-0-8 | 100.0% (34.2%-100.0%) | 60.0% | 165.9s | MISSILE |
| 2 | L/H/L | 10 | 2-0-0-8 | 100.0% (34.2%-100.0%) | 60.0% | 160.9s | BALLISTIC |
| 3 | H/H/M | 10 | 3-1-0-6 | 75.0% (30.1%-95.4%) | 60.0% | 143.5s | SCATTER |
| 4 | L/H/H | 10 | 2-1-0-7 | 66.7% (20.8%-93.9%) | 55.0% | 156.4s | BALLISTIC |
| 5 | M/M/L | 10 | 1-0-0-9 | 100.0% (20.7%-100.0%) | 55.0% | 178.4s | ENERGY |
| 6 | M/M/H | 10 | 2-1-0-7 | 66.7% (20.8%-93.9%) | 55.0% | 153.8s | BALLISTIC |
| 7 | H/L/L | 10 | 2-1-0-7 | 66.7% (20.8%-93.9%) | 55.0% | 146.5s | SCATTER |
| 8 | H/H/L | 10 | 1-0-0-9 | 100.0% (20.7%-100.0%) | 55.0% | 169.7s | SCATTER |
| 9 | H/H/H | 10 | 1-0-0-9 | 100.0% (20.7%-100.0%) | 55.0% | 178.7s | SCATTER |
| 10 | L/M/H | 10 | 2-2-0-6 | 50.0% (15.0%-85.0%) | 50.0% | 135.3s | SCATTER |
| 11 | M/L/M | 10 | 2-2-0-6 | 50.0% (15.0%-85.0%) | 50.0% | 147.5s | MISSILE |
| 12 | M/L/H | 10 | 1-1-0-8 | 50.0% (9.5%-90.5%) | 50.0% | 161.7s | ENERGY |
| 13 | M/H/L | 10 | 1-1-0-8 | 50.0% (9.5%-90.5%) | 50.0% | 169.7s | ENERGY |
| 14 | H/L/M | 10 | 1-1-0-8 | 50.0% (9.5%-90.5%) | 50.0% | 162.1s | ENERGY |
| 15 | H/L/H | 10 | 0-0-0-10 | 0.0% (0.0%-0.0%) | 50.0% | 180.0s | SCATTER |
| 16 | H/M/L | 10 | 1-1-0-8 | 50.0% (9.5%-90.5%) | 50.0% | 168.1s | SCATTER |
| 17 | H/M/M | 10 | 1-1-0-8 | 50.0% (9.5%-90.5%) | 50.0% | 157.5s | BALLISTIC |
| 18 | H/M/H | 10 | 2-2-0-6 | 50.0% (15.0%-85.0%) | 50.0% | 147.4s | BALLISTIC |
| 19 | L/L/L | 10 | 1-2-0-7 | 33.3% (6.1%-79.2%) | 45.0% | 139.4s | ENERGY |
| 20 | L/L/M | 10 | 0-1-0-9 | 0.0% (0.0%-79.3%) | 45.0% | 176.4s | BALLISTIC |
| 21 | L/L/H | 10 | 1-2-0-7 | 33.3% (6.1%-79.2%) | 45.0% | 146.8s | BALLISTIC |
| 22 | L/M/L | 10 | 1-2-0-7 | 33.3% (6.1%-79.2%) | 45.0% | 167.4s | ENERGY |
| 23 | L/H/M | 10 | 0-1-0-9 | 0.0% (0.0%-79.3%) | 45.0% | 179.9s | ENERGY |
| 24 | M/H/M | 10 | 0-1-0-9 | 0.0% (0.0%-79.3%) | 45.0% | 170.0s | SCATTER |
| 25 | M/H/H | 10 | 0-1-0-9 | 0.0% (0.0%-79.3%) | 45.0% | 172.9s | SCATTER |
| 26 | M/L/L | 10 | 1-3-0-6 | 25.0% (4.6%-69.9%) | 40.0% | 130.3s | SCATTER |
| 27 | M/M/M | 10 | 0-3-0-7 | 0.0% (0.0%-56.2%) | 35.0% | 146.6s | ENERGY |

## Armor Tier Effects

These are raw pooled results; tier stats also include mobility, power, sensor, and weight differences.

| Part | Tier | Appearances | Score | Decided win rate | Mean duration | Defeated mechs |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| HEAD | LIGHT | 90 | 50.0% | 50.0% | 158.7s | 48/180 |
| HEAD | MEDIUM | 90 | 47.2% | 38.1% | 159.0s | 47/180 |
| HEAD | SUPERHEAVY | 90 | 52.8% | 63.2% | 161.5s | 52/180 |
| BODY | LIGHT | 90 | 47.8% | 40.9% | 154.5s | 60/180 |
| BODY | MEDIUM | 90 | 50.0% | 50.0% | 157.8s | 48/180 |
| BODY | SUPERHEAVY | 90 | 52.2% | 62.5% | 166.9s | 39/180 |
| LEGS | LIGHT | 90 | 50.6% | 52.4% | 158.9s | 48/180 |
| LEGS | MEDIUM | 90 | 48.9% | 45.0% | 161.0s | 52/180 |
| LEGS | SUPERHEAVY | 90 | 50.6% | 52.4% | 159.2s | 47/180 |

## Weapon Vulnerability By Combination

Each cell is defeated-mech rate / average durability damage per mech.

| H/B/L | BALLISTIC | ENERGY | MISSILE | SCATTER |
| --- | ---: | ---: | ---: | ---: |
| H/H/H | 25.0% / 316.0 | 25.0% / 185.5 | 0.0% / 1.4 | 33.3% / 387.8 |
| H/H/L | 0.0% / 54.4 | 16.7% / 213.7 | 25.0% / 153.1 | 33.3% / 306.5 |
| H/H/M | 16.7% / 233.2 | 33.3% / 235.3 | 0.0% / 31.7 | 75.0% / 516.9 |
| H/L/H | 25.0% / 50.0 | 33.3% / 198.3 | 25.0% / 117.9 | 33.3% / 491.9 |
| H/L/L | 50.0% / 100.0 | 0.0% / 34.2 | 50.0% / 136.6 | 50.0% / 436.9 |
| H/L/M | 25.0% / 50.0 | 66.7% / 342.9 | 0.0% / 1.9 | 33.3% / 136.7 |
| H/M/H | 50.0% / 217.8 | 33.3% / 157.9 | 0.0% / 0.0 | 50.0% / 197.9 |
| H/M/L | 16.7% / 99.3 | 0.0% / 6.0 | 16.7% / 105.1 | 75.0% / 317.9 |
| H/M/M | 75.0% / 372.1 | 0.0% / 0.4 | 0.0% / 50.7 | 50.0% / 443.1 |
| L/H/H | 33.3% / 275.5 | 33.3% / 264.2 | 0.0% / 0.5 | 0.0% / 0.0 |
| L/H/L | 25.0% / 245.9 | 0.0% / 3.8 | 16.7% / 119.6 | 16.7% / 225.2 |
| L/H/M | 0.0% / 0.0 | 75.0% / 552.2 | 0.0% / 3.2 | 16.7% / 201.2 |
| L/L/H | 50.0% / 168.3 | 33.3% / 103.0 | 0.0% / 18.5 | 25.0% / 80.0 |
| L/L/L | 50.0% / 244.0 | 83.3% / 275.2 | 0.0% / 51.1 | 25.0% / 131.2 |
| L/L/M | 33.3% / 177.2 | 25.0% / 61.4 | 33.3% / 101.2 | 25.0% / 63.4 |
| L/M/H | 0.0% / 6.0 | 16.7% / 85.3 | 0.0% / 0.0 | 83.3% / 370.8 |
| L/M/L | 16.7% / 71.3 | 83.3% / 381.9 | 0.0% / 0.8 | 25.0% / 111.6 |
| L/M/M | 16.7% / 100.7 | 25.0% / 75.0 | 33.3% / 136.3 | 0.0% / 0.0 |
| M/H/H | 0.0% / 0.7 | 0.0% / 158.8 | 16.7% / 160.8 | 50.0% / 305.0 |
| M/H/L | 0.0% / 79.7 | 75.0% / 467.4 | 0.0% / 2.4 | 33.3% / 362.9 |
| M/H/M | 16.7% / 122.0 | 25.0% / 281.2 | 25.0% / 150.2 | 50.0% / 331.1 |
| M/L/H | 0.0% / 0.0 | 75.0% / 361.6 | 0.0% / 4.1 | 33.3% / 79.4 |
| M/L/L | 33.3% / 97.2 | 25.0% / 50.0 | 16.7% / 35.4 | 100.0% / 217.5 |
| M/L/M | 33.3% / 194.6 | 33.3% / 66.7 | 50.0% / 160.3 | 25.0% / 81.2 |
| M/M/H | 75.0% / 226.6 | 0.0% / 113.9 | 33.3% / 107.2 | 25.0% / 97.5 |
| M/M/L | 0.0% / 50.7 | 25.0% / 75.0 | 0.0% / 5.1 | 0.0% / 72.6 |
| M/M/M | 0.0% / 0.0 | 66.7% / 283.3 | 0.0% / 77.9 | 50.0% / 150.4 |

## Part Damage By Weapon Panel

Average durability damage per mech across both teams.

| Panel | Head | Body | Legs | Weapon arms | Mech defeat rate |
| --- | ---: | ---: | ---: | ---: | ---: |
| BALLISTIC | 30.2 | 79.4 | 13.4 | 9.3 | 24.3% |
| ENERGY | 40.7 | 126.9 | 16.0 | 5.1 | 34.6% |
| MISSILE | 11.8 | 45.4 | 7.8 | 2.0 | 13.2% |
| SCATTER | 53.5 | 148.5 | 20.2 | 14.7 | 37.1% |

## Interpretation Limits

- Defeat occurs when BODY is destroyed or every installed weapon is disabled.
- Physical team-side imbalance can confound chassis rankings even when each chassis receives equal side appearances.
- Armor tiers share collision artwork, so this measures durability/stat effects rather than silhouette size.
- Penetration, splash radius, and damage-type resistance are not implemented in damage resolution.
- Timeout results are reported separately and counted as 0.5 only in the descriptive score.
- Weapon panels use different arm-part durability and stats, because only real catalog loadouts were allowed.

Raw merged results: `docs/skirmish_balance_10_after_results.json`
