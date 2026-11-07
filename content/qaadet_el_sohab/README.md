# قعدة الصحاب — Gaming Hub (draft feature)

This is a separate, non-production feature proposal. Existing games, questions, voice, server and main remain unchanged.

## Gameplay
2–6 players. 10/15/20 rounds. Host chooses category or mixed mode. Server must own room state, deck order, votes, timer, scoring, power-card effects and reconnect snapshots. Never mix the distinct category mechanics. No repeated card within a room session; persist recent card IDs per room if supported. Guest play supported. Arabic and English are target languages, but this seed is Arabic-only and must not be presented as translated.

- open_heart: participation +10, skip without penalty; no right/wrong.
- act_it: 30 seconds; other players vote pass/fail, +20 on majority pass. Tie = no points.
- who_among_us: all eligible players vote secretly; reveal aggregate after all votes or timeout; winning nominated player +10; tie = no award; no self-vote.
- show_skill: 30 seconds, others vote pass/fail, +20 majority; tie = no points.
- truth_or_fiction: storyteller privately commits truth/fiction; everyone else votes; each correct voter +10; storyteller +10 if majority fooled. Avoid revealing sensitive personal details.
- table_flip: explicit server-side effect; one-time consumption; reject invalid targets; effects requiring previous/next round must expire correctly. No negative scores.

## Content gate
Target 3000: 500 heart, 550 act, 550 vote, 550 challenge, 550 bluff, 300 power. This seed has 72 authored Arabic prompts, not the completed bank. Before release: human review for fun, semantic duplicates, cultural safety, age-appropriateness; English localization; deterministic tests for each power and all modes; real Android two-phone test. No arithmetic/math puzzles. Do not auto-ship or merge.
