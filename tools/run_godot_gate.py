"""Require successful runtime completion, not merely Godot's process exit code."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

def run(godot, project, script, marker, log, timeout=100):
    try:
        with tempfile.TemporaryDirectory(prefix='gaminghub-test-profile-') as profile:
            result=subprocess.run([str(godot),'--headless','--path',str(project),'--script',str(script)],
                stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=timeout,
                env=dict(os.environ,XDG_DATA_HOME=profile))
        output,code=result.stdout,result.returncode
    except subprocess.TimeoutExpired as error:
        data=error.stdout or b''
        output=(data.decode(errors='replace') if isinstance(data,bytes) else data)+'\nGODOT_GATE_TIMEOUT\n';code=124
    log.parent.mkdir(parents=True,exist_ok=True);log.write_text(output)
    failed=code!=0 or marker not in output or any(x in output for x in ('SCRIPT ERROR:','ERROR:'))
    print(f"GODOT_GATE_{'FAIL' if failed else 'PASS'}: {marker}; exit={code}")
    return int(failed)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--godot',type=Path,required=True);p.add_argument('--project',type=Path,required=True)
    p.add_argument('--script',required=True);p.add_argument('--marker',required=True);p.add_argument('--log',type=Path,required=True)
    p.add_argument('--timeout',type=int,default=100);a=p.parse_args()
    raise SystemExit(run(a.godot,a.project,a.script,a.marker,a.log,a.timeout))
