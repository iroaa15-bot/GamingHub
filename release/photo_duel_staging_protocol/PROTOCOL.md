# Isolated Photo Duel v3

This server is opt-in, binds loopback by default, and is never imported into production.
Production server files/configuration and original voice modules are unchanged.

## Local operation

Reuse the existing Python environment with websockets and Pillow (the legacy server imports Pillow). No installation or deployment is required.

```powershell
python server/photo_duel_extension.py
# Original Gaming Hub application, with an explicitly enabled local menu entry:
Godot_console.exe --path . -- --duel-local=ws://127.0.0.1:8771
```

The main scene remains Main.tscn. Games > Guess Your Picture shows a separate local-only entry when this argument is present and valid. Ordinary production navigation is unchanged. The client refuses production/public endpoints and accepts only explicit loopback/private IPv4 LAN URLs. For a private LAN bind set GAMINGHUB_DUEL_HOST to the private interface IP and GAMINGHUB_DUEL_ALLOW_LAN=1. GAMINGHUB_DUEL_PORT defaults to 8771. No public interface bind is permitted by this staging launcher.

## Wire contract

All extension messages carry integer `protocol: 3` and use the `duel_` namespace. A client sends duel_hello and receives duel_capabilities before sending room actions.

| Request | Fields / result |
|---|---|
| duel_hello | protocol=3; returns players 2..6, timers 0/10/20/30/60, reconnect window 85s, chat=true, voice=false |
| duel_create | players 2..6, timer, target 1..50; returns code, private player token and slot |
| duel_join | code; joins an available slot; match starts when configured capacity is filled |
| duel_chat | text, at most 280 Unicode characters; room-wide plain text history |
| duel_question | text; active player asks designated next player |
| duel_preset | question_id from preset_questions; waits for designated yes/no reply |
| duel_reply | Boolean answer; only designated opponent, preset replies must match original image facts |
| duel_guess | guess; waits for designated opponent confirmation, no automatic award |
| duel_confirm | Boolean correct; only designated opponent; true awards 1 point and replaces guessed image for next round, false awards none |
| duel_pass | current player only, no pending response |
| duel_sync | authoritative state snapshot |
| duel_resume | code and private token; disconnected slot only, token rotates after success |
| duel_leave | closes this fixed-membership match, invalidates tokens, releases connection for another room |

`duel_state` includes per-player slot, capacity/joined/connected, current and responder slots, scores/round/target, pending question or guess, chat/history, remaining_ms/deadline_unix_ms, paused/closed/winner and revision. It never includes that player's own image or anyone else's resume token. Visible opponents contain only other players' original-200 asset paths.

The active player's designated responder is `(current+1) % capacity`. Completing a reply/confirmation or timing out advances to the next player. The server is authoritative. Timer 0 has no deadline; nonzero values cover the whole turn, including pending replies/confirmation. Disconnect pauses the entire match and preserves remaining time/pending action; the final reconnect resumes the remaining time rather than giving a new full turn. Disconnected sessions expire after 85 seconds; idle rooms expire after 20 minutes. The full 85-second expiry duration was not waited out in the automated evidence.

Chat/history are bounded to 50 entries each; incoming messages are capped at 8192 bytes; settings/Boolean fields and sender identity are validated. Chat permits at most 5 messages/s per connection and general extension traffic at most 100 requests/10s. Scores and turn identity cannot be set using client player fields. No audio, tokens or chat are persisted by the server.

## Backward compatibility

Only the separate local endpoint dispatches connections. A first non-duel message delegates to the existing unmodified legacy room handler; old photo_* messages delegate to the existing staging Photo Duel handler. A connection stays in its selected protocol. The original legacy Godot client was tested against this local endpoint for create/join/started compatibility. Original production services were not contacted. The old photo_* delegation path was retained but was not separately rerun.

## Targeted test commands

```powershell
python tests/run_photo_duel_extension.py --godot PATH_TO_GODOT --sizes 6 --case six --output OUTPUT_DIRECTORY
# Only the previously failed numeric assertion:
python tests/run_photo_duel_extension.py --godot PATH_TO_GODOT --script res://tests/photo_duel_extension_lifecycle.gd --case negative --output OTHER_OUTPUT_DIRECTORY
```

The default matrix supports 2..6 for future use; the resumed run executed only size 6. Tests use actual Godot script instances and independent WebSocketPeer TCP connections. They run with --editor so production daily-content autoloads are not instantiated; editor-safe script construction avoids scene placeholders. The embedded scene's script binding is checked separately. This is not Android or human gameplay acceptance.

## Deployment boundary

Local or private-LAN use needs no public deployment. Real Internet use of these new features requires an explicitly approved separate WSS service and a deliberate client endpoint policy/configuration update. The current client deliberately refuses public URLs. The existing production server need not be replaced. No deploy, GitHub Actions or APK build was performed.
