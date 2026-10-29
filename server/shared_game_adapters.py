"""Original typed-answer, identity and ordering mechanics for local shared rooms.
No production protocol or service is changed.
"""
import json,secrets,unicodedata
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
  names={'language':('اللغة','Language'),'deduction':('الاستنتاج','Deduction'),'order':('ترتيب الخطوات','Step ordering')}
  self.categories={q.get('topic','all'):{'ar':names.get(q.get('topic'),(q.get('topic'),q.get('topic')))[0],'en':names.get(q.get('topic'),('',q.get('topic')))[1]} for q in self.questions}
  for q in self.questions:
   mode=q.get('mode','choice')
   if mode in ('write','identity'):
    if not all(q.get('answers_'+lang) for lang in LANGS):raise ValueError('Missing accepted answers')
    if mode=='identity' and not all(q.get('clues_'+lang) for lang in LANGS):raise ValueError('Missing identity clues')
   elif mode=='order':
    if not all(len(q.get('steps_'+lang,[]))==len(q['steps_ar'])>=2 for lang in LANGS):raise ValueError('Invalid original steps')
   elif mode!='choice':raise ValueError('Unknown original mechanic')
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
