"""Shared simultaneous quiz adapters on authenticated loopback only.
Reuses room membership, security, moderation and existing PCM mixer unchanged.
"""
from room_codes_local import new_room_code
import asyncio,json,secrets,time,re
from pathlib import Path
from websockets.asyncio.server import serve
from secure_agreement_local import SecureAgreementHub
from photo_duel_extension import Room,ProtocolError,VERSION,TIMERS,integer
ROOT=Path(__file__).resolve().parents[1]

class QuestionAdapter:
 def __init__(self,game_id):
  self.game_id=game_id
  raw=__import__('approved_content').question_bank()[game_id]
  self.questions=[]
  for item in raw:
   choices=item.get('choices_ar',[]);english=item.get('choices_en',[]);correct=item.get('correct')
   if not (4<=len(choices)<=6 and len(english)==len(choices) and type(correct) is int and 0<=correct<len(choices)):continue
   if len(set(str(x).casefold().strip() for x in choices))!=len(choices) or len(set(str(x).casefold().strip() for x in english))!=len(english):continue
   if not item.get('ar') or not item.get('en'):continue
   self.validate_media(item)
   self.questions.append(item)
  if not self.questions or len({x['id'] for x in self.questions})!=len(self.questions):raise ValueError('Quiz catalog requires unique playable IDs')
  self.categories={str(x.get('topic','all')):{'ar':{'cinema':'معرفة سينمائية','craft':'صناعة السينما','audio':'المقاطع المحلية','logic':'التفكير المنطقي','numbers':'الأرقام والحساب','math':'رياضيات وتفكير'}.get(x.get('topic'),x.get('topic','')),'en':str(x.get('topic',''))} for x in self.questions}
 def decode(self,msg,question):return integer(msg.get('choice'),range(len(question['choices_ar'])))
 def correct(self,submission,answer):return submission==answer
 def reveal(self,answer):return {'correct_index':answer}
 def validate_media(self,item):pass
 def pool(self,difficulty,category):
  level={'easy':1,'medium':2,'hard':3}.get(difficulty)
  if level is None or category not in ['all',*self.categories]:raise ProtocolError('Invalid quiz settings')
  return [q for q in self.questions if int(q.get('level',1))==level and (category=='all' or q.get('topic')==category)]
 def public(self,item):
  order=list(range(len(item['choices_ar'])));secrets.SystemRandom().shuffle(order)
  result={'id':item['id'],'ar':item['ar'],'en':item['en'],'choices_ar':[item['choices_ar'][i] for i in order],'choices_en':[item['choices_en'][i] for i in order]}
  if len(item.get('choices_tr',[]))==len(order):result.update(tr=item.get('tr',''),choices_tr=[item['choices_tr'][i] for i in order])
  if 'audio' in item:result['audio']='res://assets/audio/'+item['audio']+'.wav'
  return result,order.index(item['correct'])
class CinemaAdapter(QuestionAdapter):
 def __init__(self):super().__init__('1')
class SoundAdapter(QuestionAdapter):
 def __init__(self):super().__init__('6')
 def validate_media(self,item):
  clip=item.get('audio','')
  if not isinstance(clip,str) or re.fullmatch(r'[a-z0-9_]+',clip) is None or not (ROOT/'assets/audio'/f'{clip}.wav').is_file():raise ValueError('Missing original audio asset')

