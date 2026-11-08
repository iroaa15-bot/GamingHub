#!/usr/bin/env python3
"""Validate the original Maana 500-card pack before importing to Godot."""
import json
import sys
from collections import Counter
from pathlib import Path

def validate(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    rounds = data["rounds"]
    assert len(rounds) == 500, f"Expected 500 rounds, got {len(rounds)}"
    assert data.get("game_id") == "maana_wala_alayna"
    ids = set()
    counts = Counter()
    for index, item in enumerate(rounds, 1):
        assert isinstance(item, dict), f"Round {index} not a dictionary"
        key = item.get("id")
        first = str(item.get("option_1", "")).strip()
        second = str(item.get("option_2", "")).strip()
        category = str(item.get("category", "")).strip()
        assert key and key not in ids, f"Missing/duplicate ID: {key}"
        assert first and second and first != second, f"Bad options in {key}"
        assert category, f"Missing category in {key}"
        ids.add(key)
        counts[category] += 1
    assert len(counts) == 20, f"Expected 20 categories, got {len(counts)}"
    assert all(n == 25 for n in counts.values()), "Category sizes must be 25"
    return {"rounds": len(rounds), "unique_ids": len(ids), "categories": len(counts)}

if __name__ == "__main__":
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("data/maana_wala_alayna.json")
    print("PASS:", validate(source))
