# AFT (Army Fitness Test) – Flutter + Firebase

A multi-platform Flutter app that calculates Army Fitness Test (AFT) scores using official age/sex tables, live total computation, and a branded dark theme.  
Built with Flutter 3.22+, Dart 3.5+, Riverpod (Notifier API), and Firebase for authentication and initialization.

This README provides a deep technical overview for developers and agents to quickly understand, navigate, and extend any part of the codebase.

---

## Overview

- Platforms: iOS, Android, Web, macOS, Windows, Linux
- Frameworks: Flutter 3.22+, Dart 3.5+, Riverpod (Notifier API)
- Data: Embedded CSV scoring tables, local JSON persistence (repository pattern)
- Firebase: Initialized via `firebase_options.dart` with real authentication (FirebaseAuth)
- Architecture: Modular feature-based structure with Riverpod state management and repository abstraction

---

## Quick Start

Prerequisites
- Flutter SDK ≥ 3.22.0
- Dart SDK ≥ 3.5.3
- Firebase project configured (see `firebase_options.dart`)

Install
```bash
flutter pub get
```

Run
```bash
# Mobile
flutter run

# Web
flutter run -d chrome
```

Test
```bash
flutter test
```

---

## Features

- Real scoring for all AFT events (age/sex banded):
  - 3RM Deadlift (MDL)
  - Hand-Release Push-ups (HRP)
  - Sprint-Drag-Carry (SDC)
  - Plank (PLK)
  - 2-Mile Run (2MR)
- Combat override (uses male thresholds regardless of selected sex)
- Live total updates as inputs change (partial totals allowed)
- Save result sets locally and per authenticated user
- Guest-to-user migration on sign-in
- Riverpod state management with modular routing
- Material 3 dark theme with Army branding and custom widgets
- Multi-platform support with responsive layouts and bottom navigation

---

## Architecture

High-level flow:
- main.dart → Firebase initialization + CSV preload → ProviderScope(App)
- App → MaterialApp(theme, onGenerateRoute) → AppRouter (zero-duration transitions)
- Routes.home → AuthGate → SignInPage or AftScaffold(FeatureHomeScreen)
- AftScaffold manages bottom navigation, segmented “General/Combat” control, and a profile sheet
- Feature modules (aft, home, saves, auth, screens) compose UI and logic

### App Initialization (`lib/main.dart`)
- Ensures Flutter bindings
- Initializes Firebase via `DefaultFirebaseOptions.currentPlatform`
- Preloads all scoring CSVs (MDL, HRP, SDC, PLK, 2MR)
- Boots Riverpod via `ProviderScope`

Note: Auth Emulator is disabled in code comments; re-enable locally by restoring `useAuthEmulator` in debug builds if desired.

### Routing (`lib/router/app_router.dart`)
- `/` → `AuthGate` (entry point; zero-duration transition to avoid double-render)
- `/standards` → `AftScaffold(showHeader: false, StandardsScreen())`
- `/saved-sets` → `AftScaffold(showHeader: false, SavedSetsScreen())`
- `/settings` → `AftScaffold(showHeader: false, SettingsScreen())`
- `/sign-in` → `SignInPage`

### Shell & Navigation (`lib/shell/aft_scaffold.dart`)
- Bottom Navigation (Calculator, Saved Sets, Standards, Settings)
- Optional SliverAppBar header with:
  - Title: “AFT Calculator”
  - Profile button → sign in/out sheet and account actions
  - Domain SegmentedButton: General | Combat (writes to `aftProfileProvider`)
- Honors Settings for nav label behavior and haptics

---

## Authentication

Files
- `features/auth/auth_gate.dart` – entry gate that decides first screen:
  - Loading → CircularProgressIndicator
  - Signed out → `SignInPage`
  - Signed in → `AftScaffold(showHeader: true, FeatureHomeScreen)`
  - On non-anonymous sign-in, triggers one-time guest migration
- `features/auth/providers.dart`
  - `firebaseAuthProvider`: lazily exposes `FirebaseAuth` (null if Firebase not initialized)
  - `firebaseUserProvider`: stream of `User?` via `authStateChanges()`
  - `authStateProvider`: maps Firebase user to simple `AuthState` (signedIn/signedOut)
  - `effectiveUserIdProvider`: returns `'guest'` for null/anonymous users, else `uid`
  - `authActionsProvider`: exposes `signInAnonymously()` and `signOut()`
- `features/auth/auth_state.dart`: model for UI-friendly auth state
- `features/auth/sign_in_page.dart`: sign-in UI (anonymous supported)

