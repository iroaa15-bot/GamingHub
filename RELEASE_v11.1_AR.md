# Gaming Hub v11.1 — Daily Auto Content (14 October 2026)

## What was implemented
- Verified, automatically generated *procedural* daily Arabic/English questions: 24 items for games 2 (language), 3 (logic/numbers) and 5 (science calculations).
- Python endpoint `GET /content/daily.json` on the existing multiplayer server; no cron, paid API or database required. The UTC date determines today's pack, and new content is generated when requested after UTC midnight.
- Same-day cache on the Godot client. Cached copy is replaced after a successful validation. If disconnected, bundled game questions remain playable.
- Same published question text is not reused within a 90-day window by a deterministic rolling-history algorithm. This does **not** eliminate similarity between numeric puzzle templates.
- Safe ar/en answer verification and data-length limits. No player accounts, photos, usage analytics, or personal data are needed for this endpoint.
- A button on the home screen to retry the daily content download.
- Image puzzles are deliberately excluded from auto-publication; visual correctness requires human review.

## Run server locally
`cd server && pip install -r requirements.txt && python server.py`
Then visit `http://localhost:8765/content/daily.json` (the production Godot client uses HTTPS).

## Verification
`python -m unittest discover -s server -p 'test_*.py'`
`python tests/run_checks.py`

## Deploying to production
Copy server/daily_content.py and updated server/server.py + server/Dockerfile to the **GamingHub** GitHub repository that Render actually deploys. After a successful Render deployment, check `/content/daily.json`, UTC date, count 24, and response HTTP 200. A ZIP on its own cannot update the running public server.

## Important limitations
This release is algorithmic question generation, **not OpenAI API text generation**; it is free and mathematically verifiable but has a finite family of question formats. AI image generation, if desired, remains review-first. AdMob SDK integration and Android APK device verification are separate work.
