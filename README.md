# AFT Firebase Demo

A Flutter + Riverpod app that prototypes an Army Fitness Test (AFT) calculator with a branded dark theme, placeholder scoring, and local persistence. Firebase is initialized for the app, while authentication is currently stubbed to a demo user.

- Platforms: iOS, Android, Web, Desktop (Flutter)
- State: Riverpod (Notifier API)
- UI: Material 3 with custom Army theme and widgets
- Data: Local storage via shared_preferences (repository pattern for future cloud swap)
- Firebase: Initialized via `firebase_options.dart` (no FirebaseAuth/Firestore integration yet)

## Overview

The app lets users:
1. Select profile context (age, sex, and test standard).
2. Enter event results for:
   - 3RM Deadlift (MDL)
   - Hand-Release Push-ups
   - Sprint-Drag-Carry (SDC)
   - Plank
   - 2-Mile Run
3. See per-event score rings and a running Total.
4. Save result sets locally when “signed in” as a demo user.

Important: Scoring is placeholder. The Total currently sums only the first three events (MDL, Push-ups, SDC). Plank and 2-Mile Run display scores but do not affect Total yet.

## App Flow

- `lib/main.dart`
  - Ensures Flutter binding, initializes Firebase using `DefaultFirebaseOptions`, then runs the app within a global Riverpod `ProviderScope`.
- `lib/app.dart`
  - Sets up `MaterialApp` with `ArmyTheme.dark`, `AppRouter.onGenerateRoute`, and `initialRoute: '/'`.
- `lib/router/app_router.dart`
  - Routes:
    - `/` → `AftScaffold(child: FeatureHomeScreen())`
    - `/standards` → `StandardsScreen` (stub)
    - `/saved-sets` → `SavedSetsScreen`

## State Management (Riverpod)

- Profile
  - Model: `AftProfile` (age, sex, standard, optional testDate)
  - Notifier/Provider: `ProfileNotifier` → `aftProfileProvider`
- Inputs
  - Model: `AftInputs` (mdlLbs, pushUps, sdc, plank, run2mi)
  - Notifier/Provider: `InputsNotifier` → `aftInputsProvider`
- Computed
  - `aftComputedProvider` derives per-event scores and total using `ScoringService`.
  - `AftComputed` holds `mdlScore`, `pushUpsScore`, `sdcScore`, `plankScore`, `run2miScore`, `total`.

## Scoring

- `lib/features/aft/logic/scoring_service.dart`
  - `scoreEvent(...)` validates input types and returns deterministic placeholder scores:
    - MDL: 82, Push-ups: 74, SDC: 68, Plank: 76, 2-Mile Run: 62 (when input is valid)
  - `totalScore(mdl, pushUps, sdc)` sums only MDL + Push-ups + SDC by design for the current phase.

## Data & Persistence

- `lib/data/aft_repository.dart`
  - `ScoreSet` aggregates `AftProfile`, `AftInputs`, computed scores (`AftComputed?`), and `createdAt`.
  - JSON codec helpers `encodeScoreSets`/`decodeScoreSets`.
  - `AftRepository` interface exposes `saveScoreSet` and `listScoreSets`.
- `lib/data/aft_repository_local.dart`
  - `LocalAftRepository` stores a JSON list under key `scoreSets:{userId}` via `shared_preferences`.
- `lib/data/repository_providers.dart`
  - Binds `AftRepository` to `LocalAftRepository` with `aftRepositoryProvider`.

## Authentication (Stub)

- `lib/features/auth/auth_state.dart` and `lib/features/auth/providers.dart`
  - `AuthController` toggles a deterministic demo user (no FirebaseAuth yet).
  - Exposes `authStateProvider` and an action-only `authActionsProvider` for `signIn()`/`signOut()`.

## UI & Theming

- Shell
  - `lib/shell/aft_scaffold.dart` provides the app shell with a pinned `SliverAppBar`, segmented control for AFT Standard (General/Combat), a profile button (sign in/out, saved sets), and an overflow sheet (Standards, Timeline/Settings stubs).
