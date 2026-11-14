"""Question knowledge is derived from public catalog metadata, never the hidden card.

Keep each player's evidence until that player's card changes. Suggestions use
the remaining public candidates, never the assigned hidden card. Descriptive
follow-ups stay available even when they no longer split the candidate set.
"""
import re
import unicodedata
import json
from pathlib import Path

CATEGORIES = {
 'animals': ('هل هو حيوان؟', 'Is it an animal?'),
 'fruits': ('هل هي فاكهة؟', 'Is it a fruit?'),
 'vegetables': ('هل هو من الخضروات أو مكونات الطهي؟', 'Is it a vegetable or cooking ingredient?'),
 'dishes': ('هل هو طبق طعام جاهز؟', 'Is it a prepared dish?'),
 'household': ('هل هو أثاث أو غرض منزلي؟', 'Is it furniture or a household object?'),
 'appliances': ('هل هو جهاز منزلي؟', 'Is it a home appliance?'),
 'technology': ('هل هو جهاز تقني؟', 'Is it a technology device?'),
 'science': ('هل هو أداة علمية؟', 'Is it a scientific instrument?'),
 'tools': ('هل هو أداة يدوية؟', 'Is it a hand tool?'),
 'kitchen': ('هل هو من أدوات المطبخ؟', 'Is it a kitchen utensil?'),
 'personal': ('هل هو غرض شخصي؟', 'Is it a personal item?'),
 'hobbies': ('هل يتعلق بالرياضة أو الهوايات؟', 'Is it related to sports or hobbies?'),
 'landmarks': ('هل هو مكان أو معلم؟', 'Is it a place or landmark?'),
}
LABELS = {'category_'+key: {'ar': ar, 'en': en} for key, (ar, en) in CATEGORIES.items()}
FRUIT_TRAITS = {
 'citrus': ('هل هي من الحمضيات؟', 'Is it a citrus fruit?', {'Orange','Lemon','Lime'}),
 'bunch': ('هل تنمو في عناقيد؟', 'Does it grow in bunches?', {'Banana','Grapes','Dates'}),
 'hard_shell': ('هل لها قشرة صلبة تحتاج كسرًا؟', 'Does it have a hard shell to crack?', {'Coconut'}),
 'stone': ('هل لها نواة حجرية واحدة؟', 'Does it have a single stone?', {'Peach','Apricot','Plum','Cherries','Mango','Dates'}),
}
for key, (ar, en, _) in FRUIT_TRAITS.items(): LABELS['fruit_'+key] = {'ar': ar, 'en': en}

# Reuse reviewed boolean metadata from the original cards, without inventing
# facts for missing fields or allowing unrelated domain questions.
TRAITS = {
 'round': ('هل شكله دائري؟', 'Is it round?', {'fruits','vegetables','dishes','household','kitchen','hobbies'}),
 'seeds': ('هل له بذور؟', 'Does it have seeds?', {'fruits','vegetables'}),
 'peel': ('هل له قشرة؟', 'Does it have a peel?', {'fruits','vegetables'}),
 'wild': ('هل يعيش في البرية؟', 'Does it live in the wild?', {'animals'}),
 'fur': ('هل يغطي جسمه الفراء؟', 'Does it have fur?', {'animals'}),
 'bird': ('هل هو من الطيور؟', 'Is it a bird?', {'animals'}),
 'water': ('هل يعيش في الماء؟', 'Does it live in water?', {'animals'}),
 'trunk': ('هل له خرطوم؟', 'Does it have a trunk?', {'animals'}),
 'screen': ('هل له شاشة؟', 'Does it have a screen?', {'technology','appliances'}),
 'lens': ('هل له عدسة؟', 'Does it have a lens?', {'technology','science'}),
}
for key, (ar,en,_) in TRAITS.items(): LABELS['detail_'+key]={'ar':ar,'en':en}

def enrich(catalog, filters):
    original = json.loads((Path(__file__).resolve().parents[1]/'data/cards.json').read_text(encoding='utf-8'))
    reviewed = {item['name']:item for item in original['cards']}
    for key, item in catalog.items():
        category = filters[key]['category']
        # An additive copy: preserve reviewed original facts and source catalogs.
        item['facts'] = dict(item['facts'])
        for name in CATEGORIES: item['facts']['category_'+name] = category == name
        if category == 'fruits':
            for name, (_, _, positive) in FRUIT_TRAITS.items():
                item['facts']['fruit_'+name] = item['name'] in positive
        source = reviewed.get(item['name'], {})
        for name, (_,_,domains) in TRAITS.items():
            if category in domains and type(source.get(name)) is bool:
                item['facts']['detail_'+name] = source[name]

def normalize(value):
    value = unicodedata.normalize('NFKC', value).casefold()
    value = re.sub('[أإآ]', 'ا', value).replace('ى', 'ي')
    return ''.join(c for c in value if c.isalnum())

def state(room, player):
    if not hasattr(room, 'question_evidence'): room.question_evidence = {}
    saved = room.question_evidence.get(player)
    if saved is None or saved['image'] != room.images[player]:
        saved = {'image': room.images[player], 'answers': {}, 'texts': set()}
        room.question_evidence[player] = saved
    return saved

def available(room, player):
    evidence = state(room, player)
    candidates = [item for item in room.catalog.values() if all(
        item['facts'].get(key) == answer for key, answer in evidence['answers'].items())]
    keys = set().union(*(item['facts'] for item in candidates)) if candidates else set()
    result = []
    for key in sorted(keys):
        if key in evidence['answers']: continue
        values = [item['facts'].get(key) for item in candidates]
        # Unknown metadata must not become a false answer, or reveal the card.
        # Category elimination is useful before identifying a category. Once
        # implied/ruled out, hide it; keep unasked descriptive questions instead
        # of forcing a guess just because only one candidate remains.
        known = all(type(value) is bool for value in values)
        relevant = not key.startswith('category_') or set(values) == {False, True}
        if known and relevant:
            result.append(key)
    return result

def remember(room, player, pending, answer):
    evidence = state(room, player)
    key = pending.get('question_id')
    if key: evidence['answers'][key] = answer
    if pending.get('text'): evidence['texts'].add(normalize(pending['text']))
