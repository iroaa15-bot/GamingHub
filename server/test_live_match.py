"""End-to-end WebSocket smoke test; run against local or hosted WS(S) URL."""
import asyncio, json, os
from websockets.asyncio.client import connect

async def recv(ws, expected):
    for _ in range(8):
        msg=json.loads(await asyncio.wait_for(ws.recv(), timeout=8))
        if msg.get('type') == expected: return msg
    raise AssertionError(f'Missing {expected}')

async def main():
    url=os.getenv('GAME_WS_URL','ws://127.0.0.1:8765')
    async with connect(url) as a, connect(url) as b:
        await a.send(json.dumps({'type':'create'}))
        room=await recv(a,'room'); code=room['code']
        assert len(code)==6
        await b.send(json.dumps({'type':'join','code':code}))
        await recv(b,'room')
        first=await recv(a,'started'); second=await recv(b,'started')
        assert first['opponent_card']['name'] and second['opponent_card']['name']
        assert 'your_card' not in first and 'your_card' not in second
        assert first['player_index']==0 and second['player_index']==1
        await a.send(json.dumps({'type':'ask','question':0}))
        await recv(a,'question'); await recv(b,'question')
        await recv(a,'turn'); await recv(b,'turn')
        await b.send(json.dumps({'type':'guess','guess':'intentionally_wrong_guess'}))
        result=await recv(a,'guess'); await recv(b,'guess')
        assert result['correct'] is False
        await recv(a,'turn'); await recv(b,'turn')
        await a.send(json.dumps({'type':'leave'}))
        await recv(a,'left'); await recv(b,'disconnected')
    print('PASS: 2-player room, hidden cards, question, turns, guess, leave')

if __name__=='__main__': asyncio.run(main())
