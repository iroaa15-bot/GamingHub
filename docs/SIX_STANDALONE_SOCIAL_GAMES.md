# Gaming Hub — six independent social games

Decision: Qaadet El Sohab is a content origin, NOT a nested game or submenu.
Expose six standalone titles in the main games list:
- open_heart — افتح قلبك — 500 target
- act_it — مثّل وورّينا — 550 target
- who_among_us — مين فينا؟ — 550 target
- show_skill — ورّينا شطارتك — 550 target
- truth_or_fiction — صدق ولا تأليف؟ — 550 target
- table_flip — اقلب الترابيزة — 300 target

Each game must have its own icon, scene, independent category-specific gameplay, content bank, scoring and online room mode, offline mode and back-to-games-list action. Each game mode selector displays exactly three actions: Friends, Offline, Back. No nested 'Qaadet El Sohab' hub. Preserve 132 existing authored cards and their IDs, and existing Maana Wala Alayna and Guess Your Picture games.

Integration: reuse common room, account, reconnect and UI infrastructure, but use separate game_type identifiers, filtered card decks, rule handlers and server-validated actions. Do not share one combined random deck across these six titles. Power cards in table_flip require explicit safe effect design, not silent no-op. All 3000 cards remain targets, not completed content.

Implement in integration branch, test with Godot and Android before approval/merge. No changes to main/production without permission.