- Home
  - `lib/features/home/home_screen.dart` renders:
    - Total card with pass/fail placeholder and Save button (enabled when signed in and total is non-null).
    - Context card: age dropdown, sex choice chips, test date display.
    - Event cards for MDL, Push-ups, SDC, Plank, and 2-Mile Run.
    - Input validation and mm:ss formatting via `MmSsFormatter` and helpers.
    - Light haptic feedback when Total transitions to a new valid number.
- Saved Sets
  - `lib/features/saves/saved_sets_screen.dart` lists saved score sets for the signed-in (demo) user with date/time.
- Standards
  - `lib/screens/standards_screen.dart` is currently a stub.
- Widgets
  - `AftScoreRing` (animated circular score ring), `AftStepper` (+/- numeric control), `AftChoiceChip` (gold highlight), plus shared layout widgets.
- Theme
  - `lib/theme/army_theme.dart` and `lib/theme/army_colors.dart` implement a branded dark theme with Material 3, including inputs, cards, app bars, controls, and more.

## Data Flow Details

1. User edits inputs on Home:
   - Text fields/steppers validate and update `aftInputsProvider`.
   - `aftComputedProvider` watches profile + inputs and uses `ScoringService` to compute per-event scores and total.
   - UI reacts to provider changes (score rings, Total, Save button state).
2. Saving a set:
   - When signed in (demo user) and `total != null`, tapping Save builds a `ScoreSet` and calls `AftRepository.saveScoreSet`.
   - `LocalAftRepository` writes encoded JSON to `shared_preferences`.
   - `SavedSetsScreen` reads via `listScoreSets` and displays a dated list.

## Running Locally

Prerequisites:
- Flutter SDK installed and platform toolchains set up.

Install:
- `flutter pub get`

Run:
- Mobile: `flutter run`
- Web: `flutter run -d chrome`

Firebase:
- The project includes platform configs and `lib/firebase_options.dart`. Firebase initializes at app start.
- Auth is stubbed; no FirebaseAuth yet.

Sign-in (Demo):
- Tap the profile icon → “Sign in” to toggle a demo user and enable “Save”.

## Known Limitations & Next Steps

- Replace placeholder scoring with official AFT tables (all events) and update Total to include Plank and 2-Mile Run where applicable.
- Implement real authentication (FirebaseAuth) and migrate persistence to Firestore or another backend; support per-user CRUD and sync.
- Build the Standards screen with detailed tables and explanations.
- Add pass/fail logic and thresholds by standard/age/sex; reflect results on the Total card.
- Improve validation, accessibility labels, and input affordances.
- Add tests: unit (ScoringService, providers, parsing), widget, and golden tests.
- Optional: analytics, logging, i18n, locale-aware time formatting.

## Key Files

- Entry/Routing: `lib/main.dart`, `lib/app.dart`, `lib/router/app_router.dart`
- State: `lib/features/aft/state/aft_profile.dart`, `lib/features/aft/state/aft_inputs.dart`, `lib/features/aft/state/providers.dart`, `lib/features/aft/state/aft_standard.dart`
- Logic: `lib/features/aft/logic/scoring_service.dart`
- Data: `lib/data/aft_repository.dart`, `lib/data/aft_repository_local.dart`, `lib/data/repository_providers.dart`
- UI: `lib/shell/aft_scaffold.dart`, `lib/features/home/home_screen.dart`, `lib/features/saves/saved_sets_screen.dart`, `lib/screens/standards_screen.dart`
- Widgets: `lib/widgets/aft_score_ring.dart`, `lib/widgets/aft_stepper.dart`, `lib/widgets/aft_choice_chip.dart`
- Theme: `lib/theme/army_theme.dart`, `lib/theme/army_colors.dart`
- Utils: `lib/features/aft/utils/formatters.dart`
