#!/usr/bin/env python3

import argparse
import json
import math
import statistics
from collections import defaultdict
from pathlib import Path


PARTS = ("Head", "Body", "Legs", "LeftArm", "RightArm", "Backpack")
PANELS = ("BALLISTIC", "ENERGY", "MISSILE", "SCATTER")


def percentile(values, ratio):
    ordered = sorted(values)
    if not ordered:
        return 0.0
    position = (len(ordered) - 1) * ratio
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (position - lower)


def wilson(successes, total):
    if total <= 0:
        return (0.0, 0.0)
    z = 1.96
    proportion = successes / total
    denominator = 1.0 + z * z / total
    center = (proportion + z * z / (2.0 * total)) / denominator
    margin = (
        z
        * math.sqrt(proportion * (1.0 - proportion) / total + z * z / (4.0 * total * total))
        / denominator
    )
    return (max(center - margin, 0.0), min(center + margin, 1.0))


def new_record():
    return {
        "appearances": 0,
        "wins": 0,
        "losses": 0,
        "draws": 0,
        "timeouts": 0,
        "durations": [],
        "mechs": 0,
        "defeated_mechs": 0,
        "hits": 0,
        "damage": defaultdict(float),
        "destroyed": defaultdict(int),
    }


def add_team_result(record, match, team_index, physics_hz):
    record["appearances"] += 1
    duration = match["elapsed_ticks"] / physics_hz
    record["durations"].append(duration)
    outcome = match["outcome"]
    if outcome == "WIN":
        if match["winner_team_index"] == team_index:
            record["wins"] += 1
        else:
            record["losses"] += 1
    elif outcome == "DRAW":
        record["draws"] += 1
    else:
        record["timeouts"] += 1

    for agent in match["agents"]:
        if agent["team_index"] != team_index:
            continue
        record["mechs"] += 1
        record["defeated_mechs"] += int(agent["defeated"])
        record["hits"] += agent["incoming_hits"]
        for part in PARTS:
            maximum = agent["maximum_durability"].get(part, 0.0)
            remaining = agent["durability"].get(part, 0.0)
            record["damage"][part] += maximum - remaining
        for part in agent["destroyed_parts"]:
            record["destroyed"][part] += 1


def score(record):
    return (
        record["wins"] + 0.5 * (record["draws"] + record["timeouts"])
    ) / max(record["appearances"], 1)


def tier_code(name):
    return {"LIGHT": "L", "MEDIUM": "M", "SUPERHEAVY": "H"}[name]


