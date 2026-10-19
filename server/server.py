"""Gaming Hub v0.4 authoritative room server. Python 3.10+, websockets >= 12."""
import asyncio, json, random, secrets, string, os, time, datetime as dt, base64, binascii, hmac, hashlib
from urllib.parse import urlsplit, parse_qs
from liveops_content import daily_rotation
from daily_content import json_bytes, daily_pack, validate_pack
from daily_images import public_json as daily_image_json, image_for_filename as daily_image_bytes, pack as daily_image_pack
from dataclasses import dataclass, field
from websockets.asyncio.server import serve
from websockets.http11 import Response
from websockets.datastructures import Headers

from pathlib import Path
catalog_path = Path(__file__).resolve().parent.parent / 'data' / 'cards.json'
AI_DAILY_DIR = Path(__file__).resolve().parent / 'ai_daily_publish'
if not catalog_path.exists():
    catalog_path = Path(__file__).resolve().parent / 'cards.json'
catalog = json.loads(catalog_path.read_text(encoding='utf-8'))
CARDS = catalog['cards']
QUESTIONS = catalog['questions']

def ephemeral_turn_credentials(room_code, player_index):
    """Coturn REST-auth credentials, scoped to a consenting room player."""
    secret = os.environ.get('GAMINGHUB_TURN_SECRET', '')
    urls = [item.strip() for item in os.environ.get('GAMINGHUB_TURN_URLS', '').split(',') if item.strip()]
    if not secret or not urls or len(urls) > 8:
        return None
    if any(not url.startswith(('turn:', 'turns:')) or len(url) > 512 for url in urls):
        return None
    expiry = int(time.time()) + 600
    username = f"{expiry}:gh-{room_code}-{player_index}"
    digest = hmac.new(secret.encode('utf-8'), username.encode('utf-8'), hashlib.sha1).digest()
    return {'urls': urls, 'username': username, 'credential': base64.b64encode(digest).decode('ascii'), 'expires_at': expiry}


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
    resume_tokens: list = field(default_factory=lambda: ["", ""])
    detached_at: list = field(default_factory=lambda: [None, None])
    history: list = field(default_factory=list)
    winner: int = -1
    voice_enabled: list = field(default_factory=lambda: [False, False])
    voice_packet_at: list = field(default_factory=lambda: [[], []])

rooms = {}
connections = {}
waiting = []  # queued websocket clients for random matchmaking
MAX_ROOMS = int(os.getenv('MAX_ROOMS', '500'))
WAITING_TTL = int(os.getenv('WAITING_TTL', '300'))
MATCH_TTL = int(os.getenv('MATCH_TTL', '1200'))
MAX_ACTIVE_CONNECTIONS = int(os.getenv('MAX_ACTIVE_CONNECTIONS', '1200'))
MAX_GUESS_LENGTH = 80
RECONNECT_GRACE = max(10, min(300, int(os.getenv('RECONNECT_GRACE', '90'))))


async def send(ws, payload):
    await ws.send(json.dumps(payload))

async def broadcast(room, payload):
    for p in room.players:
        if p is None: continue
        try: await send(p, payload)
        except Exception: pass

def public_card(card):
    return {'name':card['name']}

async def start_room(room):
    room.cards = random.sample(CARDS, 2)
    room.turn, room.moves, room.over = 0, 0, False
    room.asked = [set(), set()]
    room.resume_tokens = [secrets.token_hex(32), secrets.token_hex(32)]
    room.detached_at = [None, None]
    room.history = []
    room.winner = -1
    room.voice_enabled = [False, False]
    room.voice_packet_at = [[], []]
    room.started_at = room.last_activity = time.monotonic()
    for i, ws in enumerate(room.players):
        # NEVER send the player's own card before the match ends.
        await send(ws, {'type':'started','room':room.code,'opponent_card':public_card(room.cards[1-i]),'your_turn':i == 0,'player_index':i,'resume_token':room.resume_tokens[i],'questions':[q['text'] for q in QUESTIONS],'questions_ar':[q['ar'] for q in QUESTIONS],'questions_tr':[q['tr'] for q in QUESTIONS]})

def snapshot(room, index, kind='synced', include_token=False):
    """Authoritative per-player state. Never include this player's secret card.

    The replay contains public actions only until the match is finished.
    """
    state = {'type': kind, 'room': room.code, 'player_index': index,
             'opponent_card': public_card(room.cards[1-index]),
             'your_turn': room.turn == index, 'moves': room.moves,
             'finished': room.over,
             'questions': [q['text'] for q in QUESTIONS],
             'questions_ar': [q['ar'] for q in QUESTIONS],
             'questions_tr': [q['tr'] for q in QUESTIONS],
             'history': room.history.copy(),
             'paused': any(p is None for p in room.players)}
    if include_token:
        state['resume_token'] = room.resume_tokens[index]
    return state


