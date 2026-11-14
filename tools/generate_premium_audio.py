"""Original Gaming Hub score/sound design; stdlib only, no samples or downloads.
Rebuilds only assets/audio/premium. Score: 8 bars, 96 BPM, Cmaj9/Am7/Fmaj9/Gsus.
"""
from pathlib import Path
from array import array
import math,wave,random,json,hashlib
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/audio/premium'
RATE=22050
TAU=2*math.pi

def freq(note):return 440*2**((note-69)/12)
def tone(buf,start,note,duration,amp=.15,kind='keys',wrap=False):
 f=freq(note);length=int(duration*RATE);offset=round(start*RATE)
 for j in range(length):
  t=j/RATE
  if kind=='pad':
   env=min(1,t/.18)*min(1,(duration-t)/.25)*.65
   value=math.sin(TAU*f*t)+.18*math.sin(TAU*f*2*t+.15)
  else:
   env=(1-math.exp(-t*450))*math.exp(-t*(4 if kind=='keys' else 8))*(min(1,(duration-t)/.025))
   value=math.sin(TAU*f*t)+.24*math.sin(TAU*f*2*t)*math.exp(-t*8)+.08*math.sin(TAU*f*3*t)*math.exp(-t*12)
  at=offset+j
  if wrap:at%=len(buf)
  if 0<=at<len(buf):buf[at]+=amp*env*value

def save(name,buf,peak=.48,loop=False):
 mean=sum(buf)/len(buf);buf=array('f',(x-mean for x in buf));maximum=max(abs(x) for x in buf) or 1
 scale=min(1,peak/maximum)
 data=array('h',(round(max(-1,min(1,x*scale))*32767) for x in buf))
 p=OUT/(name+'.wav')
 with wave.open(str(p),'wb') as w:w.setparams((1,2,RATE,len(data),'NONE','not compressed'));w.writeframes(data.tobytes())
 return {'file':p.name,'seconds':len(data)/RATE,'sample_rate':RATE,'channels':1,'peak':max(abs(x) for x in data)/32768,'rms':math.sqrt(sum((x/32768)**2 for x in data)/len(data)),'loop':loop,'seam_jump':abs(data[0]-data[-1])/32768,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}

def generate():
 OUT.mkdir(parents=True,exist_ok=True);manifest=[];beat=.625;buf=array('f',[0])*int(20*RATE)
 chords=[[48,55,59,64,74],[45,52,55,60,67],[41,48,52,57,67],[43,50,55,60,69]]
 for bar in range(8):
  chord=chords[(bar//2)%4];start=bar*4*beat
  for n in chord[1:]:tone(buf,start,n,2.9,.028,'pad',True)
  for step in range(8):
   n=chord[1+step%4];tone(buf,start+step*beat/2,n,1.1,.085,'keys',True)
  for step in (0,2):tone(buf,start+step*beat,chord[0],.8,.13,'keys',True)
 melody=[(0,76),(1.5,79),(3,74),(4.5,72),(6,76),(7,79),(8,81),(9.5,79),(11,76),(12.5,74),(14,72),(15,74),(16,76),(18,79),(19,81),(20.5,79),(22,76),(23,74),(24,74),(26,76),(27,79),(28.5,74),(30,72)]
 for pos,n in melody:
  tone(buf,pos*beat,n,1.2,.12,'keys',True);tone(buf,pos*beat+.19,n,1.0,.023,'keys',True)
 rng=random.Random(29102026)
 for step in range(64):
  start=int(step*beat/2*RATE);smooth=0
  for j in range(int(.045*RATE)):
   noise=rng.uniform(-1,1);high=noise-smooth;smooth=.6*smooth+.4*noise
   buf[(start+j)%len(buf)]+=.008*high*math.exp(-j/(RATE*.009))
 manifest.append(save('menu_sunrise',buf,.34,True))
 designs={
 'startup':[(0,72),(.12,76),(.24,79),(.4,84)],
 'click':[(0,81)],'navigation':[(0,72),(.055,79)],'selection':[(0,76),(.065,81)],
 'room_create':[(0,60),(.09,67),(.18,76)],'player_join':[(0,74),(.12,79)],
 'all_ready':[(0,72),(.1,76),(.2,79)],'countdown':[(0,76)],
 'round_start':[(0,67),(.08,72),(.16,79)],'correct':[(0,76),(.1,79),(.2,84)],
 'incorrect':[(0,67),(.12,64)],'victory':[(0,60),(.12,64),(.24,67),(.42,72),(.6,79)],
 'results':[(0,67),(.14,72),(.28,76)]}
 for name,notes in designs.items():
  short=name in ('click','navigation','selection','countdown');tail=.13 if short else .65
  duration=max(t for t,n in notes)+tail;effect=array('f',[0])*int(duration*RATE)
  for at,n in notes:tone(effect,at,n,tail,.22 if short else .17,'pluck' if short else 'keys')
  manifest.append(save(name,effect,.38))
 (OUT/'MANIFEST.json').write_text(json.dumps({'origin':'Original procedural composition and synthesis for Gaming Hub; no third-party recordings or samples','commercial_use':'Project-owned original score/source; no external attribution or paid licenses required','tempo_bpm':96,'files':manifest},indent=2),encoding='utf-8')
 print('ORIGINAL_AUDIO_FILES',len(manifest),'BYTES',sum(p.stat().st_size for p in OUT.glob('*.wav')))
if __name__=='__main__':generate()
