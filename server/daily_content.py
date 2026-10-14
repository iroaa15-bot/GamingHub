"""Gaming Hub daily text challenges, standard-library-only and safe to auto-publish.

These are procedurally generated, *not* AI-written. Arithmetic and answer keys are
computed from the same inputs; image-generation remains in a separate review flow.
A fixed UTC date produces identical content on any Render instance without a DB.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import random
from typing import Any

SCHEMA = 1
PER_DAY = 24
ALLOWED_GAMES = {"2", "3", "5"}
AUDIENCES = ["children", "teens", "youth", "adults", "family"]


def _seed(day: dt.date, index: int, attempt: int = 0) -> int:
    data = f"gaming-hub-daily-v1:{day.isoformat()}:{index}:{attempt}".encode()
    return int.from_bytes(hashlib.sha256(data).digest()[:8], "big")


def _words_en(number: int) -> str:
    unit = ("zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen")
    tens = ("", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety")
    if number < 20:
        return unit[number]
    if number < 100:
        return tens[number // 10] + ("-" + unit[number % 10] if number % 10 else "")
    return unit[number // 100] + " hundred" + (" and " + _words_en(number % 100) if number % 100 else "")


def _words_ar(number: int) -> str:
    units = ("صفر", "واحد", "اثنان", "ثلاثة", "أربعة", "خمسة", "ستة", "سبعة", "ثمانية", "تسعة", "عشرة", "أحد عشر", "اثنا عشر", "ثلاثة عشر", "أربعة عشر", "خمسة عشر", "ستة عشر", "سبعة عشر", "ثمانية عشر", "تسعة عشر")
    tens = ("", "", "عشرون", "ثلاثون", "أربعون", "خمسون", "ستون", "سبعون", "ثمانون", "تسعون")
    hundreds = ("", "مائة", "مائتان", "ثلاثمائة", "أربعمائة", "خمسمائة", "ستمائة", "سبعمائة", "ثمانمائة", "تسعمائة")
    if number < 20:
        return units[number]
    if number < 100:
        return (units[number % 10] + " و" if number % 10 else "") + tens[number // 10]
    return hundreds[number // 100] + (" و" + _words_ar(number % 100) if number % 100 else "")


def _question(day: dt.date, slot: int, attempt: int = 0) -> dict[str, Any]:
    rng = random.Random(_seed(day, slot, attempt))
    family = slot % 8
    game, topic, level = "3", "numbers", 1 + slot % 3
    if family == 0:  # Arithmetic series (next term)
        begin, step = rng.randint(3, 149), rng.randint(3, 34)
        terms = [begin + step * i for i in range(4)]
        answer = terms[-1] + step
        en = f"Find the next number: {', '.join(map(str, terms))}, ?"
        ar = f"أكمل المتتالية: {'، '.join(map(str, terms))}، ؟"
        explanation_en, explanation_ar = f"Add {step} each time.", f"نضيف {step} في كل مرة."
        bad = [answer - step, answer + step, answer + 2 * step]
    elif family == 1:  # Multiplication
        a, b = rng.randint(6, 96), rng.randint(3, 33)
        answer = a * b
        en = f"A game has {a} teams with {b} players each. How many players are there?"
        ar = f"في بطولة {a} فريقًا، بكل فريق {b} لاعبًا. كم عدد اللاعبين؟"
        explanation_en, explanation_ar = f"{a} × {b} = {answer}.", f"{a} × {b} = {answer}."
        bad = [answer + a, answer - b, answer + b]
    elif family == 2:  # Practical arithmetic
        a, b, c = rng.randint(12, 83), rng.randint(9, 45), rng.randint(3, 22)
        answer = a + b - c
        en = f"You collect {a} stars and then {b} more, but spend {c}. How many remain?"
        ar = f"جمعت {a} نجمة ثم {b} أخرى، وأنفقت {c}. كم نجمة تبقت؟"
        explanation_en, explanation_ar = f"{a} + {b} − {c} = {answer}.", f"{a} + {b} − {c} = {answer}."
        bad = [a + b, answer + c, answer - c]
    elif family == 3:  # Numbers written in words: language game
        game, topic, level = "2", "language", 1
        answer = rng.randint(21, 899)
        en = f"Which number is written as '{_words_en(answer)}'?"
        ar = f"ما الرقم المكتوب بالحروف «{_words_ar(answer)}»؟"
        explanation_en, explanation_ar = f"The written number is {answer}.", f"الرقم المكتوب هو {answer}."
        bad = [answer + 1, answer - 1, answer + 10]
    elif family == 4:  # Conversion: metres to centimetres
        game, topic = "5", "science"
        metres = rng.randint(2, 899)
        answer = metres * 100
        en = f"A rope is {metres} metres long. How many centimetres is that?"
        ar = f"حبل طوله {metres} مترًا. كم سنتيمترًا يساوي ذلك؟"
        explanation_en, explanation_ar = f"1 metre = 100 cm, so {metres} × 100 = {answer}.", f"المتر = 100 سم، إذن {metres} × 100 = {answer}."
        bad = [metres * 10, metres * 1000, answer + 100]
    elif family == 5:  # Speed/distance
        game, topic, level = "5", "science", 2
        speed, hours = rng.randint(12, 85), rng.randint(2, 8)
        answer = speed * hours
        en = f"A train travels at {speed} km/h for {hours} hours. How far does it go (km)?"
        ar = f"قطار يسير بسرعة {speed} كم/ساعة لمدة {hours} ساعات. كم كيلومترًا قطع؟"
        explanation_en, explanation_ar = f"Distance = speed × time = {answer} km.", f"المسافة = السرعة × الزمن = {answer} كم."
        bad = [speed + hours, answer + speed, answer - speed]
    elif family == 6:  # Book sharing
        groups, per_group = rng.randint(4, 89), rng.randint(3, 38)
        answer = groups * per_group
        en = f"There are {groups} shelves with {per_group} books on each shelf. How many books?"
        ar = f"هناك {groups} رفًا، على كل رف {per_group} كتابًا. كم كتابًا بالمجموع؟"
        explanation_en, explanation_ar = f"{groups} × {per_group} = {answer} books.", f"{groups} × {per_group} = {answer} كتابًا."
        bad = [answer + groups, answer - groups, answer + per_group]
    else:  # Increasing difference series
        first, start_gap = rng.randint(4, 139), rng.randint(2, 29)
        terms = [first]
        for i in range(3):
            terms.append(terms[-1] + start_gap + i)
        answer = terms[-1] + start_gap + 3
        en = f"What comes next: {', '.join(map(str, terms))}, ?"
        ar = f"ما العدد التالي: {'، '.join(map(str, terms))}، ؟"
        explanation_en = f"The gaps are {start_gap}, {start_gap + 1}, {start_gap + 2}, then {start_gap + 3}."
        explanation_ar = f"الفروق هي {start_gap}، {start_gap + 1}، {start_gap + 2}، ثم {start_gap + 3}."
        bad = [answer - 1, answer + 1, answer + start_gap]
    # Numeric distractors are deliberately checked for collisions.
    choices = [answer]
    for candidate in bad + [answer + offset for offset in (2, -2, 5, -5, 11)]:
        if candidate > 0 and candidate not in choices:
            choices.append(candidate)
        if len(choices) == 4:
            break
    if len(choices) != 4:
        raise ValueError("Unable to create unique choices")
    rng.shuffle(choices)
    return {
        "id": f"remote_{day.isoformat()}_{slot:02d}",
        "game": game, "mode": "choice", "topic": topic,
        "level": level, "audiences": AUDIENCES,
        "en": en, "ar": ar,
        "choices_en": list(map(str, choices)), "choices_ar": list(map(str, choices)),
        "correct": choices.index(answer),
        "explain_en": explanation_en, "explain_ar": explanation_ar,
        "verification_value": answer,
    }


def _fingerprint(item: dict[str, Any]) -> str:
    return hashlib.sha256((item["en"] + "\u241f" + item["ar"]).encode("utf-8")).hexdigest()


def _validate_question(item: dict[str, Any]) -> None:
    if item["game"] not in ALLOWED_GAMES or item["mode"] != "choice":
        raise ValueError("Unsupported game/mode")
    if type(item["correct"]) is not int or item["correct"] not in range(4):
        raise ValueError("Invalid answer index")
    if any(len(item[field]) < 12 or len(item[field]) > 230 for field in ("en", "ar")):
        raise ValueError("Invalid language or question length")
    for field in ("choices_ar", "choices_en"):
        if len(item[field]) != 4 or len(set(item[field])) != 4:
            raise ValueError("Invalid/duplicate choices")
    if int(item["choices_en"][item["correct"]]) != item["verification_value"]:
        raise ValueError("Incorrect EN answer")
    if int(item["choices_ar"][item["correct"]]) != item["verification_value"]:
        raise ValueError("Incorrect AR answer")


# Keep a deterministic archive of selected fingerprints in memory. It can be
# rebuilt from a fixed epoch after Render cold starts (no durable disk needed).
# This prevents collisions with *published selections*, not only raw candidates.
_EPOCH = dt.date(2026, 10, 1)
_PACKS: dict[dt.date, dict[str, Any]] = {}
_MARKS: dict[dt.date, set[str]] = {}
_LATEST: dt.date | None = None


def daily_pack(day: dt.date | None = None) -> dict[str, Any]:
    global _LATEST
    day = day or dt.datetime.now(dt.timezone.utc).date()
    if not isinstance(day, dt.date):
        raise TypeError("Expected UTC date")
    if day < _EPOCH:
        raise ValueError("Date precedes daily generation launch")
    if day in _PACKS:
        return _PACKS[day]
    start = (_LATEST + dt.timedelta(days=1)) if _LATEST is not None and day > _LATEST else _EPOCH
    for offset in range((day - start).days + 1):
        active_day = start + dt.timedelta(days=offset)
        seen: set[str] = set()
        for delta in range(90, 0, -1):
            seen.update(_MARKS.get(active_day - dt.timedelta(days=delta), set()))
        marks = set()
        questions: list[dict[str, Any]] = []
        for slot in range(PER_DAY):
            for attempt in range(128):
                item = _question(active_day, slot, attempt)
                marker = _fingerprint(item)
                if marker not in seen and marker not in marks:
                    _validate_question(item)
                    marks.add(marker)
                    item.pop("verification_value")
                    questions.append(item)
                    break
            else:
                raise RuntimeError(f"No unique candidate for daily slot {slot}")
        payload = {
            "schema": SCHEMA, "source": "verified_procedural",
            "date_utc": active_day.isoformat(), "retention_days": 90,
            "questions": questions,
        }
        canonical = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
        payload["sha256"] = hashlib.sha256(canonical).hexdigest()
        _MARKS[active_day] = marks
        _PACKS[active_day] = payload
        _LATEST = active_day
    return _PACKS[day]


def validate_pack(pack: dict[str, Any], expected_date: dt.date | None = None) -> None:
    if pack.get("schema") != SCHEMA or pack.get("source") != "verified_procedural":
        raise ValueError("Invalid pack")
    date = dt.date.fromisoformat(pack["date_utc"])
    if expected_date is not None and date != expected_date:
        raise ValueError("Pack date mismatch")
    questions = pack.get("questions")
    if not isinstance(questions, list) or len(questions) != PER_DAY:
        raise ValueError("Expected 24 questions")
    seen: set[str] = set()
    ids: set[str] = set()
    for q in questions:
        if q.get("game") not in ALLOWED_GAMES or q.get("mode") != "choice":
            raise ValueError("Unsupported game/mode")
        if type(q.get("correct")) is not int or q["correct"] not in range(4):
            raise ValueError("Invalid correct index")
        for key in ("ar", "en", "explain_ar", "explain_en", "topic"):
            if not isinstance(q.get(key), str) or not q[key].strip() or len(q[key]) > 240:
                raise ValueError("Missing text")
        for key in ("choices_ar", "choices_en"):
            opts = q.get(key)
            if not isinstance(opts, list) or len(opts) != 4 or len(set(opts)) != 4:
                raise ValueError("Invalid choices")
        if q["choices_ar"][q["correct"]] != q["choices_en"][q["correct"]]:
            raise ValueError("Language answer mismatch")
        if not str(q.get("id", "")).startswith(f"remote_{date.isoformat()}_") or q["id"] in ids:
            raise ValueError("ID collision")
        marker = _fingerprint(q)
        if marker in seen:
            raise ValueError("Question repetition")
        ids.add(q["id"])
        seen.add(marker)
    clean = dict(pack)
    fingerprint = clean.pop("sha256", None)
    actual = hashlib.sha256(json.dumps(clean, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()
    if fingerprint != actual:
        raise ValueError("Checksum mismatch")


def json_bytes(day: dt.date | None = None) -> bytes:
    data = daily_pack(day)
    validate_pack(data, day)
    return json.dumps(data, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
