# Gaming Hub integration changes

Base: official Poing Studios v5.1.0, Android template v4.5.1. Release ZIP SHA-256 values were checked before installation.

- The headless binary installer respects the Android/iOS enable settings, preventing an Android-only build from downloading disabled iOS binaries.
- The ads/core Android AARs and export scripts are explicitly tracked. Disabled mediation binaries and iOS binaries are excluded from the source inventory.
- Advertising and UMP implementations remain the upstream SDK. The game-specific consent/reward adapter lives in scripts/poing_admob_bridge.gd.