def build_label(build):
    return "/".join(
        tier_code(build[key]) for key in ("head_tier", "body_tier", "legs_tier")
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("inputs", nargs="+")
    parser.add_argument("--report", required=True)
    parser.add_argument("--merged", required=True)
    parser.add_argument("--expected", type=int, default=1404)
    args = parser.parse_args()

    documents = [json.loads(Path(path).read_text()) for path in args.inputs]
    base = documents[0]
    physics_hz = base["physics_hz"]
    timeout_seconds = base["timeout_seconds"]
    matches = [match for document in documents for match in document["matches"]]
    matches.sort(key=lambda match: match["match_index"])
    indices = [match["match_index"] for match in matches]
    if len(indices) != len(set(indices)):
        raise SystemExit("Duplicate match indices detected")
    if args.expected and len(matches) != args.expected:
        raise SystemExit(f"Expected {args.expected} matches, received {len(matches)}")

    builds = {build["id"]: build for build in base["builds"]}
    by_build = defaultdict(new_record)
    by_build_panel = defaultdict(new_record)
    by_panel = defaultdict(new_record)
    by_factor = defaultdict(new_record)
    durations = []
    outcomes = defaultdict(int)
    team_wins = defaultdict(int)

    for match in matches:
        duration = match["elapsed_ticks"] / physics_hz
        durations.append(duration)
        outcomes[match["outcome"]] += 1
        if match["outcome"] == "WIN":
            team_wins[match["winner_team_index"]] += 1
        panel = match["panel_id"]
        by_panel[panel]["durations"].append(duration)
        by_panel[panel]["appearances"] += 1
        by_panel[panel]["timeouts"] += int(match["outcome"] == "TIMEOUT")
        for team_index, build_id in enumerate(match["team_build_ids"]):
            add_team_result(by_build[build_id], match, team_index, physics_hz)
            add_team_result(by_build_panel[(build_id, panel)], match, team_index, physics_hz)
            build = builds[build_id]
            for factor in ("head", "body", "legs"):
                add_team_result(
                    by_factor[(factor.upper(), build[f"{factor}_tier"])],
                    match,
                    team_index,
                    physics_hz,
                )

    merged = dict(base)
    merged["matches"] = matches
    merged["shard_index"] = 0
    merged["shard_count"] = 1
    Path(args.merged).write_text(json.dumps(merged, separators=(",", ":")))

    mean_duration = statistics.fmean(durations)
    median_duration = statistics.median(durations)
    p90_duration = percentile(durations, 0.9)
    timeout_rate = outcomes["TIMEOUT"] / len(matches)

    lines = [
        "# 2v2 Armor Balance Batch Report",
        "",
        "## Experiment",
        "",
        f"- Matches: {len(matches):,}",
        f"- Armor combinations: {len(builds)} (HEAD x BODY x LEGS, 3 x 3 x 3)",
        f"- Expected appearances per combination: {len(matches) * 2 // len(builds)}",
        "- Teams: two identical chassis per team; one aggressive and one range-keeper AI",
        "- Weapons: two valid identical arm-mounted rapid weapons per mech; same panel on both teams",
        (
            f"- Matchup schedule: balanced cyclic sample, "
            f"{base.get('appearances_per_build')} opponents per combination"
            if base.get("appearances_per_build", 0)
            else "- Matchup schedule: every unordered pair once per weapon panel"
        ),
        f"- Timeout: {timeout_seconds:.0f} seconds",
        "- Every experimental loadout passed `MechLoadout.is_valid()` before execution",
        "",
        "## Duration",
        "",
        f"- Restricted mean: **{mean_duration:.1f}s** (target: 120.0s)",
        f"- Median: **{median_duration:.1f}s**",
        f"- P90: **{p90_duration:.1f}s**",
        f"- Timeouts: **{outcomes['TIMEOUT']}/{len(matches)} ({timeout_rate:.1%})**",
        f"- Completed wins: {outcomes['WIN']}; draws: {outcomes['DRAW']}",
        f"- Physical side wins: team 0 **{team_wins[0]}**, team 1 **{team_wins[1]}**",
        "",
        "### Duration By Weapon Panel",
        "",
        "| Panel | Matches | Mean | Median | P90 | Timeout |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
    ]
    for panel in PANELS:
        record = by_panel[panel]
        values = record["durations"]
        lines.append(
            f"| {panel} | {len(values)} | {statistics.fmean(values):.1f}s | "
            f"{statistics.median(values):.1f}s | {percentile(values, 0.9):.1f}s | "
            f"{record['timeouts'] / max(len(values), 1):.1%} |"
        )

    lines.extend(
        [
            "",
            "## Armor Combination Leaderboard",
            "",
            "Win rate excludes timeouts and draws. Score awards 0.5 for a draw or timeout.",
            "Tier order in `H/B/L` is HEAD/BODY/LEGS; `H` means superheavy.",
            "",
            "| Rank | H/B/L | N | W-L-D-T | Win rate (95% CI) | Score | Mean time | Most vulnerable panel |",
            "| ---: | --- | ---: | --- | --- | ---: | ---: | --- |",
        ]
    )
    ranked = sorted(by_build.items(), key=lambda item: (-score(item[1]), item[0]))
    for rank, (build_id, record) in enumerate(ranked, 1):
        decided = record["wins"] + record["losses"]
        win_rate = record["wins"] / decided if decided else 0.0
        low, high = wilson(record["wins"], decided)
        vulnerable = max(
            PANELS,
            key=lambda panel: (
                by_build_panel[(build_id, panel)]["defeated_mechs"]
                / max(by_build_panel[(build_id, panel)]["mechs"], 1),
                sum(by_build_panel[(build_id, panel)]["damage"].values())
                / max(by_build_panel[(build_id, panel)]["mechs"], 1),
            ),
        )
        lines.append(
            f"| {rank} | {build_label(builds[build_id])} | {record['appearances']} | "
            f"{record['wins']}-{record['losses']}-{record['draws']}-{record['timeouts']} | "
            f"{win_rate:.1%} ({low:.1%}-{high:.1%}) | {score(record):.1%} | "
            f"{statistics.fmean(record['durations']):.1f}s | {vulnerable} |"
        )

    lines.extend(
        [
            "",
            "## Armor Tier Effects",
            "",
            "These are raw pooled results; tier stats also include mobility, power, sensor, and weight differences.",
            "",
            "| Part | Tier | Appearances | Score | Decided win rate | Mean duration | Defeated mechs |",
            "| --- | --- | ---: | ---: | ---: | ---: | ---: |",
        ]
    )
    for factor in ("HEAD", "BODY", "LEGS"):
        for tier in ("LIGHT", "MEDIUM", "SUPERHEAVY"):
            record = by_factor[(factor, tier)]
            decided = record["wins"] + record["losses"]
            win_rate = record["wins"] / decided if decided else 0.0
            lines.append(
                f"| {factor} | {tier} | {record['appearances']} | {score(record):.1%} | "
                f"{win_rate:.1%} | {statistics.fmean(record['durations']):.1f}s | "
                f"{record['defeated_mechs']}/{record['mechs']} |"
            )

    lines.extend(
        [
            "",
            "## Weapon Vulnerability By Combination",
            "",
            "Each cell is defeated-mech rate / average durability damage per mech.",
            "",
            "| H/B/L | BALLISTIC | ENERGY | MISSILE | SCATTER |",
            "| --- | ---: | ---: | ---: | ---: |",
        ]
    )
    for build_id in sorted(builds, key=lambda key: build_label(builds[key])):
        cells = []
        for panel in PANELS:
            record = by_build_panel[(build_id, panel)]
            defeat_rate = record["defeated_mechs"] / max(record["mechs"], 1)
            damage_per_mech = sum(record["damage"].values()) / max(record["mechs"], 1)
            cells.append(f"{defeat_rate:.1%} / {damage_per_mech:.1f}")
        lines.append(f"| {build_label(builds[build_id])} | " + " | ".join(cells) + " |")

    lines.extend(
        [
            "",
            "## Part Damage By Weapon Panel",
            "",
            "Average durability damage per mech across both teams.",
            "",
            "| Panel | Head | Body | Legs | Weapon arms | Mech defeat rate |",
            "| --- | ---: | ---: | ---: | ---: | ---: |",
        ]
    )
    for panel in PANELS:
        records = [record for (build_id, key), record in by_build_panel.items() if key == panel]
        mechs = sum(record["mechs"] for record in records)
        damage = defaultdict(float)
        defeated = 0
        for record in records:
            defeated += record["defeated_mechs"]
            for part, value in record["damage"].items():
                damage[part] += value
        lines.append(
            f"| {panel} | {damage['Head'] / mechs:.1f} | {damage['Body'] / mechs:.1f} | "
            f"{damage['Legs'] / mechs:.1f} | {(damage['LeftArm'] + damage['RightArm']) / mechs:.1f} | "
            f"{defeated / mechs:.1%} |"
        )

    lines.extend(
        [
            "",
            "## Interpretation Limits",
            "",
            "- Defeat occurs when BODY is destroyed or every installed weapon is disabled.",
            "- Physical team-side imbalance can confound chassis rankings even when each chassis receives equal side appearances.",
            "- Armor tiers share collision artwork, so this measures durability/stat effects rather than silhouette size.",
            "- Area splash damage, penetration, and damage-type resistance are not implemented in damage resolution.",
            "- Timeout results are reported separately and counted as 0.5 only in the descriptive score.",
            "- Weapon panels use different arm-part durability and stats, because only real catalog loadouts were allowed.",
            "",
            f"Raw merged results: `{args.merged}`",
        ]
    )
    Path(args.report).write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
