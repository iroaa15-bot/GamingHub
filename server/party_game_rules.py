"""Party Room game-specific prompt and submission contracts.

The eight games intentionally use different inputs. This module does not award
unverified points, reveal private missions, or touch production state.
"""
from dataclasses import dataclass

@dataclass(frozen=True)
class Rule:
    title_ar: str
    instruction_ar: str
    answer_kind: str
    min_players: int = 2
    max_length: int = 300
    scoring: str = "host_review"

RULES = {
    "pass_the_bomb": Rule("القنبلة الدوارة", "اكتب كلمة مناسبة قبل انتهاء المؤقت", "word", max_length=40, scoring="timed"),
    "whos_most_likely": Rule("مين فينا؟", "اختار لاعبًا واحدًا من الغرفة", "player_vote", scoring="majority_vote"),
    "odd_one_out": Rule("مين المختلف؟", "اختار العنصر المختلف من الاختيارات", "choice", scoring="correct_choice"),
    "truth_or_dare": Rule("حقيقة ولا تحدي", "اختار حقيقة أو تحدي", "truth_dare", scoring="participation"),
    "draw_disaster": Rule("ارسم الكارثة", "ارسم ثم أرسل وصفًا مختصرًا؛ الرسم الفعلي يتطلب قناة رسم", "drawing_description", max_length=500, scoring="peer_vote"),
    "crazy_emoji": Rule("إيموجي مجنون", "خمن المعنى من الرموز التعبيرية", "text", scoring="correct_answer"),
    "fake_it": Rule("كدبة مقنعة", "اكتب إجابة مقنعة دون إفشاء الإجابة الصحيحة", "text", scoring="peer_vote"),
    "secret_mission": Rule("المهمة السرية", "اكتب تأكيد إتمام المهمة دون كشف نصها", "completion", scoring="host_review"),
}

def public_rule(game_id: str) -> dict:
    rule = RULES[game_id]
    return {"game": game_id, "title_ar": rule.title_ar,
            "instruction_ar": rule.instruction_ar, "answer_kind": rule.answer_kind,
            "scoring": rule.scoring}

def validate_submission(game_id: str, answer: str, members: set[str]) -> str:
    if game_id not in RULES:
        raise ValueError("unknown_party_game")
    rule = RULES[game_id]
    if not isinstance(answer, str):
        raise ValueError("answer_must_be_text")
    answer = answer.strip()
    if not answer or len(answer) > rule.max_length:
        raise ValueError("invalid_answer_length")
    if rule.answer_kind == "player_vote" and answer not in members:
        raise ValueError("vote_for_room_member_only")
    if rule.answer_kind == "truth_dare" and answer not in ("truth", "dare"):
        raise ValueError("choose_truth_or_dare")
    if rule.answer_kind == "completion" and answer not in ("done", "skip"):
        raise ValueError("choose_done_or_skip")
    if rule.answer_kind == "choice" and answer not in ("A", "B", "C", "D"):
        raise ValueError("choose_valid_option")
    if rule.answer_kind == "word" and any(char.isspace() for char in answer):
        raise ValueError("one_word_only")
    return answer
