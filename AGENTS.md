# AGENTS.md

## Project

Flutter country trivia game. MVVM architecture with Provider for state management. Dart SDK ^3.11.1.

## Architecture

- **Pattern:** MVVM — Models (data), Services (I/O), ViewModels (state/logic), Views (UI)
- **State management:** Provider (`ChangeNotifier` + `Consumer`/`context.watch`)
- **Persistence:** SharedPreferences (solved country codes + total score)
- **APIs:** REST Countries v3.1 (`https://restcountries.com/v3.1/all?fields=name,cca2,flags`) and flagcdn (`https://flagcdn.com/w320/{cca2}.png`)

## Key Files

- `docs/master_plan.md` — Full ticket breakdown, execution order, and PR requirements
- `lib/utils/constants.dart` — API URLs, storage keys, points table, max attempts
- `lib/models/country.dart` — Country data class
- `lib/viewmodels/game_viewmodel.dart` — Core game logic (scoring, round generation)

## Commands

```bash
# Install dependencies
flutter pub get

# Static analysis (must pass before PR)
flutter analyze

# Run all tests
flutter test

# Run a single test file
flutter test test/path/to/test.dart

# Run on emulator (required for UI tickets before PR)
flutter run
```

## Git Workflow

- **Default branch:** `develop` (not `main`)
- **Feature branches:** `feature/<ticket-id>-<short-description>` from `develop`
- **PRs:** Always target `develop`, never `main`
- **PR requirements:** `flutter analyze` clean, all tests passing, emulator run for UI tickets

## Conventions

- ViewModel has zero Flutter UI imports (only `ChangeNotifier`) — keeps it unit-testable
- Persist only CCA2 codes (not full country objects) to keep storage tiny
- Distractors are random from the unsolved pool — no repeats across sessions
- Points: 1st try = 10, 2nd = 8, 3rd = 5, fail = 0

## Gotchas

- `test/widget_test.dart` is still the default counter test — it will fail once `main.dart` is replaced. Delete or update it when working on T-15/T-16.
- `CardTheme` must be `CardThemeData` in this Flutter version (type mismatch otherwise).

## PR Review

- GitHub Actions workflow (`.github/workflows/pr-review.yml`) auto-reviews PRs using OpenCode with `opencode/big-pickle` model
- Setup instructions: `docs/opencode_setup.md`
- Requires `OPENCODE_API_KEY` repository secret
