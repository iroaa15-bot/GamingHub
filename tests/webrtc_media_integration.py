"""Real Opus/SRTP over loopback UDP, using actual room signaling locally or staging.
No Android microphone, mobile NAT, TURN, echo-quality or device claim.
Requires aiortc, numpy, websockets.
"""
import argparse
import asyncio
import json
import sys
from fractions import Fraction
from pathlib import Path
import numpy as np
import aioice.ice
from aiortc import AudioStreamTrack,RTCPeerConnection,RTCConfiguration,RTCSessionDescription,RTCRtpSender
from av import AudioFrame
from websockets.asyncio.client import connect
from websockets.asyncio.server import serve
# Deterministic local media; interface enumeration isn't permitted in this sandbox.
aioice.ice.get_host_addresses=lambda use_ipv4,use_ipv6:['127.0.0.1']

class Tone(AudioStreamTrack):
    def __init__(self,frequency):
        super().__init__();self.frequency=frequency;self.samples=0;self.clock=None
    async def recv(self):
        now=asyncio.get_running_loop().time()
        if self.clock is None:self.clock=now
        await asyncio.sleep(max(0,self.clock+self.samples/48000-now))
        wave=(np.sin(2*np.pi*self.frequency*(np.arange(960)+self.samples)/48000)*3000).astype('<i2')
        frame=AudioFrame(format='s16',layout='mono',samples=960);frame.planes[0].update(wave.tobytes())
        frame.sample_rate=48000;frame.pts=self.samples;frame.time_base=Fraction(1,48000);self.samples+=960
        return frame
async def receive(ws,kind):
    while True:
        packet=json.loads(await asyncio.wait_for(ws.recv(),20))
        if packet.get('type')=='error':raise AssertionError('Server error: '+packet.get('scope',''))
        if packet.get('type')==kind:return packet
async def media_test(url):
    peers=[RTCPeerConnection(RTCConfiguration(iceServers=[])) for _ in range(2)]
    counts=[0,0];levels=[0.,0.];tasks=[]
    async def consume(track,index):
        while counts[index]<30:
            frame=await asyncio.wait_for(track.recv(),10)
            samples=frame.to_ndarray().astype(np.float64)
            levels[index]=max(levels[index],float(np.sqrt(np.mean(samples*samples))));counts[index]+=1
    for index,peer in enumerate(peers):
        peer.addTrack(Tone(440+index*440))
        peer.getTransceivers()[0].setCodecPreferences([c for c in RTCRtpSender.getCapabilities('audio').codecs if c.mimeType.lower()=='audio/opus'])
        peer.on('track',lambda track,i=index:tasks.append(asyncio.create_task(consume(track,i))))
    try:
        async with connect(url,open_timeout=70) as a,connect(url,open_timeout=70) as b:
            await a.send(json.dumps({'type':'create'}));room=await receive(a,'room')
            await b.send(json.dumps({'type':'join','code':room['code']}));await receive(b,'room')
            await receive(a,'started');await receive(b,'started')
            await a.send(json.dumps({'type':'voice_state','enabled':True,'request_id':1}))
            await receive(a,'voice_state_ack');await receive(b,'voice_state')
            await b.send(json.dumps({'type':'voice_state','enabled':True,'request_id':1}))
            epoch=(await receive(b,'voice_state_ack'))['epoch'];await receive(a,'voice_state')
            await a.send(json.dumps({'type':'voice_ice_config'}));ice=(await receive(a,'voice_ice_config')).get('payload',{})
            offer=await peers[0].createOffer();await peers[0].setLocalDescription(offer)
            await a.send(json.dumps({'type':'voice_offer','payload':{'sdp':peers[0].localDescription.sdp,'epoch':epoch}}))
            packet=await receive(b,'voice_offer');assert packet['payload']['epoch']==epoch
            await peers[1].setRemoteDescription(RTCSessionDescription(packet['payload']['sdp'],'offer'))
            answer=await peers[1].createAnswer();await peers[1].setLocalDescription(answer)
            await b.send(json.dumps({'type':'voice_answer','payload':{'sdp':peers[1].localDescription.sdp,'epoch':epoch}}))
            packet=await receive(a,'voice_answer')
            await peers[0].setRemoteDescription(RTCSessionDescription(packet['payload']['sdp'],'answer'))
            async with asyncio.timeout(20):
                while len(tasks)<2:await asyncio.sleep(.02)
                await asyncio.gather(*tasks)
            assert min(counts)>=30 and min(levels)>100,(counts,levels)
            assert all(p.connectionState=='connected' for p in peers)
            await a.send(json.dumps({'type':'voice_ice','payload':{'candidate':7}}))
            error=json.loads(await asyncio.wait_for(a.recv(),5));assert error.get('scope')=='voice'
            await a.send(json.dumps({'type':'ping','id':931}));assert (await receive(a,'pong'))['id']==931
            await a.send(json.dumps({'type':'voice_state','enabled':False,'request_id':2}))
            await receive(a,'voice_state_ack');await receive(b,'voice_state')
            print(json.dumps({'result':'WEBRTC_MEDIA_PASS','media':'Opus/SRTP loopback UDP','received_frames':counts,
                'non_silent':True,'turn_configured':bool(ice.get('urls')),'turn_transport_tested':False,
                'android_hardware_tested':False,'signaling':'staging' if 'onrender.com' in url else 'localhost'}))
    finally:
        await asyncio.gather(*(p.close() for p in peers))
        for task in tasks:
            if not task.done():task.cancel()
async def main(staging):
    if staging:await media_test('wss://gaminghub-voice-staging.onrender.com')
    else:
        sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'));import server as app
        async with serve(app.handler,'127.0.0.1',0,ping_interval=None,compression=None) as server:
            await media_test(f'ws://127.0.0.1:{server.sockets[0].getsockname()[1]}')
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--staging',action='store_true')
    asyncio.run(main(parser.parse_args().staging))
