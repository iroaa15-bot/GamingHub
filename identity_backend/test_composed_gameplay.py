"""Real HTTP -> WebSocket -> PostgreSQL -> HTTP tests for the composed service."""
import time,uuid,io,wave
from fastapi.testclient import TestClient

def until(ws,kind,predicate=lambda value:True):
    for _ in range(30):
        message=ws.receive_json()
        if message.get('type')==kind and predicate(message):return message
    raise AssertionError('Expected game event not received')

def test_composed_win_reaches_account_profile_once(monkeypatch):
    monkeypatch.setenv('DUEL_AUTH_SECRET','ci-transport-secret-'+'x'*48)
    from identity_backend.integrated_app import app
    with TestClient(app) as client:
        account=client.post('/api/auth/register',json={'email':str(uuid.uuid4())+'@example.test','password':'test-password-123','display_name':'Composed player'}).json()['access_token']
        headers={'Authorization':'Bearer '+account}
        sessions=[client.get('/session',headers={'X-GamingHub-Terms':'1'}).json()['token'] for _ in range(2)]
        with client.websocket_connect('/',headers={'Authorization':'Bearer '+sessions[0]}) as a,client.websocket_connect('/',headers={'Authorization':'Bearer '+sessions[1]}) as b:
            def send(ws,kind,**fields):ws.send_json({'type':kind,'protocol':3,**fields})
            for ws in (a,b):send(ws,'duel_hello',game_id='3');until(ws,'duel_capabilities')
            send(a,'duel_auth_bind',access_token=account);assert until(a,'duel_auth_bound')['ok']
            send(a,'duel_quiz_create',game_id='3',players=2,timer=0,rounds=1,difficulty='easy')
            code=until(a,'duel_created')['code'];until(a,'duel_state')
            send(b,'duel_join',code=code);until(b,'duel_joined');until(b,'duel_state');until(a,'duel_state',lambda v:v['joined']==2)
            room=app.state.hub.rooms[code]
            for ws in (a,b):send(ws,'duel_accept',config_revision=room.config_revision,picture_difficulty='easy')
            until(a,'duel_state',lambda v:all(v['confirmed']))
            send(a,'duel_start');started=until(a,'duel_state',lambda v:v.get('quiz',{}).get('phase')=='question')
            time.sleep(1.6)
            send(a,'duel_quiz_answer',question_id=started['quiz']['question']['id'],choice=room.answer)
            send(b,'duel_quiz_answer',question_id=started['quiz']['question']['id'],choice=(room.answer+1)%4)
            result=until(a,'duel_state',lambda v:v.get('quiz',{}).get('phase')=='finished')
            assert result['scores']==[1000,0]
            send(a,'duel_sync');until(a,'duel_state',lambda v:v.get('quiz',{}).get('phase')=='finished')
            deadline=time.monotonic()+5
            points=0
            while time.monotonic()<deadline:
                points=client.get('/api/me',headers=headers).json()['user']['points']
                if points==10:break
                time.sleep(.05)
            assert points==10
            time.sleep(.1)
            assert client.get('/api/me',headers=headers).json()['user']['points']==10

def test_published_wav_snapshot_reaches_public_gameplay_and_revokes(monkeypatch):
    monkeypatch.setenv('GAMINGHUB_INTERNAL_ADMIN_KEY','ci-publish-only')
    from identity_backend.app import app,initialize
    initialize();client=TestClient(app);headers={'X-Admin-Key':'ci-publish-only'}
    binary=io.BytesIO()
    with wave.open(binary,'wb') as clip:
        clip.setnchannels(1);clip.setsampwidth(2);clip.setframerate(16000);clip.writeframes(bytes(3200))
    asset=client.post('/api/admin/assets',content=binary.getvalue(),headers=headers).json()['id']
    q={'game_id':'6','ar':'اختبار الصوت','en':'Sound test','choices_ar':['أ','ب','ج','د'],'choices_en':['A','B','C','D'],'correct':1,'staged_asset_id':asset}
    draft=client.post('/api/admin/content',json={'category':'sound','title':'Playable sound','payload':q},headers=headers).json()['id']
    for decision in ('submit','approve'):assert client.post(f'/api/admin/content/{draft}/review/{decision}',headers=headers).status_code==200
    publication=client.post(f'/api/admin/content/{draft}/publish',headers=headers)
    assert publication.status_code==201,publication.text
    identifier=publication.json()['id']
    item=next(v for v in client.get('/api/content/gameplay').json()['items'] if v['id']=='pub_'+identifier)
    assert item['game_id']=='6' and 'staged_asset_id' not in item
    assert client.delete(f'/api/admin/content/{draft}',headers=headers).status_code==200
    assert client.delete(f'/api/admin/assets/{asset}',headers=headers).status_code==200
    # The published copy survives deletion of the editable original binary.
    assert client.get(item['media']['path']).content==binary.getvalue()
    assert client.post(f'/api/admin/published/{identifier}/revoke',headers=headers).status_code==200
    assert client.get(item['media']['path']).status_code==404
    assert not any(v['id']=='pub_'+identifier for v in client.get('/api/content/gameplay').json()['items'])
