# AFT – Internal Developer README (Flutter + Firebase)

This repo contains a multi-platform Flutter app for Army Fitness Test (AFT) scoring and proctoring utilities.
It is built for **internal/team**

**Tech:** Flutter (3.22+), Dart (3.5+), Riverpod (Notifier API), Firebase Auth, SharedPreferences.

---

## Table of Contents

- [1. What this app does](#1-what-this-app-does)
- [2. Quick start](#2-quick-start)
- [3. Running & configuration](#3-running--configuration)
- [4. Project structure](#4-project-structure)
- [5. Architecture overview](#5-architecture-overview)
- [6. State management (Riverpod)](#6-state-management-riverpod)
- [7. Data & persistence](#7-data--persistence)
- [8. Scoring logic](#8-scoring-logic)
- [9. Proctor module](#9-proctor-module)
- [10. UI & theming](#10-ui--theming)
- [11. Assets (SVG icons, ranks)](#11-assets-svg-icons-ranks)
- [12. Testing](#12-testing)
- [13. Troubleshooting](#13-troubleshooting)
- [14. Contributing / conventions](#14-contributing--conventions)

Additional docs:

- [Auth documentation](docs/auth.md)

---

## 1. What this app does

### Calculator

- Calculates AFT points for the five AFT events using embedded scoring tables.
- Supports **General** vs **Combat** standard (Combat forces male thresholds).
- Live score recomputation as inputs change.
- Save/restore sets.

### Proctor

- Contains tools that assist a proctor during execution (timers, calculators, and utilities).

### Account / Saves

- Anonymous sign-in supported.
- Guest data can be migrated into a real user bucket on first non-anonymous sign-in.

### Settings

- Defaults (profile prefill), navigation behavior, haptics.

---

## 2. Quick start

### Prerequisites

- Flutter SDK: **≥ 3.22.0**
- Dart SDK: **≥ 3.5.3**

### Install

```bash
flutter pub get
```

### Run

```bash
# iOS/Android (choose a device)
flutter run

# Web
flutter run -d chrome
```

### Test

```bash
flutter test
```

---

## 3. Running & configuration

### Firebase

Firebase is initialized via `lib/firebase_options.dart`.

Relevant dependencies:

- `firebase_core`
- `firebase_auth`

### Local emulation (optional)

If you want to use Firebase Auth emulator locally:

1. Start the emulator suite.
2. In the app startup (after Firebase init) call `FirebaseAuth.instance.useAuthEmulator(host, port)` in `kDebugMode`.

---

## 4. Project structure

High-signal directories:

```
lib/
  main.dart                  # bootstrap
  app.dart                   # top-level MaterialApp wiring
  router/                     # route table
  shell/                      # scaffold + navigation chrome
  features/
    aft/                      # scoring + state
    home/                     # calculator UI
    proctor/                  # proctor tools & timing
    auth/                     # AuthGate + sign-in
    saves/                    # saved sets UI + migration
  state/                      # global-ish settings/app state
  theme/                      # Army theme + colors
  widgets/                    # reusable UI components
assets/
  icons/                      # SVG icons
  icons/ranks/                # rank insignia SVGs
test/
  ...                         # unit + widget tests
```

---

## 5. Architecture overview

### Startup

`lib/main.dart` (high-level flow):

1. Flutter bindings
2. Firebase initialization
3. Preload scoring tables
4. `ProviderScope(...)`

### Routing

`lib/router/app_router.dart` defines app routes. The home entry typically flows through `AuthGate`.

### Shell / navigation

`lib/shell/aft_scaffold.dart` provides:

- bottom navigation
- top chrome (optionally)
- common layout conventions

---

## 6. State management (Riverpod)

Core provider entrypoint:

- `lib/features/aft/state/providers.dart`

Key state domains:

- **Profile**: `aftProfileProvider` (age, sex, standard, testDate)
- **Inputs**: `aftInputsProvider` (event inputs)
- **Computed**: `aftComputedProvider` (derived scores and total)

Settings:

- `lib/state/settings_state.dart`
- `lib/screens/settings_screen.dart`

---

## 7. Data & persistence

Repository layer:

- `lib/data/aft_repository.dart` (interface + codecs)
- `lib/data/aft_repository_local.dart` (SharedPreferences)
- `lib/data/repository_providers.dart`

### Saved model

`ScoreSet` (see repository/model files) captures:

- profile snapshot
- inputs snapshot
- computed per-event scores + total
- timestamps

### Guest migration

`lib/features/saves/guest_migration.dart`:

- guest bucket key: `scoreSets:guest`
- user bucket key: `scoreSets:{uid}`
- migrated flag: `guestMigrated:{uid}`

---

## 8. Scoring logic

Primary entry:

- `lib/features/aft/logic/scoring_service.dart`

Tables:

- `lib/features/aft/logic/data/*` (CSV/table sources)

Rules (high level):

- event score is derived from sex + age band
- Combat forces male thresholds
- total = sum of event scores (null treated as 0)

---

## 9. Proctor module

Location:

- `lib/features/proctor/`

This area includes the proctor screen and tools (timing, calculators, etc.).

---

## 10. UI & theming

Theme:

- `lib/theme/army_theme.dart`
- `lib/theme/army_colors.dart`

Shared widgets:

- `lib/widgets/` (chips, cards, steppers, score rings, etc.)

---

## 11. Assets (SVG icons, ranks)

### Rank insignias

Rank SVGs live in:

- `assets/icons/ranks/`

They are mapped in:

- `lib/features/aft/utils/rank_assets.dart`

Important notes:

- Many rank SVGs originate from Inkscape; `flutter_svg` may warn on Inkscape-only tags.
- To keep the UI consistent, rank SVGs should include a `viewBox`.
- `pubspec.yaml` must include both:
  - `assets/icons/`
  - `assets/icons/ranks/`

### Why some ranks looked “squished”

If an SVG lacks a `viewBox`, Flutter’s scaling can appear inconsistent across icons (especially when fitting into a fixed-size box). Normalizing the SVG root tag (add viewBox, remove Inkscape-only metadata) makes sizing consistent.

---

## 12. Testing

Run everything:

```bash
flutter test
```

There are both unit and widget tests under `test/`.

---

## 13. Troubleshooting

### “Unable to load asset …/assets/icons/ranks/…”

Make sure `pubspec.yaml` includes `assets/icons/ranks/` and run:

```bash
flutter pub get
```

Then do a full restart.

### flutter_svg warnings about `<metadata>` / `<sodipodi:namedview>`

These warnings come from Inkscape metadata. The icon may still render.
Solution: strip the Inkscape metadata blocks and ensure a proper `viewBox`.

---

## 14. Contributing / conventions

Guidelines:

- Prefer Riverpod Notifiers + immutable state objects.
- Keep scoring logic pure + testable.
- Treat persistence via the repository interface.
- Add/adjust tests when changing scoring, persistence, or major UI flows.

Where to add things:

- new calculator logic: `lib/features/aft/logic/`
- new proctor tools: `lib/features/proctor/`
- new screens/routes: `lib/screens/` + `lib/router/app_router.dart`
