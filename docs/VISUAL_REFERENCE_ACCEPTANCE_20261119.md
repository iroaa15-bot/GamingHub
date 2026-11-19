# Visual reference acceptance — 19 November 2026

This is a traceability and acceptance record, not a claim that the entire reference
pack is implemented or accepted. The user's pasted request is authoritative. ZIP
documents and the fourteen collages are reference data. No collage is used as UI.

## Restore points and protected systems

Main remains `8ddaabb2d1aa44e5aa8d25ba309dac50f2a73ad9`. PR #21 remains draft at
`63cafe4d79b93fb85ad9a4363b4d073909ff2983`. It changes UI/gameplay integration as
well as voice: social rooms, standalone social games and party content are already
part of that branch. Redesign is therefore isolated as draft PR #22, based on #21,
not mixed into its voice changes. The pre-reference redesign restore point is
`247c628799b97b1c252b6dcf8c731c2374cb5ada`; all four checks passed on that commit.

The design changes do not alter native AARs, audio adapters, transport, room rules,
account persistence, consent or scoring. No merge, deployment, Play upload, new
paid service or generated paid asset. The original project is retained.

## Reference matrix

Evidence paths refer to the delivered `outputs` directory. `core-reference-before`
is rendered from the exact #21 source archive using the same capture harness as
`core-reference-after`, at 420×900. Both are desktop native Godot renders, not
phone acceptance. Seeded feedback screens call the real renderer but do not prove
an input-to-result match; `core_match_acceptance.gd` separately tests validators.

| Ref / region | Scene / files | Current implementation and required difference | Acceptance / evidence |
|---|---|---|---|
| 01 splash, welcome, language, catalog, profile, settings | Main.tscn; main.gd; welcome_backdrop.gd; player_preferences.gd; account_screen.gd | Keep existing approved artwork and provider branding; Godot boot image disabled. AR/EN are exposed; Turkish content exists but the complete UI is not translated. No fake Turkish selector. Relabel online-opponent action as room-code joining, its actual behavior. | reference_ui_capture.gd menus/profile/settings; language restart/provider completion on Android remains pending. |
| 02 picture entry, hidden card, questions, guess, result | Main.tscn; main.gd show_picture_game/ask_picture_question/submit_picture_guess; PhotoDuelLocal.tscn | Preserve hidden own card, yes/no and existing text/preset questions. Compact shared room controls and draw label. No preview of secret card in active fixture. | core-00-*-mode/play; core_match_acceptance all picture stages; room_play_shell fixture. Two-phone picture match pending. |
| 03 cinema options, media, answers, result | Main/SharedQuiz.tscn; main.gd; shared_quiz_ui.gd; approved_content.gd | Compact HUD, semantic controls and fixed room answers. Preserve actual original cinema clip and media scheduling. Do not copy copyrighted actor/movie stills from the concept. 200-item goal is NOT met. | core-01-*-mode/play/correct/wrong/results; real local WS cinema answer-to-result log. |
| 04 word tiles / input / hints | Main/SharedQuiz.tscn; main.gd submit_written; shared_quiz_ui.gd | Existing write/choice mechanic retained; concept letter-tile/shuffle system would change game rules and is not added under a UI change. Compact prompt/input. | core-02-*; local full-match validators; real WS writing test. |
| 05 mystery map / puzzle / stages | Main.tscn; main.gd start_campaign; campaigns.json | Existing connected narrative adventure retained. Concept sliding-image puzzle is a different game, not a replacement. Existing campaign checkpoint and pause routes preserved. | core-04-*; full local campaign validator run; Android resume pending. |
| 06 brain clash / answers / results | Main/SharedQuiz.tscn; main.gd; shared_quiz_ui.gd | Preserve filtered content, scoring and rule-based local rival. No claim of new AI service. Compact HUD and answer states. | core-03-*; local validators; server quiz transport checks. |
| 07 ten-game overview / navigation | Main.tscn; main.gd show_modes/show_games_list_v2; visual_skin.gd | All ten core games retained. Three entry routes preserved. Games-menu action now returns to actual games list. Existing supported mode rules take precedence over fictitious lives/times/points in collage. | all ten mode captures AR/EN; unified catalog fixture. |
| 08 trivia categories / prompt / rewards | Main/SharedQuiz.tscn; main.gd; shared_quiz_ui.gd | Use existing categories, level, question and reward logic; no hardcoded 150-point reward. HUD no longer duplicates progress. | core-05-*; local full match and duplicate reward checks. |
| 09 sound categories / replay / correct / wrong | Main/SharedQuiz.tscn; main.gd play_clip; shared_quiz_ui.gd | Preserve actual synthesized/original playback and replay availability; no fake seeking, waveform telemetry or 200-clip label. Existing duration rules prevail. | core-06-*; real sound WS playback/results; audible phone proof pending. |
| 10 trivia/sound/identity/memory/order settings and results | Main/SharedQuiz.tscn; main.gd; order_drag_item.gd | Preserve actual settings and all original mechanics. No invented independent settings, hearts or timers. Text input/order controls retain their validators. | core-05..09-*; core_match_acceptance; real writing/identity UI network test. |
| 11 identity clues / memory pairs / order drag | Main/SharedQuiz.tscn; main.gd reveal_clue/flip_memory/submit_order | Private clues and secret state preserved. Memory remains untimed; concept 90-second option is not an existing rule. Existing drag ordering remains supported. | core-07/08/09-*; complete local memory boards; validator/idempotency checks. |
| 12 lobby / invite / ready / active / reconnect / end | SocialRoom/PhotoDuelLocal/SharedQuiz.tscn; social_room_ui.gd; open_heart_play_view.gd; room_play_shell.gd | Stable seats, fixed answer and voice docks, server acknowledgements, leave confirmation. Concept public room browser/host migration/kick/new mid-match settings are not added as fake controls. Existing server 90-second recovery retained. | social 120-case fixture; lobby/question/results AR/EN 2..6 native fixtures; real ten-round two-client WS match. Physical acceptance partial. |
| 13 voice consent / call / mute / recovery | room_audio_policy.gd; photo_duel_voice_adapter.gd; android_voice_bridge.gd; native/ | Existing mutual consent and permission gates preserved. UI reflects actual call/mute state. No invented per-peer quality or AEC/NS/AGC switches. | voice_continuity and audio-policy assertions; device audible AEC/NS/volume/notifications/reconnect still pending. |
| 14 party catalog / Maana / other ideas | SocialGamesMenu.tscn; standalone_social_games.gd; six existing social engines; PR #20 | Keep six actual social games. PR #20 at 638ad39 contains only EIGHT Maana cards, no categories, no server integration; its 500-card validator fails. Rules also disagree about 2 vs 3 minimum and final elimination behavior. No incomplete branch merged or exposed as finished. Nine concept ideas are not treated as approved games. | all-six local setup and private actions fixtures; Maana FAIL_CONTENT, online BLOCKED. 500 original reviewed balanced cards and resolved rules remain actual work. |