async def cleanup_room(code, reason='Match expired', exclude=None):
    room = rooms.pop(code, None)
    if room is None:
        return
    for peer in room.players:
        if peer is not None:
            connections.pop(peer, None)
        if peer is None or peer == exclude:
            continue
        try:
            await send(peer, {'type':'disconnected','message':reason})
        except Exception:
            pass

async def expire_stale_rooms(now=None):
    now = time.monotonic() if now is None else now
    for code, room in list(rooms.items()):
        ttl = MATCH_TTL if len(room.players) == 2 else WAITING_TTL
        if any(t is not None and now - t >= RECONNECT_GRACE for t in room.detached_at):
            await cleanup_room(code, 'Reconnection window expired')
        elif now - room.last_activity > ttl:
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
    if action not in ('ping', 'sync') and code_for_activity in rooms:
        rooms[code_for_activity].last_activity = time.monotonic()

    # Lightweight application heartbeat; it never reveals room or card state.
    if action == 'ping':
        nonce = msg.get('id')
        if type(nonce) is not int or nonce < 0:
            return await send(ws, {'type':'error','message':'Invalid ping'})
        return await send(ws, {'type':'pong','id':nonce})
    # Reconcile a potentially lost move acknowledgement without replaying the move.
    # Only the existing room socket can request a snapshot; a room code alone is
    # never an authentication credential.
    if action == 'sync':
        code = connections.get(ws)
        room = rooms.get(code)
        if room is None or len(room.players) != 2 or not room.cards or ws not in room.players:
            return await send(ws, {'type':'error','message':'No active match'})
        index = room.players.index(ws)
        return await send(ws, snapshot(room, index))
    if action == 'resume':
        code = msg.get('code')
        token = msg.get('token')
        if ws in connections or ws in waiting:
            return await send(ws, {'type':'error','message':'Already in a room'})
        if not isinstance(code, str) or not isinstance(token, str) or len(token) != 64:
            return await send(ws, {'type':'error','message':'Invalid resume credentials'})
        room = rooms.get(code)
        if room is None or len(room.players) != 2 or not room.cards:
            return await send(ws, {'type':'error','message':'Match unavailable'})
        idx = next((i for i, expected in enumerate(room.resume_tokens)
                    if expected and secrets.compare_digest(expected, token)), -1)
        if idx < 0:
            return await send(ws, {'type':'error','message':'Invalid resume credentials'})
        disconnected_at = room.detached_at[idx]
        if disconnected_at is None:
            return await send(ws, {'type':'error','message':'Original player still connected'})
        if time.monotonic() - disconnected_at >= RECONNECT_GRACE:
            await cleanup_room(code, 'Reconnection window expired')
            return await send(ws, {'type':'error','message':'Reconnection expired'})
        # Rotate capability on successful resume: an intercepted old token cannot be replayed.
        room.resume_tokens[idx] = secrets.token_hex(32)
        room.players[idx] = ws
        had_voice_consent = any(room.voice_enabled)
        room.voice_enabled = [False, False]
        room.detached_at[idx] = None
        connections[ws] = code
        room.last_activity = time.monotonic()
        await send(ws, snapshot(room, idx, 'resumed', include_token=True))
        if all(p is not None for p in room.players):
            await broadcast(room, {'type':'peer_resumed', 'player':idx, 'turn':room.turn})
            if had_voice_consent:
                await broadcast(room, {'type':'voice_state','player':idx,'enabled':False})
        return
    # Optional voice signaling only. Audio media must use a native WebRTC client.
    # No SDP/ICE is stored in room history or server-side databases.
    if action in ('voice_state', 'voice_offer', 'voice_answer', 'voice_ice', 'voice_audio', 'voice_ice_config'):
        code = connections.get(ws)
        room = rooms.get(code)
        if room is None or len(room.players) != 2 or not room.cards or room.over or ws not in room.players:
            return await send(ws, {'type':'error','message':'No active voice room'})
        if any(peer is None for peer in room.players):
            return await send(ws, {'type':'error','message':'Voice peer unavailable'})
        index = room.players.index(ws)
        if action == 'voice_state':
            enabled = msg.get('enabled')
            if type(enabled) is not bool:
                return await send(ws, {'type':'error','message':'Invalid voice state'})
            room.voice_enabled[index] = enabled
            await send(room.players[1-index], {'type':'voice_state','player':index,'enabled':enabled})
            await send(ws, {'type':'voice_state_ack','enabled':enabled,'peer_enabled':room.voice_enabled[1-index]})
            return
        if not all(room.voice_enabled):
            return await send(ws, {'type':'error','message':'Both players must enable voice'})
        if action == 'voice_ice_config':
            config = ephemeral_turn_credentials(code, index)
            # No credentials unless both players explicitly enabled voice.
            return await send(ws, {'type': 'voice_ice_config', 'payload': config or {}})
        if action == 'voice_audio':
            # 20 ms, 16 kHz mono PCM16: exactly 640 bytes, base64 encoded.
            # No persistence. Per-sender pacing protects rooms from audio floods.
            encoded = msg.get('pcm')
            if not isinstance(encoded, str) or len(encoded) != 856:
                return await send(ws, {'type':'error','message':'Invalid audio packet'})
            try:
                pcm = base64.b64decode(encoded, validate=True)
            except (ValueError, binascii.Error):
                return await send(ws, {'type':'error','message':'Invalid audio encoding'})
            if len(pcm) != 640:
                return await send(ws, {'type':'error','message':'Invalid audio size'})
            # Legitimate 20 ms frames can arrive in bursts when the mobile UI
            # catches up. A 12 ms inter-arrival gate dropped those frames and
            # caused audible missing syllables. Limit the rolling rate instead.
            now = time.monotonic()
            recent = room.voice_packet_at[index]
            recent[:] = [t for t in recent if now - t < 1.0]
            if len(recent) >= 80:
                return  # Reject sustained >80 packets/s; expected rate is 50.
            recent.append(now)
            await send(room.players[1-index], {'type':'voice_audio','pcm':encoded})
            return
        payload = msg.get('payload')
        if not isinstance(payload, dict) or len(json.dumps(payload)) > (18000 if action in ('voice_offer', 'voice_answer') else 6000):
            return await send(ws, {'type':'error','message':'Invalid voice payload'})
        if action in ('voice_offer', 'voice_answer'):
            if not isinstance(payload.get('sdp'), str) or not 0 < len(payload['sdp']) <= 16000:
                return await send(ws, {'type':'error','message':'Invalid voice SDP'})
        if action == 'voice_ice' and (not isinstance(payload.get('candidate'), str) or not 0 < len(payload['candidate']) <= 4096):
            return await send(ws, {'type':'error','message':'Invalid ICE candidate'})
        await send(room.players[1-index], {'type':action,'player':index,'payload':payload})
        return
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
    if any(p is None for p in room.players):
        return await send(ws, {'type':'error','message':'Match paused; waiting for reconnect'})
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
        event = {'type':'question','player':index,'question_index':qi,'text':q['text'],'text_ar':q['ar'],'text_tr':q['tr'],'answer':answer}
        room.history.append(event)
        await broadcast(room, event)
    elif action == 'guess':
        raw_guess = msg.get('guess', '')
        if not isinstance(raw_guess, str) or not raw_guess.strip():
            return await send(ws, {'type':'error','message':'Invalid guess'})
        if len(raw_guess) > MAX_GUESS_LENGTH:
            return await send(ws, {'type':'error','message':'Guess too long'})
        guess = raw_guess.strip().casefold()
        correct = normalize_guess(guess) in {normalize_guess(a) for a in room.cards[index]['aliases']}
        event = {'type':'guess','player':index,'guess':guess,'correct':correct}
        room.history.append(event)
        await broadcast(room, event)
        if correct:
            room.over = True
            room.winner = index
            result = {'type':'finished','winner':index,'cards':[c['name'] for c in room.cards]}
            room.history.append(result)
            return await broadcast(room, result)
    else:
        return await send(ws, {'type':'error','message':'Unknown action'})
    room.moves += 1
    if room.moves >= 20:
        room.over = True
        room.winner = -1
        result = {'type':'finished','winner':-1,'cards':[c['name'] for c in room.cards]}
        room.history.append(result)
        return await broadcast(room, result)
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
        room = rooms.get(code)
        if room and ws in room.players:
            idx = room.players.index(ws)
            if len(room.players) == 2 and room.cards:
                room.players[idx] = None
                had_voice_consent = any(room.voice_enabled)
                room.voice_enabled = [False, False]
                room.detached_at[idx] = time.monotonic()
                for peer in room.players:
                    if peer is not None:
                        try:
                            await send(peer, {'type':'paused','player':idx,'seconds':RECONNECT_GRACE})
                            if had_voice_consent:
                                await send(peer, {'type':'voice_state','player':idx,'enabled':False})
                        except Exception: pass
            else:
                await cleanup_room(code, 'Opponent disconnected')


