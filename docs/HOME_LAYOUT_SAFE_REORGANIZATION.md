# Home layout v2 — safe reorganization

Status: design approved, code not yet changed.

Order: existing header; Guess Your Picture prominent hero; one Games List entry containing all current games and future Party Room games; existing Create Room, Join by Code, connections, chat, voice/mute and settings controls. Keep existing callbacks and IDs. Do not add dummy buttons.

Safety: work on feature/party-room-8games-15rounds only; main untouched. Inspect current UI and routing before editing. Feature flag home_layout_v2_enabled defaults false, with instant fallback to old home. No changes to gameplay, voice relay, server or room protocol. Hide unfinished party games. Test every existing game launch, invite/join, mute, Arabic RTL, Android small screens and build. Manual approval required before merge/release.
