"""Isolated Party Room state machine. Not wired into production WebSocket routes.

No audio, ads, daily generation or existing room state is touched.
Python 3.10+; stdlib only.
"""
from dataclasses import dataclass, field
import secrets
import time
from .party_game_rules import public_rule, validate_submission

MAX_PLAYERS = 6
ROUND_SEQUENCE = (
    "pass_the_bomb", "whos_most_likely", "odd_one_out", "crazy_emoji",
    "fake_it", "truth_or_dare", "draw_disaster", "secret_mission",
    "pass_the_bomb", "whos_most_likely", "odd_one_out", "crazy_emoji",
    "fake_it", "draw_disaster", "secret_mission",
)
VALID_GAMES = frozenset(ROUND_SEQUENCE)
GRACE_SECONDS = 90


class PartyError(ValueError):
    """Invalid or unauthorized Party Room operation."""


@dataclass
class Member:
    player_id: str
    display_name: str
    token: str = field(default_factory=lambda: secrets.token_urlsafe(32))
    ready: bool = False
    connected: bool = True
    disconnected_at: float | None = None
    mic_enabled: bool = False
    speaker_enabled: bool = False


@dataclass
class PartyRoom:
    code: str
    host_id: str
    members: dict[str, Member] = field(default_factory=dict)
    phase: str = "lobby"
    round_index: int = -1
    revision: int = 0
    submissions: dict[str, str] = field(default_factory=dict)
    scores: dict[str, int] = field(default_factory=dict)
    processed: dict[str, dict] = field(default_factory=dict)
    deadline: float | None = None
    last_reveal: dict = field(default_factory=dict)

    def _member(self, player_id: str) -> Member:
        if player_id not in self.members:
            raise PartyError("not_room_member")
        return self.members[player_id]

    def snapshot(self) -> dict:
        return {
            "code": self.code, "host_id": self.host_id, "phase": self.phase,
            "revision": self.revision, "round_index": self.round_index,
            "total_rounds": len(ROUND_SEQUENCE),
            "game": ROUND_SEQUENCE[self.round_index] if self.round_index >= 0 else None,
            "members": [{"id": m.player_id, "name": m.display_name,
                         "ready": m.ready, "connected": m.connected}
                        for m in self.members.values()],
            "scores": dict(self.scores), "submitted_count": len(self.submissions),
            "deadline": self.deadline,
            "reveal": dict(self.last_reveal) if self.phase in ("reveal", "results") else None,
            "round_rule": public_rule(ROUND_SEQUENCE[self.round_index]) if self.phase != "results" and self.round_index >= 0 else None,
        }

    def join(self, player_id: str, name: str) -> str:
        if self.phase != "lobby":
            raise PartyError("match_started")
        if not player_id or len(player_id) > 64 or player_id in self.members:
            raise PartyError("invalid_player")
        if len(self.members) >= MAX_PLAYERS:
            raise PartyError("room_full")
        name = name.strip()
        if not name or len(name) > 32:
            raise PartyError("invalid_name")
        member = Member(player_id, name)
        self.members[player_id] = member
        self.scores[player_id] = 0
        self.revision += 1
        return member.token

    def ready(self, player_id: str, value: bool) -> dict:
        if self.phase != "lobby":
            raise PartyError("not_in_lobby")
        self._member(player_id).ready = bool(value)
        self.revision += 1
        return self.snapshot()

    def start(self, player_id: str) -> dict:
        if player_id != self.host_id:
            raise PartyError("host_only")
        if self.phase != "lobby" or len(self.members) < 2:
            raise PartyError("not_ready")
        if not all(m.ready and m.connected for m in self.members.values()):
            raise PartyError("not_ready")
        self.round_index = 0
        self.phase = "active"
        self.submissions.clear()
        self.last_reveal.clear()
        self.deadline = time.monotonic() + 60
        self.revision += 1
        return self.snapshot()

    def submit(self, player_id: str, answer: str, request_id: str) -> dict:
        self._member(player_id)
        if not request_id or len(request_id) > 100:
            raise PartyError("invalid_request_id")
        key = player_id + ":" + request_id
        if key in self.processed:
            return dict(self.processed[key])
        if self.phase != "active":
            raise PartyError("round_not_active")
        if player_id in self.submissions:
            raise PartyError("already_submitted")
        if not isinstance(answer, str) or len(answer) > 1000:
            raise PartyError("invalid_answer")
        if self.deadline is not None and time.monotonic() > self.deadline:
            raise PartyError("round_expired")
        try:
            answer = validate_submission(ROUND_SEQUENCE[self.round_index], answer, set(self.members))
        except ValueError as exc:
            raise PartyError(str(exc)) from exc
        self.submissions[player_id] = answer
        self.revision += 1
        response = self.snapshot()
        self.processed[key] = dict(response)
        return response

    def reveal(self, player_id: str) -> dict:
        if player_id != self.host_id:
            raise PartyError("host_only")
        if self.phase != "active":
            raise PartyError("round_not_active")
        game = ROUND_SEQUENCE[self.round_index]
        awarded = {}
        # Score only deterministic votes. Subjective games remain unscored.
        if game == "whos_most_likely" and self.submissions:
            counts = {}
            for voted_for in self.submissions.values():
                counts[voted_for] = counts.get(voted_for, 0) + 1
            maximum = max(counts.values())
            winners = sorted(pid for pid, votes in counts.items() if votes == maximum)
            for winner in winners:
                self.scores[winner] += 1
                awarded[winner] = 1
        self.last_reveal = {
            "game": game, "answers": dict(self.submissions),
            "awarded": awarded,
            "scoring_pending": game != "whos_most_likely",
        }
        self.phase = "reveal"
        self.deadline = None
        self.revision += 1
        return self.snapshot()

    def next_round(self, player_id: str) -> dict:
        if player_id != self.host_id:
            raise PartyError("host_only")
        if self.phase != "reveal":
            raise PartyError("reveal_required")
        self.round_index += 1
        self.submissions.clear()
        self.processed.clear()
        if self.round_index < len(ROUND_SEQUENCE):
            self.last_reveal.clear()
        self.phase = "results" if self.round_index == len(ROUND_SEQUENCE) else "active"
        self.deadline = None if self.phase == "results" else time.monotonic() + 60
        self.revision += 1
        return self.snapshot()

    def disconnect(self, player_id: str) -> None:
        member = self._member(player_id)
        member.connected = False
        member.disconnected_at = time.monotonic()
        member.mic_enabled = False
        self.revision += 1

    def reconnect(self, player_id: str, token: str) -> dict:
        member = self._member(player_id)
        if not secrets.compare_digest(member.token, token):
            raise PartyError("invalid_resume_token")
        if member.disconnected_at is not None and time.monotonic() - member.disconnected_at > GRACE_SECONDS:
            raise PartyError("resume_expired")
        member.connected = True
        member.disconnected_at = None
        member.mic_enabled = False  # voice always needs fresh opt-in
        self.revision += 1
        return self.snapshot()


def new_room(host_id: str, host_name: str) -> tuple[PartyRoom, str]:
    room = PartyRoom(code=secrets.token_hex(3).upper(), host_id=host_id)
    token = room.join(host_id, host_name)
    return room, token
