"""Start an isolated local room server and run two actual Godot clients; no Actions/APK."""
import argparse
import asyncio
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'server'))
import server as app
from websockets.asyncio.server import serve

async def main(godot):
    async with serve(app.handler, '127.0.0.1', 0, ping_interval=None, compression=None) as server:
        endpoint = f'ws://127.0.0.1:{server.sockets[0].getsockname()[1]}'
        env = dict(os.environ, GAMINGHUB_TEST_WS=endpoint)
        process = await asyncio.create_subprocess_exec(godot, '--headless', '--path', str(ROOT),
            '--script', 'res://tests/voice_room_runtime.gd', env=env,
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT)
        try:
            output, _ = await asyncio.wait_for(process.communicate(), 55)
        except asyncio.TimeoutError:
            process.kill(); output, _ = await process.communicate()
            print(output.decode(errors='replace')); print('VOICE_ROOM_RUNTIME_TIMEOUT')
            return 1
        text = output.decode(errors='replace'); print(text)
        return int(process.returncode != 0 or 'VOICE_ROOM_RUNTIME_PASS' not in text or 'SCRIPT ERROR' in text)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--godot', default=os.getenv('GODOT_BIN', 'godot'))
    args = parser.parse_args(); raise SystemExit(asyncio.run(main(args.godot)))