Behavior
- Anonymous sign-in is supported out of the box
- Guest data migrates to the authenticated user’s bucket upon first non-anonymous sign-in

---

## Data & Persistence

Repository Abstraction
- `lib/data/aft_repository.dart`: repository interface, JSON codecs for `ScoreSet`
- `lib/data/aft_repository_local.dart`: local persistence via `shared_preferences`
- `lib/data/repository_providers.dart`: binds `aftRepositoryProvider` to `LocalAftRepository`

Data Model (selected)
- `ScoreSet` captures:
  - Profile snapshot (age, sex, standard, test date)
  - Inputs snapshot (MDL lbs, push-ups reps, `Duration` times)
  - Computed scores per event and total
  - `createdAt` timestamp
- All saved data is serialized to JSON

Guest Migration
- `features/saves/guest_migration.dart`
  - Keys
    - Guest bucket: `scoreSets:guest`
    - User bucket: `scoreSets:{uid}`
    - One-time flag: `guestMigrated:{uid}`
  - Process
    - If guest bucket has data and not yet migrated for `uid`, merge into user bucket (most recent first), clear guest bucket, and set flag

Repository Operations (typical)
- `getScoreSets(userId)`
- `saveScoreSet(userId, ScoreSet)`
- `clearScoreSets(userId)`
- Enc/dec helpers: `encodeScoreSets`, `decodeScoreSets`

---

## State Management (Riverpod)

Core Providers (`lib/features/aft/state/providers.dart`)
- Profile
  - `ProfileNotifier` → `aftProfileProvider`
  - State: `AftProfile` (age, sex, testDate, standard)
  - Methods: `setAge`, `setSex`, `setStandard`, `setTestDate`
- Inputs
  - `InputsNotifier` → `aftInputsProvider`
  - State: `AftInputs` (mdlLbs, pushUps, sdc, plank, run2mi)
  - Methods: `setMdlLbs`, `setPushUps`, `setSdc`, `setPlank`, `setRun2mi`, `clearAll`
- Computed
  - `aftComputedProvider`: derives per-event scores and `total` from `ScoringService`
  - Reactive to `aftProfileProvider` + `aftInputsProvider` changes

Settings State (`lib/state/settings_state.dart`, `lib/screens/settings_screen.dart`)
- State fields (inferred from UI):
  - `hapticsEnabled`: bool
  - `defaultBirthdate`: DateTime?
  - `defaultSex`: `AftSex?`
  - `applyDefaultsOnCalculator`: bool
  - `navBehavior`: enum with values `onlySelected` | `always`
- Behaviors:
  - Controls NavigationBar label behavior
  - Enables haptics on tab change
  - Allows setting defaults that can prefill the Calculator profile
  - Provides “Clear all saved sets” for the current effective user

---

## Scoring Logic

Files
- `lib/features/aft/logic/scoring_service.dart`
- CSV-backed tables under `lib/features/aft/logic/data/`:
  - `mdl_csv.dart`, `mdl_table.dart`
  - `hrp_csv.dart`, `hrp_table.dart`
  - `sdc_csv.dart`, `sdc_table.dart`
  - `plk_csv.dart`, `plk_table.dart`
  - `run2mi_csv.dart`, `run2mi_table.dart`
- Time/format helpers: `features/aft/utils/formatters.dart`
- Slider/display config: `features/aft/logic/slider_config.dart`

Rules
- Each event delegates to a sex-aware function:
  - MDL: `mdlPointsForSex`
  - HRP: `hrpPointsForSex`
  - SDC: `sdcPointsForSex`
  - PLK: `plkPointsForSex`
  - 2MR: `run2miPointsForSex`
- Combat override: if `standard == AftStandard.combat`, effective sex is forced to male
- CSV columns represent age/sex bands; gaps are filled downward per column
- Awarding rule scans from 100 → 0 and returns the first threshold met
- `totalScore(...)` sums MDL + HRP + SDC + PLK + 2MR; null scores are treated as 0

Validation & Formatting
- Inputs are validated in UI (e.g., non-negative numbers) with inline error messaging
- Times parsed/validated via `formatters.dart` using `mm:ss` format
- `FeatureHomeScreen` updates state through notifiers and displays derived computations

---

## UI Modules

