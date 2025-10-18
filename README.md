# AFT Firebase Demo

A Flutter + Riverpod app that prototypes an Army Fitness Test (AFT) calculator with a branded dark theme, real scoring for several events, unit tests, and local persistence. Firebase is initialized for the app; authentication is currently stubbed to a demo user.

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
   - Hand-Release Push-ups (HRP)
   - Sprint-Drag-Carry (SDC)
   - Plank
   - 2-Mile Run
3. See per-event score rings and a running Total.
4. Save result sets locally when “signed in” as a demo user.

Important:

- Scoring for MDL, HRP, SDC, and PLK uses real age/sex tables with a per-column fill-down rule and a Combat override.
- Total currently sums only the first three events (MDL, Push-ups, SDC). Plank and 2-Mile Run are displayed but do not affect Total yet.

## App Flow

- `lib/main.dart`
  - Ensures Flutter binding, initializes Firebase using `DefaultFirebaseOptions`, preloads scoring CSVs (MDL, HRP, SDC, PLK), then runs the app within a global Riverpod `ProviderScope`.
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

## Scoring (current logic)

- `lib/features/aft/logic/scoring_service.dart`
  - Central entry `scoreEvent(standard, profile, event, input)` validates input and routes to table functions:
    - MDL (3RM Deadlift): `mdlPointsForSex(effectiveSex, age, lbs)`
    - HRP (Hand-Release Push-ups): `hrpPointsForSex(effectiveSex, age, reps)`
    - SDC (Sprint-Drag-Carry): `sdcPointsForSex(effectiveSex, age, time)`
    - Plank: `plkPointsForSex(effectiveSex, age, time)`
    - 2-Mile Run: placeholder (static score)
  - Combat override:
    - When `standard == AftStandard.combat`, scoring forces `effectiveSex = AftSex.male` (uses male tables regardless of selected sex).
  - Total:
    - `totalScore(mdl, pushUps, sdc)` sums MDL + Push-ups + SDC. Plank and Run2mi are excluded for now.

### Scoring tables and rules

CSV preload at app startup:

- `lib/main.dart` calls:
  - `preloadMdlCsvOnce(mdlCsv)`
  - `preloadHrpCsvOnce(hrpCsv)`
  - `preloadSdcCsvOnce(sdcCsv)`
  - `preloadPlkCsvOnce(plkCsv)`

MDL (weight-based, higher is better)

- Files:
  - Data: `lib/features/aft/logic/data/mdl_csv.dart`
  - Tables/logic: `lib/features/aft/logic/data/mdl_table.dart`
- Structure:
  - 20-column CSV: `Points, M17–21, F17–21, M22–26, F22–26, ..., M62+, F62+`
  - Per-column fill-down rule:
    - For each age/sex column, from P=100 down to P=0:
      - If a requirement is `-1`, inherit from the next lower published P.
      - If none found by 0, use the column’s minimum published requirement (or 0).
  - Awarding rule:
    - Scan from 100 → 0; return the first (highest) point whose requirement is met (top-of-plateau awarding).

HRP (rep-based, higher is better)

- Files:
  - Data: `lib/features/aft/logic/data/hrp_csv.dart`
  - Tables/logic: `lib/features/aft/logic/data/hrp_table.dart`
- Same CSV layout and fill-down/awarding rules as MDL.
- `hrpPointsForSex(sex, age, reps)`

SDC (time-based, lower is better)

- Files:
  - Data: `lib/features/aft/logic/data/sdc_csv.dart`
  - Tables/logic: `lib/features/aft/logic/data/sdc_table.dart`
- Same CSV layout; times are parsed from `mm:ss` using `parseMmSs` in `lib/features/aft/utils/formatters.dart`.
- Fill-down rule per column (in seconds), then awarding rule:
  - Scan from 100 → 0; return the first (highest) point where `actualTime <= requirementTime`.

PLK (time-based, higher is better)
- Files:
  - Data: `lib/features/aft/logic/data/plk_csv.dart`
  - Tables/logic: `lib/features/aft/logic/data/plk_table.dart`
- Same CSV layout; times are parsed from `mm:ss` using `parseMmSs` in `lib/features/aft/utils/formatters.dart`.
- Fill-down rule per column (in seconds), then awarding rule:
  - Scan from 100 → 0; return the first (highest) point where `actualTime >= requirementTime`.

### Combat override

- Implemented in `ScoringService` for MDL, HRP, SDC.
- When Combat is selected in the UI, male thresholds are used even if the selected sex is Female.