class QuizRoom(Room):
 def __init__(self,code,capacity,timer,rounds,catalog,adapter,difficulty):
  super().__init__(code,capacity,timer,rounds,catalog)
  self.adapter=adapter;self.picture_difficulty=difficulty;self.picture_category='all'
  self.agreement=True;self.config_revision=1;self.confirmed=[False]*capacity;self.primary_mode='voice'
  self.pause_started=None;self.phase='lobby';self.match_finished=False;self.quiz_rounds=rounds;self.queue=[];self.index=-1;self.question=None;self.answer=None;self.answers={};self.results=[];self.start_at=0;self.start_clock=0;self.audio_at=0;self.audio_serial=0;self.replays=0
 def begin_question(self):
  self.index+=1;self.question,self.answer=self.adapter.public(self.queue[self.index]);self.answers={};self.clues_used={};self.memory={};self.results=[];self.phase='question';self.pending=None
  self.start_at=int(time.time()*1000)+1500;self.start_clock=time.monotonic()+1.5
  self.deadline=self.start_clock+self.timer if self.timer else None;self.remaining=None
  self.audio_at=self.start_at;self.audio_serial+=1;self.replays=0
 def finish_question(self):
  self.results=[]
  correct_times=sorted({elapsed for choice,elapsed in self.answers.values() if self.adapter.correct(choice,self.answer)})
  for player in range(self.capacity):
   choice,elapsed=self.answers.get(player,(-1,None));correct=self.adapter.correct(choice,self.answer)
   # Correct answers earn 1000; distinct server-receipt speed ranks share up to 500 bonus.
   # Exact millisecond ties receive equal rewards, without arbitrary player-index tie breaks.
   bonus=int(500*(len(correct_times)-correct_times.index(elapsed))/len(correct_times)) if correct and self.timer and elapsed is not None else 0
   points=max(100,1000+bonus-200*self.clues_used.get(player,0)) if correct else 0
   if self.question.get('mode')=='memory' and correct:
    pairs=len(self.answer['board'])//2;moves=self.memory[player]['moves'];points=max(10,pairs*15-max(0,moves-pairs)*2)
   self.scores[player]+=points
   self.results.append({'player':player,'choice':choice,'correct':correct,'points':points,'elapsed_ms':elapsed})
  self.phase='finished' if self.index+1>=self.quiz_rounds else 'results';self.match_finished=self.phase=='finished';self.deadline=None;self.remaining=None
  if self.match_finished:
   leaders=[i for i,score in enumerate(self.scores) if score==max(self.scores)]
   self.winner=leaders[0] if len(leaders)==1 else -1
 def expire(self):
  if self.phase=='question' and not self.paused and self.deadline is not None and time.monotonic()>=self.deadline:
   self.finish_question();self.revision+=1;return True
  return False
 def view(self,player):
  value=super().view(player);value.update(opponents=[],preset_questions=[],match_finished=self.match_finished)
  quiz={'game_id':self.adapter.game_id,'phase':self.phase,'round':self.index+1,'rounds':self.quiz_rounds,'question':self.question,'answered_count':len(self.answers),'your_answer':self.answers.get(player,[None])[0],'start_unix_ms':self.start_at,'audio_start_unix_ms':self.audio_at,'audio_serial':self.audio_serial,'replay_available':self.phase=='question' and self.replays<1,'server_unix_ms':int(time.time()*1000)}
  if self.phase in ('results','finished'):quiz.update(**self.adapter.reveal(self.answer),results=self.results)
  if isinstance(self.answer,dict) and self.answer.get('mode')=='memory':
   from shared_game_adapters import media_path
   state=self.memory.get(player,{'open':[],'matched':[],'moves':0,'hide_at':0})
   opened=state['open'] if len(state['open'])<2 or time.monotonic()<state['hide_at'] else []
   visible=set(state['matched']+opened)
   quiz['memory']={'hide_unix_ms':int(time.time()*1000+max(0,state['hide_at']-time.monotonic())*1000) if len(state['open'])==2 else 0,'moves':state['moves'],'matched':state['matched'],'revealed':{str(i):{**{lang:card.get(lang,card['name']) for lang in ('ar','en','tr')},'image':media_path(card['image'])} for i,card in enumerate(self.answer['board']) if i in visible}}
  if isinstance(self.answer,dict) and self.answer.get('mode')=='identity':
   count=self.clues_used.get(player,0)+1
   quiz['clues']={lang:items[:count] for lang,items in self.answer['clues'].items()};quiz['more_clues']=count<len(self.answer['clues']['ar'])
  value['quiz']=quiz;return value

