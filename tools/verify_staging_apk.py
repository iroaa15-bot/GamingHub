#!/usr/bin/env python3
"""Inspect the built staging APK, including actual DEX definitions and packaged profile."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
from zipfile import ZipFile

from verify_voice_aar import native_fingerprint

STAGING_URL = 'wss://gaminghub-recovery-staging.onrender.com'
APPLICATION_ID = 'com.iroaa15.gaminghub.recoverystaging'


def dex_classes(data):
    if not data.startswith(b'dex\n'):
        raise ValueError('Not a standard Android DEX file')
    def word(offset): return struct.unpack_from('<I', data, offset)[0]
    strings_offset, types_offset = word(60), word(68)
    for index in range(word(96)):
        class_index = word(word(100) + index * 32)
        descriptor_index = word(types_offset + class_index * 4)
        start = word(strings_offset + descriptor_index * 4)
        while data[start] & 0x80: start += 1
        start += 1
        yield data[start:data.index(b'\0', start)].decode('utf-8')


def verify(apk, sdk):
    build_tools = sdk/'build-tools/36.0.0'
    def command(*args):
        return subprocess.check_output([str(build_tools/args[0]), *map(str, args[1:])], text=True, stderr=subprocess.STDOUT)
    signature = command('apksigner', 'verify', '--verbose', '--print-certs', apk)
    badging = command('aapt', 'dump', 'badging', apk)
    permissions = command('aapt', 'dump', 'permissions', apk)
    manifest = command('aapt', 'dump', 'xmltree', apk, 'AndroidManifest.xml')
    if f"package: name='{APPLICATION_ID}'" not in badging:
        raise ValueError('APK has an unexpected application ID')
    if "application-label:'Gaming Hub Recovery Test'" not in badging:
        raise ValueError('Staging application label missing')
    if "sdkVersion:'24'" not in badging or "targetSdkVersion:'36'" not in badging:
        raise ValueError('Unexpected Android SDK compatibility')
    for permission in ('RECORD_AUDIO', 'MODIFY_AUDIO_SETTINGS', 'INTERNET'):
        if f"'android.permission.{permission}'" not in permissions:
            raise ValueError(f'Missing Android permission: {permission}')
    for text in ('org.godotengine.plugin.v2.GamingHubVoice', 'com.gaminghub.voice.GamingHubVoicePlugin'):
        if text not in manifest: raise ValueError(f'Plugin registration missing: {text}')
    with ZipFile(apk) as archive:
        classes = set()
        for name in archive.namelist():
            if re.fullmatch(r'classes\d*\.dex', name): classes.update(dex_classes(archive.read(name)))
        for name in ('GamingHubVoicePlugin', 'AndroidVoiceEngine', 'WebRtcVoiceEngine', 'VoiceJitterBuffer', 'CapturedFrames', 'Pcm16Normalizer'):
            if f'Lcom/gaminghub/voice/{name};' not in classes:
                raise ValueError(f'Native voice class not defined in APK DEX: {name}')
        for name in ('Lorg/webrtc/PeerConnection;', 'Lorg/webrtc/audio/JavaAudioDeviceModule;'):
            if name not in classes: raise ValueError(f'WebRTC definition missing: {name}')
        for abi in ('arm64-v8a', 'armeabi-v7a'):
            if f'lib/{abi}/libjingle_peerconnection_so.so' not in archive.namelist():
                raise ValueError(f'WebRTC native library missing for {abi}')
        config_paths = [n for n in archive.namelist() if n.endswith('/data/voice_staging.json')]
        if len(config_paths) != 1: raise ValueError('Packaged staging profile missing or ambiguous')
        config = json.loads(archive.read(config_paths[0]))
        if config != {'enabled': True, 'server_url': STAGING_URL}:
            raise ValueError('APK does not contain the expected enabled staging profile')
        info = json.loads(archive.read('assets/gaminghub_voice_build.json'))
        if info != {'protocol': 2, 'source_sha256': native_fingerprint()}:
            raise ValueError('Packaged native voice implementation is stale')
        abis = sorted({n.split('/')[1] for n in archive.namelist() if n.startswith('lib/') and n.endswith('/libgodot_android.so')})
        if abis != ['arm64-v8a', 'armeabi-v7a']:
            raise ValueError(f'Expected universal ARM staging APK; got {abis}')
        compressed_native = all(i.compress_type == 8 for i in archive.infolist() if i.filename.startswith('lib/') and i.filename.endswith('.so'))
        if not compressed_native: raise ValueError('Native libraries are not compressed for this staging build')
        if archive.testzip() is not None: raise ValueError('Corrupt APK archive')
    return {'status': 'STAGING_APK_VERIFIED', 'application_id': APPLICATION_ID, 'label': 'Gaming Hub Recovery Test',
            'staging_url': STAGING_URL, 'min_sdk': 24, 'target_sdk': 36, 'abis': abis,
            'native_voice_protocol': 2, 'voice_engine': 'libwebrtc-144.7559.15', 'native_source_sha256': info['source_sha256'],
            'apk_size_bytes': apk.stat().st_size, 'apk_sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
            'signature_verified': True, 'compressed_native_libraries': compressed_native, 'real_device_audio_tested': False}, signature, badging, permissions


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('apk', type=Path)
    parser.add_argument('--sdk', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    summary, signature, badging, permissions = verify(args.apk.resolve(), args.sdk.resolve())
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output/'apk-verification.json').write_text(json.dumps(summary, indent=2)+'\n')
    (args.output/'apk-signature.txt').write_text(signature)
    (args.output/'apk-badging.txt').write_text(badging)
    (args.output/'apk-permissions.txt').write_text(permissions)
    print(json.dumps(summary, indent=2))
