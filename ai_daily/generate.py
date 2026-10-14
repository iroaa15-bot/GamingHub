#!/usr/bin/env python3
"""Gaming Hub daily picture puzzle generator.

Review policy:
- Safe object categories (animals, food, fruits, vegetables, objects, landmarks, countries)
  can be generated and approved after visual answer review.
- Person categories (celebrities, footballers, actors, singers) are generated only as
  reviewed content and should never be auto-published blindly.
"""
import argparse, base64, datetime, hashlib, json, os, pathlib, random, struct, urllib.request, zlib
from typing import Dict, List

BASE = pathlib.Path(__file__).resolve().parent
OUTPUT = BASE / "output"
PUBLISH = BASE / "publish"

SAFE_CATEGORIES = {
    "animals": {
        "label_en": "Animals", "label_ar": "حيوانات",
        "items": [
            {"answer_en":"Elephant","answer_ar":"فيل","aliases":["elephant"]},
            {"answer_en":"Lion","answer_ar":"أسد","aliases":["lion"]},
            {"answer_en":"Panda","answer_ar":"باندا","aliases":["panda"]},
            {"answer_en":"Tiger","answer_ar":"نمر","aliases":["tiger"]},
            {"answer_en":"Giraffe","answer_ar":"زرافة","aliases":["giraffe"]},
            {"answer_en":"Penguin","answer_ar":"بطريق","aliases":["penguin"]},
            {"answer_en":"Dolphin","answer_ar":"دولفين","aliases":["dolphin"]},
        ],
        "scene": "Create a clean, colorful, kid-safe single-subject image of a {answer_en}. Centered composition, plain or softly stylized background, no text or watermark.",
    },
    "food": {
        "label_en": "Food", "label_ar": "طعام",
        "items": [
            {"answer_en":"Pizza","answer_ar":"بيتزا","aliases":["pizza"]},
            {"answer_en":"Burger","answer_ar":"برجر","aliases":["burger"]},
            {"answer_en":"Cake","answer_ar":"كيكة","aliases":["cake"]},
            {"answer_en":"Sushi","answer_ar":"سوشي","aliases":["sushi"]},
        ],
        "scene": "Create an appetizing single-subject photo-real style image of {answer_en}, isolated and easy to recognize, no text.",
    },
    "fruits": {
        "label_en": "Fruits", "label_ar": "فواكه",
        "items": [
            {"answer_en":"Apple","answer_ar":"تفاحة","aliases":["apple"]},
            {"answer_en":"Banana","answer_ar":"موزة","aliases":["banana"]},
            {"answer_en":"Strawberry","answer_ar":"فراولة","aliases":["strawberry"]},
            {"answer_en":"Orange","answer_ar":"برتقالة","aliases":["orange"]},
        ],
        "scene": "Create a fresh, realistic close-up image of {answer_en}, centered, bright lighting, no text.",
    },
    "vegetables": {
        "label_en": "Vegetables", "label_ar": "خضروات",
        "items": [
            {"answer_en":"Carrot","answer_ar":"جزرة","aliases":["carrot"]},
            {"answer_en":"Tomato","answer_ar":"طماطم","aliases":["tomato"]},
            {"answer_en":"Cucumber","answer_ar":"خيار","aliases":["cucumber"]},
            {"answer_en":"Pepper","answer_ar":"فلفل","aliases":["pepper"]},
        ],
        "scene": "Create a realistic, easy-to-recognize single-subject image of {answer_en}, plain background, no text.",
    },
    "objects": {
        "label_en": "Objects", "label_ar": "جماد وأدوات",
        "items": [
            {"answer_en":"Guitar","answer_ar":"جيتار","aliases":["guitar"]},
            {"answer_en":"Camera","answer_ar":"كاميرا","aliases":["camera"]},
            {"answer_en":"Laptop","answer_ar":"لابتوب","aliases":["laptop"]},
            {"answer_en":"Bicycle","answer_ar":"دراجة","aliases":["bicycle"]},
            {"answer_en":"Football","answer_ar":"كرة قدم","aliases":["football"]},
            {"answer_en":"Violin","answer_ar":"كمان","aliases":["violin"]},
        ],
        "scene": "Create a detailed image of {answer_en}, single main subject, easy to identify, no brand logos and no text.",
    },
    "countries_landmarks": {
        "label_en": "Countries & Landmarks", "label_ar": "بلاد ومعالم",
        "items": [
            {"answer_en":"Eiffel Tower","answer_ar":"برج إيفل","aliases":["eiffel tower","france"]},
            {"answer_en":"Pyramids","answer_ar":"الأهرامات","aliases":["pyramids","egypt"]},
            {"answer_en":"Taj Mahal","answer_ar":"تاج محل","aliases":["taj mahal","india"]},
            {"answer_en":"Lighthouse","answer_ar":"منارة","aliases":["lighthouse"]},
        ],
        "scene": "Create a clean travel-poster-style image highlighting {answer_en} as the obvious main landmark, no text.",
    },
}