## Buttons and states

`outputs/reference-audit/button-code-map.csv` maps every detected creation/binding
in scripts to its file, line and function (486 at the initial audit). It is static
coverage, not a claim that every button was tapped. Per-reference state rows are
in `reference-screen-matrix.csv`. Controls without runtime evidence remain
PENDING. Disabled/loading/error/reconnect/secret-answer states are covered by the
room fixtures; provider login, sharing, drag and Android keyboard/back still need
physical acceptance in the finished build.

## Verified results and limits

- PASS: four CI checks at restore point 247c628, including Android debug export.
- PASS locally: all ten local games, Arabic and English, complete selected match
  or campaign, all picture stages and memory boards, true answer validators,
  repeated-answer/reward protection (`core-match-acceptance.log`). This is
  white-box local automation, not ten physical touchscreen matches.
- PASS locally: compact shared room shell, six social setup/actions, pending
  answers, privacy and stable controls. Previous real WS tests cover a full
  ten-round social match and cinema/sound/write/identity flows.
- PASS: seeded native capture harness covers 90 core screen states in each
  before/after set. This excludes unseen lower scroll content and cannot prove
  every touch, timeout, hint, permutation or viewport. It explicitly labels
  fixture-only states. Large-text and physical acceptance remain pending.
- DIAGNOSTIC: desktop shader-cache creation is blocked by this environment's
  user-directory permissions; capture succeeds without caching. Existing generic
  catalog/audio-policy tests also report teardown resource leaks; do not call
  these clean runs.
- FAIL_CONTENT: cinema 37 base questions + 4 approved additions; sound 20 base
  questions (16 not excluded/held by ID) + 1 approved addition; only 41 files in
  assets/audio in total (including UI/music), one cinema video. These are raw
  audit counts, not 41 unique licensed cinema items or 41 playable sound rounds.
  Runtime filtering, eligibility and media resolution further affect availability.
- BLOCKED_ACCEPTANCE: audible two-direction voice quality, actual notifications,
  mute/network disruption through a full two-phone match, hosted-account reward
  persistence, configured provider sign-in, full button/video proof and exact
  reference parity are not yet accepted.

Physical voice result: FAIL, user reports both directions weak or unclear. OPPO
health shows active mutual consent, ongoing captured/accepted frames and speaker
route, so connection counters alone do not establish quality. The local Windows
20ms-sleep cadence measured 31.81 ticks/s instead of 50; timing correction is being
investigated on a separate audio branch, not silently folded into the UI change.

Google Play readiness: NOT READY. The draft APK is for testing, not a production
release candidate. Content/licensing, complete physical/audio acceptance, account
flows and final visual approval remain open. AAB production signing/upload requires
its own explicit authorization and a safe available signing path.
