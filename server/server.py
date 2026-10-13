"""Gaming Hub v0.4 authoritative room server. Python 3.10+, websockets >= 12."""
import asyncio, json, random, secrets, string, os, time
from dataclasses import dataclass, field
from websockets.asyncio.server import serve
from websockets.http11 import Response
from websockets.datastructures import Headers

from pathlib import Path
catalog_path = Path(__file__).resolve().parent.parent / 'data' / 'cards.json'
if not catalog_path.exists():
    catalog_path = Path(__file__).resolve().parent / 'cards.json'
catalog = json.loads(catalog_path.read_text(encoding='utf-8'))
CARDS = catalog['cards']
QUESTIONS = catalog['questions']

def normalize_guess(value):
    value = str(value).strip().casefold()
    for mark in 'ًٌٍَُِّْـ': value = value.replace(mark, '')
    value = value.replace('أ','ا').replace('إ','ا').replace('آ','ا').replace('ى','ي')
    for source, target in [('ı','i'),('ş','s'),('ç','c'),('ğ','g'),('ü','u'),('ö','o'),('\u0307','')]:
        value = value.replace(source,target)
    if value.startswith('ال'): value = value[2:]
    return value.replace(' ','').replace('_','').replace('-','').replace('.','')

@dataclass
class Room:
    code: str
    players: list = field(default_factory=list)
    cards: list = field(default_factory=list)
    turn: int = 0
    moves: int = 0
    over: bool = False
    asked: list = field(default_factory=lambda: [set(), set()])
    created_at: float = field(default_factory=time.monotonic)
    last_activity: float = field(default_factory=time.monotonic)
    started_at: float = 0.0

rooms = {}
connections = {}
waiting = []  # queued websocket clients for random matchmaking
MAX_ROOMS = int(os.getenv('MAX_ROOMS', '500'))
WAITING_TTL = int(os.getenv('WAITING_TTL', '300'))
MATCH_TTL = int(os.getenv('MATCH_TTL', '1200'))
MAX_ACTIVE_CONNECTIONS = int(os.getenv('MAX_ACTIVE_CONNECTIONS', '1200'))
MAX_GUESS_LENGTH = 80


async def send(ws, payload):
    await ws.send(json.dumps(payload))

async def broadcast(room, payload):
    for p in room.players:
        try: await send(p, payload)
        except Exception: pass

def public_card(card):
    return {'name':card['name']}

async def start_room(room):
    room.cards = random.sample(CARDS, 2)
    room.turn, room.moves, room.over = 0, 0, False
    room.asked = [set(), set()]
    room.started_at = room.last_activity = time.monotonic()
    for i, ws in enumerate(room.players):
        # NEVER send the player's own card before the match ends.
        await send(ws, {'type':'started','room':room.code,'opponent_card':public_card(room.cards[1-i]),'your_turn':i == 0,'player_index':i,'questions':[q['text'] for q in QUESTIONS],'questions_ar':[q['ar'] for q in QUESTIONS],'questions_tr':[q['tr'] for q in QUESTIONS]})

async def cleanup_room(code, reason='Match expired', exclude=None):
    room = rooms.pop(code, None)
    if room is None:
        return
    for peer in room.players:
        connections.pop(peer, None)
        if peer == exclude:
            continue
        try:
            await send(peer, {'type':'disconnected','message':reason})
        except Exception:
            pass

async def expire_stale_rooms(now=None):
    now = time.monotonic() if now is None else now
    for code, room in list(rooms.items()):
        ttl = MATCH_TTL if len(room.players) == 2 else WAITING_TTL
        if now - room.last_activity > ttl:
            await cleanup_room(code, 'Room timed out')

async def expiry_loop():
    while True:
        await asyncio.sleep(30)
        await expire_stale_rooms()

