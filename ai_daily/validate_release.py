#!/usr/bin/env python3
"""Validate an approved daily picture puzzle and its image before deployment."""
import argparse, datetime, hashlib, json, pathlib, re, sys

SAFE = {"animals","food","fruits","vegetables","objects","countries_landmarks"}
REVIEWED = {"footballers","actors","singers","celebrities"}
ALL = SAFE | REVIEWED

def validate(folder):
    folder = pathlib.Path(folder)
    data = json.loads((folder/'daily.json').read_text(encoding='utf-8'))
    required = {'schema','id','date','type','category','category_en','category_ar','title_en','title_ar','image','sha256','status','provider','answer_verified','choices_en','choices_ar','correct_index','xp','reviewed_only','auto_publish_allowed'}
    assert required <= data.keys(), 'Missing required fields'
    assert data['schema'] == 2 and data['status'] == 'approved' and data['answer_verified'] is True
    assert data['provider'] != 'demo', 'Demo cannot be published'
    assert datetime.date.fromisoformat(data['date']).isoformat() == data['date']
    assert data['type'] == 'image_guess'
    assert data['category'] in ALL
    assert bool(data['reviewed_only']) == (data['category'] in REVIEWED)
    assert bool(data['auto_publish_allowed']) == (data['category'] in SAFE)
    assert re.fullmatch(r'daily-\d{4}-\d{2}-\d{2}\.png', data['image'])
    assert data['image'] == 'daily-' + data['date'] + '.png'
    assert all(isinstance(data[k],str) and 2 <= len(data[k]) <= 200 for k in ('title_en','title_ar','category_en','category_ar'))
    assert all(isinstance(data[k],list) and 4 <= len(data[k]) <= 4 and all(isinstance(x,str) and 0 < len(x) <= 120 for x in data[k]) for k in ('choices_en','choices_ar'))
    assert type(data['correct_index']) is int and 0 <= data['correct_index'] < len(data['choices_en'])
    assert type(data['xp']) is int and 0 <= data['xp'] <= 100
    image = (folder/data['image']).read_bytes()
    assert image.startswith(b'\x89PNG\r\n\x1a\n') and len(image) <= 3_000_000
    assert hashlib.sha256(image).hexdigest() == data['sha256'], 'Image checksum mismatch'
    return data

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('folder')
    args=parser.parse_args()
    try:
        info=validate(args.folder)
        print('Approved release validated:', info['id'])
    except (AssertionError, ValueError, KeyError, OSError, json.JSONDecodeError) as exc:
        print('Release rejected:',exc,file=sys.stderr)
        sys.exit(1)
