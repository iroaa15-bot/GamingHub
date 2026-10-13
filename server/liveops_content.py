"""Free, deterministic daily/weekly mission rotation; no cron, API key or database."""
import datetime
import hashlib
import json
from pathlib import Path

CONFIG_PATH = Path(__file__).with_name('liveops_rotation.json')

def _offset(seed: str, size: int) -> int:
    return int.from_bytes(hashlib.sha256(seed.encode('utf-8')).digest()[:4], 'big') % size

def daily_rotation(today=None):
    """UTC-based rotation, computed on demand so the free service needs no scheduler."""
    today = today or datetime.datetime.now(datetime.timezone.utc).date()
    if not isinstance(today, datetime.date):
        raise TypeError('today must be a date')
    source = json.loads(CONFIG_PATH.read_text(encoding='utf-8'))
    monday = today - datetime.timedelta(days=today.weekday())
    day = today.isoformat()
    week = monday.isoformat()
    daily = source['daily_missions']
    weekly = source['weekly_missions']
    events = source['event_rotation']
    if not daily or not weekly or not events:
        raise ValueError('Rotation pools cannot be empty')
    di = _offset('daily:' + day, len(daily))
    wi = _offset('weekly:' + week, len(weekly))
    ei = _offset('event:' + week, len(events))
    return {
        'schema': 1,
        'season': source['season'],
        'effective_date_utc': day,
        'effective_week_utc': week,
        'daily_missions': [daily[di], daily[(di + 1) % len(daily)]],
        'weekly_missions': [weekly[wi], weekly[(wi + 1) % len(weekly)]],
        'event_rotation': [events[ei]],
    }
