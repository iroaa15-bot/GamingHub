"""Numeric invitations for local/staging rooms; not authentication tokens."""
import secrets

def new_room_code(rooms):
    for _ in range(100):
        code = str(100000 + secrets.randbelow(900000))
        if code not in rooms:
            return code
    raise RuntimeError('Room code allocation temporarily unavailable')
