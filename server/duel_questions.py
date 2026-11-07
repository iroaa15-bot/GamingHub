"""Question knowledge is derived from public catalog metadata, never the hidden card.

Keep each player's evidence until that player's card changes. Suggestions must
partition the remaining candidates, so already implied or contradicted questions
disappear without disclosing which candidate is actually assigned.
"""
import re
import unicodedata

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

def enrich(catalog, filters):
    for key, item in catalog.items():
        category = filters[key]['category']
        # An additive copy: preserve reviewed original facts and source catalogs.
        item['facts'] = dict(item['facts'])
        for name in CATEGORIES: item['facts']['category_'+name] = category == name
        if category == 'fruits':
            for name, (_, _, positive) in FRUIT_TRAITS.items():
                item['facts']['fruit_'+name] = item['name'] in positive

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
        if all(type(value) is bool for value in values) and set(values) == {False, True}:
            result.append(key)
    return result

def remember(room, player, pending, answer):
    evidence = state(room, player)
    key = pending.get('question_id')
    if key: evidence['answers'][key] = answer
    if pending.get('text'): evidence['texts'].add(normalize(pending['text']))
