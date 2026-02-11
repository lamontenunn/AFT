# AFT – Internal Developer README (Flutter + Firebase)

This repo contains a multi-platform Flutter app for Army Fitness Test (AFT) scoring and proctoring utilities.
It is built for **internal/team**

**Tech:** Flutter (3.22+), Dart (3.5+), flutter_riverpod 3.x (Notifier + legacy StateNotifier),
Firebase Auth + Firestore, App Links, Sign in with Apple, Google Sign-In, SharedPreferences,
Syncfusion PDF.

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

### Standards

- Displays event thresholds for a selected age band + sex.
- Combat toggle forces male thresholds for standards view.

### Account / Saves

- Email/password, Google, and Apple sign-in (Apple available on iOS/macOS).
- Anonymous sign-in supported.
- OAuth sign-in attempts to link anonymous users to preserve uid when possible.
- Guest data can be migrated into a real user bucket on first non-anonymous sign-in.
- Signed-out users cannot access saved tests; guests stay local-only; signed-in users sync via Firestore.
- Saved tests can be exported to DA Form 705 (page 1) using profile defaults when available.
  Export uses Syncfusion PDF + Share Plus.

### Settings

- Defaults (profile prefill), theme, haptics, combat info toggle.
- In-app support (feature requests, bug reports) and an in-app privacy policy.

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
- `cloud_firestore`
- `app_links`
- `sign_in_with_apple`
- `google_sign_in`

Auth provider configuration:

- Apple sign-in requires the App ID capability + Service ID key configured in Firebase Auth,
  and `ios/Runner/Runner.entitlements` includes the `com.apple.developer.applesignin` entitlement.
- Google sign-in uses the iOS reversed client ID in `ios/Runner/Info.plist`.
- Password reset links are handled by `app_links` and the `/__/auth/` routes.

Hosting (app links / domain association):

- `.well-known` files live under `public/.well-known/` and are deployed via Firebase Hosting.
- Currently used: `apple-app-site-association`, `assetlinks.json`.
- Optional: `apple-developer-domain-association.txt` (if a checker expects it).

### Local emulation (optional)

If you want to use Firebase Auth emulator locally:

1. Start the emulator suite.
2. In the app startup (after Firebase init) call `FirebaseAuth.instance.useAuthEmulator(host, port)` in `kDebugMode`.

### App Check

App Check is currently disabled in the app. If you enable App Check enforcement in the
console, Firestore reads/writes from the app will fail with permission-denied. Keep
App Check in Monitor/Off until it is re-enabled in code.

### Android release signing

Release builds are intentionally blocked unless a real signing key is configured.

1. Copy `android/key.properties.example` to `android/key.properties`.
2. Set these values:
   - `storeFile` path to your `.jks` upload key file
   - `storePassword`, `keyAlias`, `keyPassword`
3. Build: `flutter build appbundle --release` (Play Store) or `flutter build apk --release`.

`android/key.properties`, keystores, and `*.jks` are ignored by git.

### Release verification checklist

- `flutter analyze --no-fatal-infos`
- `flutter test`
- `flutter build apk --release` (or `flutter build appbundle --release`)
- Verify App Links/Universal Links after signing:
  - `public/.well-known/assetlinks.json` must contain the release signing cert fingerprint
  - `public/.well-known/apple-app-site-association` must match Team ID + bundle ID

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
    standards/                # standards table helpers
  screens/                    # top-level screens (settings, standards, etc.)
  state/                      # global-ish settings/app state
  theme/                      # Army theme + colors
  widgets/                    # reusable UI components
assets/
  icons/                      # SVG icons
  icons/ranks/                # rank insignia SVGs
  forms/                      # DA 705 template assets
  onboarding/                 # login showcase assets
public/
  .well-known/                # app link / domain association files (hosting)
test/
  ...                         # unit + widget tests
```

---

## 5. Architecture overview

### Startup

`lib/main.dart` (high-level flow):

1. Flutter bindings
2. Lock orientation to portrait
3. Firebase initialization
4. Preload scoring tables
5. `ProviderScope(...)`
6. App links are handled in `lib/app.dart` for password reset routing

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
- `settingsProvider` uses legacy `StateNotifierProvider` (riverpod 3.x legacy API)

---

## 7. Data & persistence

Repository layer:

- `lib/data/aft_repository.dart` (interface + codecs)
- `lib/data/aft_repository_local.dart` (SharedPreferences)
- `lib/data/aft_repository_firestore.dart` (Firestore sync)
- `lib/data/repository_providers.dart`

Signed-in users sync saved sets across devices via Firestore.
Guests store locally (SharedPreferences), and signed-out users do not store saved sets.
Default profile settings sync to `users/{uid}` under `defaultProfile`.
Support messages are stored in `feedback` and client diagnostics in `clientEvents`.
Firestore rules (see `firestore.rules`) enforce schema validation and prevent
`createdAt` changes after creation.

### Saved model

`ScoreSet` (see repository/model files) captures:

- profile snapshot
- inputs snapshot
- computed per-event scores + total
- timestamps

### Guest migration

`lib/features/saves/guest_migration.dart`:

- guest bucket key (legacy signed-out): `scoreSets:guest`
- anonymous guest bucket: `scoreSets:guest:{anonUid}`
- legacy local user bucket: `scoreSets:{uid}`
- tracking keys: `scoreSets:lastAnonUid`, `scoreSets:guestOwnerUid`
- user data path: `users/{uid}/scoreSets`
- guest data is copied into Firestore when present
- profile settings path: `users/{uid}` → `defaultProfile`
- guest data is tied to the first signed-in account on that device

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
Includes plate math, height/weight, and body fat utilities.

---

## 10. UI & theming

Theme:

- `lib/theme/army_theme.dart`
- `lib/theme/army_colors.dart`

Shared widgets:

- `lib/widgets/` (chips, cards, steppers, score rings, etc.)

---

## 11. Assets (SVG icons, ranks)

Other assets:

- `assets/forms/` (DA 705 template)
- `assets/onboarding/` (login showcase images)

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

### Integration tests

```bash
# Run on a simulator/emulator or device
flutter test integration_test

# Run on a specific device
flutter test integration_test/app_smoke_test.dart -d <deviceId>

# Optional: use flutter drive (legacy runner)
flutter drive --driver test_driver/integration_test.dart --target integration_test/app_smoke_test.dart -d <deviceId>
```

Note: The smoke test only asserts the app boots into either Sign in or Home,
so it should pass regardless of current auth state.

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
