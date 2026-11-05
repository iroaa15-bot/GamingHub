"""One focused new-security integration run. No production and no old protocol matrix."""
import argparse,asyncio,json,os,re,secrets,sqlite3,subprocess,sys,time,urllib.request,urllib.error
from pathlib import Path
from websockets.asyncio.client import connect
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser();p.add_argument("--godot",required=True);p.add_argument("--output",type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
 env=os.environ.copy();env.update(DUEL_AUTH_SECRET=secrets.token_urlsafe(48),DUEL_MODERATION_DB=str(a.output/"moderation.sqlite"),PORT="0",PYTHONUTF8="1");env.pop("RENDER",None)
 with (a.output/"server.log").open("w") as log:
  server=subprocess.Popen([sys.executable,"-u",str(ROOT/"server/secure_duel_service.py")],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
  try:
   port=None
   for _ in range(100):
    m=re.search(r"SECURE_DUEL_READY (\d+)",(a.output/"server.log").read_text())
    if m:port=m[1];break
    if server.poll() is not None:break
    time.sleep(.1)
   if port is None:raise RuntimeError((a.output/"server.log").read_text()[-1200:])
   url="http://127.0.0.1:"+port;checks={}
   checks["health"] = json.load(urllib.request.urlopen(url+"/health"))["status"]=="ok"
   try:urllib.request.urlopen(url+"/session");checks["terms_required"]=False
   except urllib.error.HTTPError as e:checks["terms_required"]=e.code==403
   async def rejected():
    try:
     async with connect(url.replace("http://","ws://")):return False
    except Exception as e:return getattr(getattr(e,"response",None),"status_code",None)==401
   checks["anonymous_ws_rejected"]=asyncio.run(rejected())
   with (a.output/"godot.log").open("w",encoding="utf8") as stream:
    result=subprocess.run([a.godot,"--headless","--editor","--path",str(ROOT),"--script","res://tests/secure_duel_integration.gd","--log-file",str(a.output/"engine.log"),"--","--duel-local=ws://127.0.0.1:"+port],cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=100)
   body=(a.output/"godot.log").read_text(encoding="utf8")
   checks["real_godot_new_security_media"]=result.returncode==0 and "SECURE_INTEGRATION_PASS" in body and "SCRIPT ERROR:" not in body
   with sqlite3.connect(a.output/"moderation.sqlite") as db:checks["report_persisted"]=db.execute("SELECT count(*) FROM reports").fetchone()[0]==1
   summary={"checks":checks,"pass":all(checks.values()),"public_wss":"BLOCKED: not deployed","voice_device":"BLOCKED: PCM transport does not prove Android audio","android_touch":"BLOCKED: no Android device","old_protocol_matrix_rerun":False}
   (a.output/"results.json").write_text(json.dumps(summary,indent=2));print(json.dumps(summary,indent=2));return 0 if summary["pass"] else 1
  finally:
   server.terminate()
   try:server.wait(timeout=5)
   except subprocess.TimeoutExpired:server.kill();server.wait()
if __name__=="__main__":sys.exit(main())