class SharedQuizHub(SecureAgreementHub):
 def __init__(self,secret,database):
  super().__init__(secret,database)
  from shared_game_adapters import MechanicsAdapter,KnowledgeAdapter,AdventureAdapter,MemoryAdapter,media_path
  self.adapters={'1':CinemaAdapter(),'6':SoundAdapter(),'3':QuestionAdapter('3')}
  self.adapters.update({key:MechanicsAdapter(key,QuestionAdapter) for key in ('2','7','9')})
  self.adapters.update({'4':AdventureAdapter(QuestionAdapter),'5':KnowledgeAdapter(QuestionAdapter),'8':MemoryAdapter()})
  self.requested_games={}
 async def send(self,ws,message):
  if message.get('type')=='duel_capabilities':
   adapter=self.adapters.get(self.requested_games.get(ws))
   message={**message,'shared_quiz':True,'quiz_games':list(self.adapters),'quiz_categories':adapter.categories if adapter else {}}
  return await super().send(ws,message)
 async def handle(self,ws,msg):
  identity=self.identities.get(ws)
  if not identity or identity['exp']<=time.time():raise ProtocolError('Session expired')
  if type(msg.get('protocol')) is not int or msg['protocol']!=VERSION:raise ProtocolError('Unsupported protocol')
  action=msg.get('type')
  if action=='duel_auth_bind':return await super().handle(ws,msg)
  if action=='duel_hello' and 'game_id' in msg:
   if msg['game_id'] not in self.adapters:raise ProtocolError('Unsupported game adapter')
   self.requested_games[ws]=msg['game_id']
  if action=='duel_resume':
   result=await super().handle(ws,msg)
   binding=self.bindings.get(ws);restored=self.rooms.get(binding[0]) if binding else None
   if isinstance(restored,QuizRoom) and not restored.paused and restored.pause_started is not None:
    pause_duration=time.monotonic()-restored.pause_started
    restored.start_clock+=pause_duration;restored.audio_at+=int(pause_duration*1000);restored.pause_started=None
    restored.start_at=int(time.time()*1000-max(0,time.monotonic()-restored.start_clock)*1000)
    await self.publish(restored)
   return result
  if action=='duel_join' and isinstance(msg.get('code'),str):
   target=self.rooms.get(msg['code'])
   if isinstance(target,QuizRoom) and self.requested_games.get(ws)!=target.adapter.game_id:raise ProtocolError('Join from the same game')
  if action=='duel_quiz_create':
   if ws in self.bindings or len(self.rooms)>=100:raise ProtocolError('Room capacity reached')
   adapter=self.adapters.get(msg.get('game_id'))
   if adapter is None:raise ProtocolError('Unsupported game adapter')
   capacity=integer(msg.get('players',2),range(2,7));timer=integer(msg.get('timer',30),TIMERS);rounds=integer(msg.get('rounds',5),range(1,31));difficulty=msg.get('difficulty')
   if len(adapter.pool(difficulty,'all'))<rounds:raise ProtocolError('Not enough existing questions for the requested round count')
   code=new_room_code(self.rooms)
   room=QuizRoom(code,capacity,timer,rounds,self.catalog,adapter,difficulty);room.peers[0]=ws;room.joined=1;self.rooms[code]=room;self.bindings[ws]=(code,0);self.subjects[code]={0:identity['sub']}
   await self.send(ws,{'type':'duel_created','code':code,'token':room.tokens[0],'player':0});return await self.publish(room)
  binding=self.bindings.get(ws);room=self.rooms.get(binding[0]) if binding else None
  if not isinstance(room,QuizRoom):return await super().handle(ws,msg)
  player=binding[1];room.activity=time.monotonic()
  if action=='duel_quiz_propose':
   if player!=0 or room.started:raise ProtocolError('Host proposal only before start')
   category=msg.get('category');mode=msg.get('primary_mode')
   if mode not in ('voice','text','tap'):raise ProtocolError('Invalid communication mode')
   if len(room.adapter.pool(room.picture_difficulty,category))<room.quiz_rounds:raise ProtocolError('Not enough existing questions in this category')
   if category!=room.picture_category or mode!=room.primary_mode:
    if mode!='voice':self.reset_voice(room)
    room.picture_category=category;room.primary_mode=mode;room.config_revision+=1;room.confirmed=[False]*room.capacity
   return await self.publish(room)
  if action=='duel_start':
   if player!=0 or room.started or room.paused or room.joined!=room.capacity or not all(room.confirmed) or not all(room.peers):raise ProtocolError('All players must confirm before quiz start')
   pool=room.adapter.pool(room.picture_difficulty,room.picture_category)
   if len(pool)<room.quiz_rounds:raise ProtocolError('Insufficient real questions')
   room.queue=pool[:room.quiz_rounds] if room.adapter.game_id=='4' else secrets.SystemRandom().sample(pool,room.quiz_rounds);room.started=True;room.begin_question();return await self.publish(room)
  if action in ('duel_quiz_answer','duel_quiz_next','duel_quiz_replay','duel_quiz_clue','duel_quiz_flip'):
   if room.expire():await self.publish(room)
   if room.paused:raise ProtocolError('Room paused until reconnect')
   if action=='duel_quiz_next':
    if player!=0 or room.phase!='results':raise ProtocolError('Host advances only after shared results')
    room.begin_question();return await self.publish(room)
   if room.phase!='question' or msg.get('question_id')!=room.question['id']:raise ProtocolError('Stale question')
   if action=='duel_quiz_replay':
    if 'audio' not in room.question or room.replays>=1 or player in room.answers:raise ProtocolError('Replay unavailable')
    room.replays+=1;room.audio_serial+=1;room.audio_at=int(time.time()*1000)+500;return await self.publish(room)
   if player in room.answers or time.monotonic()<room.start_clock:raise ProtocolError('Answer already submitted or countdown not started')
   if action=='duel_quiz_flip':
    if not isinstance(room.answer,dict) or room.answer.get('mode')!='memory':raise ProtocolError('Not a memory board')
    index=integer(msg.get('index'),range(len(room.answer['board'])))
    state=room.memory.setdefault(player,{'open':[],'matched':[],'moves':0,'hide_at':0})
    if time.monotonic()<state['hide_at']:raise ProtocolError('Wait for cards to turn back')
    if len(state['open'])==2:state['open']=[]
    if index in state['open'] or index in state['matched']:raise ProtocolError('Card already revealed')
    state['open'].append(index)
    if len(state['open'])==2:
     state['moves']+=1;a,b=state['open']
     if room.answer['board'][a]['name']==room.answer['board'][b]['name']:state['matched']+=state['open'];state['open']=[]
     else:state['hide_at']=time.monotonic()+{'easy':1.6,'medium':1.2,'hard':.9}[room.picture_difficulty]
    if len(state['matched'])==len(room.answer['board']):
     room.answers[player]=(True,int(max(0,time.monotonic()-room.start_clock)*1000))
     if len(room.answers)==room.capacity:room.finish_question()
    return await self.publish(room)
   if action=='duel_quiz_clue':
    if not isinstance(room.answer,dict) or room.answer.get('mode')!='identity' or room.clues_used.get(player,0)+1>=len(room.answer['clues']['ar']):raise ProtocolError('No further clue')
    room.clues_used[player]=room.clues_used.get(player,0)+1
    return await self.publish(room)
   if room.question.get('mode')=='memory':raise ProtocolError('Memory requires card flips')
   choice=room.adapter.decode(msg,room.question)
   room.answers[player]=(choice,int(max(0,time.monotonic()-room.start_clock)*1000))
   if len(room.answers)==room.capacity:room.finish_question()
   return await self.publish(room)
  if action not in ('duel_accept','duel_sync','duel_leave','duel_voice_state','duel_voice_audio','duel_report','duel_block','duel_chat','duel_session_refresh'):raise ProtocolError('Action does not belong to this game adapter')
  return await super().handle(ws,msg)
 async def disconnect(self,ws):
  binding=self.bindings.get(ws);room=self.rooms.get(binding[0]) if binding else None
  if isinstance(room,QuizRoom) and not room.paused:room.pause_started=time.monotonic()
  await super().disconnect(ws);self.requested_games.pop(ws,None)

async def main():
 hub=SharedQuizHub(secrets.token_urlsafe(48),':memory:')
 async with serve(hub.connection,'127.0.0.1',8884,process_request=hub.http,max_size=8192,max_queue=32,compression=None,ping_interval=20,ping_timeout=20):
  print('SHARED_QUIZ_LOCAL_READY 8884',flush=True)
  tasks=[asyncio.create_task(hub.sweep()),asyncio.create_task(hub.mixer())]
  try:await asyncio.Event().wait()
  finally:
   for task in tasks:task.cancel()
   await asyncio.gather(*tasks,return_exceptions=True);hub.moderation.db.close()
if __name__=='__main__':asyncio.run(main())