- Shell: `lib/shell/aft_scaffold.dart` – scaffold + bottom nav + segmented control + profile sheet
- Home: `lib/features/home/home_screen.dart` – total, profile context (age/sex/date), event inputs with validation
- Saved Sets: `lib/features/saves/saved_sets_screen.dart` – list and restore saved score sets
- Standards: `lib/screens/standards_screen.dart` – stub for future expansion
- Settings: `lib/screens/settings_screen.dart` – haptics, defaults, labels, data actions
- Theme: `lib/theme/army_theme.dart`, `lib/theme/army_colors.dart`
- Reusable widgets: `lib/widgets/` – `AftScoreRing`, `AftStepper`, `AftChoiceChip`, `AftEventCard`, etc.

---

## Firebase Integration

- Firebase initialized at startup via `firebase_options.dart`
- Authentication via `firebase_auth` (anonymous sign-in supported)
- Guest data automatically migrated to user bucket on sign-in
- Platform configuration files included for iOS, Android, macOS, and web

Local emulation (optional)
- The app is set to use real Firebase. To use emulators, add `useAuthEmulator(host, port)` when `kDebugMode` after initialization and ensure emulators are running. Update as needed via `flutterfire configure`.

---

## Testing

- Unit tests:
  - `test/aft_scoring_test.dart` – scoring boundaries, combat override, live total change
  - `test/saves_repository_test.dart` – persistence and list operations
  - `test/profile_date_test.dart` – profile age/ DOB logic
- Widget tests:
  - `test/widget_test.dart` – scaffold and basic UI boot

Run tests
```bash
flutter test
```

---

## Project Structure (selected)

```
lib/
├── app.dart
├── main.dart
├── firebase_options.dart
├── router/
│   └── app_router.dart
├── shell/
│   └── aft_scaffold.dart
├── features/
│   ├── auth/
│   │   ├── auth_gate.dart
│   │   ├── auth_state.dart
│   │   ├── providers.dart
│   │   └── sign_in_page.dart
│   ├── aft/
│   │   ├── logic/
│   │   │   ├── scoring_service.dart
│   │   │   ├── data/ (embedded CSV + tables)
│   │   │   └── slider_config.dart
│   │   ├── state/
│   │   │   ├── providers.dart
│   │   │   ├── aft_profile.dart
│   │   │   ├── aft_inputs.dart
│   │   │   └── aft_standard.dart
│   │   └── utils/
│   │       └── formatters.dart
│   ├── home/
│   │   └── home_screen.dart
│   ├── saves/
│   │   ├── saved_sets_screen.dart
│   │   ├── editing.dart
│   │   └── guest_migration.dart
│   └── ...
├── screens/
│   ├── standards_screen.dart
│   └── settings_screen.dart
├── theme/
│   ├── army_theme.dart
│   └── army_colors.dart
├── widgets/
│   ├── aft_score_ring.dart
│   ├── aft_stepper.dart
│   └── aft_choice_chip.dart
└── data/
    ├── aft_repository.dart
    ├── aft_repository_local.dart
    └── repository_providers.dart
```

---

## Extension Points

- Add a new screen
  - Create under `lib/screens/` and add a route in `AppRouter`
  - Wrap with `AftScaffold(showHeader: false, child: ...)` for consistent chrome
- Add/modify scoring rules
  - Update the relevant table under `logic/data/*_table.dart`
  - Adjust parsing/formatting in `utils/formatters.dart` if needed
  - Extend `ScoringService` and corresponding provider usage
- Change persistence
  - Implement a new repository (e.g., Firestore) conforming to `AftRepository`
  - Bind via a provider in `data/repository_providers.dart`
  - Keep JSON codecs in sync with the `ScoreSet` model
- Adjust defaults & UX
  - Update `settings_state.dart` and its consumers (`SettingsScreen`, `AftScaffold`, `HomeScreen`)
  - Consider haptics toggles and NavigationBar label behavior

---

## Roadmap

- [x] Implement FirebaseAuth integration
- [x] Add guest-to-user migration
- [ ] Migrate persistence to Firestore
- [ ] Expand Standards screen with detailed tables
- [ ] Add pass/fail logic and UI states to total
- [ ] Improve accessibility, i18n, and analytics
- [ ] Add golden and end-to-end tests

---

## Developer Notes

- Riverpod is used for all state; prefer providers/notifiers over globals
- Keep scoring logic pure and testable; avoid UI coupling
- Use the repository pattern for persistence (local now; Firestore-ready)
- Follow the modular feature structure under `lib/features/`
- For Firebase changes, update `firebase_options.dart` via `flutterfire configure`
- Routing transitions use `Duration.zero` to avoid double-render during AuthGate switches

This document is designed to give developers and maintainers a complete, practical understanding of the app’s architecture, data flow, and extension points.
