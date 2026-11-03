"""Build the dependency-free Java identity plugin with the installed JDK/Android SDK.

Gradle remains available; this path also works when Maven is unavailable. No SDK,
compiler or dependency is downloaded and no verification is disabled.
"""
import argparse,hashlib,json,os,subprocess,tempfile,zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

def archive(path,entries):
    with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED) as output:
        for name,data in sorted(entries.items()):
            info=zipfile.ZipInfo(name,(2026,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
            output.writestr(info,data)

def build(jdk,sdk,godot):
    source=ROOT/'native/android-identity/src/main'
    java=list(source.rglob('*.java'))
    output=ROOT/'addons/gaminghub_identity/bin';output.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory() as directory:
        scratch=Path(directory);engine=scratch/'godot.jar'
        with zipfile.ZipFile(godot) as aar:engine.write_bytes(aar.read('classes.jar'))
        classes=scratch/'classes';classes.mkdir()
        compiler=jdk/'bin'/('javac.exe' if os.name=='nt' else 'javac')
        subprocess.run([str(compiler),'--release','17','-encoding','UTF-8','-classpath',
            os.pathsep.join((str(sdk/'platforms/android-36/android.jar'),str(engine))),
            '-d',str(classes),*[str(p) for p in java]],check=True)
        jar=scratch/'classes.jar'
        archive(jar,{p.relative_to(classes).as_posix():p.read_bytes() for p in classes.rglob('*.class')})
        evidence={'schema':1,'sources':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
            for p in [*java,source/'AndroidManifest.xml']},'godot_aar_sha256':hashlib.sha256(godot.read_bytes()).hexdigest()}
        manifest=(source/'AndroidManifest.xml').read_bytes().replace(b'<manifest ',b'<manifest package="com.gaminghub.identity" ',1)
        entries={'AndroidManifest.xml':manifest,'classes.jar':jar.read_bytes(),
            'assets/gaminghub_identity_build.json':json.dumps(evidence,sort_keys=True).encode()}
        for variant in ('debug','release'):
            archive(output/f'gaminghub-identity-{variant}.aar',entries)
    print('IDENTITY_PLUGIN_BUILD_PASS')

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for name in ('jdk','sdk','godot-aar'):parser.add_argument('--'+name,type=Path,required=True)
    args=parser.parse_args();build(args.jdk,args.sdk,args.godot_aar)