# Additive historical library. The server can reconstruct every day deterministically.
_HISTORY_EPOCH = dt.date(2026, 10, 1)
_MAX_HISTORY_DAYS = 7

def history_payload(kind: str, before: str | None = None, days: int = 7) -> bytes:
    days = max(1, min(int(days), _MAX_HISTORY_DAYS))
    today = dt.datetime.now(dt.timezone.utc).date()
    cursor = dt.date.fromisoformat(before) if before else today + dt.timedelta(days=1)
    if cursor > today + dt.timedelta(days=1):
        raise ValueError("Future cursor")
    dates = [cursor - dt.timedelta(days=k + 1) for k in range(days)]
    dates = [day for day in dates if _HISTORY_EPOCH <= day <= today]
    packs = []
    for day in dates:
        if kind == "text":
            pack_item = daily_pack(day)
            validate_pack(pack_item, day)
        elif kind == "image":
            pack_item = daily_image_pack(day.isoformat())
        else:
            raise ValueError("Unknown category")
        packs.append(pack_item)
    return json.dumps({"schema": 1, "kind": kind, "newest_first": True,
                       "retains_old_content": True, "packs": packs,
                       "next_before": dates[-1].isoformat() if dates and dates[-1] > _HISTORY_EPOCH else ""},
                      ensure_ascii=False, separators=(",", ":")).encode("utf-8")

