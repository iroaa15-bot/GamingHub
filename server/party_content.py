"""Validated Qaadet El Sohab card catalog loader; independent of production rooms."""
from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FILES = (
    ROOT / "content/qaadet_el_sohab/seed_ar.json",
    ROOT / "content/qaadet_el_sohab/seed_ar_batch02.json",
)
CATEGORIES = {
    "open_heart", "act_it", "who_among_us",
    "show_skill", "truth_or_fiction", "table_flip",
}
MAX_CARDS = 3000

def load_cards(paths=FILES):
    cards = []
    seen = set()
    for path in paths:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        if data.get("game_id") != "qaadet_el_sohab" or not isinstance(data.get("cards"), list):
            raise ValueError("Invalid Qaadet El Sohab catalog")
        for card in data["cards"]:
            if not isinstance(card, dict):
                raise ValueError("Card must be an object")
            card_id = card.get("id")
            category = card.get("category")
            text = card.get("text_ar")
            if (not isinstance(card_id, str) or not card_id.strip()
                    or card_id in seen or category not in CATEGORIES
                    or not isinstance(text, str) or not text.strip()
                    or len(text) > 500):
                raise ValueError("Invalid or duplicate card")
            seen.add(card_id)
            cards.append(card.copy())
            if len(cards) > MAX_CARDS:
                raise ValueError("Too many cards")
    if not cards:
        raise ValueError("Empty card catalog")
    return cards

if __name__ == "__main__":
    result = load_cards()
    counts = {category: sum(c["category"] == category for c in result) for category in sorted(CATEGORIES)}
    print(json.dumps({"total": len(result), "categories": counts}, ensure_ascii=False))
