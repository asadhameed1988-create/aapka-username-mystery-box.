# BUILD_STATE — MYSTERY BOX (updated 2026-11-12)

Engine: Godot 4.7.2 stable (verified 2026-11-12; 4.8 is still beta, do not use).
Theme: Arabic style, old historical. Abstract geometric symbols only; no religious text or calligraphy on game objects.

## DONE (code written, run-tested, see VERIFIED)
- Project config: portrait, Mobile renderer, autoloads GameState / Loc / Missions.
- PCG core (scripts/pcg): Rng, RingsGenerator (BFS), ComboGenerator (constraint enumeration),
  LatchGenerator (topological sort), MissionGenerator (multi-stage + visual variation + diversity),
  BatchTester.
- Playable slice: MainMenu, Game (procedural 3D box that turns, lid opens), RingsView, ComboView,
  LatchView, hints, local save/continue, adaptive difficulty, endless rounds, local daily seed.
- English + Urdu strings (Loc.gd).
- tests/batch_test.gd (headless 10,000 run) and in-game Generator Test screen.

- Phase 4 part 1 (added 2026-11-12, generator version 2): SeqGenerator (number sequence, ambiguity check),
  PatternGenerator (symbol pattern, smallest-period check), LightsGenerator (hidden lantern switches, BFS),
  ChoiceView, LightsView. 6 of 15 puzzle types now exist.

- Phase 4 part 2 (2026-11-12, generator version 3): GridTree (shared grid helpers), MazeGenerator (backtracking
  maze + key, BFS + route replay), CircuitGenerator (rotate tiles, connectivity check), SliderGenerator
  (sliding plates, BFS), MazeView, CircuitView, SliderView. 9 of 15 puzzle types now exist.
  Remaining 6: gears, colour sequence, symbol decoding, light reflection, multi-stage rules, interconnected mechanisms.
- Phase 4 part 3 (2026-11-12, generator version 4): GearGenerator (gear alignment, BFS), ColourGenerator
  (colour code deduction, full enumeration), CipherGenerator (symbol decoding), MirrorGenerator (light reflection,
  all mirror combinations), SymbolIcon, GearView, ColourView, CipherView, MirrorView. 13 puzzle types exist.
  The three list items without their own generator are covered like this: multi-stage lock systems = a mission
  is 1-3 locks; key-and-compartment = key inside the maze; interconnected mechanisms = linked rings, gear cranks,
  lantern switches. Dedicated versions can be added later.
- Phase 5 (2026-11-12): Content.gd (5 chapters x 10 seeded boxes, 16 achievements, 10 journal notes EN/UR),
  MissionService rewritten (chapters, unlock at 7/10, statistics, achievements, hint tokens, daily streak),
  Chapters.tscn, Pages.tscn (achievements + statistics, journal, inventory), hint tokens in Game (start 5, +1 per
  box, +2 daily, max 20), result panel shows earned tokens and new achievements, old saves are upgraded on load.
  Urdu font bundled: assets/fonts/NotoNaskhArabic-Regular.ttf (SIL OFL 1.1, licence file beside it).
