# AFT (Army Fitness Test) – Flutter + Riverpod + Firebase

Multi-platform Flutter app that calculates AFT scores with real age/sex tables, a live total, and a branded dark theme. Uses Riverpod for state management and local persistence via shared_preferences. Firebase is initialized; authentication is currently a demo toggle.

- Platforms: iOS, Android, Web, macOS/Windows/Linux
- Frameworks: Flutter 3.22+, Dart 3.5+, Riverpod (Notifier API)
- Data: Embedded CSV scoring tables, local JSON persistence (repository pattern)
- Firebase: `firebase_core` initialized via `firebase_options.dart` (no FirebaseAuth/Firestore yet)

## Quick start

Prerequisites
- Flutter SDK ≥ 3.22.0
- Dart SDK ≥ 3.5.3

Install
- `flutter pub get`

Run
- Mobile: `flutter run`
- Web: `flutter run -d chrome`

Test
- `flutter test`

## Features

- Real scoring for all events (age/sex banded):
  - 3RM Deadlift (MDL)
  - Hand-Release Push-ups (HRP)
  - Sprint-Drag-Carry (SDC)
  - Plank (PLK)
  - 2-Mile Run (2MR)
- Combat override (uses male thresholds regardless of selected sex)
- Live total that updates as inputs change (partial totals allowed)
- Save result sets locally when “signed in” as a demo user
- Riverpod state management and modular routing
- Material 3 dark theme with branded Army styling and custom widgets

## How it works

App init (`lib/main.dart`)
- Ensures bindings, initializes Firebase via `DefaultFirebaseOptions`, preloads all scoring CSVs (MDL, HRP, SDC, PLK, 2MR), then runs within a global `ProviderScope`.

Routing (`lib/router/app_router.dart`)
- `/` → `AftScaffold(child: FeatureHomeScreen())`
- `/standards` → `StandardsScreen` (stub)
- `/saved-sets` → `SavedSetsScreen`

State (Riverpod)
- Profile: `AftProfile` and `ProfileNotifier` → `aftProfileProvider`
- Inputs: `AftInputs` and `InputsNotifier` → `aftInputsProvider`
- Computed: `aftComputedProvider` derives per-event scores and total via `ScoringService`

Scoring (`lib/features/aft/logic/scoring_service.dart`)
- `scoreEvent(standard, profile, event, input)` validates input and delegates to:
  - MDL: `mdlPointsForSex`
  - HRP: `hrpPointsForSex`
  - SDC: `sdcPointsForSex`
  - PLK: `plkPointsForSex`
  - 2MR: `run2miPointsForSex`
- Combat override: when `standard == AftStandard.combat`, `effectiveSex` is forced to `AftSex.male`
- Total: `totalScore(...)` sums MDL + HRP + SDC + PLK + 2MR, treating null scores as 0

Tables & CSV preload
- Embedded CSVs parsed at startup:
  - MDL: `lib/features/aft/logic/data/mdl_csv.dart`, `mdl_table.dart`
  - HRP: `lib/features/aft/logic/data/hrp_csv.dart`, `hrp_table.dart`
  - SDC: `lib/features/aft/logic/data/sdc_csv.dart`, `sdc_table.dart`
  - PLK: `lib/features/aft/logic/data/plk_csv.dart`, `plk_table.dart`
  - 2MR: `lib/features/aft/logic/data/run2mi_csv.dart`, `run2mi_table.dart`
- Common rules across tables:
  - CSV columns per age/sex band with a per-column fill-down to handle gaps
  - Awarding rule scans from 100 → 0 and returns the first threshold met
  - Time parsing for SDC/PLK/2MR via `utils/formatters.dart` (`mm:ss`)

Data & persistence
- `AftRepository` interface with `LocalAftRepository` implementation (`shared_preferences`)
- `ScoreSet` includes profile, inputs, computed scores, and `createdAt`
- JSON codec helpers for persistence (see `lib/data/aft_repository.dart` and `aft_repository_local.dart`)

UI & theming
- Shell: `lib/shell/aft_scaffold.dart` with segmented control for standard (General/Combat), profile actions, overflow menu, and pinned `SliverAppBar`
- Home: `lib/features/home/home_screen.dart` shows total, profile context (age/sex/date), and event cards with validation/formatters
- Saved sets: `lib/features/saves/saved_sets_screen.dart` lists locally saved score sets
- Standards: `lib/screens/standards_screen.dart` (stub)
- Theme: `lib/theme/army_theme.dart`, `lib/theme/army_colors.dart`
- Reusable widgets: `AftScoreRing`, `AftStepper`, `AftChoiceChip`, and layout utilities

## Firebase

- Firebase is initialized at app startup via `firebase_options.dart`.
- No real authentication flows are implemented yet; “Sign in” toggles a demo user and enables Save.
- Platform configuration files are included for iOS/Android/macOS (and web manifest).

## Testing

- Unit tests: `test/aft_scoring_test.dart` covers anchors/boundaries for MDL, HRP, SDC, PLK, 2MR, combat override behavior, and live total as inputs change.
- Widget test scaffold: `test/widget_test.dart`

Run tests
- `flutter test`

## Project structure (selected)

- `lib/`
  - `app.dart`, `main.dart`, `firebase_options.dart`
  - `router/app_router.dart`
  - `shell/aft_scaffold.dart`
  - `features/`
    - `home/home_screen.dart`
    - `aft/`
      - `logic/`
        - `scoring_service.dart`
        - `data/mdl_*.dart`, `hrp_*.dart`, `sdc_*.dart`, `plk_*.dart`, `run2mi_*.dart`
        - `utils/formatters.dart`
      - `state/` (AftProfile, AftInputs, providers)
    - `saves/saved_sets_screen.dart`
  - `theme/army_theme.dart`, `theme/army_colors.dart`
  - `widgets/` (`AftScoreRing`, `AftStepper`, `AftChoiceChip`, etc.)
  - `data/` (repositories, models)

## Roadmap

- Implement real authentication (FirebaseAuth) and migrate persistence to Firestore
- Expand Standards screen to present detailed tables and explanations
- Pass/fail logic by standard/age/sex with clear UI states on the Total card
- Accessibility/i18n improvements; analytics/logging
- Additional tests (widget/goldens, end-to-end provider flows)

## License

TBD (add a LICENSE file if you plan to open source)
