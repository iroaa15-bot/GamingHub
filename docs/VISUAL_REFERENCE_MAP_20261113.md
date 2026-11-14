# Gaming Hub visual reference implementation map

The four owner-supplied montages are visual references, not game rules or screenshots of the implemented app. All labels remain native Arabic/English controls. No screenshot is used as a full-screen interface. Status below is a component mapping, not acceptance.

Reference IDs: A = Interactive Arabic Game Flows; B = Neon Arabic Gaming Hub App Montage; C = Arabic Mobile Game UI Showcase; D = Neon Arabic Lobby Showcase-1. Each is the PNG supplied on 13 November 2026. Earlier approved welcome artwork remains in `assets/ui/gaming_hub_brand.png`; provider logos retain official branding.

| Reference screen/state | Real project component | Actual controls and constraints |
|---|---|---|
| A1, B1, C1 welcome | `scripts/main.gd:show_welcome`, `welcome_backdrop.gd` | Exactly Guest, Google, Facebook plus language; keep actual account flows |
| B2, C21 language dialog | `main.gd:_add_language_control`, `player_preferences.gd` | Arabic/English, persisted choice, fixed globe position; no extra login |
| A2, B3, C3 game catalog | `main.gd:show_home`, `_add_unique_game_catalog`, `_add_social_game_catalog` | All original ten plus six social games, each once; four approved bottom destinations |
| A3, B4, C4 play mode | `main.gd:show_modes`, `standalone_social_games.gd` | Friends / Offline / Games; do not rename offline into a fictitious computer opponent |
| A4–5, B5–6, C5–6 room entry/settings | `photo_duel_extension_ui.gd` | Create, join, valid numeric code, players2–6, existing timer/round/target modes only |
| A6, B7, C7, D main lobby | `photo_duel_extension_ui.gd:_state` | Verified profiles, actual connected/readiness state, host, share/copy code, ready/start/leave |
| D three-player/joining state | Same lobby player grid | Empty seats are placeholders, never fictitious online players; joined count from server |
| D five-player/not-ready state | Same grid and agreement controls | Start gated by joined, connected and ready state; no visual-only enablement |
| D six-player/all-ready state | Same grid and host readiness action | Host/crown, current user, ready chips and room capacity remain authoritative |
| D disconnected/reconnected state | Room client + player grid + voice adapter | Show reconnecting; preserve90-second protocol recovery; never fake successful reconnect |
| D microphone badges | `photo_duel_voice_adapter.gd`, voice controls | Show only proven local mic state; current server does not expose each peer's mute state |
| A7–9 rounds/score/final | `social_room_ui.gd`, `shared_quiz_ui.gd`, `main.gd:show_results` | Round count, server score, next round, winner/draw; existing replay/exit routes |
| A social title/deck choice, B social landing | Social catalog + six mode scenes | Keep each game's existing rules and separately selected category; no combined rules inferred from artwork |
| A card-back/reveal | Six `*_offline.gd` scenes and social-room private card state | Never reveal actor-only performance card to opponents |
| A/B/C cream question cards | `social_room_ui.gd`, `visual_skin.gd` | Native text on a cream/gold panel, category badge and wrapping; no text baked into artwork |
| A Who Among Us vote/result | `social_room_ui.gd`, `server/social_rooms.py` | Existing secret vote, one legal vote/player, authoritative results |
| B/C Truth or Fiction | `truth_or_fiction_offline.gd`, social room controls | Story secret choice and opponent vote; no automatic truth verification invented |
| B challenge/action card | `act_it_offline.gd`, `show_skill_offline.gd`, social room | Existing actor roles, timer and voting; visual card only changes presentation |
| A/B/C cinema category/type | `main.gd` game1, `shared_quiz_ui.gd`, approved content adapters | Existing playable question types only; film stills, actor photos and audio require licenses |
| A/B/C cinema answer feedback | `main.gd`, `shared_quiz_ui.gd` | Four choices where applicable, actual result, replay/next; no invented copyrighted media |
| A/B/C sound categories | `main.gd` game6 and content adapters | Existing real sound bank; category selection only for available content |
| A/B/C sound playback/question | `shared_quiz_ui.gd` audio player and answer controls | Real play/replay, synchronized permission and existing replay limit; waveform must not imply unmeasured audio |
| A/B/C correct/wrong result | `visual_skin.gd:add_feedback_panel`, shared/local result handlers | Genuine correctness, displayed award; never add account points from UI |
| A/B/C rankings/podium | Match results and existing leaderboard components | Actual names and scores; no mock global standings or new leaderboard service |
| B/C profile/setup/edit | `player_account_ui.gd`, `account_screen.gd`, `player_avatar_image.gd` | Real name/photo/points/progress, native photo picker, authenticated persistence |
| B friends/invite | `player_account_ui.gd` friends mode and room invite actions | Existing invitations; no fake online contacts or device contacts permission |
| B/C settings | `main.gd:show_accessibility`, existing audio/preferences | Actual audio/effects/language/privacy controls; preserve RTL/LTR and Android9 |
| B admin | Existing server admin dashboard | Content/assets/publication/audit authorization remains server-side, outside player APK |
| C shop and reference-only extras | Intentionally excluded | No store, payment, unsupported achievements/options, QR scanner or new game solely because pictured |
| Missing loading/error/offline states | Account/room status controls, pending-action guards | Same visual shell, readable actual error, retry only when meaningful, offline stays available |

## Shared visual specification

- Deep indigo/violet background with restrained cyan architectural accents; no continuous full-screen shader.
- Glossy rounded blue primary actions, violet secondary actions, green ready/start/success, red leave/error, gold emphasis.
- Player portraits80–88 logical pixels when space permits,72 for3–4-player lobbies,64 for5–6; active dense views may compact without covering questions. Real account photos remain circular and unaltered except the existing crop/mask.
- Cream social cards with gold/violet rim and dark native text. Arabic and English headings come from code; inaccurate reference spellings are not copied.
- Minimum56 logical-pixel primary touch targets, no fixed screenshot coordinates in application logic. Containers reflow for narrow screens and long names.
- No new permissions, paid assets, generated replacement montage, mock identity, or rule changes.

## Acceptance evidence to collect

Native captures of welcome/language, catalog, mode, create/join/settings,2–6-player grids, each gameplay mechanic and result, profile/settings, plus loading/disconnect/recovery. Fixture renders must be labeled as fixtures; physical captures must identify the tested APK. New styling is not accepted solely by this mapping.
