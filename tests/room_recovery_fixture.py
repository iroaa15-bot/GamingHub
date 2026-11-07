"""Ephemeral loopback room service for the real Godot recovery regression."""
import asyncio
import secrets
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "server"))
from shared_quiz_local import SharedQuizHub
from websockets.asyncio.server import serve


async def main():
    hub = SharedQuizHub(secrets.token_urlsafe(48), ":memory:")
    async with serve(hub.connection, "127.0.0.1", 8942,
                     process_request=hub.http, max_size=8192):
        tasks = [asyncio.create_task(hub.sweep()), asyncio.create_task(hub.mixer())]
        print("ROOM_RECOVERY_FIXTURE_READY", flush=True)
        try:
            await asyncio.Event().wait()
        finally:
            for task in tasks:
                task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)
            hub.moderation.db.close()


if __name__ == "__main__":
    asyncio.run(main())
