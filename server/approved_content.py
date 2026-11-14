"""Explicitly approved additive content only. Never loads staging/review manifests."""
import json,re
from functools import lru_cache
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
RIGHTS='USER_ATTESTED_ORIGINAL_GENERATED_COMMERCIAL_USE'
def pictures():
 path=ROOT/'data/approved_content/pictures.json'
 if not path.is_file():return {'cards':[],'catalog':[],'filters':{'categories':{},'items':{}}}
 value=json.loads(path.read_text(encoding='utf-8'))
 if value.get('approval',{}).get('kind')!=RIGHTS:raise ValueError('Missing explicit picture approval')
 ids=set();names=set();assets=set()
 for card,item in zip(value['cards'],value['catalog'],strict=True):
  if item['rights_status']!=RIGHTS or item['id'] in ids or card['name'] in names or item['image'] in assets:raise ValueError('Duplicate/unapproved supplemental image')
  path=item['image']
  if not path.startswith('res://assets/imported_photos/') or '..' in path or not (ROOT/path[6:]).is_file():raise ValueError('Missing approved asset')
  if item['name']!=card['name'] or not all(card.get(k) and item.get(k)==card[k] for k in ('ar','en','tr')):raise ValueError('Mismatched approved labels')
  ids.add(item['id']);names.add(card['name']);assets.add(path)
 return value
def question_bank():
 base=json.loads((ROOT/'data/questions.json').read_text(encoding='utf-8'))
 file=ROOT/'data/approved_content/questions.json'
 if not file.is_file():return {game:[q for q in group if question_allowed(q)] for game,group in base.items()}
 additions=json.loads(file.read_text(encoding='utf-8')).get('questions',{})
 ids={q['id'] for group in base.values() for q in group}
 for game,items in additions.items():
  if game not in base:raise ValueError('No new games allowed')
  for q in items:
   if q.get('review',{}).get('status')!='VERIFIED_EDITORIAL' or not q['review'].get('source_url','').startswith('https://'):raise ValueError('Unverified question blocked')
   if q['id'] in ids or q.get('topic') in ('math','numbers'):raise ValueError('Duplicate/arithmetic addition')
   if type(q.get('correct')) is not int or not 0<=q['correct']<4:raise ValueError('Invalid answer index')
   for lang in ('ar','en','tr'):
    choices=q.get('choices_'+lang,[])
    if not q.get(lang) or len(choices)!=4 or len({c.strip().casefold() for c in choices})!=4 or any(not c.strip() for c in choices):raise ValueError('Invalid localized choices')
   ids.add(q['id']);base[game].append(q)
 return {game:[q for q in group if question_allowed(q)] for game,group in base.items()}

@lru_cache(maxsize=1)
def question_policy():
 policy=json.loads((ROOT/'data/approved_content/question_policy.json').read_text(encoding='utf-8-sig'))
 return set(policy['excluded_ids'])|set(policy.get('held_ids',{})),re.compile(policy['arithmetic_pattern'])
def question_allowed(item):
 ids,pattern=question_policy()
 return item.get('id') not in ids and pattern.search(item.get('ar','')) is None
