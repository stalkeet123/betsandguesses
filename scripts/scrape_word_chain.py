"""
scrape_word_chain.py
─────────────────────────────────────────────────────────────
Scrapes Word Chain answers from https://www.gameanswer.net

Each level page has the URL pattern:
    https://www.gameanswer.net/word-chain-level-{N}/

The answers for each level are <li> items inside a <ul> that
follows the "Word Chain Level N Answers:" heading.

Output: word_chain_answers.json
         {
           "1": ["Ice", "Cream", "Cheese"],
           "2": [...],
           ...
         }

Usage:
    pip install requests beautifulsoup4
    python scrape_word_chain.py
    python scrape_word_chain.py --start 1 --end 100
"""

import argparse
import json
import time
import re
import sys
from typing import Optional

import requests
from bs4 import BeautifulSoup

# ─── Config ────────────────────────────────────────────────
BASE_URL   = "https://www.gameanswer.net/word-chain-level-{n}/"
HEADERS    = {
    "User-Agent": (
        "Mozilla/5.0 (compatible; WordChainScraper/1.0; "
        "+https://github.com/your-handle)"
    )
}
DELAY_SEC  = 0.3   # polite delay between requests
OUTPUT     = "word_chain_answers.json"
# ───────────────────────────────────────────────────────────


def fetch_level(session: requests.Session, level: int) -> Optional[list[str]]:
    """
    Fetches one level page and returns the list of answer words.
    Returns None if the level page does not exist (404) or has no answers.
    """
    url = BASE_URL.format(n=level)
    try:
        resp = session.get(url, headers=HEADERS, timeout=15)
    except requests.RequestException as exc:
        print(f"  [!] Network error on level {level}: {exc}")
        return None

    if resp.status_code == 404:
        return None           # no more levels
    if resp.status_code != 200:
        print(f"  [!] HTTP {resp.status_code} for level {level}, skipping")
        return []

    soup = BeautifulSoup(resp.text, "html.parser")

    # ── Strategy 1: Find the "Answers:" heading then get next <ul> ──
    words: list[str] = []
    for heading in soup.find_all(["h2", "h3", "h4", "strong", "p"]):
        text = heading.get_text(strip=True)
        # Match "Word Chain Level N Answers:" style headings
        if re.search(r"answers", text, re.IGNORECASE):
            # Grab the very next <ul> sibling
            sibling = heading.find_next_sibling()
            while sibling:
                if sibling.name == "ul":
                    words = [li.get_text(strip=True)
                             for li in sibling.find_all("li")
                             if li.get_text(strip=True)]
                    break
                elif sibling.name in ["h2", "h3", "h4"]:
                    break    # new section — stop searching
                sibling = sibling.find_next_sibling()
            if words:
                break

    # ── Strategy 2: If strategy 1 found nothing, try entry-content <ul> ──
    if not words:
        content_div = soup.find(class_=re.compile(r"entry.content|post.content", re.I))
        if content_div:
            for ul in content_div.find_all("ul"):
                candidates = [li.get_text(strip=True)
                              for li in ul.find_all("li")
                              if li.get_text(strip=True)]
                # Filter out navigation / sidebar noise
                # (real answers are short single-word items)
                candidates = [w for w in candidates if len(w.split()) <= 3]
                if candidates:
                    words = candidates
                    break

    return words if words else []


def save_checkpoint(data: dict, path: str) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"  💾 Checkpoint saved ({len(data)} levels → {path})")


def scrape(start: int, end: int, out: str) -> dict[str, list[str]]:
    # ── Resume: load existing file if present ──
    results: dict[str, list[str]] = {}
    try:
        with open(out, encoding="utf-8") as f:
            results = json.load(f)
        last_saved = max((int(k) for k in results), default=0)
        if last_saved >= start:
            start = last_saved + 1
            print(f"  ↩ Resuming from level {start} ({last_saved} already saved)")
    except (FileNotFoundError, json.JSONDecodeError):
        pass

    session = requests.Session()

    for level in range(start, end + 1):
        print(f"  Fetching level {level} …", end=" ", flush=True)
        answers = fetch_level(session, level)

        if answers is None:
            print("→ no page found, stopping.")
            break

        if answers:
            print(f"→ {answers}")
            results[str(level)] = answers
        else:
            print("→ (no answers parsed, skipped)")

        # ── Checkpoint every 10 levels ──
        if level % 10 == 0:
            save_checkpoint(results, out)

        time.sleep(DELAY_SEC)

    return results


def main():
    parser = argparse.ArgumentParser(description="Word Chain answer scraper")
    parser.add_argument("--start", type=int, default=1,  help="First level (default: 1)")
    parser.add_argument("--end",   type=int, default=300, help="Last level to try (default: 300)")
    parser.add_argument("--out",   default=OUTPUT, help=f"Output JSON file (default: {OUTPUT})")
    args = parser.parse_args()

    print(f"Scraping Word Chain levels {args.start}–{args.end} …")
    data = scrape(args.start, args.end, args.out)

    # Final save
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"\n✓ Done — {len(data)} levels written to {args.out}")


if __name__ == "__main__":
    main()
