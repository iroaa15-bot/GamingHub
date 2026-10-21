"""Bounded end-to-end transport checks on the existing staging service only.
No hardware audio or TURN transport claims; session capabilities are never logged.
"""
import asyncio
import json
import time
from websockets.asyncio.client import connect

URL = 'wss://gaminghub-voice-staging.onrender.com'
async def send(ws, kind, **data):
    await ws.send(json.dumps({'type': kind, **data}))
async def receive(ws, kind):
    async with asyncio.timeout(15):
        while True:
            packet = json.loads(await ws.recv())
            if packet.get('type') == kind:
                return packet
            if packet.get('type') == 'error':
                raise AssertionError('Unexpected server error; scope=' + packet.get('scope', 'game'))
async def consent(a, b, request):
    await send(a, 'voice_state', enabled=True, request_id=request)
    await receive(a, 'voice_state_ack'); await receive(b, 'voice_state')
    await send(b, 'voice_state', enabled=True, request_id=request)
    ack = await receive(b, 'voice_state_ack'); await receive(a, 'voice_state')
    assert ack['local_enabled'] and ack['peer_enabled']
    return ack['epoch']
async def main():
    checks = []
    a = await connect(URL, open_timeout=70)
    b = await connect(URL, open_timeout=30)
    try:
        await send(a, 'create'); room = (await receive(a, 'room'))['code']
        await send(b, 'join', code=room); await receive(b, 'room')
        sa, sb = await asyncio.gather(receive(a, 'started'), receive(b, 'started'))
        assert sa['room'] == sb['room'] == room
        checks.append('create_join_same_room')
        epoch = await consent(a, b, 1)
        await send(a, 'voice_offer', payload={'sdp': 'v=0\r\n', 'epoch': epoch})
        assert (await receive(b, 'voice_offer'))['payload']['epoch'] == epoch
        await send(b, 'voice_answer', payload={'sdp': 'v=0\r\n', 'epoch': epoch})
        assert (await receive(a, 'voice_answer'))['payload']['epoch'] == epoch
        candidate = 'candidate:1 1 UDP 2122260223 127.0.0.1 50000 typ host'
        for sender, receiver in [(a,b), (b,a)]:
            await send(sender, 'voice_ice', payload={'candidate': candidate, 'sdpMid': '0', 'sdpMLineIndex': 0, 'epoch': epoch})
            assert (await receive(receiver, 'voice_ice'))['payload']['candidate'] == candidate
        checks.append('bidirectional_sdp_ice_forwarding')
        before = time.monotonic()
        for n in range(501):
            await send(a, 'voice_ice', payload={'candidate': f'candidate:{n} 1 UDP 2122260223 127.0.0.1 50000 typ host', 'epoch': epoch})
        await send(a, 'ping', id=442)
        assert (await receive(a, 'pong'))['id'] == 442
        burst_seconds = round(time.monotonic() - before, 3)
        await send(a, 'ask', question=0)
        qa, qb = await asyncio.gather(receive(a, 'question'), receive(b, 'question'))
        assert qa == qb and qa['question_index'] == 0
        ta, tb = await asyncio.gather(receive(a, 'turn'), receive(b, 'turn'))
        assert ta['moves'] == tb['moves'] == 1 and ta['player'] == 1
        checks.append('501_ice_burst_preserves_ping_and_real_game_move')
        await a.close(); await receive(b, 'paused')
        a = await connect(URL, open_timeout=30)
        await send(a, 'resume', code=room, token='0'*64)
        error = await receive(a, 'error'); assert error.get('scope') == 'resume'
        await send(a, 'resume', code=room, token=sa['resume_token'])
        state = await receive(a, 'resumed'); await receive(a, 'peer_resumed'); await receive(b, 'peer_resumed')
        assert state['room'] == room and state['moves'] == 1 and not state['your_turn']
        assert state['resume_token'] != sa['resume_token'] and len(state['history']) == 1
        assert 'own_card' not in state and 'cards' not in state
        checks.append('authenticated_resume_restores_state_rotates_token_rejects_wrong_token')
        await send(a, 'voice_offer', payload={'sdp': 'v=0\r\n', 'epoch': epoch})
        assert (await receive(a, 'error')).get('scope') == 'voice'
        await send(b, 'ask', question=0)
        await asyncio.gather(receive(a, 'question'), receive(b, 'question'))
        ta, tb = await asyncio.gather(receive(a, 'turn'), receive(b, 'turn'))
        assert ta['moves'] == tb['moves'] == 2
        checks.append('voice_rejected_until_fresh_consent_without_interrupting_game')
        new_epoch = await consent(a, b, 2); assert new_epoch > epoch
        await send(a, 'voice_ice', payload={'candidate': candidate, 'epoch': new_epoch})
        assert (await receive(b, 'voice_ice'))['payload']['epoch'] == new_epoch
        await send(a, 'voice_state', enabled=False, request_id=3)
        off = await receive(a, 'voice_state_ack'); await receive(b, 'voice_state')
        assert not off['local_enabled']
        await send(a, 'ping', id=443); assert (await receive(a, 'pong'))['id'] == 443
        checks.append('fresh_voice_epoch_after_resume_opt_out_and_game_heartbeat')
        await send(a, 'leave'); await receive(a, 'left'); await receive(b, 'disconnected')
        checks.append('explicit_leave_cleanup')
        print(json.dumps({'result': 'STAGING_RECOVERY_TRANSPORT_PASS', 'endpoint': URL,
            'checks': checks, 'burst_roundtrip_seconds': burst_seconds,
            'android_hardware_tested': False, 'sdp_ice_test': 'transport only; real SDP/Opus verified separately'}))
    finally:
        await asyncio.gather(a.close(), b.close())
if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(); parser.add_argument('--url', default=URL)
    URL = parser.parse_args().url
    asyncio.run(main())