REVIEWED_PERSON_CATEGORIES = {
    "footballers": {
        "label_en": "Footballers", "label_ar": "لاعبو كرة القدم",
        "items": [
            {"answer_en":"Football star A","answer_ar":"نجم كرة قدم أ","aliases":["football star a"]},
            {"answer_en":"Football star B","answer_ar":"نجم كرة قدم ب","aliases":["football star b"]},
            {"answer_en":"Football star C","answer_ar":"نجم كرة قدم ج","aliases":["football star c"]},
            {"answer_en":"Football star D","answer_ar":"نجم كرة قدم د","aliases":["football star d"]},
        ],
        "scene": "Create an original sports-portrait style image of {answer_en}, clear face, clean background, no team logos, no text.",
    },
    "actors": {
        "label_en": "Actors", "label_ar": "ممثلون",
        "items": [
            {"answer_en":"Actor A","answer_ar":"ممثل أ","aliases":["actor a"]},
            {"answer_en":"Actor B","answer_ar":"ممثل ب","aliases":["actor b"]},
            {"answer_en":"Actor C","answer_ar":"ممثل ج","aliases":["actor c"]},
            {"answer_en":"Actor D","answer_ar":"ممثل د","aliases":["actor d"]},
        ],
        "scene": "Create a clean portrait-style image of {answer_en}, attractive lighting, no text or branding.",
    },
    "singers": {
        "label_en": "Singers", "label_ar": "مغنون",
        "items": [
            {"answer_en":"Singer A","answer_ar":"مغنٍ أ","aliases":["singer a"]},
            {"answer_en":"Singer B","answer_ar":"مغنٍ ب","aliases":["singer b"]},
            {"answer_en":"Singer C","answer_ar":"مغنٍ ج","aliases":["singer c"]},
            {"answer_en":"Singer D","answer_ar":"مغنٍ د","aliases":["singer d"]},
        ],
        "scene": "Create a lively portrait-style image of {answer_en}, music-themed mood, no text or branding.",
    },
    "celebrities": {
        "label_en": "Celebrities", "label_ar": "مشاهير",
        "items": [
            {"answer_en":"Celebrity A","answer_ar":"مشهور أ","aliases":["celebrity a"]},
            {"answer_en":"Celebrity B","answer_ar":"مشهور ب","aliases":["celebrity b"]},
            {"answer_en":"Celebrity C","answer_ar":"مشهور ج","aliases":["celebrity c"]},
            {"answer_en":"Celebrity D","answer_ar":"مشهور د","aliases":["celebrity d"]},
        ],
        "scene": "Create an original glamorous portrait-style image of {answer_en}, no logos, no text.",
    },
}

ALL_CATEGORIES = {**SAFE_CATEGORIES, **REVIEWED_PERSON_CATEGORIES}
AUTO_PUBLISH_CATEGORIES = set(SAFE_CATEGORIES.keys())


def png_placeholder(path: pathlib.Path, title: str):
    w, h = 768, 512
    rows = []
    for y in range(h):
        row = bytearray([0])
        for x in range(w):
            row.extend((int(30 + 100 * x / w), int(80 + 80 * y / h), 170))
        rows.append(bytes(row))
    def chunk(tag, data):
        return len(data).to_bytes(4, 'big') + tag + data + (zlib.crc32(tag + data) & 0xffffffff).to_bytes(4, 'big')
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(b"".join(rows), 6)) + chunk(b"IEND", b""))


def _choose_category(day_seed: str) -> str:
    rng = random.Random("category::" + day_seed)
    weighted = list(SAFE_CATEGORIES.keys()) + ["animals", "objects", "food"] + list(REVIEWED_PERSON_CATEGORIES.keys())
    return rng.choice(weighted)


def _pick_choices(category_key: str, day_seed: str):
    cfg = ALL_CATEGORIES[category_key]
    rng = random.Random("choices::" + day_seed + "::" + category_key)
    items = cfg["items"][:]
    correct = rng.choice(items)
    others = [x for x in items if x is not correct]
    rng.shuffle(others)
    chosen = [correct] + others[:3]
    rng.shuffle(chosen)
    correct_index = chosen.index(correct)
    return correct, chosen, correct_index


def _prompt(category_key: str, correct: Dict[str, str]) -> str:
    cfg = ALL_CATEGORIES[category_key]
    return (
        "Create a clean, original, colorful, highly recognizable guessing-game image. "
        "One obvious main subject only. No text, no watermark, no collage, no extra labels, no logos. "
        + cfg["scene"].format(**correct)
    )


