"""Deterministic, offline-cost daily picture challenges.

Draws original vector-style illustrations with Pillow, without any external image API.
Only non-person subjects are automatically published; well-known people are
registered for a later licensed-photo review workflow, not automatically depicted.
"""
from __future__ import annotations

import datetime as dt
import functools
import hashlib
import io
import json
import random
import re
from PIL import Image, ImageDraw, ImageFilter

SCHEMA = 3
PER_DAY = 6
CATALOG = {
    "animals": [("cat", "Cat", "قطة"), ("panda", "Panda", "باندا"), ("penguin", "Penguin", "بطريق"), ("fish", "Fish", "سمكة"), ("rabbit", "Rabbit", "أرنب")],
    "food": [("pizza", "Pizza", "بيتزا"), ("burger", "Burger", "برجر"), ("cake", "Cake", "كيكة"), ("sushi", "Sushi", "سوشي")],
    "fruits": [("apple", "Apple", "تفاحة"), ("banana", "Banana", "موزة"), ("strawberry", "Strawberry", "فراولة"), ("orange", "Orange", "برتقالة")],
    "vegetables": [("carrot", "Carrot", "جزرة"), ("cucumber", "Cucumber", "خيار"), ("tomato", "Tomato", "طماطم"), ("pepper", "Bell pepper", "فلفل رومي")],
    "objects": [("camera", "Camera", "كاميرا"), ("football", "Football", "كرة قدم"), ("guitar", "Guitar", "جيتار"), ("bicycle", "Bicycle", "دراجة")],
    "countries": [("egypt", "Egypt", "مصر"), ("turkey", "Türkiye", "تركيا"), ("france", "France", "فرنسا"), ("japan", "Japan", "اليابان"), ("brazil", "Brazil", "البرازيل")],
    "landmarks": [("pyramids", "Pyramids", "الأهرامات"), ("eiffel", "Eiffel Tower", "برج إيفل"), ("taj", "Taj Mahal", "تاج محل"), ("lighthouse", "Lighthouse", "منارة")],
}
LABELS = {"animals": ("Animals", "حيوانات"), "food": ("Food", "طعام"), "fruits": ("Fruits", "فواكه"), "vegetables": ("Vegetables", "خضروات"), "objects": ("Objects", "جماد وأدوات"), "countries": ("Countries", "بلاد"), "landmarks": ("Landmarks", "معالم")}
# Real names only, never automatically used as the answer for an unverified picture.
REVIEW_ONLY_PEOPLE = {
    "footballers": [("Mohamed Salah", "محمد صلاح"), ("Lionel Messi", "ليونيل ميسي"), ("Cristiano Ronaldo", "كريستيانو رونالدو"), ("Kylian Mbappé", "كيليان مبابي"), ("Erling Haaland", "إيرلينج هالاند"), ("Kevin De Bruyne", "كيفن دي بروين")],
    "actors": [("Omar Sharif", "عمر الشريف"), ("Adel Emam", "عادل إمام"), ("Ahmed Helmy", "أحمد حلمي"), ("Dwayne Johnson", "دواين جونسون"), ("Tom Hanks", "توم هانكس"), ("Emma Watson", "إيما واتسون")],
    "singers": [("Amr Diab", "عمرو دياب"), ("Mohamed Mounir", "محمد منير"), ("Sherine Abdel Wahab", "شيرين عبد الوهاب"), ("Adele", "أديل"), ("Ed Sheeran", "إد شيران"), ("Taylor Swift", "تايلور سويفت")],
    "celebrities": [("Ahmed Zewail", "أحمد زويل"), ("Naguib Mahfouz", "نجيب محفوظ"), ("Mona Zaki", "منى زكي"), ("Keanu Reeves", "كيانو ريفز"), ("Will Smith", "ويل سميث"), ("Zendaya", "زيندايا")],
}