async def http_health(connection, request):
    """Render health check without requiring a WebSocket upgrade."""
    parsed_path = urlsplit(request.path)
    if parsed_path.path in ("/content/history.json", "/ai_daily/history.json"):
        try:
            args = parse_qs(parsed_path.query, strict_parsing=False)
            n = int(args.get("days", ["7"])[0])
            if n < 1 or n > _MAX_HISTORY_DAYS:
                raise ValueError("Invalid page size")
            before = args.get("before", [None])[0]
            payload = history_payload("text" if parsed_path.path.startswith("/content/") else "image", before, n)
            return Response(200, "OK", Headers({"Content-Type":"application/json; charset=utf-8",
                 "Cache-Control":"public, max-age=300", "Access-Control-Allow-Origin":"*",
                 "X-Content-Type-Options":"nosniff"}), payload)
        except (ValueError, OverflowError, TypeError):
            return Response(400, "Bad Request", Headers({"Content-Type":"application/json"}), b'{"error":"invalid_history_page"}')
    if request.path == "/content/daily.json":
        payload = json_bytes()
        return Response(200, "OK", Headers({"Content-Type":"application/json; charset=utf-8",
                                             "Cache-Control":"public, max-age=300",
                                             "Access-Control-Allow-Origin":"*",
                                             "X-Content-Type-Options":"nosniff"}), payload)
    if request.path == "/liveops/rotation.json":
        # No personal data, credentials, or player history are exposed.
        payload = json.dumps(daily_rotation(), ensure_ascii=False, separators=(',', ':')).encode('utf-8')
        return Response(200, "OK", Headers({"Content-Type":"application/json; charset=utf-8",
                                              "Cache-Control":"public, max-age=300",
                                              "Access-Control-Allow-Origin":"*"}), payload)
    if request.path == "/ai_daily/daily.json":
        return Response(200, "OK", Headers({"Content-Type":"application/json; charset=utf-8",
                                             "Cache-Control":"public, max-age=120",
                                             "Access-Control-Allow-Origin":"*",
                                             "X-Content-Type-Options":"nosniff"}), daily_image_json())
    if request.path.startswith("/ai_daily/"):
        name = request.path.removeprefix("/ai_daily/")
        image = daily_image_bytes(name)
        if image is not None:
            return Response(200, "OK", Headers({"Content-Type":"image/png",
                                                 "Cache-Control":"public, max-age=120",
                                                 "Access-Control-Allow-Origin":"*",
                                                 "X-Content-Type-Options":"nosniff"}), image)
        return Response(404, "Not Found", Headers({"Content-Type":"application/json; charset=utf-8"}), b'')
    if request.path == "/health":
        payload = json.dumps({
            "status": "ok",
            "release": "11.6",
            "content_history_available": True,
            "release": "11.6",
            "content_history_available": True,
            "service": "gaminghub-multiplayer",
            "ai_daily_available": True,  # pictures are generated on demand
        }, ensure_ascii=False).encode('utf-8')
        return Response(200, "OK", Headers({"Content-Type":"application/json; charset=utf-8"}), payload)
    return None

async def main():
    host = os.getenv('HOST','0.0.0.0')
    port = int(os.getenv('PORT','8765'))
    async with serve(handler, host, port, max_size=32768, ping_interval=20, ping_timeout=20, max_queue=16, process_request=http_health):
        print(f'Gaming Hub server on {host}:{port}')
        task = asyncio.create_task(expiry_loop())
        try:
            await asyncio.Future()
        finally:
            task.cancel()
            await asyncio.gather(task, return_exceptions=True)

if __name__ == '__main__':
    asyncio.run(main())
