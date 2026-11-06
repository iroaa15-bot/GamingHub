"""Isolated party protocol adapter. No production routes or sockets are modified."""
from __future__ import annotations
from dataclasses import dataclass, field
import asyncio
import secrets
from typing import Any
from party_rooms import PartyRoom

MAX_MESSAGE_FIELDS = 8
MAX_NAME_LENGTH = 32

@dataclass
class Session:
    room: PartyRoom
    owner: str
    tokens: dict[str, str] = field(default_factory=dict)
    lock: asyncio.Lock = field(default_factory=asyncio.Lock)

class PartyGateway:
    """In-memory authenticated dispatcher; transport must bind token to each socket."""
    def __init__(self, cards: list[dict[str, Any]]):
        self.cards = cards
        self.sessions: dict[str, Session] = {}

    def create(self, player_names: list[str], rounds: int = 10) -> dict[str, Any]:
        if not isinstance(player_names, list) or not all(type(p) is str and 0 < len(p) <= MAX_NAME_LENGTH for p in player_names):
            raise ValueError("Invalid players")
        room = PartyRoom(tuple(player_names), self.cards, rounds)
        session = Session(room, room.players[0])
        session.tokens = {player: secrets.token_urlsafe(32) for player in room.players}
        self.sessions[room.room_id] = session
        return {"room": room.room_id, "credentials": session.tokens.copy()}

    def authenticate(self, room_id: str, player: str, token: str) -> Session:
        session = self.sessions.get(room_id)
        if session is None or not isinstance(player, str) or not isinstance(token, str):
            raise ValueError("Invalid credentials")
        expected = session.tokens.get(player)
        if expected is None or not secrets.compare_digest(expected, token):
            raise ValueError("Invalid credentials")
        return session

    async def dispatch(self, room_id: str, player: str, token: str, message: dict[str, Any]) -> dict[str, Any]:
        session = self.authenticate(room_id, player, token)
        if not isinstance(message, dict) or len(message) > MAX_MESSAGE_FIELDS:
            raise ValueError("Invalid message")
        action = message.get("type")
        if action not in ("party_sync", "party_draw", "party_vote", "party_story_commit", "party_finish"):
            raise ValueError("Unknown action")
        async with session.lock:
            room = session.room
            if action == "party_sync":
                return room.public_state(player)
            if action == "party_draw":
                if player != session.owner:
                    raise ValueError("Host only")
                category = message.get("category", "")
                if type(category) is not str:
                    raise ValueError("Invalid category")
                return room.draw(category)
            if action == "party_vote":
                room.vote(player, message.get("choice"))
                return {"type": "party_vote_ack", "round": room.round_number}
            if action == "party_story_commit":
                room.commit_story(player, message.get("is_true"))
                return {"type": "party_story_commit_ack"}
            if action == "party_finish":
                if player != session.owner:
                    raise ValueError("Host only")
                participated = message.get("participated", True)
                if type(participated) is not bool:
                    raise ValueError("Invalid participation")
                return room.finish(participated=participated)
            raise ValueError("Invalid action")