def _draw_subject(draw: ImageDraw.ImageDraw, subject: str) -> None:
    """High-contrast, child-friendly, reproducible vector-like symbols."""
    e, r, p, l = draw.ellipse, draw.rectangle, draw.polygon, draw.line
    if subject in ("apple", "tomato", "orange"):
        color = {"apple": "#e83c49", "tomato": "#e5433a", "orange": "#ff9c2c"}[subject]
        e((110,100,386,385), fill=color, outline="#a53437", width=6)
        p([(242,117),(250,70),(284,94),(266,125)], fill="#348957")
        e((270,82,326,112), fill="#49a956")
        if subject == "orange": e((190,156,230,205), fill="#ffbe66")
    elif subject == "strawberry":
        p([(150,124),(345,124),(305,303),(250,396),(189,303)], fill="#e84256")
        for x,y in [(200,205),(270,188),(310,234),(235,276),(279,320),(188,259)]: e((x,y,x+12,y+18), fill="#ffe9a0")
        p([(170,120),(229,98),(250,128),(270,98),(330,125),(276,151),(224,150)], fill="#27965e")
    elif subject == "banana":
        p([(126,150),(167,151),(174,278),(257,319),(337,275),(355,215),(373,239),(362,315),(281,378),(196,364),(133,282)], fill="#f9d53b", outline="#bb9b15")
        l([(145,172),(152,257),(207,338)], fill="#fff0a4", width=13)
    elif subject == "carrot":
        p([(152,128),(359,162),(226,398)], fill="#f18a26", outline="#b65c16", width=5)
        p([(225,151),(185,91),(234,121),(250,79),(274,135),(330,111),(288,168)], fill="#319e65")
        for y in [206,257,308]: l([(220,y),(250,y-10)], fill="#c96720", width=7)
    elif subject == "cucumber":
        r((136,172,359,306), fill="#249965", outline="#136c49", width=6)
        e((104,172,167,306), fill="#249965", outline="#136c49", width=6)
        e((329,172,390,306), fill="#249965", outline="#136c49", width=6)
        for x in [185,235,290,338]: e((x,200,x+13,215), fill="#89ce91")
    elif subject == "pepper":
        e((135,138,360,348), fill="#e93935", outline="#a62d2b", width=5)
        e((136,230,240,357), fill="#e93935")
        e((260,230,356,357), fill="#e93935")
        r((241,88,259,160), fill="#258552")
        p([(210,138),(251,121),(290,138),(250,173)], fill="#278b56")
    elif subject == "pizza":
        p([(117,144),(395,229),(185,397)], fill="#e4b058", outline="#ac712d", width=8)
        p([(125,158),(352,230),(198,353)], fill="#f6d665")
        for x,y in [(188,200),(284,242),(218,298)]: e((x-23,y-22,x+23,y+22), fill="#cc4b42")
        l([(117,144),(395,229)], fill="#9f5e31", width=26)
    elif subject == "burger":
        e((112,139,392,279), fill="#e6ad59", outline="#9b693d", width=6)
        r((115,262,390,300), fill="#5f3329")
        p([(124,255),(168,286),(219,253),(267,286),(319,256),(378,276),(388,287),(122,286)], fill="#49aa59")
        r((137,308,372,366), fill="#e3ad5c", outline="#ac753a", width=5)
        for x,y in [(210,180),(265,170),(306,213)]: e((x,y,x+9,y+7), fill="#fff4c5")
    elif subject == "cake":
        r((135,212,363,358), fill="#ffccab", outline="#bb6f83", width=6)
        r((130,207,370,239), fill="#f06f9f")
        r((130,272,370,294), fill="#fff6e4")
        r((245,141,257,206), fill="#6b9dd1")
        e((232,115,269,151), fill="#ffdc54")
    elif subject == "sushi":
        for x,y in [(145,151),(267,151),(206,263)]:
            r((x,y,x+106,y+103),fill="#252934",outline="#0e1722",width=5)
            e((x+10,y+9,x+96,y+93),fill="#faf4db")
            e((x+34,y+34,x+74,y+72),fill="#ef785e")
    elif subject in ("cat", "rabbit", "panda"):
        head="#f0b96b" if subject=="cat" else "#ffffff"
        if subject=="cat":
            p([(150,175),(145,86),(228,140)],fill=head)
            p([(344,175),(356,86),(275,140)],fill=head)
        elif subject=="rabbit":
            e((157,47,220,202),fill="#ffffff",outline="#9da6af",width=4)
            e((275,47,338,202),fill="#ffffff",outline="#9da6af",width=4)
            e((175,68,204,182),fill="#f7b2c3")
            e((293,68,322,182),fill="#f7b2c3")
        else:
            e((142,124,226,210),fill="#171b28")
            e((280,124,364,210),fill="#171b28")
        e((120,129,385,388),fill=head,outline="#b8aab0",width=6)
        if subject=="panda":
            e((168,211,236,287),fill="#252938");e((272,211,339,287),fill="#252938")
        e((188,232,213,264),fill="#17263b");e((291,232,316,264),fill="#17263b")
        p([(236,291),(259,291),(247,306)],fill="#e97f95")
        l([(246,308),(236,323)],fill="#64464a",width=4)
        l([(246,308),(258,324)],fill="#64464a",width=4)
    elif subject == "penguin":
        e((141,90,364,397),fill="#252b3e")
        e((190,155,321,378),fill="#ffffff")
        for x in [208,281]: e((x,170,x+20,197),fill="#161b2d")
        p([(240,218),(280,231),(242,252)],fill="#ec9b2f")
        for x in [194,278]: e((x,377,x+42,400),fill="#e9a543")
    elif subject == "fish":
        e((118,162,352,329),fill="#40acd0",outline="#167a9d",width=6)
        p([(315,239),(418,152),(418,341)],fill="#36a9cb")
        e((171,205,195,230),fill="#16314b")
        for x in [232,271]: l([(x,190),(x,303)],fill="#82daec",width=8)
    elif subject == "football":
        e((130,108,370,354),fill="#ffffff",outline="#283244",width=8)
        p([(223,199),(280,178),(316,227),(276,276),(223,260)],fill="#273344")
        for pts in [[(162,139),(209,158),(195,202),(152,195)],[(321,142),(350,175),(328,223),(291,182)],[(144,269),(193,270),(210,316),(169,334)],[(300,309),(332,272),(361,295),(335,341)]]:p(pts,fill="#273344")
    elif subject == "camera":
        r((117,170,389,337),fill="#313f56",outline="#1c293b",width=6)
        r((172,134,293,182),fill="#313f56")
        e((194,187,315,309),fill="#8dbdd7",outline="#12243b",width=15)
        e((235,227,274,264),fill="#42556e")
        e((341,196,371,225),fill="#ffcf59")
    elif subject == "guitar":
        p([(265,61),(291,65),(264,268),(231,260)],fill="#815334")
        e((135,232,291,395),fill="#c37a36",outline="#7d3e1f",width=8)
        e((192,170,300,312),fill="#dc9046")
        e((215,247,260,294),fill="#503126")
        for i in range(5):l([(248+i*3,72),(220+i*3,366)],fill="#fff0d7",width=2)
    elif subject == "bicycle":
        e((93,256,213,377),outline="#293b4f",width=13)
        e((299,256,419,377),outline="#293b4f",width=13)
        l([(153,317),(229,212),(359,317),(153,317),(241,317),(229,212)],fill="#d94d45",width=12)
        l([(225,212),(217,185),(275,185)],fill="#263d50",width=10)
        l([(353,311),(331,210),(367,202)],fill="#273d50",width=10)
    elif subject in ("egypt", "france", "japan", "turkey", "brazil"):
        r((95,142,408,338),fill="#ffffff",outline="#384458",width=5)
        if subject=="egypt":
            r((99,146,405,207),fill="#e44147");r((99,268,405,335),fill="#111827")
            e((241,218,265,262),fill="#d9b04f")
        elif subject=="france":
            r((99,146,201,335),fill="#2e4aa3");r((301,146,405,335),fill="#e84051")
        elif subject=="japan":e((193,192,309,291),fill="#cf364a")
        elif subject=="turkey":
            r((99,146,405,335),fill="#cb384c")
            e((186,182,294,287),fill="#fffaf3");e((206,170,305,271),fill="#cb384c")
            p([(322,221),(327,238),(345,238),(331,249),(335,267),(322,256),(307,267),(313,249),(299,239),(316,238)],fill="#fffaf3")
        else:
            r((99,146,405,335),fill="#279360")
            p([(251,170),(376,238),(251,314),(129,238)],fill="#efcf57")
            e((192,194,309,280),fill="#3674b6")
    elif subject == "pyramids":
        p([(110,367),(226,148),(330,367)],fill="#dfa74e",outline="#b3782b")
        p([(223,367),(332,210),(412,367)],fill="#efbf71",outline="#b68545")
        l([(82,367),(434,367)],fill="#d8a65c",width=11)
    elif subject == "eiffel":
        p([(255,91),(220,322),(144,386),(369,386),(291,322)],fill="#6b6478",outline="#403c4f")
        p([(255,124),(238,291),(272,291)],fill="#faf5ec")
        l([(190,285),(320,285)],fill="#4f4b5b",width=18)
        l([(167,347),(346,347)],fill="#4f4b5b",width=18)
    elif subject == "lighthouse":
        p([(194,379),(215,160),(288,160),(315,379)],fill="#fff8eb",outline="#54627d",width=6)
        for y in [222,283]:p([(209,y),(298,y),(303,y+35),(204,y+35)],fill="#ec5c63")
        r((192,124,311,170),fill="#364761")
        p([(182,124),(252,85),(320,124)],fill="#e25a5a")
        e((231,133,269,163),fill="#fddc7e")
    elif subject == "taj":
        r((123,270,379,375),fill="#f5e8db",outline="#97888c",width=5)
        e((195,149,306,283),fill="#f0e4dc",outline="#9f9595",width=4)
        p([(197,212),(250,105),(304,212)],fill="#f8e5da")
        for x in [142,339]:
            r((x,169,x+19,374),fill="#ede5db")
            e((x-8,149,x+27,189),fill="#f7eee4")
        p([(230,375),(230,313),(274,313),(274,375)],fill="#69778a")


