"""Local acceptance endpoint; loopback only, ephemeral transport secret."""
import argparse
import asyncio
import secrets
from websockets.asyncio.server import serve
from social_rooms import SocialHub


async def main(port, draft_content):
    hub=SocialHub(secrets.token_urlsafe(48),':memory:',draft_content)
    tasks=[]
    try:
        async with serve(hub.connection,'127.0.0.1',port,process_request=hub.http,
                         max_size=8192,max_queue=32,compression=None,ping_interval=20,ping_timeout=20):
            tasks=[asyncio.create_task(hub.sweep()),asyncio.create_task(hub.mixer())]
            print('SOCIAL_LOCAL_READY',port,'draft_content='+str(draft_content),flush=True)
            await asyncio.Event().wait()
    finally:
        for task in tasks:task.cancel()
        await asyncio.gather(*tasks,return_exceptions=True)
        hub.moderation.db.close()


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--port',type=int,default=8897)
    parser.add_argument('--draft-content',action='store_true')
    args=parser.parse_args()
    if not 1024<=args.port<=65535:parser.error('Use a local development port')
    asyncio.run(main(args.port,args.draft_content))
