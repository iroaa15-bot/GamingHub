# Gaming Hub v7.7 — Android Publishing Sprint 1

**Status:** Local QA candidate prepared; not approved for Google Play release.

## Completed
- Optimized 5 campaign PNGs to WebP, reducing combined bytes from 14,462,010 to 1,489,186 (~89.7%).
- Added duplicate-move protection to the Godot WebSocket client.
- Offline regression checks: 66 game tests + 10 server tests + 2 daily content tests = **78 passing**.
- Added explicit 16-gate release audit, Android device QA checklist, and Play listing/privacy review drafts.

## Not completed
- Godot 4.5.1 editor/runtime import and smoke test.
- Android signed AAB and real-device tests.
- Real 2-device internet match and FPS/memory metrics.
- AdMob Android native SDK integration and live ads.
- Google Play Console listing, Data safety, privacy publication, closed testing, and approval.

## Important
The **full Godot client v7.7 is a downloadable ZIP in the ChatGPT conversation**, not in this GitHub repository. This repo hosts the live Render multiplayer backend. Do not treat this file as evidence that a signed Android build has been published.

Backend: https://gaminghub-multiplayer.onrender.com/health
