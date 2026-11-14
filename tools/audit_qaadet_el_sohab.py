#!/usr/bin/env python3
"""Offline content audit for the six social games. Python standard library only."""
from collections import Counter, defaultdict
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1] / "content" / "qaadet_el_sohab"
TARGETS = {
    "open_heart": 500,
    "act_it": 550,
    "who_among_us": 550,
    "show_skill": 550,
    "truth_or_fiction": 550,
    "table_flip": 300,
}
EXPECTED = {
    "open_heart": ("", 10),
    "act_it": ("group_vote", 20),
    "who_among_us": ("secret_vote", 10),
    "show_skill": ("group_vote", 20),
    "truth_or_fiction": ("truth_vote", 10),
    "table_flip": ("", 0),
}
def normalize(text):
    text = re.sub(r"[\u064b-\u065f\u0670\u0640]", "", text)
    text = text.translate(str.maketrans("أإآىة", "ااايه"))
    return re.sub(r"[^\w]+", " ", text).strip().lower()

def main():
    errors = []
    warnings = []
    counts = Counter()
    ids = {}
    normalized = defaultdict(list)
    stems = defaultdict(Counter)
    batch_files = sorted(ROOT.glob("*_batch_*.json"))
    files = [ROOT / "seed_ar.json", ROOT / "seed_ar_batch02.json"] + batch_files
    for path in files:
        if not path.is_file():
            errors.append(f"Missing file: {path}")
            continue
        try:
            parsed = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            errors.append(f"{path.name}: invalid JSON: {exc}")
            continue
        cards = parsed.get("cards")
        if not isinstance(cards, list):
            errors.append(f"{path.name}: missing cards array")
            continue
        for index, card in enumerate(cards):
            loc = f"{path.name}:{index+1}"
            if not isinstance(card, dict):
                errors.append(f"{loc}: not an object")
                continue
            category = card.get("category")
            if category not in TARGETS:
                continue
            counts[category] += 1
            ident = card.get("id")
            if not isinstance(ident, str) or not ident:
                errors.append(f"{loc}: missing ID")
            elif ident in ids:
                errors.append(f"{loc}: duplicate ID {ident} (first {ids[ident]})")
            else:
                ids[ident] = loc
            text = card.get("text_ar")
            if not isinstance(text, str) or len(text.strip()) < 12:
                errors.append(f"{loc}: short/empty Arabic text")
                continue
            key = normalize(text)
            normalized[(category, key)].append(loc)
            stems[category][normalize(text[:30])] += 1
            if card.get("locale") != "ar":
                errors.append(f"{loc}: incorrect locale")
            interaction, points = EXPECTED[category]
            if interaction and card.get("interaction") != interaction:
                errors.append(f"{loc}: incorrect interaction")
            if card.get("points") != points:
                errors.append(f"{loc}: incorrect points")
            if category in ("act_it", "show_skill") and card.get("duration_seconds") != 30:
                errors.append(f"{loc}: expected 30-second timer")
            if category == "table_flip" and ident and ident.startswith("qs_power_"):
                try:
                    n = int(ident.rsplit("_", 1)[1])
                    if n > 22 and card.get("power_type") not in {
                        "reverse", "swap", "bonus", "steal", "shield", "skip",
                        "double", "gift", "self_bonus", "choice",
                    }:
                        errors.append(f"{loc}: unsupported power type")
                except ValueError:
                    errors.append(f"{loc}: malformed power ID")
    for category, expected in TARGETS.items():
        if counts[category] != expected:
            errors.append(f"{category}: expected {expected}, found {counts[category]}")
    for (category, text), locations in normalized.items():
        if len(locations) > 1:
            errors.append(f"{category}: duplicate normalized text in {', '.join(locations[:5])}")
    for category, counter in stems.items():
        most = counter.most_common(3)
        if most and most[0][1] >= 15:
            warnings.append(f"{category}: repetitive opening phrases {most}")
    report = {
        "status": "FAIL" if errors else "PASS_WITH_EDITORIAL_WARNINGS" if warnings else "PASS",
        "counts": dict(counts), "total": sum(counts.values()),
        "errors": errors, "warnings": warnings,
        "note": "Static structural audit only. Human editorial review and Godot runtime tests still required.",
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if errors else 0

if __name__ == "__main__":
    sys.exit(main())
