"""Public gameplay projection. Editable drafts and administrative fields stay private."""
import hashlib
import os
import re
import psycopg
from fastapi import APIRouter,HTTPException
from fastapi.responses import Response
router=APIRouter()

def question_projection(identifier,category,payload):
    if not isinstance(payload,dict):return None
    game=str(payload.get('game_id',''))
    if game not in ('1','3','5','6'):return None
    if category=='sound' and game!='6':return None
    if category=='image' and game!='5':return None
    if category=='question' and game=='6':return None
    answer=payload.get('correct')
    if type(answer) is not int or not 0<=answer<4:return None
    level=payload.get('level',1)
    if type(level) is not int or level not in (1,2,3):return None
    result={'id':'pub_'+identifier,'game_id':game,'level':level,'correct':answer,'topic':str(payload.get('topic','all'))[:60]}
    for lang in ('ar','en'):
        text=payload.get(lang);choices=payload.get('choices_'+lang)
        if not isinstance(text,str) or not 1<=len(text)<=1500:return None
        if not isinstance(choices,list) or len(choices)!=4 or any(not isinstance(c,str) or not c.strip() or len(c)>300 for c in choices):return None
        if len({c.strip().casefold() for c in choices})!=4:return None
        result[lang]=text;result['choices_'+lang]=choices
    # Unknown fields (including arbitrary paths, URLs, scripts and secrets) never enter gameplay.
    return result

@router.get('/api/content/gameplay')
def gameplay_manifest():
    from identity_backend.published_content import ensure_table
    items=[]
    with psycopg.connect(os.environ['GAMINGHUB_DATABASE_URL'],connect_timeout=3) as db:
        ensure_table(db)
        rows=db.execute('SELECT id,category,payload,asset_mime,asset_sha256 FROM published_content WHERE active ORDER BY published_at,id LIMIT 1001').fetchall()
    if len(rows)>1000:raise HTTPException(503,'Gameplay catalog exceeds supported limit')
    for identifier,category,payload,mime,digest in rows:
        q=question_projection(identifier,category,payload)
        if q is None:continue
        if category in ('image','sound'):
            allowed=('image/png','image/jpeg','image/webp') if category=='image' else ('audio/wav',)
            if mime not in allowed or not digest:continue
            q['media']={'kind':category,'path':f'/api/content/assets/{identifier}','mime':mime,'sha256':digest}
        items.append(q)
    return {'schema':1,'items':items}

@router.get('/api/content/assets/{identifier}')
def gameplay_asset(identifier:str):
    if not re.fullmatch(r'[a-f0-9-]{36}',identifier):raise HTTPException(404,'Asset unavailable')
    from identity_backend.published_content import ensure_table
    with psycopg.connect(os.environ['GAMINGHUB_DATABASE_URL'],connect_timeout=3) as db:
        ensure_table(db)
        row=db.execute('SELECT asset_mime,asset_data FROM published_content WHERE id=%s AND active',(identifier,)).fetchone()
    if not row or not row[1]:raise HTTPException(404,'Asset unavailable')
    return Response(bytes(row[1]),media_type=row[0],headers={'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'})
