"""Isolated Party Room state machine. Not wired into production WebSocket routes.

No audio, ads, daily generation or existing room state is touched.
Python 3.10+; stdlib only.
"""
from dataclasses import dataclass, field
import secrets
import time
from .party_game_rules import public_rule, validate_submission
from .party_challenges import challenge, normalize, drawing, MISSIONS, TRUTH, DARE

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
    completed: set = field(default_factory=set)
    approved: set = field(default_factory=set)
    votes: dict = field(default_factory=dict)
    bomb_index: int = 0
    option_owners: dict = field(default_factory=dict)

    def view(self, player_id):
        self._member(player_id)
        state=self.snapshot()
        state['my_submission']=self.submissions.get(player_id)
        state['my_completed']=player_id in self.completed
        state['has_voted']=player_id in self.votes
        if self.phase=='voting':
            state['reveal']['options']={key:value for key,value in state['reveal']['options'].items() if self.option_owners[key]!=player_id}
        if self.round_index>=0 and self.round_index<len(ROUND_SEQUENCE):
            game=ROUND_SEQUENCE[self.round_index]
            if game=='secret_mission':state['private_task']=MISSIONS[(list(self.members).index(player_id)+self.round_index)%len(MISSIONS)]
            if game=='truth_or_dare' and player_id in self.submissions:
                tasks=TRUTH if self.submissions[player_id]=='truth' else DARE
                state['private_task']=tasks[(list(self.members).index(player_id)+self.round_index)%len(tasks)]
        return state

    def complete(self, player_id):
        self._member(player_id)
        if self.phase!='active' or ROUND_SEQUENCE[self.round_index]!='truth_or_dare' or player_id not in self.submissions:raise PartyError('no_task')
        self.completed.add(player_id)
        self.revision+=1

    def approve(self, host_id, player_id):
        if host_id!=self.host_id:raise PartyError('host_only')
        if self.phase!='reveal' or ROUND_SEQUENCE[self.round_index] not in ('truth_or_dare','secret_mission'):raise PartyError('review_not_available')
        if player_id in self.approved:raise PartyError('already_reviewed')
        if player_id not in self.completed:raise PartyError('task_not_completed')
        self.approved.add(player_id)
        self.scores[player_id]+=1
        self.last_reveal['awarded'][player_id]=1
        self.revision+=1

    def vote(self, player_id, option):
        self._member(player_id)
        if self.phase!='voting' or player_id in self.votes:raise PartyError('vote_not_available')
        choices=self.last_reveal['options']
        if not isinstance(option,str) or option not in choices or self.option_owners[option]==player_id:raise PartyError('invalid_vote')
        self.votes[player_id]=option
        self.revision+=1
        if len(self.votes)==len(self.members):self.finish_votes()

    def finish_votes(self):
        if self.phase!='voting':raise PartyError('vote_not_available')
        awards={}
        def add(p, points):awards[p]=awards.get(p,0)+points
        if ROUND_SEQUENCE[self.round_index]=='fake_it':
            for voter,choice in self.votes.items():
                owner=self.option_owners[choice]
                if owner=='truth':add(voter,2)
                else:add(owner,1)
        else:
            for choice in self.votes.values():add(self.option_owners[choice],1)
        for p,points in awards.items():self.scores[p]+=points
        self.last_reveal['awarded']=awards
        self.last_reveal['scoring_pending']=False
        self.phase='reveal';self.deadline=None;self.revision+=1

    def tick(self):
        if self.deadline is not None and time.monotonic()>=self.deadline:
            if self.phase=='active':self.reveal(self.host_id)
            elif self.phase=='voting':self.finish_votes()


    def _member(self, player_id: str) -> Member:
        if player_id not in self.members:
            raise PartyError("not_room_member")
        return self.members[player_id]

    def snapshot(self) -> dict:
        return {
            "code": self.code, "host_id": self.host_id, "phase": self.phase,
            "revision": self.revision, "round_index": self.round_index,
            "total_rounds": len(ROUND_SEQUENCE),
            "game": ROUND_SEQUENCE[self.round_index] if 0 <= self.round_index < len(ROUND_SEQUENCE) else None,
            "members": [{"id": m.player_id, "name": m.display_name,
                         "ready": m.ready, "connected": m.connected}
                        for m in self.members.values()],
            "scores": dict(self.scores), "submitted_count": len(self.submissions),
            "deadline": self.deadline,
            "remaining": max(0,int(self.deadline-time.monotonic())) if self.deadline else None,
            "challenge": challenge(ROUND_SEQUENCE[self.round_index],self.round_index) if 0<=self.round_index<len(ROUND_SEQUENCE) else {},
            "bomb_player": list(self.members)[min(self.bomb_index,len(self.members)-1)] if self.phase=='active' and ROUND_SEQUENCE[self.round_index]=='pass_the_bomb' else None,
            "reveal": {"game":self.last_reveal["game"],"options":dict(self.last_reveal["options"])} if self.phase=="voting" else dict(self.last_reveal) if self.phase in ("reveal", "results") else None,
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
        self.deadline = time.monotonic() + (15 if ROUND_SEQUENCE[self.round_index]=="pass_the_bomb" else 60)
        self.revision += 1
        return self.snapshot()

    def submit(self, player_id: str, answer: str, request_id: str) -> dict:
        self._member(player_id)
        if not isinstance(request_id,str) or not request_id or len(request_id) > 100:
            raise PartyError("invalid_request_id")
        key = player_id + ":" + request_id
        if key in self.processed:
            return dict(self.processed[key])
        if self.phase != "active":
            raise PartyError("round_not_active")
        if player_id in self.submissions:
            raise PartyError("already_submitted")
        if not isinstance(answer, str) or len(answer) > 12000:
            raise PartyError("invalid_answer")
        if self.deadline is not None and time.monotonic() > self.deadline:
            raise PartyError("round_expired")
        try:
            answer = validate_submission(ROUND_SEQUENCE[self.round_index], answer, set(self.members))
        except ValueError as exc:
            raise PartyError(str(exc)) from exc
        game=ROUND_SEQUENCE[self.round_index]
        if game=='draw_disaster':
            try:drawing(answer)
            except ValueError as exc:raise PartyError(str(exc)) from exc
        if game=='pass_the_bomb':
            if player_id!=list(self.members)[min(self.bomb_index,len(self.members)-1)]:raise PartyError('not_bomb_holder')
            if not answer.casefold().startswith(('ب','b')) or not answer.isalpha() or len(answer)<2:raise PartyError('word_must_start_b')
            if normalize(answer) in [normalize(a) for a in self.submissions.values()]:raise PartyError('duplicate_word')
            self.bomb_index+=1
            self.deadline=time.monotonic()+15
        if game=='fake_it' and normalize(answer) in ('المشتري','مشتري','jupiter'):raise PartyError('write_a_bluff')
        self.submissions[player_id] = answer
        if game=='secret_mission' and answer=='done':self.completed.add(player_id)
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
        if game=='odd_one_out':
            awarded={p:2 for p,a in self.submissions.items() if a=='B'}
        elif game=='crazy_emoji':
            awarded={p:2 for p,a in self.submissions.items() if normalize(a) in ('الاسدالملك','الملكالاسد','lionking','thelionking')}
        elif game=='pass_the_bomb':awarded={p:1 for p in self.submissions}
        if game!='whos_most_likely':
            for p,points in awarded.items():self.scores[p]+=points
        self.last_reveal = {
            "game": game, "answers": dict(self.submissions),
            "awarded": awarded,
            "scoring_pending": game in ("truth_or_dare","secret_mission","draw_disaster","fake_it"),
        }
        self.phase = "reveal"
        self.deadline = None
        if game in ('fake_it','draw_disaster') and self.submissions:
            entries=dict(self.submissions)
            if game=='fake_it':entries['truth']='المشتري'
            self.option_owners={secrets.token_hex(8):p for p in entries}
            self.last_reveal['options']={key:entries[p] for key,p in self.option_owners.items()}
            self.phase='voting';self.deadline=time.monotonic()+30
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
        self.completed.clear();self.approved.clear();self.votes.clear();self.option_owners.clear();self.bomb_index=0
        if self.round_index < len(ROUND_SEQUENCE):
            self.last_reveal.clear()
        self.phase = "results" if self.round_index == len(ROUND_SEQUENCE) else "active"
        self.deadline = None if self.phase == "results" else time.monotonic() + (15 if ROUND_SEQUENCE[self.round_index]=="pass_the_bomb" else 60)
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
        member.token = secrets.token_urlsafe(32)
        member.connected = True
        member.disconnected_at = None
        member.mic_enabled = False  # voice always needs fresh opt-in
        self.revision += 1
        return self.snapshot()


def new_room(host_id: str, host_name: str) -> tuple[PartyRoom, str]:
    room = PartyRoom(code=secrets.token_hex(3).upper(), host_id=host_id)
    token = room.join(host_id, host_name)
    return room, token