async def process(ws, msg):
    action = msg.get('type')
    if not isinstance(action, str):
        return await send(ws, {'type':'error','message':'Missing action'})
    code_for_activity = connections.get(ws)
    if code_for_activity in rooms:
        rooms[code_for_activity].last_activity = time.monotonic()

    # Mobile clients send a heartbeat every 12 seconds. Reply without touching
    # the active match turn; an unknown ping previously timed out the client.
    if action == 'ping':
        nonce = msg.get('id')
        if type(nonce) is not int or nonce < 0:
            return await send(ws, {'type':'error','message':'Invalid ping'})
        return await send(ws, {'type':'pong','id':nonce})

    if action == 'leave':
        if ws in waiting:
            waiting.remove(ws)
        code = connections.pop(ws, None)
        if code:
            await cleanup_room(code, 'Opponent left', exclude=ws)
        return await send(ws, {'type':'left','status':'ok'})
    if action == 'matchmake':
        if ws in connections or ws in waiting:
            return await send(ws, {'type':'error','message':'Already waiting or in a room'})
        while waiting:
            opponent = waiting.pop(0)
            if opponent.state.name != "OPEN" or opponent in connections:
                continue
            if len(rooms) >= MAX_ROOMS:
                return await send(ws, {'type':'error','message':'Server is at capacity'})
            code = ''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(6))
            while code in rooms:
                code = ''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(6))
            room = Room(code, [opponent, ws])
            rooms[code] = room
            connections[opponent] = code
            connections[ws] = code
            await send(opponent, {'type':'room','code':code,'status':'matched'})
            await send(ws, {'type':'room','code':code,'status':'matched'})
            return await start_room(room)
        if len(waiting) >= MAX_ACTIVE_CONNECTIONS:
            return await send(ws, {'type':'error','message':'Matchmaking queue is full'})
        waiting.append(ws)
        return await send(ws, {'type':'queue','status':'waiting'})
    if action == 'cancel_queue':
        if ws in waiting:
            waiting.remove(ws)
        return await send(ws, {'type':'queue','status':'cancelled'})
    if action == 'create':
        if ws in connections or ws in waiting: return await send(ws, {'type':'error','message':'Already waiting or in a room'})
        if len(rooms) >= MAX_ROOMS:
            return await send(ws, {'type':'error','message':'Server is at capacity'})
        code = ''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(6))
        while code in rooms:
            code = ''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(6))
        room = Room(code, [ws]); rooms[code] = room; connections[ws] = code
        return await send(ws, {'type':'room','code':code,'status':'waiting'})
    if action == 'join':
        if ws in connections or ws in waiting: return await send(ws, {'type':'error','message':'Already waiting or in a room'})
        code = str(msg.get('code','')).strip().upper()
        room = rooms.get(code)
        if room is None or len(room.players) != 1: return await send(ws, {'type':'error','message':'Room not found or full'})
        room.players.append(ws); connections[ws] = code
        await send(ws, {'type':'room','code':code,'status':'joined'})
        return await start_room(room)
    code = connections.get(ws)
    room = rooms.get(code)
    if room is None or len(room.players) != 2 or room.over:
        return await send(ws, {'type':'error','message':'No active match'})
    index = room.players.index(ws)
    if index != room.turn: return await send(ws, {'type':'error','message':'Wait for your turn'})
    if action == 'ask':
        qi = msg.get('question')
        if type(qi) is not int or not 0 <= qi < len(QUESTIONS):
            return await send(ws, {'type':'error','message':'Invalid question'})
        if qi in room.asked[index]:
            return await send(ws, {'type':'error','message':'Question already asked'})
        room.asked[index].add(qi)
        q = QUESTIONS[qi]
        answer = room.cards[index][q['key']] == q['value']
        await broadcast(room, {'type':'question','player':index,'text':q['text'],'text_ar':q['ar'],'text_tr':q['tr'],'answer':answer})
    elif action == 'guess':
        raw_guess = msg.get('guess', '')
        if not isinstance(raw_guess, str) or not raw_guess.strip():
            return await send(ws, {'type':'error','message':'Invalid guess'})
        if len(raw_guess) > MAX_GUESS_LENGTH:
            return await send(ws, {'type':'error','message':'Guess too long'})
        guess = raw_guess.strip().casefold()
        correct = normalize_guess(guess) in {normalize_guess(a) for a in room.cards[index]['aliases']}
        await broadcast(room, {'type':'guess','player':index,'guess':guess,'correct':correct})
        if correct:
            room.over = True
            return await broadcast(room, {'type':'finished','winner':index,'cards':[c['name'] for c in room.cards]})
    else:
        return await send(ws, {'type':'error','message':'Unknown action'})
    room.moves += 1
    if room.moves >= 20:
        room.over = True
        return await broadcast(room, {'type':'finished','winner':-1,'cards':[c['name'] for c in room.cards]})
    room.turn = 1 - index
    await broadcast(room, {'type':'turn','player':room.turn,'moves':room.moves})

async def handler(ws):
    # Simple per-connection burst limiter; production still needs authentication and proxy limits.
    timestamps = []
    try:
        async for raw in ws:
            now = time.monotonic()
            timestamps = [t for t in timestamps if now - t < 10]
            timestamps.append(now)
            if len(timestamps) > 35:
                await send(ws, {'type':'error','message':'Too many requests'})
                await ws.close(code=1008, reason='Rate limit')
                break
            try:
                if len(raw) > 8192: raise ValueError('Oversized message')
                msg = json.loads(raw)
                if not isinstance(msg, dict): raise ValueError('Expected object')
                await process(ws, msg)
            except (ValueError, TypeError, json.JSONDecodeError):
                await send(ws, {'type':'error','message':'Invalid message'})
    finally:
        if ws in waiting:
            waiting.remove(ws)
        code = connections.pop(ws, None)
        room = rooms.pop(code, None)
        if room:
            for peer in room.players:
                if peer != ws:
                    connections.pop(peer, None)
                    try: await send(peer, {'type':'disconnected','message':'Opponent left'})
                    except Exception: pass

async def http_health(connection, request):
    """Render health check without requiring a WebSocket upgrade."""
    if request.path == "/health":
        return Response(200, "OK", Headers({"Content-Type":"application/json"}), b'{"status":"ok","service":"gaminghub-multiplayer"}\n')
    return None

async def main():
    host = os.getenv('HOST','0.0.0.0')
    port = int(os.getenv('PORT','8765'))
    async with serve(handler, host, port, max_size=8192, ping_interval=20, ping_timeout=20, max_queue=16, process_request=http_health):
        print(f'Gaming Hub server on {host}:{port}')
        task = asyncio.create_task(expiry_loop())
        try:
            await asyncio.Future()
        finally:
            task.cancel()
            await asyncio.gather(task, return_exceptions=True)

if __name__ == '__main__':
    asyncio.run(main())