@functools.lru_cache(maxsize=256)
def illustration(day_str: str, subject: str, slot: int) -> bytes:
    seed = int(hashlib.sha256((day_str+subject+str(slot)).encode()).hexdigest()[:8], 16)
    rng = random.Random(seed)
    colors = [("#edf5ff", "#b3d3fa"), ("#fdf2f1", "#ffd4bb"), ("#ebfff6", "#b4efda"), ("#fff9e4", "#f9d6a1")]
    top, bottom = colors[seed % len(colors)]
    im = Image.new("RGB", (512, 512), top)
    dr = ImageDraw.Draw(im)
    dr.rounded_rectangle((24,24,488,488),radius=58,fill=bottom,outline="#ffffff",width=9)
    for i in range(12):
        x,y=rng.randint(45,466),rng.randint(45,466)
        sz=rng.randint(3,8)
        dr.ellipse((x,y,x+sz,y+sz), fill="#ffffff")
    dr.ellipse((95,400,423,438),fill="#ffffff")
    _draw_subject(dr,subject)
    output=io.BytesIO()
    im.save(output,format="PNG", optimize=True)
    return output.getvalue()


@functools.lru_cache(maxsize=128)
def pack(day_str: str) -> dict:
    day=dt.date.fromisoformat(day_str)
    if day.isoformat()!=day_str: raise ValueError("Invalid UTC date")
    categories=list(CATALOG)
    start=day.toordinal()%len(categories)
    # Six categories out of seven each day, rotating the omitted category.
    categories=[categories[(start+i)%len(categories)] for i in range(PER_DAY)]
    puzzles=[]
    for slot,cat in enumerate(categories):
        options=CATALOG[cat]
        r=random.Random(f"{day_str}:{cat}:{slot}")
        answer=options[(day.toordinal()//len(categories)+slot)%len(options)]
        other=[x for x in options if x!=answer]
        r.shuffle(other)
        choices=[answer]+other[:3]
        r.shuffle(choices)
        idx=choices.index(answer)
        image_name=f"daily-{day_str}-{slot:02d}.png"
        picture=illustration(day_str,answer[0],slot)
        titles=LABELS[cat]
        puzzles.append({"schema":2,"id":f"daily-{day_str}-{slot:02d}","date":day_str,
                        "type":"image_guess","category":cat,"category_en":titles[0],"category_ar":titles[1],
                        "title_en":"Guess the Picture","title_ar":"خمن الصورة",
                        "image":image_name,"sha256":hashlib.sha256(picture).hexdigest(),
                        "status":"approved","provider":"original_procedural_art","answer_verified":True,
                        "choices_en":[x[1] for x in choices],"choices_ar":[x[2] for x in choices],
                        "correct_index":idx,"xp":25})
    return {"schema":SCHEMA,"date_utc":day_str,"source":"deterministic_original_illustrations","puzzles":puzzles}


def today_pack():
    return pack(dt.datetime.now(dt.timezone.utc).date().isoformat())


def image_for_filename(filename: str) -> bytes | None:
    m=re.fullmatch(r"daily-(\d{4}-\d{2}-\d{2})-(\d{2})\.png",filename)
    if not m:return None
    date,slot=m.group(1),int(m.group(2))
    # Only today's images are exposed; stale packs are rejected by the client.
    if date!=dt.datetime.now(dt.timezone.utc).date().isoformat() or slot>=PER_DAY:return None
    data=pack(date)["puzzles"][slot]
    answer_key=CATALOG[data["category"]][0][0]
    # Locate the answer corresponding to correct_index with English name.
    answer_name=data["choices_en"][data["correct_index"]]
    subject=next(x[0] for x in CATALOG[data["category"]] if x[1]==answer_name)
    return illustration(date,subject,slot)


def public_json():
    return json.dumps(today_pack(),ensure_ascii=False,separators=(",", ":")).encode("utf-8")
