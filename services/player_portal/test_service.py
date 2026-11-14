import contextlib
import json,sqlite3,tempfile,threading,unittest,urllib.request,urllib.error
from pathlib import Path
from service import make_server

class PortalAcceptance(unittest.TestCase):
 def test_content_answer_alias_validation(self):
  from service import Store,Fault
  with tempfile.TemporaryDirectory() as td:
   store=Store(str(Path(td)/'validation.sqlite'))
   with store.db() as c:
    c.execute("INSERT INTO users(id,name,role) VALUES('admin','Test only','super_admin')")
    token=store.session(c,'admin')
   data={'labels':{'ar':'أ','en':'Q','tr':'S'},'options':[{'id':'a','ar':'نعم','en':'Yes','tr':'Evet'},{'id':'b','ar':'لا','en':'No','tr':'Hayır'}],'correct':'a','aliases':{'ar':['نعم'],'en':['Yes'],'tr':['Evet']}}
   store.call('POST','/admin/content',{'kind':'question','id':'q','data':data},token)
   data['aliases']['en']=['Yes','No']
   with self.assertRaises(Fault):store.call('POST','/admin/content',{'kind':'question','id':'q','data':data},token)
   with self.assertRaises(Fault):store.call('POST','/admin/content',{'kind':'settings','id':'s','data':{'turn_time':7}},token)
   print('PASS: localized correct alias accepted; distractor alias and invalid timer rejected')
 def test_real_http_auth_friends_progress_admin(self):
  with tempfile.TemporaryDirectory() as td:
   path=str(Path(td)/'players.sqlite');server=make_server(path,0);thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start();url='http://127.0.0.1:'+str(server.server_port)
   def request(route,body=None,token='',status=200,headers=None):
    h={'Content-Type':'application/json'}
    if token:h['Authorization']='Bearer '+token
    h.update(headers or {})
    req=urllib.request.Request(url+route,data=json.dumps(body).encode() if body is not None else None,headers=h)
    try:
     response=urllib.request.urlopen(req);code=response.status;data=response.read();response_headers=response.headers
    except urllib.error.HTTPError as e:code=e.code;data=e.read();response_headers=e.headers
    self.assertEqual(code,status,(route,data));return json.loads(data),response_headers
   try:
    password='test-only-'+__import__('secrets').token_urlsafe(20)
    guest,_=request('/auth/guest',{'name':'Guest test'});a,headers=request('/auth/register',{'name':'Alice test','email':'a@example.test','password':password,'role':'super_admin'})
    b,_=request('/auth/register',{'name':'Bob test','email':'b@example.test','password':password})
    self.assertIn('HttpOnly',headers['Set-Cookie']);self.assertIn('SameSite=Strict',headers['Set-Cookie']);self.assertEqual(a['user']['role'],'player')
    request('/admin/status',token=a['token'],status=403);request('/me',token='invalid',status=401)
    request('/auth/login',{'email':'a@example.test','password':'wrong-password-123'},status=401)
    request('/auth/login',{'email':'a@example.test','password':password},headers={'Origin':'https://evil.invalid'},status=403)
    request('/progress',{'progress':{'xp':20,'wins':1}},guest['token'])
    linked,_=request('/auth/link-guest',{'guest_token':guest['token']},a['token']);self.assertEqual(linked['progress']['xp'],20)
    request('/me',token=guest['token'],status=401)
    request('/progress',{'progress':{'xp':10}},a['token']);me,_=request('/me',token=a['token']);self.assertEqual(me['progress']['xp'],20)
    request('/progress',{'progress':{'xp':True}},a['token'],400)
    request('/friends/request',{'user_id':b['user']['id']},a['token'])
    request('/friends/accept',{'user_id':a['user']['id']},a['token'],404)
    request('/friends/accept',{'user_id':a['user']['id']},b['token'])
    request('/invites',{'user_id':b['user']['id'],'code':'ROOM12'},a['token']);inv,_=request('/invites',token=b['token']);self.assertEqual(inv['invites'][0]['code'],'ROOM12')
    # Test-only role provisioning in a disposable DB; no default administrator exists.
    with contextlib.closing(sqlite3.connect(path)) as c, c:c.execute("UPDATE users SET role='super_admin' WHERE id=?",(a['user']['id'],))
    photos,_=request('/admin/photos',token=a['token']);self.assertEqual(len(photos['photos']),200)
    question={'labels':{'ar':'سؤال','en':'Question','tr':'Soru'},'options':[{'id':'yes','ar':'نعم','en':'Yes','tr':'Evet'},{'id':'no','ar':'لا','en':'No','tr':'Hayır'}],'correct':'yes','aliases':{'ar':['نعم'],'en':['Yes'],'tr':['Evet']}}
    request('/admin/content',{'kind':'question','id':'test','data':question},a['token'])
    question['correct']='missing';request('/admin/content',{'kind':'question','id':'bad','data':question},a['token'],400)
    request('/admin/content',{'kind':'photo','id':'bad','data':{'asset':'../../secret','labels':{'ar':'أ','en':'A','tr':'A'}}},a['token'],400)
    request('/admin/players',{'id':b['user']['id'],'suspended':True},a['token']);request('/me',token=b['token'],status=401)
    audit,_=request('/admin/audit',token=a['token']);self.assertTrue(any(x['action']=='moderate-player' for x in audit['audit']))
    with contextlib.closing(sqlite3.connect(path)) as c, c:
     with self.assertRaises(sqlite3.DatabaseError):c.execute('DELETE FROM audit')
    request('/auth/logout',{},a['token']);request('/me',token=a['token'],status=401)
    # Reopen the database to verify persistence rather than relying on in-memory state.
    from service import Store
    reopened=Store(path)
    with reopened.db() as c:self.assertEqual(reopened.progress(c,a['user']['id'])['xp'],20)
    print('PASS: actual HTTP guest/register/login/link/progress/friends/invites/admin RBAC/moderation/audit/persistence; OAuth NOT tested or configured')
   finally:server.shutdown();server.server_close();thread.join()
if __name__=='__main__':unittest.main()
