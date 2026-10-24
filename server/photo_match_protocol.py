"""Isolated photo-match state machine for staging integration (not imported by live server).
No socket/audio dependencies. Server is authoritative for turns, scores and timers.
"""
from dataclasses import dataclass, field
import time

ALLOWED_TIMERS = (0, 10, 20, 30, 60)
ALLOWED_TARGETS = (3, 5, 10, 15, 20, 30, 50)
ALLOWED_REWARDS = (1, 2, 3, 5)
MAX_TEXT = 280

class MatchError(ValueError):
    pass

@dataclass
class PhotoMatch:
    players: tuple[str, str]
    target: int = 10
    timer: int = 30
    reward: int = 1
    current: int = 0
    scores: list[int] = field(default_factory=lambda: [0, 0])
    round: int = 1
    finished: bool = False
    awaiting_confirmation: bool = False
    guess_text: str = ""
    confirmation_started: float = 0.0
    server_facts: dict = field(default_factory=dict, repr=False)
    pending_question: bool = False
    turn_started: float = field(default_factory=time.monotonic)
    events: list[dict] = field(default_factory=list)

    def __post_init__(self):
        if len(self.players) != 2 or not all(self.players) or self.players[0] == self.players[1]:
            raise MatchError("Exactly two distinct players required")
        if any(type(v) is not int for v in (self.target,self.timer,self.reward)):
            raise MatchError("Settings must be integers")
        if self.target not in ALLOWED_TARGETS or self.timer not in ALLOWED_TIMERS or self.reward not in ALLOWED_REWARDS:
            raise MatchError("Invalid match settings")

    def _player(self, player: str) -> int:
        if player not in self.players:
            raise MatchError("Not a room member")
        return self.players.index(player)

    def _active(self, player: str) -> int:
        index = self._player(player)
        if self.finished:
            raise MatchError("Match ended")
        if self.timer and time.monotonic() - self.turn_started >= self.timer:
            raise MatchError("Turn expired")
        if index != self.current:
            raise MatchError("Not your turn")
        return index

    def _event(self, kind: str, **payload) -> dict:
        event = {"type": "photo_" + kind, "round": self.round, **payload}
        self.events.append(event)
        del self.events[:-256]
        return event

    def pass_turn(self, player: str) -> dict:
        self._active(player)
        if self.awaiting_confirmation:
            raise MatchError("Guess awaiting opponent confirmation")
        self.current = 1 - self.current
        self.pending_question = False
        self.turn_started = time.monotonic()
        return self._event("turn", player=self.current)

    def ask_text(self, player: str, text: str) -> dict:
        self._active(player)
        if self.awaiting_confirmation or not isinstance(text, str) or not 0 < len(text.strip()) <= MAX_TEXT:
            raise MatchError("Invalid text question")
        if self.pending_question:
            raise MatchError("Previous question awaiting answer")
        self.pending_question = True
        return self._event("question", player=self.current, mode="text", text=text.strip())

    def ask_tap(self, player: str, question_id: str) -> dict:
        self._active(player)
        facts = self.server_facts
        if self.awaiting_confirmation or question_id not in facts or type(facts[question_id]) is not bool:
            raise MatchError("No verified answer for this question")
        if self.pending_question:
            raise MatchError("Previous question awaiting answer")
        return self._event("question", player=self.current, mode="tap", question_id=question_id, answer=facts[question_id])

    def reply(self, player: str, yes: bool) -> dict:
        index = self._player(player)
        if self.timer and time.monotonic() - self.turn_started >= self.timer:
            raise MatchError("Turn expired")
        if self.finished or self.awaiting_confirmation or index == self.current or type(yes) is not bool:
            raise MatchError("Only opponent can answer yes/no")
        if not self.pending_question:
            raise MatchError("No text question awaiting answer")
        self.pending_question = False
        return self._event("reply", player=index, answer=yes)

    def propose_guess(self, player: str, guess: str = "") -> dict:
        self._active(player)
        if self.awaiting_confirmation or not isinstance(guess, str) or len(guess) > MAX_TEXT:
            raise MatchError("Invalid guess")
        self.awaiting_confirmation = True
        self.confirmation_started = time.monotonic()
        self.pending_question = False
        self.guess_text = guess.strip()
        return self._event("guess_pending", player=self.current, guess=self.guess_text)

    def confirm_guess(self, player: str, correct: bool) -> list[dict]:
        index = self._player(player)
        if self.finished or index == self.current or not self.awaiting_confirmation or type(correct) is not bool:
            raise MatchError("Only opponent can confirm pending guess")
        if time.monotonic() - self.confirmation_started >= 30:
            raise MatchError("Confirmation expired")
        self.awaiting_confirmation = False
        result = [self._event("guess_result", player=self.current, correct=correct)]
        if correct:
            self.scores[self.current] += self.reward
            if self.scores[self.current] >= self.target:
                self.finished = True
                result.append(self._event("finished", winner=self.current, scores=self.scores.copy()))
                return result
            self.round += 1
        self.current = 1 - self.current
        self.turn_started = time.monotonic()
        result.append(self._event("turn", player=self.current, scores=self.scores.copy()))
        return result

    def expire_turn(self) -> dict | None:
        if self.finished:
            return None
        if self.awaiting_confirmation:
            if time.monotonic() - self.confirmation_started < 30:
                return None
            self.awaiting_confirmation = False
            self.guess_text = ""
        elif not self.timer:
            return None
        elif time.monotonic() - self.turn_started < self.timer:
            return None
        self.pending_question = False
        self.current = 1 - self.current
        self.turn_started = time.monotonic()
        return self._event("turn", player=self.current, reason="timeout")
