#!/usr/bin/env python3
"""Safe source-sync helper: dry-run by default; push requires local gh authentication.

Never stores a token, never force-pushes, never modifies the main branch.
"""
import argparse, os, shutil, subprocess, sys, tempfile
from pathlib import Path
from source_manifest import ROOT, inventory, verify

REPOSITORY = 'iroaa15-bot/GamingHub'
BRANCH = 'gaminghub-v9.3-source-upload'

def command(*args, cwd=None):
    return subprocess.run(args, cwd=cwd, check=True, text=True)

def publish(root, branch):
    if not shutil.which('git') or not shutil.which('gh'):
        raise RuntimeError('Git and GitHub CLI (gh) are required for publishing')
    command('gh','auth','status')
    with tempfile.TemporaryDirectory(prefix='gaminghub-sync-') as folder:
        work = Path(folder)/'repo'
        command('gh','repo','clone',REPOSITORY,str(work),'--','--depth','1')
        command('git','fetch','origin',branch,cwd=work)
        command('git','checkout','-b',branch,'--track','origin/'+branch,cwd=work)
        source_files = inventory(root)
        for relative in source_files:
            origin=root/relative
            target=work/relative
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(origin,target)
        manifest=root/'release/source_manifest.json'
        dest=work/'release/source_manifest.json'
        dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(manifest,dest)
        command('git','add','--',*source_files.keys(),'release/source_manifest.json',cwd=work)
        changed = subprocess.run(['git','diff','--cached','--quiet'],cwd=work)
        if changed.returncode == 0:
            print('No source changes to publish')
            return
        if changed.returncode != 1:
            raise RuntimeError('git diff failed')
        command('git','commit','-m','Upload Gaming Hub v9.5 Hoor Zain visuals and Godot source',cwd=work)
        command('git','push','-u','origin',branch,cwd=work)
        print('SOURCE_PUSHED_TO_EXISTING_DRAFT_PR',branch)

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--publish',action='store_true',help='Push a new branch and open PR (requires gh auth)')
    parser.add_argument('--branch',default=BRANCH)
    args=parser.parse_args()
    problems=verify(ROOT)
    if problems:
        print('REFUSING_TO_SYNC:',*problems,sep='\n - ')
        sys.exit(1)
    source_files=inventory(ROOT)
    print(f'REPO {REPOSITORY}; BRANCH {args.branch}; FILES {len(source_files)}; BYTES {sum((ROOT/f).stat().st_size for f in source_files)}')
    if not args.publish:
        print('DRY_RUN_OK: no network or repository changes performed')
    else:
        try:publish(ROOT,args.branch)
        except (RuntimeError,subprocess.CalledProcessError) as exc:
            print('PUBLISH_FAILED:',exc,file=sys.stderr)
            sys.exit(1)