def generate(date: str, provider: str, category: str | None = None):
    datetime.date.fromisoformat(date)
    category = category or _choose_category(date)
    if category not in ALL_CATEGORIES:
        raise RuntimeError(f"Unknown category: {category}")
    reviewed_only = category in REVIEWED_PERSON_CATEGORIES
    correct, choices, correct_index = _pick_choices(category, date)
    folder = OUTPUT / date
    folder.mkdir(parents=True, exist_ok=True)
    image = folder / "daily.png"
    prompt = _prompt(category, correct)
    if provider == "openai":
        key = os.environ.get("OPENAI_API_KEY")
        if not key:
            raise RuntimeError("OPENAI_API_KEY missing; use --provider demo for an offline dry run.")
        payload = json.dumps({"model": os.environ.get("IMAGE_MODEL", "gpt-image-1"), "prompt": prompt, "size": "1536x1024", "n": 1}).encode()
        request = urllib.request.Request(
            "https://api.openai.com/v1/images/generations",
            data=payload,
            headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=120) as response:
            result = json.load(response)
        image.write_bytes(base64.b64decode(result["data"][0]["b64_json"]))
    else:
        png_placeholder(image, correct["answer_en"])
    sha = hashlib.sha256(image.read_bytes()).hexdigest()
    item = {
        "schema": 2,
        "id": "daily-" + date,
        "date": date,
        "type": "image_guess",
        "category": category,
        "category_en": ALL_CATEGORIES[category]["label_en"],
        "category_ar": ALL_CATEGORIES[category]["label_ar"],
        "title_en": f"Guess the image • {ALL_CATEGORIES[category]['label_en']}",
        "title_ar": f"خمن الصورة • {ALL_CATEGORIES[category]['label_ar']}",
        "image": "daily.png",
        "sha256": sha,
        "status": "pending_review",
        "provider": provider,
        "prompt": prompt,
        "answer_verified": False,
        "choices_en": [x["answer_en"] for x in choices],
        "choices_ar": [x["answer_ar"] for x in choices],
        "aliases": [x.get("aliases", []) for x in choices],
        "correct_index": correct_index,
        "xp": 25,
        "reviewed_only": reviewed_only,
        "auto_publish_allowed": category in AUTO_PUBLISH_CATEGORIES,
    }
    (folder / "draft.json").write_text(json.dumps(item, ensure_ascii=False, indent=2), encoding="utf-8")
    return folder


def approve(date: str, confirmed: bool):
    folder = OUTPUT / date
    entry = json.loads((folder / "draft.json").read_text(encoding="utf-8"))
    if entry["provider"] == "demo":
        raise RuntimeError("Demo placeholder cannot be approved for publication.")
    if not confirmed:
        raise RuntimeError("Human visual and answer review required: --reviewed")
    if not isinstance(entry.get("correct_index"), int) or entry["correct_index"] not in range(4):
        raise RuntimeError("Invalid answer")
    if len(entry.get("choices_en", [])) != 4 or len(entry.get("choices_ar", [])) != 4:
        raise RuntimeError("Choices missing")
    image = folder / entry["image"]
    if hashlib.sha256(image.read_bytes()).hexdigest() != entry["sha256"]:
        raise RuntimeError("Image checksum mismatch")
    entry["status"] = "approved"
    entry["answer_verified"] = True
    (folder / "approved.json").write_text(json.dumps(entry, ensure_ascii=False, indent=2), encoding="utf-8")
    return folder


def publish(date: str, destination: pathlib.Path, force: bool = False):
    folder = OUTPUT / date
    entry = json.loads((folder / "approved.json").read_text(encoding="utf-8"))
    if entry.get("reviewed_only") and not force:
        # Person categories still publish only after review, but the explicit force flag
        # prevents accidental blind publication in automation.
        raise RuntimeError("This category requires an explicit --force-publish after review.")
    destination.mkdir(parents=True, exist_ok=True)
    import shutil
    target_name = f"daily-{date}.png"
    shutil.copy2(folder / entry["image"], destination / target_name)
    entry["image"] = target_name
    (destination / "daily.json").write_text(json.dumps(entry, ensure_ascii=False, indent=2), encoding="utf-8")
    return destination


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["generate", "approve", "publish"])
    parser.add_argument("--date", default=datetime.date.today().isoformat())
    parser.add_argument("--provider", choices=["demo", "openai"], default="demo")
    parser.add_argument("--category", default=None)
    parser.add_argument("--reviewed", action="store_true")
    parser.add_argument("--destination", default=str(PUBLISH))
    parser.add_argument("--force-publish", action="store_true")
    args = parser.parse_args()
    if args.action == "generate":
        print(generate(args.date, args.provider, args.category))
    elif args.action == "approve":
        print(approve(args.date, args.reviewed))
    else:
        print(publish(args.date, pathlib.Path(args.destination), args.force_publish))
