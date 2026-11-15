# MYSTERY BOX — Unlock the Unknown

Arabic-style, old-historical mechanical puzzle game. Godot 4.7.2 stable, GDScript, Android portrait.

## Kaise chalayen
1. Godot 4.7.2 mein "Import" se `project.godot` kholen, images import hone dein, Play (F5) dabayen.
2. Phone par: docs/RELEASE.md ke mutabiq APK banayen.

## Folder
- `scripts/pcg` puzzle generators + validators (13 types), `scripts/puzzles` un ki screens
- `scripts/core` save, missions, content, awaaz; `scripts/net` online; `scripts/monetize` ads/shop/analytics
- `backend/` server (FastAPI + PostgreSQL), `tools/` audio aur server generation, `tests/` tests
- `docs/` TEST_REPORT, RELEASE, MONETIZATION, PLAY_STORE, PRIVACY_POLICY

## Tests
    godot --headless --path . -s tests/batch_test.gd          # 10,000 puzzles
    cd backend && python3 -m pytest -q tests                   # server

Halat aur baqi kaam: `BUILD_STATE.md`. Nayi chat mein yeh ZIP upload kar ke "Continue" likhein.