- Phase 6a (2026-11-12): backend/ (FastAPI + SQLAlchemy; PostgreSQL in production): guest/registered accounts,
  daily/weekly/pool missions, completion records with plausibility checks, leaderboards with privacy opt-out,
  progress sync (more boxes wins), remote config, account delete, admin dashboard (/admin), generation worker with
  per-run cap, Dockerfile, docker-compose, migrations/001_init.sql, DEPLOY.md.
  Godot side: scripts/pcg/ServerExport.gd + tools/server_generate.gd (server runs the game's own generator headless).
  backend/.gdignore keeps Godot from scanning the folder.
- Phase 6b (2026-11-12): scripts/net/Online.gd (autoload "Online"): guest login, server daily + weekly missions
  (cached, re-validated on the phone, rejected if from a newer generator), saved result queue with retry,
  leaderboard, progress sync, remote config, register/login, account delete. Pages: leaderboard, weekly, profile
  (privacy note, online on/off, name, leaderboard visibility, register/login, delete). Menu: Weekly, Leaderboards,
  Profile and Privacy. Online stays OFF until DEFAULT_SERVER_URL in Online.gd is set to the deployed HTTPS address.
- Phase 7 (2026-11-12): scripts/core/Fx.gd (autoload "Fx"): 7 sound effects, background music, fade transitions
  (Fx.go / Fx.reload replace direct scene changes). tools/make_audio.py generates all audio from code (original):
  effects as WAV, music as assets/audio/music_loop.ogg (53 s seamless loop, maqam Hijaz: strings, daf, oud, ney).
  Button press animation + tap sound (UiKit.button), sounds in all 13 puzzle screens, box idle sway and gold sparks
  on opening, result panel fade-in. Settings page (sound, music, graphics HIGH/LOW, language) replaces the
  Language button. LOW graphics turns off MSAA and sparks.
- Phase 8 (2026-11-13): scripts/monetize/: Ads.gd (rules: when ads may appear), Store.gd (products, grants),
  Analytics.gd (anonymous events + performance sample), TestAdProvider.gd, AdmobProvider.gd and PlayBillingProvider.gd
  (real providers, loaded by name so they are inert without the Android plugins). Shop lives on the Inventory page;
  rewarded button also on the result screen. Backend: /v1/events + /admin/analytics. Guide: docs/MONETIZATION.md.
  Plugins to install on the owner's machine: godot-sdk-integrations/godot-admob v7.0, godot-google-play-billing 3.x.
- Phase 9 (2026-11-13): scripts/pcg/Schema.gd (shape guard for mission data from disk/network; used by
  MissionGenerator.validate_mission, which also checks the stored solution record), safer clue access in
  Combo/Cipher/Colour generators, rule/args check in SeqGenerator, BatchTester.tamper_test().
  Generator Test menu button now only in debug builds.
- Phase 10 (2026-11-13): export_presets.cfg (APK test + AAB, package com.freegamesstation.mysterybox, min SDK 23,
  INTERNET permission, no keystore data), launcher/adaptive/Play icons in assets/icon, docs/RELEASE.md,
  docs/PLAY_STORE.md, docs/PRIVACY_POLICY.md (draft template), README rewritten.
- Asset batch 1 integrated (2026-11-12): logo + menu background (MainMenu), chapter background behind a
  transparent 3D viewport (Game), symbol sprite sheet (SymbolPainter, re-packed to 1024x512 = 4x2 cells of 256),
  brass 9-slice buttons (UiKit, panel resized to 256), wood/brass triplanar textures on the 3D box (Box3D),
  app icon + boot splash (project.godot). Every use falls back to the old placeholder if the file is missing.
- Stored but not used yet: assets/ui/ring_plate.png (rings are still drawn with code).

## VERIFIED (2026-11-12, see docs/TEST_REPORT.md)
- Project boots and runs in Godot 4.7.2 (custom WebAssembly build, Compatibility renderer, headless Chrome).
- 10,000-puzzle batch test executed (13 types): 10,000 valid, 0 invalid, 749 duplicates, 1,000/1,000 missions valid. PASS.
- Phase 5 run: 3,000-puzzle batch PASS, 8 chapter boxes played (chapter 2 unlocks), all 50 chapter missions valid,
  Chapters and Pages screens open in English and Urdu, Urdu text renders with the bundled font.
- All 13 puzzle screens at all 5 levels, menu, full endless flow, daily, self-test scene: no script errors.
- Naming rules learned: never name a const after a native class (Slider) or a static func after an
  Object method (is_connected).

- Backend: 9 automated tests pass on SQLite and on PostgreSQL 16; schema file applies on PostgreSQL 16;
  live uvicorn smoke test. Test missions were exported from the real engine.

- Game <-> server end to end (engine build in headless Chrome against backend/tests/e2e_server.py):
  guest login, server daily played through the real game screen and ranked 1st, rename, bad name refused,
  5 weekly boxes, progress sync, remote config, register, wrong password refused, login on a wiped save restores
  progress, result kept in the queue while the server is unreachable and delivered after reconnect, local daily
  used when offline, account delete. Offline regression run still passes.

- Phase 7 run: all 7 sound effects load and play calls run without errors; settings page (EN/UR) and LOW
  graphics game open; full regression PASS. Real mouse clicks through menu -> chapters -> boxes -> game -> back
  work with the fade transitions.

- Phase 8 run: ad rules with the stand-in provider (free boxes, every-N, 2-minute gap, remove-ads, no ad loaded),
  rewarded reward + daily cap of 5, purchases granted exactly once, pending payment not granted, real providers
  inert without their plugins; backend 10 tests pass; full regression PASS.

- Phase 9 run: 10,000 puzzles (13 types) valid, 0 invalid, 749 duplicates, 1,000/1,000 missions; tamper test:
  2,249 corrupted puzzles, none broke the engine, all rejected except one that equals the original value;
  game <-> server end to end again; backend 10 tests.

## NOT VERIFIED YET
- export_presets.cfg has never been opened by the Godot editor; no APK or AAB has been built.
  build_apk_windows.bat and .github/workflows/build-apk.yml (quick test APK, non-Gradle preset) have never been run.
  The build sandbox cannot reach Maven, the Android SDK or Godot release downloads, so no APK can be built there.
- AdmobProvider.gd and PlayBillingProvider.gd against the real plugins on Android (names were read from the plugin
  sources, never executed). AdMob consent form flow. Real purchases.
- Music playback inside the engine (the test build has no Ogg Vorbis module; the file itself decodes correctly
  with ffmpeg). Nobody has LISTENED to any of the audio yet: the owner must judge how it sounds.
- Backend: Docker build, official Godot headless running tools/server_generate.gd, HTTPS, real load.
- Official Godot editor import of the images, Mobile renderer, Android export, real touch input, device performance.
- boot_splash setting names should be checked in Project Settings.
- Brass texture is not perfectly seamless top-to-bottom; a faint seam may show on the box.

## PLACEHOLDERS (clearly temporary)
- icon.svg, all colours/styles in UiKit.gd, symbols in SymbolPainter.gd, flat box materials in Box3D.gd.
- Puzzle progress inside a lock is not saved (resume restarts the current lock).

## PLANNED
- Phase 6 leftovers: email password reset (needs an email service), full replay verification of leaderboard results.
- Android export must enable the INTERNET permission; the server address must be HTTPS.
- Phase 7 leftovers: chapter backgrounds 2-5 (asset batch 2 prompts are in the plan doc), ring plate art in the rings puzzle.
- Phase 8 leftovers: run the real AdMob/Billing providers on a phone; premium packs; server receipt verification.
- Owner side of Phase 9/10: device QA, build APK/AAB, signing, Play Console (see docs/RELEASE.md checklist).
- Optional: dedicated puzzles for key-and-compartment and interconnected mechanisms.

## BLOCKED / NEEDS OWNER
- Open the project in the official Godot 4.7.2 editor, build the test APK, play on a phone (docs/RELEASE.md).
- Listen to the audio; generate asset batch 2; AdMob + Play Console setup; deploy the server.

## Asset batch 1 (filenames expected in res://assets/)
MB-001 logo/logo_mystery_box.png 2048x1024 transparent
MB-002 icon/app_icon_1024.png 1024x1024
MB-003 splash/splash_portrait.png 1080x1920
MB-004 bg/bg_main_menu.png 1080x1920
MB-005 bg/bg_house_of_wisdom.png 1080x1920
MB-006 tex/tex_walnut_inlay.png 1024x1024 tileable
MB-007 tex/tex_brass_engraved.png 1024x1024 tileable
MB-008 ui/ring_plate.png 1024x1024 transparent
MB-009 ui/symbols_sheet.png 2048x1024 (4x2 grid) transparent
MB-010 ui/panel_brass_9slice.png 512x512 transparent

## Update 2026-11-15 – Easy question boxes (owner feedback: puzzles too hard)
- New default lock mode "quiz": every box = 1 Islamic question (Hanafi fiqh), 1 easy sum, 1 general-knowledge question.
- Files: scripts/pcg/QuestionBank.gd (72 Islamic + 58 GK), QuizGenerator.gd, MathGenerator.gd, scripts/puzzles/QuizView.gd.
- Mechanical puzzles still available: Settings -> "Locks: Mechanical puzzles (hard)".
- Generator VERSION 5; save version 2 (old unfinished box is dropped once).
- Recent questions are not repeated (last 60 remembered).
- Sources: docs/QUESTION_SOURCES.md. Scholar review of Islamic questions: NOT done yet (required before release).
- Tested in the browser Godot 4.7.2 build: 3,000-puzzle batch PASS (15 types), 300/300 missions, 500/500 quiz missions,
  130/130 bank questions OK, 75/75 screens, 4 full games, screenshots EN + UR checked.
- APK: still not built (no GitHub account linked to the chat; Android tools cannot be downloaded in the sandbox).

## Update 2026-11-15 (2) – Sections, no repeats, prizes (owner feedback)
- Main menu: three sections (Islamic knowledge / General knowledge / Maths), each with endless
  chapters of 10 boxes, 3 questions per box. Old story chapters, endless mode, journal and
  inventory are no longer in the menu (code kept). Mechanical-puzzle toggle removed.
- Questions: Islamic 722,169 and GK 2,360,512 different questions, maths unlimited (5 levels,
  equations from level 2). QuestionDeck guarantees no repeats. See docs/QUESTION_SOURCES.md.
- Prizes ("Inaamat"): one every 5 boxes, 31 in total (24 seals in bronze/silver/gold from the
  owner's symbol sheet + 7 of the owner's pictures). Hints and store moved to Settings.
- Generator VERSION 6, save version 3 (unfinished older box dropped once).
- Tested in browser Godot 4.7.2: 3,000-puzzle batch PASS; ~4,000 questions checked (0 problems);
  facts check (Al-Baqarah 286, Ya-Sin para 22, An-Nas 114, Shawwal after Ramadan, Islamabad);
  1,500 questions per section from the deck with 0 repeats (also across save/load);
  3,000 maths questions (0 problems); 300/300 section boxes; 17 boxes played through the game
  screen (Islamic reached chapter 2); prizes 3 at 17 boxes; pages EN + UR.
- Islamic questions still need review by a qualified Hanafi scholar before release.

## Update 2026-11-16 – Release pipeline
- New workflow .github/workflows/build-release.yml: Gradle build with the AdMob plugin (fetched from
  godot-sdk-integrations/godot-admob releases), test APK with Google TEST ads, and the Play AAB signed
  with an upload key (needs repository secret UPLOAD_KEY_PASSWORD, 16+ chars; key created once,
  stored encrypted in signing/upload.p12.enc). Version code = 100 + run number.
- Release builds show no ads until real AdMob ids are set in AdmobProvider.gd.
- docs/PRIVACY_POLICY.md (final English; CONTACT_EMAIL still to fill), docs/STORE_LISTING.md,
  render.yaml + docs/SERVER_SETUP.md (Render + Neon), DATABASE_URL accepts postgres:// URLs.

## Update 2026-11-16 (2) – Box look, coins, references, hints (owner feedback)
- Box3D rebuilt: plinth, bands, framed panels, brass corner brackets, pearl star inlays, lock plate
  with keyhole, two-tier lid with brass ring + owner's symbol, velvet lining with coins, display
  table, rim light, shadows, filmic tonemap + glow. Opening: lid, inner glow, sparks and a coin
  shower (gold for a clean box, silver otherwise) with a coin sound (tools/make_audio.py coins).
- Coins counted (gold/silver) on the menu and in Settings.
- Hints: 3 per box, never saved up; one extra per box from a rewarded ad. Hint pack removed.
- Islamic questions show a reference after the right answer (Arabic line: surah + ayah numbers or the
  book; plus English/Urdu) and the box result lists every question, answer and reference.
  No Quran verse text is shown (references only). scripts/pcg/References.gd.

## Update 2026-11-16 (3) – Four schools, choose-all, hadith text, question language
- FiqhData.gd (126 four-school questions, 9 choose-all, 21 hadith questions), HadithData.gd
  (29 Bukhari hadiths, Arabic + English), References.combine (Quran + books + hadith text).
- QuizView: Urdu / English / Arabic question switch (settings.qlang), choose-all mode with Check,
  hint greys out a wrong option, hadith text in a scrollable reference panel.
- All bank questions and templates have Arabic text; CountryData has Arabic country names.
- Tests (browser Godot 4.7.2): every question template checked in EN/UR/AR (0 problems),
  126/126 fiqh, 9/9 choose-all, 21/21 hadith with text, decks 0 repeats, gameplay OK.
- docs/SCHOLAR_REVIEW.md for the owner's scholars. Not reviewed yet.
