"""Exercise compiled Godot resources from an APK; not Android/JNI device execution."""
import argparse
import hashlib
import json
from pathlib import Path,PurePosixPath
import tempfile
from zipfile import ZipFile
from run_godot_gate import run
ROOT=Path(__file__).resolve().parents[1]
def verify(apk,godot,output):
    output.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='gaminghub-apk-') as tmp:
        project=Path(tmp)/'assets';project.mkdir()
        with ZipFile(apk) as archive:
            for entry in archive.infolist():
                if not entry.filename.startswith('assets/') or entry.is_dir():continue
                relative=PurePosixPath(entry.filename).relative_to('assets')
                if '..' in relative.parts:raise ValueError('Unsafe archive path')
                target=project.joinpath(*relative.parts);target.parent.mkdir(parents=True,exist_ok=True)
                target.write_bytes(archive.read(entry))
        if not (project/'project.binary').exists():raise ValueError('Compiled Godot project missing')
        failed=run(godot,project,(ROOT/'tests/recovery_runtime.gd').resolve(),'RECOVERY_RUNTIME_PASS',output/'apk-gameplay-runtime.log')
    result={'result':'APK_RUNTIME_FAIL' if failed else 'APK_RUNTIME_PASS','apk_sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),
        'execution':'Godot 4.5.1 headless on extracted APK resources','android_jni_executed':False,'physical_device_tested':False}
    (output/'apk-runtime.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));return failed
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('apk',type=Path);p.add_argument('--godot',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();raise SystemExit(verify(a.apk,a.godot.resolve(),a.output))
