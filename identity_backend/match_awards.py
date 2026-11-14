"""Pure adapter for translating authoritative room completion to identity award intent.

The room server must supply a trusted account binding separately; player indices
and client-submitted winner claims are never sufficient for awarding points.
"""
from dataclasses import dataclass

@dataclass(frozen=True)
class AwardIntent:
    match_id: str
    user_id: str
    points: int

def award_from_finished(room_code, finished_event, bound_account_ids, points_per_win=10):
    if not isinstance(finished_event, dict) or finished_event.get("type") != "finished":
        return None
    winner = finished_event.get("winner")
    if type(winner) is not int or winner < 0 or winner >= len(bound_account_ids):
        return None
    account_id = bound_account_ids[winner]
    if not isinstance(account_id, str) or not account_id.strip():
        return None
    if not isinstance(room_code, str) or not room_code.strip():
        return None
    if type(points_per_win) is not int or not (1 <= points_per_win <= 100):
        return None
    return AwardIntent(match_id=room_code, user_id=account_id, points=points_per_win)
