"""Original typed-answer, identity and ordering mechanics for local shared rooms.
No production protocol or service is changed.
"""
import json,secrets
from pathlib import Path
from photo_duel_extension import ProtocolError,integer
ROOT=Path(__file__).resolve().parents[1]
LANGS=('ar','en','tr')
def normalize(value):
 value=value.strip().lower()
 for mark in 'ًٌٍَُِّْـ':value=value.replace(mark,'')
 for a,b in [('أ','ا'),('إ','ا'),('آ','ا'),('ى','ي')]:value=value.replace(a,b)
 if value.startswith('ال'):value=value[2:]
 for a,b in [('̇',''),('ı','i'),('ş','s'),('ç','c'),('ğ','g'),('ü','u'),('ö','o')]:value=value.replace(a,b)
 return value.translate(str.maketrans('','',' -._'))
class MechanicsAdapter:
 def __init__(self,game_id,choice_adapter):
  self.game_id=game_id;self.choice_adapter=choice_adapter.__new__(choice_adapter)
  self.questions=json.loads((ROOT/'data/questions.json').read_text(encoding='utf-8'))[game_id]
  if len({q['id'] for q in self.questions})!=len(self.questions):raise ValueError('Duplicate question IDs')
  names={'language':('اللغة','Language'),'deduction':('الاستنتاج','Deduction'),'order':('ترتيب الخطوات','Step ordering'),'science':('العلوم','Science'),'geography':('الجغرافيا','Geography'),'nature':('الطبيعة','Nature'),'space':('الفضاء','Space'),'visual':('استكشف الصور','Picture explorer'),'numbers':('الأرقام والحساب','Numbers'),'math':('رياضيات وتفكير','Math & puzzles'),'logic':('التفكير المنطقي','Logic')}
  self.categories={q.get('topic','all'):{'ar':names.get(q.get('topic'),(q.get('topic'),q.get('topic')))[0],'en':names.get(q.get('topic'),('',q.get('topic')))[1]} for q in self.questions}
  for q in self.questions:
   mode=q.get('mode','choice')
   if mode in ('write','identity'):
    if not all(q.get('answers_'+lang) for lang in LANGS):raise ValueError('Missing accepted answers')
    if mode=='identity' and not all(q.get('clues_'+lang) for lang in LANGS):raise ValueError('Missing identity clues')
   elif mode=='order':
    if not all(len(q.get('steps_'+lang,[]))==len(q['steps_ar'])>=2 for lang in LANGS):raise ValueError('Invalid original steps')
   elif mode=='choice':
    choices=q.get('choices_ar',[])
    if not 4<=len(choices)<=6 or type(q.get('correct')) is not int or not 0<=q['correct']<len(choices):raise ValueError('Invalid original choice mapping')
    for lang in LANGS:
     translated=q.get('choices_'+lang,[])
     if len(translated)!=len(choices) or len({str(v).strip().casefold() for v in translated})!=len(choices):raise ValueError('Ambiguous original choices')
   else:raise ValueError('Unknown original mechanic')
 def pool(self,difficulty,category):
  level={'easy':1,'medium':2,'hard':3}.get(difficulty)
  if level is None or category not in ['all',*self.categories]:raise ProtocolError('Invalid game settings')
  return [q for q in self.questions if q.get('level',1)==level and (category=='all' or q.get('topic')==category)]
 def public(self,item):
  mode=item.get('mode','choice')
  if mode=='choice':return self.choice_adapter.public(item)
  public={k:item[k] for k in ('id','ar','en','tr') if k in item};public['mode']=mode
  if mode=='order':
   order=list(range(len(item['steps_ar'])));secrets.SystemRandom().shuffle(order)
   if order==list(range(len(order))):order.reverse()
   for lang in LANGS:public['steps_'+lang]=[item['steps_'+lang][i] for i in order]
   return public,{'mode':mode,'sequence':[order.index(i) for i in range(len(order))]}
  return public,{'mode':mode,'aliases':[normalize(a) for lang in LANGS for a in item['answers_'+lang]],'labels':{lang:item['answers_'+lang][0] for lang in LANGS},'clues':{lang:item.get('clues_'+lang,[]) for lang in LANGS}}
 def decode(self,msg,question):
  mode=question.get('mode','choice')
  if mode=='order':
   seq=msg.get('sequence');n=len(question['steps_ar'])
   if not isinstance(seq,list) or len(seq)!=n or any(type(i)is not int for i in seq) or set(seq)!=set(range(n)):raise ProtocolError('Submit each step exactly once')
   return seq
  if mode in ('write','identity'):
   text=msg.get('text')
   if not isinstance(text,str) or not text.strip() or len(text)>200:raise ProtocolError('Invalid written answer')
   return normalize(text)
  return integer(msg.get('choice'),range(len(question['choices_ar'])))
 def correct(self,submission,answer):
  if not isinstance(answer,dict):return submission==answer
  return submission==answer['sequence'] if answer['mode']=='order' else submission in answer['aliases']
 def reveal(self,answer):
  if not isinstance(answer,dict):return {'correct_index':answer}
  return {'correct_sequence':answer['sequence']} if answer['mode']=='order' else {'answer_labels':answer['labels']}
