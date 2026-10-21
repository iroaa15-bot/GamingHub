"""Android libwebrtc vs aiortc, through the real isolated Colyseus gateway.

Requires the staging APK installed and microphone allowed on a running emulator.
Synthetic remote tone and virtual Android mic: no physical echo/volume claim.
Run adb, emulator and this process in the same network namespace.
"""
import argparse
import asyncio
import json
from pathlib import Path
import subprocess
import sys
import time

import aioice.ice
from aiortc import RTCPeerConnection, RTCConfiguration, RTCSessionDescription, RTCRtpSender
from aiortc.sdp import candidate_from_sdp
from websockets.asyncio.client import connect

from webrtc_media_integration import Tone

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = 'com.iroaa15.gaminghub.colyseustest.voicefix118'
aioice.ice.get_host_addresses = lambda use_ipv4, use_ipv6: ['127.0.0.1']

async def main(adb, output):
    output.mkdir(parents=True, exist_ok=True)
    def android(*args):
        return subprocess.run([str(adb), *args], capture_output=True, text=True, timeout=60, check=True).stdout
    server_log = (output/'gateway.log').open('w')
    server = await asyncio.create_subprocess_exec('node', 'android-lan-server.mjs',
        cwd=ROOT/'experiments/colyseus-room-poc', stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT)
    pc = RTCPeerConnection(RTCConfiguration(iceServers=[]))
    pc.addTrack(Tone(440))
    pc.getTransceivers()[0].setCodecPreferences([c for c in RTCRtpSender.getCapabilities('audio').codecs if c.mimeType.lower() == 'audio/opus'])
    counts = {'received_android_audio_frames': 0, 'host_sent_game_move': False, 'authoritative_turn_received': False}
    tasks = []
    async def consume(track):
        try:
            while True:
                await track.recv()
                counts['received_android_audio_frames'] += 1
        except Exception:
            pass
    @pc.on('track')
    def remote(track): tasks.append(asyncio.create_task(consume(track)))
    try:
        async with asyncio.timeout(30):
            while line := await server.stdout.readline():
                server_log.write(line.decode()); server_log.flush()
                if b'COLYSEUS_GATEWAY_READY' in line: break
            else: raise RuntimeError('Gateway did not start')
        android('reverse', 'tcp:2568', 'tcp:2568')
        async with connect('ws://127.0.0.1:2568/gaminghub') as ws:
            await ws.send(json.dumps({'type':'create'}))
            while True:
                packet = json.loads(await ws.recv())
                if packet.get('type') == 'room': code = packet['code']; break
            android('logcat', '-c')
            android('shell','am','start','-S','-n',PACKAGE+'/com.godot.game.GodotApp',
                    '--esa','command_line_params','--max-fps,15,--script,res://diagnostics/android_voice_runtime.gd,--,--room-code='+code)
            request = 0
            epoch = None
            answer = False
            pending = []
            logcat = ''
            end = time.monotonic() + 300
            while time.monotonic() < end:
                try: packet = json.loads(await asyncio.wait_for(ws.recv(), 1))
                except asyncio.TimeoutError: packet = {}
                kind = packet.get('type')
                if kind == 'started':
                    request += 1
                    await ws.send(json.dumps({'type':'voice_state','enabled':True,'request_id':request}))
                elif kind in ('voice_state', 'voice_state_ack') and packet.get('local_enabled') and packet.get('peer_enabled') and epoch is None:
                    epoch = packet['epoch']
                    offer = await pc.createOffer(); await pc.setLocalDescription(offer)
                    # The emulator's host-loopback alias crosses its user-mode NAT.
                    sdp = pc.localDescription.sdp.replace('127.0.0.1', '10.0.2.2')
                    await ws.send(json.dumps({'type':'voice_offer','payload':{'sdp':sdp,'epoch':epoch}}))
                elif kind == 'voice_answer':
                    await pc.setRemoteDescription(RTCSessionDescription(packet['payload']['sdp'], 'answer')); answer = True
                    for candidate in pending: await pc.addIceCandidate(candidate)
                    pending.clear()
                elif kind == 'voice_ice':
                    payload = packet['payload']
                    candidate = candidate_from_sdp(payload['candidate'].removeprefix('candidate:'))
                    candidate.sdpMid = payload.get('sdpMid'); candidate.sdpMLineIndex = payload.get('sdpMLineIndex', 0)
                    if answer: await pc.addIceCandidate(candidate)
                    else: pending.append(candidate)
                elif kind == 'turn' and counts['host_sent_game_move']:
                    counts['authoritative_turn_received'] = packet.get('moves', 0) >= 1
                elif kind == 'error': raise AssertionError('Gateway error scope='+packet.get('scope','game'))
                if pc.connectionState == 'connected' and not counts['host_sent_game_move']:
                    await ws.send(json.dumps({'type':'ask','question':0})); counts['host_sent_game_move'] = True
                logcat = await asyncio.to_thread(android,'logcat','-d','-v','threadtime')
                (output/'android-logcat.txt').write_text(logcat)
                (output/'progress.json').write_text(json.dumps(dict(counts, connection_state=pc.connectionState)))
                if any(s in logcat for s in ('Fatal signal','FATAL EXCEPTION','ANDROID_ROOM_NATIVE_FAIL','ANDROID_VOICE_TIMEOUT')): break
                if 'ANDROID_ROOM_NATIVE_PASS' in logcat: break
            passed = ('ANDROID_ROOM_NATIVE_PASS' in logcat and counts['received_android_audio_frames'] >= 100
                      and counts['host_sent_game_move'] and counts['authoritative_turn_received'])
            result = dict(counts, passed=passed, actual_android_jni=True, android_api=29,
                          media='Android libwebrtc / aiortc Opus-SRTP; synthetic tone / virtual mic',
                          physical_device_tested=False, physical_echo_volume_tested=False)
            (output/'result.json').write_text(json.dumps(result,indent=2)); print(json.dumps(result))
            if not passed: raise AssertionError('Android media/room integration failed')
    finally:
        await pc.close()
        for task in tasks: task.cancel()
        server.terminate()
        try: await asyncio.wait_for(server.communicate(),10)
        except asyncio.TimeoutError: server.kill(); await server.wait()
        server_log.close()

if __name__ == '__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--adb',type=Path,required=True); parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args(); asyncio.run(main(args.adb.resolve(),args.output.resolve()))
