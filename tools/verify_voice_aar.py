"""Verify the bundled Godot voice library's registration and native source fingerprint."""
import hashlib
import io
import json
from pathlib import Path
from zipfile import ZipFile
ROOT = Path(__file__).resolve().parents[1]

def native_fingerprint(root=ROOT):
    native = root/'native/android-voice'
    files = list((native/'src/main').rglob('*.kt')) + [native/'src/main/AndroidManifest.xml']
    files += [native/name for name in ('build.gradle.kts','settings.gradle.kts','gradle.properties','consumer-rules.pro')]
    digest = hashlib.sha256()
    for file in sorted(files, key=lambda p: p.relative_to(native).as_posix()):
        digest.update(file.relative_to(native).as_posix().encode() + b'\0')
        digest.update(file.read_bytes().replace(b'\r\n', b'\n') + b'\0')
    return digest.hexdigest()

def verify(path, root=ROOT):
    with ZipFile(path) as aar:
        info = json.loads(aar.read('assets/gaminghub_voice_build.json'))
        if info != {'protocol': 2, 'source_sha256': native_fingerprint(root)}:
            raise ValueError(f'Stale native voice AAR: {path}; rebuild with installPlugin')
        manifest = aar.read('AndroidManifest.xml').decode()
        for item in ('org.godotengine.plugin.v2.GamingHubVoice', 'com.gaminghub.voice.GamingHubVoicePlugin',
                     'android.permission.RECORD_AUDIO', 'android.permission.MODIFY_AUDIO_SETTINGS'):
            if item not in manifest: raise ValueError(f'Missing Android declaration: {item}')
        with ZipFile(io.BytesIO(aar.read('classes.jar'))) as jar:
            for name in ('GamingHubVoicePlugin', 'AndroidVoiceEngine', 'VoiceJitterBuffer', 'CapturedFrames', 'Pcm16Normalizer'):
                if f'com/gaminghub/voice/{name}.class' not in jar.namelist():
                    raise ValueError(f'Missing native class: {name}')
    return info['source_sha256']

if __name__ == '__main__':
    for variant in ('debug', 'release'):
        path = ROOT/f'addons/gaminghub_voice/bin/gaminghub-voice-{variant}.aar'
        print('VOICE_AAR_PASS', variant, verify(path))
