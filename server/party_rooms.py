"""Standalone authoritative party-room core. Not wired into production websocket server."""
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Any
import secrets

CATEGORIES = {"open_heart", "act_it", "who_among_us", "show_skill", "truth_or_fiction", "table_flip"}
ROUNDS = {10, 15, 20}

@dataclass
class PartyRoom:
    players: tuple[str, ...]
    cards: list[dict[str, Any]]
    round_limit: int = 10
    room_id: str = field(default_factory=lambda: secrets.token_hex(8))
    scores: dict[str, int] = field(default_factory=dict)
    used: set[str] = field(default_factory=set)
    current: dict[str, Any] | None = None
    turn: int = 0
    round_number: int = 0
    votes: dict[str, Any] = field(default_factory=dict)
    story_truth: bool | None = None
    story_committed: bool = False

    def __post_init__(self):
        if not 2 <= len(self.players) <= 6 or len(set(self.players)) != len(self.players) or any(not p for p in self.players):
            raise ValueError("Need 2-6 distinct players")
        if self.round_limit not in ROUNDS:
            raise ValueError("Invalid round count")
        ids = [str(c.get("id", "")) for c in self.cards]
        if not ids or any(not i for i in ids) or len(set(ids)) != len(ids):
            raise ValueError("Card IDs must be unique and nonempty")
        if any(c.get("category") not in CATEGORIES for c in self.cards):
            raise ValueError("Invalid category")
        self.scores = dict.fromkeys(self.players, 0)

    @property
    def actor(self) -> str:
        return self.players[self.turn]

    def draw(self, category: str = "") -> dict[str, Any]:
        if self.current is not None or self.round_number >= self.round_limit:
            raise ValueError("Round already active or match finished")
        if category and category not in CATEGORIES:
            raise ValueError("Unknown category")
        available = [c for c in self.cards if c["id"] not in self.used and (not category or c["category"] == category)]
        if not available:
            raise ValueError("Deck exhausted")
        self.current = secrets.choice(available).copy()
        self.used.add(self.current["id"])
        self.votes.clear()
        self.story_truth = None
        self.story_committed = False
        return self.public_state()

    def commit_story(self, player: str, is_true: bool) -> None:
        if self.current is None or self.current["category"] != "truth_or_fiction" or player != self.actor or type(is_true) is not bool or self.story_committed:
            raise ValueError("Invalid story commitment")
        self.story_truth = is_true
        self.story_committed = True

    def vote(self, player: str, choice: Any) -> None:
        if self.current is None or player not in self.players or player in self.votes:
            raise ValueError("Invalid voter or duplicate")
        category = self.current["category"]
        if category != "who_among_us" and player == self.actor:
            raise ValueError("Actor cannot vote on their own performance")
        if category == "who_among_us":
            if type(choice) is not str or choice not in self.players or choice == player:
                raise ValueError("Invalid nominee")
        elif category in ("act_it", "show_skill", "truth_or_fiction"):
            if type(choice) is not bool:
                raise ValueError("Vote must be boolean")
            if category == "truth_or_fiction" and not self.story_committed:
                raise ValueError("Story must be committed first")
        else:
            raise ValueError("This category does not accept votes")
        self.votes[player] = choice

    def finish(self, *, participated: bool = True) -> dict[str, Any]:
        if self.current is None:
            raise ValueError("No active round")
        category = self.current["category"]
        if category == "truth_or_fiction" and not self.story_committed:
            raise ValueError("Missing story commitment")
        if category in ("act_it", "show_skill", "who_among_us", "truth_or_fiction"):
            required = len(self.players) if category == "who_among_us" else len(self.players)-1
            if len(self.votes) != required:
                raise ValueError("Wait for all eligible votes")
        awards: dict[str, int] = {}
        def award(player: str, amount: int) -> None:
            self.scores[player] += amount
            awards[player] = awards.get(player, 0) + amount
        if category == "open_heart" and participated:
            award(self.actor, 10)
        elif category in ("act_it", "show_skill"):
            yes = sum(v is True for v in self.votes.values())
            no = sum(v is False for v in self.votes.values())
            if yes > no:
                award(self.actor, 20)
        elif category == "who_among_us" and self.votes:
            counts = {p: list(self.votes.values()).count(p) for p in self.players}
            maximum = max(counts.values())
            winners = [p for p, count in counts.items() if count == maximum]
            if maximum > 0 and len(winners) == 1:
                award(winners[0], 10)
        elif category == "truth_or_fiction":
            correct = wrong = 0
            for player, vote in self.votes.items():
                if vote is self.story_truth:
                    award(player, 10)
                    correct += 1
                else:
                    wrong += 1
            if wrong > correct:
                award(self.actor, 10)
        result = {"awards": awards, "scores": self.scores.copy(), "round": self.round_number + 1}
        self.current = None
        self.votes.clear()
        self.story_truth = None
        self.story_committed = False
        self.round_number += 1
        self.turn = (self.turn + 1) % len(self.players)
        result["finished"] = self.round_number >= self.round_limit
        return result

    def public_state(self, viewer: str | None = None) -> dict[str, Any]:
        if viewer is not None and viewer not in self.players:
            raise ValueError("Not a room member")
        return {
            "room": self.room_id,
            "players": list(self.players),
            "scores": self.scores.copy(),
            "round": self.round_number,
            "actor": self.actor,
            "card": self.current.copy() if self.current else None,
            "voted_players": list(self.votes),
            "story_committed": self.story_committed,
            "finished": self.round_number >= self.round_limit,
        }
