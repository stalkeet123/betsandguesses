"""
analyze_hubs.py
──────────────────────────────────────────────────────────────
Reads word_chain_answers.json and finds "hub" words — words
that appear in at least MIN_APPEARANCES different levels.

For each hub word, we also collect its NEIGHBORS — every word
that appeared next to it (before or after) in any chain.

Output: hub_words.json
  {
    "SUN": {
      "appearances": 9,
      "levels": [12, 45, 88, ...],
      "neighbors": ["Glasses", "Cream", "Flower", "Rise", "Set", ...]
    },
    ...
  }

And a readable hub_words_report.txt summary.

Usage:
    python scripts/analyze_hubs.py
    python scripts/analyze_hubs.py --min 6 --input word_chain_answers.json
"""

import argparse
import json
from collections import defaultdict

MIN_APPEARANCES = 6
INPUT_FILE = "word_chain_answers.json"
OUTPUT_JSON = "hub_words.json"
OUTPUT_REPORT = "hub_words_report.txt"


def analyze(data: dict, min_appearances: int) -> dict:
    # word (uppercase) → set of level numbers where it appears
    word_levels: dict[str, set[int]] = defaultdict(set)
    # word → set of neighbor words (the words directly adjacent in chain)
    word_neighbors: dict[str, set[str]] = defaultdict(set)

    for level_str, chain in data.items():
        level = int(level_str)
        for i, word in enumerate(chain):
            key = word.upper()
            word_levels[key].add(level)

            # Collect neighbors (adjacent words in the chain)
            if i > 0:
                word_neighbors[key].add(chain[i - 1])
            if i < len(chain) - 1:
                word_neighbors[key].add(chain[i + 1])

    # Filter to hub words only
    hubs = {}
    for word, levels in word_levels.items():
        if len(levels) >= min_appearances:
            hubs[word] = {
                "appearances": len(levels),
                "levels": sorted(levels),
                "neighbors": sorted(word_neighbors[word]),
            }

    # Sort by appearances descending
    hubs = dict(sorted(hubs.items(), key=lambda x: -x[1]["appearances"]))
    return hubs


def write_report(hubs: dict, path: str) -> None:
    lines = [
        f"HUB WORDS — appearing in {MIN_APPEARANCES}+ different levels",
        f"Total hub words found: {len(hubs)}",
        "=" * 60,
        "",
    ]
    for word, info in hubs.items():
        lines.append(f"▶ {word}  ({info['appearances']} levels)")
        lines.append(f"  Levels : {info['levels']}")
        lines.append(f"  Connects to: {', '.join(info['neighbors'])}")
        lines.append("")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", default=INPUT_FILE)
    parser.add_argument("--min", type=int, default=MIN_APPEARANCES,
                        help="Minimum appearances to be a hub (default: 6)")
    parser.add_argument("--out-json", default=OUTPUT_JSON)
    parser.add_argument("--out-report", default=OUTPUT_REPORT)
    args = parser.parse_args()

    print(f"Loading {args.input} …")
    with open(args.input, encoding="utf-8") as f:
        data = json.load(f)
    print(f"  → {len(data)} levels loaded")

    print(f"Finding hub words (min {args.min} appearances) …")
    hubs = analyze(data, args.min)
    print(f"  → {len(hubs)} hub words found")

    # Save JSON
    with open(args.out_json, "w", encoding="utf-8") as f:
        json.dump(hubs, f, ensure_ascii=False, indent=2)
    print(f"  → Saved to {args.out_json}")

    # Save readable report
    write_report(hubs, args.out_report)
    print(f"  → Report saved to {args.out_report}")

    # Print top 20 to console
    print("\n── TOP 20 HUB WORDS ─────────────────────────────────")
    for i, (word, info) in enumerate(hubs.items()):
        if i >= 20:
            break
        neighbors_str = ", ".join(info["neighbors"][:8])
        if len(info["neighbors"]) > 8:
            neighbors_str += f" … (+{len(info['neighbors']) - 8} more)"
        print(f"  {word:15s} {info['appearances']:3d} levels  →  {neighbors_str}")


if __name__ == "__main__":
    main()
