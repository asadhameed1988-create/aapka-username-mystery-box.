# TEST REPORT — 2026-11-12 (generator version 4, 13 puzzle types)

Run inside Godot Engine v4.7.2.stable (custom WebAssembly build from npm package @ringozz/godot-web-wasm32 4.7.2-685,
Compatibility renderer, headless Chrome). This is NOT the official editor binary and NOT an Android device.
Scene used: tests/WebRunner.tscn (BATCH raised to 10000). Art was loaded through test-only imported textures.

```
MYSTERY BOX generator batch test
Total generated: 10000
Valid puzzles: 10000
Invalid puzzles: 0
Rejected and regenerated attempts: 3285
Duplicate configurations: 749
Serialization failures: 0
Non-deterministic seeds: 0
Generation time: 76747.6 ms total, 7.675 ms each
By type: {"cipher":769,"circuit":769,"colours":769,"combo":770,"gears":769,"latch":770,"lights":769,"maze":769,"mirrors":769,"pattern":769,"rings":770,"seq":769,"slider":769}
Difficulty distribution: {"1":2002,"2":2002,"3":2002,"4":2002,"5":1992}
Score min per difficulty: {"1":1.0,"2":1.0,"3":2.0,"4":3.0,"5":3.5}
Score max per difficulty: {"1":6.76890750230186,"2":7.5,"3":9.02471989593555,"4":11.0,"5":12.85}
Validation failures: {}
Missions: 1000 generated, 1000 valid
Mission failures: {}
RESULT: PASS
```

- 65 of 65 puzzle screens (13 types x 5 levels) opened from a JSON round-tripped spec and returned a hint.
- Main menu, 6 full endless rounds (hint, stage solved, lid open, rating update, save), daily mission,
  self-test scene, Urdu text: no script errors.
- Bugs found by running and fixed: const 'Slider' shadowed a native class; static func 'is_connected' clashed with
  Object.is_connected; mirror generator often had no crystal (rebuilt to lay the beam path first);
  cipher clue labels wrapped one letter per line; beam tail pointed the wrong way after the last mirror.
- Not tested: touch input on a real phone, Android export, Mobile renderer, editor import of the images,
  performance on device.

## Phase 5 run (same engine build)
- 3,000-puzzle batch: 3,000 valid, 0 invalid. 65/65 puzzle screens. 6 endless rounds.
- Chapter flow: 8 boxes of chapter 1 played; chapter 2 unlocked, chapter 3 still locked; 8 medallions; achievements awarded.
- All 50 chapter missions (5 chapters x 10 boxes) generate valid.
- Chapters screen and the three Pages (achievements, journal, inventory) open in English and Urdu without script errors.
- Urdu text was unreadable boxes before the font was bundled; with NotoNaskhArabic-Regular.ttf it renders.

## Phase 6 (backend and online play)
- backend: 9 automated tests pass on SQLite and on PostgreSQL 16; migrations/001_init.sql applies on PostgreSQL 16.
- End to end, the game (same engine build) against a real local API server: guest login; server daily mission
  validated on the client, played through the game screen, accepted and ranked 1st; display name change; invalid name
  refused (422); 5 weekly missions; progress sync; remote config; registration; wrong password refused; login on a
  wiped save restored the progress; a result made while the server was unreachable stayed in the saved queue and was
  delivered after reconnect; offline daily falls back to the local box; account deletion.
- The e2e server serves missions exported from the engine (no Godot binary on the server side in this test).
- Not tested: official Godot headless on a server, Docker build, HTTPS, Android networking, real load.

## Phase 7 (audio and polish)
- 7 of 7 sound effects load in the engine and every play call runs without errors; regression run PASS
  (3,000 puzzles, 65 screens, chapters, pages, settings in both languages, LOW graphics).
- Navigation driven by real mouse clicks in the browser: menu -> Chapters -> chapter 1 -> Box 1 (game) -> Back -> menu,
  with fade transitions, no errors.
- Music: the test engine build lacks the Ogg Vorbis module, so playback was not exercised there. The .ogg decodes
  correctly with ffmpeg. Audio was checked only by measurement (length, level, frequency balance), not by ear.

## Phase 8 (monetization and analytics)
- With the stand-in ad provider in the engine: rewarded ad gave 3 hints; of five interstitial requests exactly one
  was shown (blocked by: too few boxes, shown too recently, ads removed, no ad loaded) and all five continued the game;
  rewarded daily cap stopped at 5; a purchase reported twice granted 20 hints once; a pending purchase granted nothing;
  remove_ads recorded.
- The real AdMob and Play Billing providers load and stay inert when their Android plugins are absent.
- backend: 10 tests pass (includes usage events and the admin analytics page). Regression: 3,000 puzzles PASS,
  65 screens, chapters, pages, settings.
- Not tested: real ads, the consent form, real purchases, anything on Android.

## Phase 9 final QA (2026-11-13, same engine build)

```
MYSTERY BOX generator batch test
Total generated: 10000
Valid puzzles: 10000
Invalid puzzles: 0
Rejected and regenerated attempts: 3285
Duplicate configurations: 749
Serialization failures: 0
Non-deterministic seeds: 0
Generation time: 72225.8 ms total, 7.223 ms each
By type: {"cipher":769,"circuit":769,"colours":769,"combo":770,"gears":769,"latch":770,"lights":769,"maze":769,"mirrors":769,"pattern":769,"rings":770,"seq":769,"slider":769}
Difficulty distribution: {"1":2002,"2":2002,"3":2002,"4":2002,"5":1992}
Score min per difficulty: {"1":1.0,"2":1.0,"3":2.0,"4":3.0,"5":3.5}
Score max per difficulty: {"1":6.76890750230186,"2":7.5,"3":9.02471989593555,"4":11.0,"5":12.85}
Validation failures: {}
Missions: 1000 generated, 1000 valid
Mission failures: {}
RESULT: PASS
```

- Tamper test: 2,249 deliberately corrupted puzzles (every parameter replaced by null, wrong types, wrong sizes).
  Before the Schema guard the engine stopped responding on such data; now none breaks it and all are rejected,
  except one case where the "corrupt" value is the same as the original (a maze with no key).
- 65 of 65 puzzle screens, 6 endless rounds, chapters, all pages, settings, ads rules, store rules: no script errors.
- Game <-> server end to end repeated after the changes: all steps pass, including anonymous events delivery.
- backend: 10 tests pass.

### What the spec asked to test, and where it stands
| Area | Status |
| --- | --- |
| Puzzle generation, solvability, difficulty, duplicates | Executed: 10,000 batch |
| Mission serialization | Executed: JSON round trip for every puzzle and mission |
| Invalid configurations | Executed: tamper test |
| Save / load | Executed in flows (continue, wiped-save restore); old saves upgraded on load |
| Online synchronization, API validation | Executed: backend tests + end to end |
| Performance regressions | Measured only in the test build: about 7 ms per generated puzzle |
| Android compatibility, device performance, touch | NOT executed: needs the owner's phone |
