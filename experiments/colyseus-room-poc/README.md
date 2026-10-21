# Colyseus room experiment — isolated POC

Status: experimental; NOT deployed or integrated into Gaming Hub.

## Scope and guardrails
- Branch: `experiment/colyseus-room-poc`; never modify `main` or production services.
- No paid hosting, GitHub Actions workflow, automatic deploy, or changes to current room/voice services.
- Keep current game, user progress, daily generation and all existing game modes unchanged.
- Reference: https://github.com/colyseus/realtime-tanks-demo (MIT license; preserve notices if copying code).
- Colyseus is for room membership, matchmaking and state synchronization, **not** a voice solution.

## Evaluation steps
1. Clone the upstream demo separately and pin an audited commit, inspect dependencies and MIT notices.
2. Run the upstream server locally in a sandbox; do not expose it publicly.
3. Test two simulated clients: create private room, join by code, leave, reconnect, room capacity and unauthorized joins.
4. Compare results to Gaming Hub's current server, especially recovery after a dropped connection and timeout behavior.
5. Run soak tests and record CPU/memory, latency and disconnect rates.
6. Only after passing tests, propose an opt-in client adapter on this branch, with feature flag default OFF.
7. Validate two physical Android phones separately for gameplay and voice. Never infer voice success from Colyseus tests.

## Acceptance criteria
- Existing Gaming Hub production server remains untouched.
- Room code and matchmaking function in local test with two clients.
- Reconnection behavior documented with failure cases.
- No GitHub Actions minutes or paid infrastructure used for this experiment.
- No merge or deploy until explicit approval.

## Current state
Planning scaffold only; no running Colyseus server, client integration, APK, or test pass is claimed.
