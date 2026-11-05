"""Start only a loopback server, run real Godot clients, stop our child server.
No production URLs, APK build, dependency installation, or GitHub operations.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--godot",required=True)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--sizes",default="2,3,4,5,6")
    parser.add_argument("--script",default="res://tests/photo_duel_extension_godot.gd")
    parser.add_argument("--case",default="all")
    args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    protected=["server/server.py","server/photo_duel_staging.py","server/photo_room_service.py","server/photo_match_protocol.py","data/network_config.json","scripts/multiplayer.gd","scripts/android_voice_bridge.gd","project.godot","export_presets.cfg"]
    def digests(): return {p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in protected}
    before=digests()
    env=os.environ.copy()
    env.update(GAMINGHUB_DUEL_HOST="127.0.0.1",GAMINGHUB_DUEL_PORT="0",PYTHONUTF8="1")
    server_log=args.output/"server.log"
    result=None
    with server_log.open("w",encoding="utf8") as stream:
        server=subprocess.Popen([sys.executable,"-u",str(ROOT/"server/photo_duel_extension.py")],cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT)
        try:
            endpoint=None
            for _ in range(120):
                body=server_log.read_text(encoding="utf8")
                match=re.search(r"LOCAL_PHOTO_DUEL_READY (\d+)",body)
                if match:
                    endpoint="ws://127.0.0.1:"+match[1]
                    break
                if server.poll() is not None: break
                time.sleep(.1)
            if endpoint is None: raise RuntimeError("Local server failed: "+server_log.read_text(encoding="utf8")[-1500:])
            command=[args.godot,"--headless","--editor","--path",str(ROOT),"--script",args.script,"--log-file",str(args.output/"godot_engine.log"),"--","--duel-local="+endpoint,"--duel-sizes="+args.sizes,"--duel-case="+args.case]
            with (args.output/"godot_clients.log").open("w",encoding="utf8") as log:
                result=subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=145)
            body=(args.output/"godot_clients.log").read_text(encoding="utf8")
            summary={"endpoint":endpoint,"godot_exit":result.returncode,"local_extension_pass":"LOCAL_EXTENSION_PASS" in body and result.returncode==0 and "SCRIPT ERROR:" not in body and "Traceback" not in server_log.read_text(encoding="utf8"),"script_errors":"SCRIPT ERROR:" in body,"editor_shutdown_resource_warnings":"leaked at exit" in body,"protected_files_unchanged":digests()==before,"protected_sha256":before,"apk_built":False,"production_contacted_by_test_clients":False,"android_audio":"BLOCKED: no real device test","android_touch":"BLOCKED: no real device test"}
            (args.output/"run.json").write_text(json.dumps(summary,indent=2),encoding="utf8")
            print(json.dumps({k:v for k,v in summary.items() if k!="protected_sha256"},indent=2))
            return 0 if summary["local_extension_pass"] and summary["protected_files_unchanged"] else 1
        finally:
            server.terminate()
            try: server.wait(timeout=5)
            except subprocess.TimeoutExpired: server.kill();server.wait()

if __name__=="__main__":sys.exit(main())