def media_path(image):
 if not isinstance(image,str) or not image or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_' for c in image.lower()):raise ValueError('Invalid original media ID')
 for folder,ext in [('photos','jpg'),('generated','webp'),('cards','png')]:
  relative=f'assets/{folder}/{image.lower()}.{ext}'
  if (ROOT/relative).is_file():return 'res://'+relative
 raise ValueError('Missing original image: '+image)
class KnowledgeAdapter(MechanicsAdapter):
 def __init__(self,choice_adapter):
  super().__init__('5',choice_adapter)
  for q in self.questions:
   if q.get('image'):media_path(q['image'])
 def public(self,item):
  question,answer=super().public(item)
  if item.get('image'):question['image']=media_path(item['image'])
  return question,answer
class AdventureAdapter(MechanicsAdapter):
 def __init__(self,choice_adapter):
  super().__init__('4',choice_adapter)
  self.categories={'island':{'ar':'جزيرة الاكتشاف','en':'Discovery Island'},'archive':{'ar':'أرشيف الأسرار','en':'Secret Archive'}}
 def pool(self,difficulty,category):
  if difficulty not in ('easy','medium','hard') or category not in ('all',*self.categories):raise ProtocolError('Invalid adventure settings')
  # A campaign keeps its authored stage sequence and mixed stage mechanics/levels.
  campaign='island' if category=='all' else category
  return [q for q in self.questions if q.get('campaign','archive')==campaign]
 def public(self,item):
  question,answer=super().public(item)
  for key in ('campaign','chapter','act','narrative_ar','narrative_en','narrative_tr'):
   if key in item:question[key]=item[key]
  return question,answer
class MemoryAdapter:
 game_id='8'
 def __init__(self):
  self.cards=json.loads((ROOT/'data/cards.json').read_text(encoding='utf-8'))['cards']
  for card in self.cards:media_path(card['image'])
  self.categories={c['category']:{'ar':{'Animal':'حيوانات','Food':'طعام','Object':'أشياء','Place':'أماكن','Fruit':'فواكه'}.get(c['category'],c['category']),'en':c['category']} for c in self.cards}
  self.questions=[{'id':'memory_'+str(i)} for i in range(30)]
 def pool(self,difficulty,category):
  if difficulty not in ('easy','medium','hard') or category not in ('all',*self.categories):raise ProtocolError('Invalid memory settings')
  cards=[c for c in self.cards if category=='all' or c['category']==category]
  pairs=4+{'easy':1,'medium':2,'hard':3}[difficulty]*2
  pairs=min(len(cards),pairs)
  if pairs<2:return []
  return [{'id':'memory_'+str(i),'cards':cards,'pairs':pairs} for i in range(30)]
 def public(self,item):
  chosen=secrets.SystemRandom().sample(item['cards'],item['pairs']);board=chosen+chosen;secrets.SystemRandom().shuffle(board)
  return {'id':item['id'],'mode':'memory','ar':'اعثر على أزواج الصور','en':'Find the matching picture pairs','tr':'Eşleşen resim çiftlerini bul','size':len(board)}, {'mode':'memory','board':board}
 def correct(self,submission,answer):return submission is True
 def reveal(self,answer):return {}
