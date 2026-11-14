"""Original deterministic electronic score and non-tonal UI click; no samples/APIs.
Preserves every existing audio asset. Run from any directory with Python stdlib.
"""
from array import array
from pathlib import Path
import hashlib,json,math,random,wave

OUT=Path(__file__).resolve().parents[1]/'assets/audio/premium'
RATE=22050
TAU=math.tau

def save(name,values):
    peak=max(abs(x) for x in values) or 1
    pcm=array('h',(round(x*.62/peak*32767) for x in values))
    path=OUT/(name+'.wav')
    with wave.open(str(path),'wb') as file:
        file.setparams((1,2,RATE,len(pcm),'NONE','not compressed'))
        file.writeframes(pcm.tobytes())
    return dict(file=path.name,seconds=len(pcm)/RATE,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),seam_jump=abs(pcm[0]-pcm[-1])/32768)

def generate():
    beat=60/128;length=32*beat;music=array('f',[0])*round(length*RATE)
    rng=random.Random(6112026)
    def layer(at,duration,fn):
        for sample in range(round(duration*RATE)):
            time=sample/RATE
            music[(round(at*RATE)+sample)%len(music)]+=fn(time,duration)
    roots=[45,45,48,48,41,41,43,43]
    for bar,root in enumerate(roots):
        for step in range(16):
            at=(bar*4+step/4)*beat
            if step%4==0:
                layer(at,.19,lambda t,d:.44*math.sin(TAU*(48*t+9*(1-math.exp(-t*55))))*(1-math.exp(-t*1500))*math.exp(-t*23))
            if step%2==0:
                noise=[rng.uniform(-1,1) for _ in range(round(.045*RATE))]
                layer(at,.045,lambda t,d,n=noise:.045*n[min(len(n)-1,round(t*RATE))]*math.exp(-t*90)*(1-t/d))
            if step in (4,12):
                noise=[rng.uniform(-1,1) for _ in range(round(.11*RATE))]
                layer(at,.11,lambda t,d,n=noise:.10*n[min(len(n)-1,round(t*RATE))]*math.exp(-t*35)*(1-t/d))
            if step in (0,3,6,8,10,14):
                frequency=440*2**((root+(12 if step==14 else 0)-69)/12)
                layer(at,.20,lambda t,d,f=frequency:.19*(math.sin(TAU*f*t)+.17*math.sin(TAU*2*f*t))*(1-math.exp(-t*800))*math.exp(-t*19)*(1-t/d))
            if step%2==1:
                note=root+24+[0,7,12,7,3,7,10,7][step//2]
                frequency=440*2**((note-69)/12)
                layer(at,.14,lambda t,d,f=frequency:.07*(math.sin(TAU*f*t)+.22*math.sin(TAU*2*f*t))*(1-math.exp(-t*900))*math.exp(-t*25)*(1-t/d))
    # Circular synthesis includes tails crossing the loop; no cut or silent gap.
    # Remove the tiny discontinuity left by deterministic percussive noise.
    delta=music[-1]-music[0]
    for sample in range(128):music[-128+sample]-=delta*sample/127
    click=array('f',[0])*round(.028*RATE);previous=0.0
    for sample in range(len(click)):
        noise=rng.uniform(-1,1);high=noise-previous;previous=noise
        t=sample/RATE
        click[sample]=high*math.exp(-t*240)*min(1,t/.0008)*(1-sample/(len(click)-1))
    manifest={'origin':'Original procedural score and deterministic noise synthesis; no recordings, songs, samples or external services',
              'commercial_use':'Created specifically for Gaming Hub; no third-party sample licenses',
              'tempo_bpm':128,'bars':8,'files':[save('challenge_loop',music),save('ui_click',click)]}
    (OUT/'CHALLENGE_MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(manifest,indent=2))

if __name__=='__main__':generate()
