"""Compile reviewed native sources using the installed JDK/SDK and pinned Gradle.

Provider libraries resolve through official repositories with normal TLS checks.
"""
import argparse,hashlib,json,os,subprocess,zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

def archive(path,entries):
    with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED) as output:
        for name,data in sorted(entries.items()):
            info=zipfile.ZipInfo(name,(2026,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
            output.writestr(info,data)

def build(jdk,sdk,godot):
    project=ROOT/'native/android-identity'
    env={**os.environ,'JAVA_HOME':str(jdk),'ANDROID_HOME':str(sdk)}
    java=jdk/'bin'/('java.exe' if os.name=='nt' else 'java')
    subprocess.run([str(java),'-classpath',str(project/'gradle/wrapper/gradle-wrapper.jar'),
        'org.gradle.wrapper.GradleWrapperMain','assembleDebug','assembleRelease','--console=plain',
        '-PgodotAar='+str(godot.resolve())],cwd=project,env=env,check=True)
    sources=sorted([*project.glob('*.kts'),*project.glob('*.properties'),*(project/'src/main').rglob('*.java'),
        project/'src/main/AndroidManifest.xml'])
    evidence={'schema':2,'sources':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
        for p in sources},'godot_aar_sha256':hashlib.sha256(godot.read_bytes()).hexdigest()}
    output=ROOT/'addons/gaminghub_identity/bin';output.mkdir(parents=True,exist_ok=True)
    for variant in ('debug','release'):
        built=project/f'build/outputs/aar/gaminghub-identity-{variant}.aar'
        with zipfile.ZipFile(built) as aar:entries={name:aar.read(name) for name in aar.namelist() if not name.endswith('/')}
        entries['assets/gaminghub_identity_build.json']=json.dumps(evidence,sort_keys=True).encode()
        archive(output/f'gaminghub-identity-{variant}.aar',entries)
    print('IDENTITY_PLUGIN_BUILD_PASS')

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for name in ('jdk','sdk','godot-aar'):parser.add_argument('--'+name,type=Path,required=True)
    args=parser.parse_args();build(args.jdk,args.sdk,args.godot_aar)
