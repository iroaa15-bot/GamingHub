"""Run actual Godot clients and Opus/SRTP media against an isolated local gateway.

The native JNI object in the Godot test is simulated. aiortc media is real UDP,
but uses generated tones, not Android microphones or speakers.
"""
import argparse
import asyncio
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

async def main(godot, output):
    output.mkdir(parents=True, exist_ok=True)
    server = await asyncio.create_subprocess_exec(
        'node', 'android-lan-server.mjs', cwd=ROOT/'experiments/colyseus-room-poc',
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT)
    async def ready():
        while line := await server.stdout.readline():
            if b'COLYSEUS_GATEWAY_READY' in line:
                return line.decode().strip().split()[-1]
        raise RuntimeError('Colyseus gateway failed to start')
    try:
        endpoint = await asyncio.wait_for(ready(), 20)
        commands = [
            ('godot-colyseus-room.log', [sys.executable, 'tools/run_godot_gate.py', '--godot', str(godot.resolve()),
             '--project', str(ROOT), '--script', 'tests/webrtc_room_runtime.gd', '--marker', 'WEBRTC_ROOM_RUNTIME_PASS',
             '--log', str(output/'godot-colyseus-room.log')]),
            ('webrtc-colyseus-media.log', [sys.executable, 'tests/webrtc_media_integration.py', '--url', endpoint, '--frames', '1500']),
            ('colyseus-recovery-transport.log', [sys.executable, 'tests/staging_recovery_transport.py', '--url', endpoint]),
        ]
        for name, command in commands:
            env = dict(os.environ, GAMINGHUB_TEST_WS=endpoint)
            process = await asyncio.create_subprocess_exec(*command, cwd=ROOT, env=env,
                stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT)
            try:
                result, _ = await asyncio.wait_for(process.communicate(), 100)
            except asyncio.TimeoutError:
                process.kill(); await process.wait(); raise
            if name != 'godot-colyseus-room.log': (output/name).write_bytes(result)
            print(result.decode(errors='replace'), end='')
            if process.returncode: return process.returncode
        return 0
    finally:
        if server.returncode is None:
            server.terminate()
            try: await asyncio.wait_for(server.communicate(), 5)
            except asyncio.TimeoutError: server.kill(); await server.wait()

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    raise SystemExit(asyncio.run(main(args.godot, args.output.resolve())))