## Data & Persistence

- `lib/data/aft_repository.dart`
  - `ScoreSet` aggregates `AftProfile`, `AftInputs`, computed scores (`AftComputed?`), and `createdAt`.
  - JSON codec helpers `encodeScoreSets`/`decodeScoreSets`.
  - `AftRepository` interface exposes `saveScoreSet` and `listScoreSets`.
- `lib/data/aft_repository_local.dart`
  - `LocalAftRepository` stores a JSON list under key `scoreSets:{userId}` via `shared_preferences`.
- `lib/data/repository_providers.dart`
  - Binds `AftRepository` to `LocalAftRepository` with `aftRepositoryProvider`.

## UI & Theming

- Shell
  - `lib/shell/aft_scaffold.dart` provides the app shell with a pinned `SliverAppBar`, segmented control for AFT Standard (General/Combat), a profile button (sign in/out, saved sets), and an overflow sheet (Standards, Timeline/Settings stubs).
- Home
  - `lib/features/home/home_screen.dart` renders:
    - Total card with pass/fail placeholder and Save button (enabled when signed in and total is non-null).
    - Context card: age dropdown, sex choice chips, test date display.
    - Event cards for MDL, Push-ups (HRP), SDC, Plank, and 2-Mile Run.
    - Input validation and mm:ss formatting via `MmSsFormatter` and helpers.
- Saved Sets
  - `lib/features/saves/saved_sets_screen.dart` lists saved score sets for the signed-in (demo) user with date/time.
- Standards
  - `lib/screens/standards_screen.dart` is currently a stub.
- Widgets
  - `AftScoreRing` (animated circular score ring), `AftStepper` (+/- numeric control), `AftChoiceChip` (gold highlight), plus shared layout widgets.
- Theme
  - `lib/theme/army_theme.dart` and `lib/theme/army_colors.dart` implement a branded dark theme with Material 3.

## Tests

- Run all tests:
  - `flutter test`
- Implemented unit tests:
  - MDL: `test/mdl_table_test.dart` (age/sex anchors, fill-down behavior, combat override for male thresholds)
  - HRP: `test/hrp_table_test.dart` (age/sex anchors, base thresholds, combat override)
- SDC uses the same table machinery; anchors can be added similarly.

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

- Implement official tables for 2-Mile Run; update Total to include Plank and 2-Mile Run where applicable.
- Add pass/fail logic and thresholds by standard/age/sex; reflect results on the Total card.
- Expand Standards screen to show detailed tables and explanations.
- Implement real authentication (FirebaseAuth) and migrate persistence to Firestore; support per-user CRUD and sync.
- Improve validation, accessibility labels, and input affordances.
- Add more tests (SDC anchors, ScoringService end-to-end, providers, widget tests, goldens).
- Optional: analytics, logging, i18n, locale-aware time formatting.

## Key Files

- Entry/Routing: `lib/main.dart`, `lib/app.dart`, `lib/router/app_router.dart`
- State: `lib/features/aft/state/aft_profile.dart`, `lib/features/aft/state/aft_inputs.dart`, `lib/features/aft/state/providers.dart`, `lib/features/aft/state/aft_standard.dart`
- Scoring Service: `lib/features/aft/logic/scoring_service.dart`
- Tables & Data:
  - MDL: `lib/features/aft/logic/data/mdl_csv.dart`, `lib/features/aft/logic/data/mdl_table.dart`
  - HRP: `lib/features/aft/logic/data/hrp_csv.dart`, `lib/features/aft/logic/data/hrp_table.dart`
  - SDC: `lib/features/aft/logic/data/sdc_csv.dart`, `lib/features/aft/logic/data/sdc_table.dart`
  - PLK: `lib/features/aft/logic/data/plk_csv.dart`, `lib/features/aft/logic/data/plk_table.dart`
- Data repo: `lib/data/aft_repository.dart`, `lib/data/aft_repository_local.dart`, `lib/data/repository_providers.dart`
- Shell & Screens: `lib/shell/aft_scaffold.dart`, `lib/features/home/home_screen.dart`, `lib/features/saves/saved_sets_screen.dart`, `lib/screens/standards_screen.dart`
- Widgets: `lib/widgets/aft_score_ring.dart`, `lib/widgets/aft_stepper.dart`, `lib/widgets/aft_choice_chip.dart`
- Theme: `lib/theme/army_theme.dart`, `lib/theme/army_colors.dart`
- Utils: `lib/features/aft/utils/formatters.dart`
