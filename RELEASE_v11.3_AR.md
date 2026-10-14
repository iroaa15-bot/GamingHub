# Gaming Hub v11.3 — Daily Picture Challenges

- Six original illustrated picture challenges per UTC day, served by Render with deterministic generation and no paid image API.
- Categories rotated: animals, food, fruits, vegetables, objects, countries, landmarks.
- Four Arabic/English options; images served as PNG with verified SHA-256.
- The game now includes a picture-challenge entry on the home screen, prev/next navigation, and one XP reward per completed puzzle ID.
- Person categories (footballers, actors, singers, celebrities) have verified-name candidate lists for manual photo/content review only. They are NOT automatically published, nor are dummy likenesses served.
- Server compatibility: preserve original multiplayer WebSocket routes; add `/ai_daily/daily.json` and `/ai_daily/daily-YYYY-MM-DD-NN.png`.
- More daily variety is possible, but daily subjects can recur over time; this is deterministic content rotation, **not** a trained image generation service.
- AdMob Android SDK is NOT implemented in this release.
- To test locally: open project.godot with Godot 4.5.1; test new menu, puzzle navigation, and XP (max once per ID).
