# Country Trivia App — Master Plan

## 1. Overview

A Flutter trivia game where users identify a country from its flag. Each round presents one flag and four country names. Points are awarded based on how quickly the user guesses correctly. Solved flags are never repeated across sessions, and the user's score persists between app restarts.

---

## 2. Game Rules

| Attempt | Points |
|---------|--------|
| 1st try (correct) | 10 |
| 2nd try (correct) | 8 |
| 3rd try (correct) | 5 |
| All 3 tries exhausted | 0 (correct answer revealed) |

- Each round: 1 flag + 4 country-name options (1 correct + 3 distractors).
- After each wrong guess, that option is disabled/removed.
- After the round resolves (correct guess or 3 failures), a "Next" button advances to a new flag.
- Flags already solved in any previous session are excluded from the pool.

---

## 3. Tech Stack

| Concern | Package |
|---------|---------|
| State management | `provider` |
| HTTP requests | `http` |
| Local persistence | `shared_preferences` |
| Flag images | `cached_network_image` (for smooth loading + caching) |
| JSON serialization | Built-in `dart:convert` (no codegen needed) |

---

## 4. API Details

### 4.1 Country Data — REST Countries v3.1

**Endpoint:** `GET https://restcountries.com/v3.1/all?fields=name,cca2,flags`

**Relevant fields per country:**
- `name.common` — display name (e.g., "Germany")
- `cca2` — 2-letter ISO code (e.g., "DE") — used for flag URL
- `flags.png` — fallback flag URL (we use flagcdn instead)

**Response size:** ~250 countries. Fetch once at app start, cache in memory.

### 4.2 Flag Images — flagcdn.com

**URL pattern:** `https://flagcdn.com/w320/{cca2_lowercase}.png`

Example: `https://flagcdn.com/w320/de.png`

- `w320` = 320px wide (good balance of quality vs. bandwidth).
- Use `cached_network_image` to avoid re-downloading.

---

## 5. Architecture — MVVM with Provider

```
lib/
├── main.dart                      # App entry, MultiProvider setup
├── app.dart                       # MaterialApp + theme
├── models/
│   └── country.dart               # Country data model
├── services/
│   ├── api_service.dart           # REST Countries HTTP fetch
│   └── storage_service.dart       # SharedPreferences wrapper
├── viewmodels/
│   ├── game_viewmodel.dart        # Core game logic & state
│   └── settings_viewmodel.dart    # (optional) settings/state
├── views/
│   ├── home_view.dart             # Main game screen
│   └── widgets/
│       ├── flag_card.dart         # Flag image display
│       ├── answer_button.dart     # Single answer option
│       ├── score_bar.dart         # Current score display
│       └── round_result.dart      # Correct/incorrect feedback overlay
└── utils/
    ├── constants.dart             # API URLs, storage keys, game constants
    └── app_theme.dart             # ThemeData
```

### 5.1 Layer Responsibilities

| Layer | Responsibility |
|-------|---------------|
| **Model** (`Country`) | Pure data class. Holds `name`, `cca2`, `flagUrl`. |
| **Service** (`ApiService`, `StorageService`) | I/O only. No UI knowledge. |
| **ViewModel** (`GameViewModel`) | Holds game state, exposes methods (`submitAnswer`, `nextRound`), notifies listeners. |
| **View** (`HomeView`, widgets) | Renders state from ViewModel, dispatches user intents. |

---

## 6. Data Models

### 6.1 `Country`

```dart
class Country {
  final String name;    // common name, e.g. "Germany"
  final String cca2;    // ISO 3166-1 alpha-2, e.g. "DE"

  const Country({required this.name, required this.cca2});

  String get flagUrl => 'https://flagcdn.com/w320/${cca2.toLowerCase()}.png';

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      name: json['name']['common'] as String,
      cca2: json['cca2'] as String,
    );
  }
}
```

### 6.2 Game State (inside ViewModel)

```dart
enum RoundStatus { active, correct, failed }

class GameState {
  final int totalScore;
  final int attempt;            // 1, 2, or 3
  final Country correctCountry;
  final List<Country> options;  // shuffled, length 4
  final RoundStatus status;
  final int? lastPointsAwarded; // null if failed
}
```

---

## 7. ViewModel Design — `GameViewModel`

### 7.1 State Fields

| Field | Type | Description |
|-------|------|-------------|
| `_allCountries` | `List<Country>` | Full fetched list |
| `_solvedCodes` | `Set<String>` | CCA2 codes already solved (persisted) |
| `_availableCountries` | `List<Country>` | Unsolved pool |
| `_currentRound` | `Round?` | Active round data |
| `_score` | `int` | Running total (persisted) |
| `_isLoading` | `bool` | Initial fetch flag |
| `_errorMessage` | `String?` | Network error |

### 7.2 Key Methods

| Method | Behavior |
|--------|----------|
| `initialize()` | Load solved codes + score from SharedPreferences; fetch countries from API; build first round. |
| `submitAnswer(Country guess)` | Compare guess.cca2 to correct.cca2. If correct → award points, mark solved, persist. If wrong → increment attempt. If attempt > 3 → mark failed, reveal answer. |
| `nextRound()` | Pick new correct country from available pool, generate 3 distractors, shuffle, reset attempt counter. |
| `resetGame()` | Clear solved codes, reset score, rebuild pool. |

### 7.3 Round Generation Logic

```
1. Pick random correct country from _availableCountries.
2. Pick 3 random distractors from _availableCountries (excluding correct).
3. Combine into list of 4, shuffle.
4. Set _currentRound with attempt = 1, status = active.
```

### 7.4 Scoring Logic

```dart
const Map<int, int> _pointsTable = {1: 10, 2: 8, 3: 5};

void submitAnswer(Country guess) {
  if (_currentRound == null || _currentRound!.status != RoundStatus.active) return;

  if (guess.cca2 == _currentRound!.correctCountry.cca2) {
    final points = _pointsTable[_currentRound!.attempt]!;
    _score += points;
    _solvedCodes.add(_currentRound!.correctCountry.cca2);
    _currentRound = _currentRound!.copyWith(
      status: RoundStatus.correct,
      lastPointsAwarded: points,
    );
    _persistState();
  } else {
    final newAttempt = _currentRound!.attempt + 1;
    if (newAttempt > 3) {
      _currentRound = _currentRound!.copyWith(
        status: RoundStatus.failed,
        attempt: 3,
      );
      _solvedCodes.add(_currentRound!.correctCountry.cca2); // mark as seen
      _persistState();
    } else {
      _currentRound = _currentRound!.copyWith(attempt: newAttempt);
    }
  }
  notifyListeners();
}
```

---

## 8. Persistence Design

### 8.1 SharedPreferences Keys

| Key | Type | Description |
|-----|------|-------------|
| `solved_country_codes` | `List<String>` (JSON) | CCA2 codes of all solved flags |
| `total_score` | `int` | Cumulative points |

### 8.2 Storage Service

```dart
class StorageService {
  static const _solvedKey = 'solved_country_codes';
  static const _scoreKey = 'total_score';

  Future<Set<String>> loadSolvedCodes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_solvedKey);
    if (jsonStr == null) return {};
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list.cast<String>().toSet();
  }

  Future<void> saveSolvedCodes(Set<String> codes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_solvedKey, jsonEncode(codes.toList()));
  }

  Future<int> loadScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scoreKey) ?? 0;
  }

  Future<void> saveScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_scoreKey, score);
  }
}
```

---

## 9. UI Design

### 9.1 Home Screen Layout

```
┌──────────────────────────────────┐
│  🏆 Score: 125                   │  ← ScoreBar (top)
├──────────────────────────────────┤
│                                  │
│         ┌──────────┐             │
│         │          │             │
│         │   FLAG   │             │  ← FlagCard (cached image)
│         │  (w320)  │             │
│         │          │             │
│         └──────────┘             │
│                                  │
│   "Which country does this       │
│        flag belong to?"          │
│                                  │
│  ┌──────────┐  ┌──────────┐      │
│  │ Option A │  │ Option B │      │  ← AnswerButton (grid 2×2)
│  └──────────┘  └──────────┘      │
│  ┌──────────┐  ┌──────────┐      │
│  │ Option C │  │ Option D │      │
│  └──────────┘  └──────────┘      │
│                                  │
│         [ Next → ]               │  ← shown after round resolves
└──────────────────────────────────┘
```

### 9.2 Answer Button States

| State | Visual |
|-------|--------|
| Default | Filled container, tappable |
| Wrong (tapped) | Red tint, disabled, strike-through or ✗ icon |
| Correct (revealed) | Green tint, ✓ icon |
| Disabled (after round ends) | Greyed out |

### 9.3 Feedback

- **Correct guess:** Brief green flash / snackbar showing "+10", "+8", or "+5".
- **Failed round:** Snackbar showing "The correct answer was: [Country]".
- **All flags solved:** Congratulatory dialog with final score and "Play Again" (reset).

---

## 10. Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  provider: ^6.1.2
  http: ^1.2.2
  shared_preferences: ^2.3.2
  cached_network_image: ^3.4.1
```

---

## 11. Implementation Phases

### Phase 1 — Project Setup
1. Add dependencies to `pubspec.yaml`.
2. Run `flutter pub get`.
3. Create folder structure under `lib/`.

### Phase 2 — Models & Services
1. Implement `Country` model with `fromJson`.
2. Implement `ApiService` with `fetchCountries()` using `http` package.
3. Implement `StorageService` with load/save for solved codes and score.
4. Write unit tests for `Country.fromJson`.

### Phase 3 — ViewModel
1. Implement `GameViewModel` with all state fields.
2. Implement `initialize()`, `submitAnswer()`, `nextRound()`, `resetGame()`.
3. Implement round generation (correct + 3 distractors, shuffled).
4. Write unit tests for scoring logic and round generation.

### Phase 4 — UI
1. Build `HomeView` with `Scaffold`, `ScoreBar`, `FlagCard`, answer grid.
2. Build `FlagCard` widget using `CachedNetworkImage`.
3. Build `AnswerButton` widget with state-driven styling.
4. Wire up `Provider.of<GameViewModel>` in the view.
5. Add "Next" button logic and round-result feedback.
6. Add loading and error states.

### Phase 5 — Persistence Integration
1. Call `StorageService.loadSolvedCodes()` and `loadScore()` in `initialize()`.
2. Call `saveSolvedCodes()` and `saveScore()` after every state change.
3. Verify data survives app restart.

### Phase 6 — Polish & Edge Cases
1. Handle network failure gracefully (retry button).
2. Handle empty available pool (all countries solved → victory screen).
3. Add pull-to-refresh or manual refresh if needed.
4. Add subtle animations (flag fade-in, button press feedback).
5. Ensure accessibility (semantic labels on buttons).

### Phase 7 — Testing
1. Unit tests: `GameViewModel` scoring, round generation, persistence.
2. Widget test: tap correct answer → score increases.
3. Widget test: tap wrong answers 3 times → correct answer revealed.
4. Integration test: full game flow.

---

## 12. Error Handling

| Scenario | Behavior |
|----------|----------|
| Network failure on fetch | Show error message with "Retry" button |
| Flag image fails to load | Show placeholder icon (e.g., `Icons.flag_outlined`) |
| All countries solved | Show victory dialog with final score + reset option |
| SharedPreferences write fails | Log warning, continue in-memory |

---

## 13. File-by-File Summary

| File | Purpose |
|------|---------|
| `lib/main.dart` | Entry point. `MultiProvider` with `GameViewModel`. |
| `lib/app.dart` | `MaterialApp` with theme and `HomeView`. |
| `lib/models/country.dart` | `Country` data class. |
| `lib/services/api_service.dart` | Fetches country list from REST Countries API. |
| `lib/services/storage_service.dart` | SharedPreferences read/write. |
| `lib/viewmodels/game_viewmodel.dart` | All game state and logic. |
| `lib/views/home_view.dart` | Main game screen widget. |
| `lib/views/widgets/flag_card.dart` | Displays flag image. |
| `lib/views/widgets/answer_button.dart` | Single answer option button. |
| `lib/views/widgets/score_bar.dart` | Shows current score. |
| `lib/views/widgets/round_result.dart` | Feedback after round ends. |
| `lib/utils/constants.dart` | API URLs, storage keys, points table. |
| `lib/utils/app_theme.dart` | `ThemeData` definition. |

---

## 14. Key Design Decisions

1. **Fetch all countries once** — The full list is ~250 items; a single fetch at startup is simpler and faster than paginated requests.
2. **Distractors from same pool** — Random selection from unsolved countries ensures variety and avoids repeats.
3. **Persist solved codes, not full country objects** — Only CCA2 strings are stored; country details are re-fetched each session (keeps storage tiny).
4. **Provider over Riverpod/Bloc** — Matches user requirement; sufficient for this app's complexity.
5. **CachedNetworkImage for flags** — Reduces network usage and improves perceived performance.
6. **MVVM separation** — ViewModel has zero Flutter UI imports (only `ChangeNotifier`), making it unit-testable without a widget tester.

---

## 15. Estimated Complexity

| Component | Lines (est.) |
|-----------|-------------|
| Models | ~30 |
| Services | ~80 |
| ViewModel | ~150 |
| Views + Widgets | ~300 |
| Utils | ~40 |
| Tests | ~200 |
| **Total** | **~800** |

---

## 16. Git Branching Strategy

### 16.1 Branch Model

| Branch | Purpose |
|--------|---------|
| `main` | Production-ready code — protected, only updated via PR from `develop` |
| `develop` | Integration branch — **default branch**, all feature PRs target this |
| `feature/*` | Individual feature branches — branched from `develop`, merged back via PR |

### 16.2 Workflow

1. **Default branch is `develop`** — all new work starts here.
2. **Feature branches** are created from `develop`:
   ```
   git checkout develop
   git checkout -b feature/T-01-add-dependencies
   ```
3. **Pull requests** are raised against `develop` (not `main`).
4. **Merge to `main`** only happens when `develop` is stable and ready for release.
5. **Naming convention:** `feature/<ticket-id>-<short-description>`

### 16.3 PR Requirements

Every PR raised against `develop` must include:
- [ ] Successful run on emulator (for UI tickets)
- [ ] All unit tests passing
- [ ] `flutter analyze` clean
- [ ] PR description linking the ticket(s)
- [ ] Screenshots/screen recording (for UI changes)

---

## 17. Ticket Breakdown & Execution Plan

### 16.1 Ticket Summary

| ID | Title | Phase | Dependencies | Parallel Group |
|----|-------|-------|--------------|----------------|
| T-01 | Add dependencies to pubspec.yaml | 1 | None | A |
| T-02 | Create lib/ folder structure | 1 | None | A |
| T-03 | Implement Country model | 2 | None | A |
| T-04 | Implement ApiService | 2 | T-01 | B |
| T-05 | Implement StorageService | 2 | T-01 | B |
| T-06 | Write Country model unit tests | 2 | T-03 | C |
| T-07 | Implement GameViewModel core | 3 | T-03, T-04, T-05 | D |
| T-08 | Write GameViewModel unit tests | 3 | T-07 | E |
| T-09 | Create constants.dart | 1 | None | A |
| T-10 | Create app_theme.dart | 1 | None | A |
| T-11 | Build FlagCard widget | 4 | T-09, T-10 | F |
| T-12 | Build AnswerButton widget | 4 | T-09, T-10 | F |
| T-13 | Build ScoreBar widget | 4 | T-09, T-10 | F |
| T-14 | Build RoundResult widget | 4 | T-09, T-10 | F |
| T-15 | Build HomeView screen | 4 | T-07, T-11, T-12, T-13, T-14 | G |
| T-16 | Wire up Provider in main.dart | 4 | T-07, T-15 | H |
| T-17 | Create app.dart with MaterialApp | 4 | T-10, T-16 | I |
| T-18 | Add loading & error states | 4 | T-15 | J |
| T-19 | Add victory/reset flow | 6 | T-15 | J |
| T-20 | Add animations & polish | 6 | T-18, T-19 | K |
| T-21 | Write widget tests | 7 | T-15 | L |
| T-22 | Write integration test | 7 | T-16, T-21 | M |

---

### 16.2 Emulator Verification Policy

> **All UI-related tickets (T-11 through T-22) must pass a successful run on an Android or iOS emulator before a pull request is raised.**

This means:
- The app must launch without crashes on the emulator
- The specific feature/changes in the ticket must be manually verified on the emulator
- Any visual regressions must be caught and fixed before PR
- Emulator screenshots or screen recordings should be attached to the PR when applicable

---

### 16.3 Ticket Details

#### T-01: Add dependencies to pubspec.yaml
**Phase:** 1 — Project Setup
**Dependencies:** None
**Parallel Group:** A

Add the following to `pubspec.yaml`:
- `provider: ^6.1.2`
- `http: ^1.2.2`
- `shared_preferences: ^2.3.2`
- `cached_network_image: ^3.4.1`

Run `flutter pub get` and verify no conflicts.

**Acceptance Criteria:**
- `flutter pub get` succeeds
- `flutter analyze` shows no errors

---

#### T-02: Create lib/ folder structure
**Phase:** 1 — Project Setup
**Dependencies:** None
**Parallel Group:** A

Create directories:
```
lib/
├── models/
├── services/
├── viewmodels/
├── views/
│   └── widgets/
└── utils/
```

**Acceptance Criteria:**
- All directories exist
- Project still compiles

---

#### T-03: Implement Country model
**Phase:** 2 — Models & Services
**Dependencies:** None
**Parallel Group:** A

Create `lib/models/country.dart`:
- Fields: `name` (String), `cca2` (String)
- Computed: `flagUrl` getter
- Factory: `Country.fromJson(Map<String, dynamic> json)`
- `toString()`, `==`, `hashCode` for value equality

**Acceptance Criteria:**
- Model compiles
- `fromJson` correctly parses `name.common` and `cca2`
- `flagUrl` returns correct URL format

---

#### T-04: Implement ApiService
**Phase:** 2 — Models & Services
**Dependencies:** T-01
**Parallel Group:** B

Create `lib/services/api_service.dart`:
- `Future<List<Country>> fetchCountries()` — GET request to REST Countries API
- Parse JSON response into `List<Country>`
- Handle HTTP errors (non-200 status)
- Timeout after 15 seconds

**Acceptance Criteria:**
- Returns list of countries on success
- Throws descriptive exception on network/HTTP error
- Unit test with mocked HTTP client passes

---

#### T-05: Implement StorageService
**Phase:** 2 — Models & Services
**Dependencies:** T-01
**Parallel Group:** B

Create `lib/services/storage_service.dart`:
- `loadSolvedCodes()` → `Set<String>`
- `saveSolvedCodes(Set<String>)` → void
- `loadScore()` → int
- `saveScore(int)` → void
- JSON encode/decode for solved codes list

**Acceptance Criteria:**
- All four methods work correctly
- Returns empty set / 0 when no data exists
- Unit test with mocked SharedPreferences passes

---

#### T-06: Write Country model unit tests
**Phase:** 2 — Models & Services
**Dependencies:** T-03
**Parallel Group:** C

Create `test/models/country_test.dart`:
- Test `fromJson` with valid JSON
- Test `fromJson` with missing fields (should throw)
- Test `flagUrl` returns correct format
- Test equality and hashCode

**Acceptance Criteria:**
- All tests pass
- Coverage > 90% for Country model

---

#### T-07: Implement GameViewModel core
**Phase:** 3 — ViewModel
**Dependencies:** T-03, T-04, T-05
**Parallel Group:** D

Create `lib/viewmodels/game_viewmodel.dart`:
- Extend `ChangeNotifier`
- State fields: `_allCountries`, `_solvedCodes`, `_availableCountries`, `_currentRound`, `_score`, `_isLoading`, `_errorMessage`
- Methods: `initialize()`, `submitAnswer(Country)`, `nextRound()`, `resetGame()`
- Round generation: pick correct + 3 distractors, shuffle
- Scoring: 10/8/5 points table
- Persist state after each change

**Acceptance Criteria:**
- ViewModel compiles
- `initialize()` loads persisted data and fetches countries
- `submitAnswer()` correctly awards points and updates state
- `nextRound()` generates valid round with 4 unique options
- `resetGame()` clears all state

---

#### T-08: Write GameViewModel unit tests
**Phase:** 3 — ViewModel
**Dependencies:** T-07
**Parallel Group:** E

Create `test/viewmodels/game_viewmodel_test.dart`:
- Test scoring: 1st try = 10, 2nd = 8, 3rd = 5, fail = 0
- Test round generation: 4 unique options, 1 correct
- Test solved codes are excluded from future rounds
- Test persistence calls (mock StorageService)
- Test reset functionality

**Acceptance Criteria:**
- All tests pass
- Coverage > 85% for GameViewModel

---

#### T-09: Create constants.dart
**Phase:** 1 — Project Setup
**Dependencies:** None
**Parallel Group:** A

Create `lib/utils/constants.dart`:
- `countriesApiUrl` — REST Countries endpoint
- `flagCdnBaseUrl` — flagcdn URL pattern
- `storageKeys` — SharedPreferences key names
- `pointsTable` — `{1: 10, 2: 8, 3: 5}`
- `maxAttempts` — 3

**Acceptance Criteria:**
- All constants defined and accessible

---

#### T-10: Create app_theme.dart
**Phase:** 1 — Project Setup
**Dependencies:** None
**Parallel Group:** A

Create `lib/utils/app_theme.dart`:
- `ThemeData` with Material 3
- Color scheme (seed color or custom)
- Typography settings
- Button theme data

**Acceptance Criteria:**
- Theme applies correctly in app

---

#### T-11: Build FlagCard widget
**Phase:** 4 — UI
**Dependencies:** T-09, T-10
**Parallel Group:** F

Create `lib/views/widgets/flag_card.dart`:
- `CachedNetworkImage` with placeholder and error widget
- Rounded corners, shadow
- Loading indicator while image loads
- Fallback icon on error

**Acceptance Criteria:**
- Displays flag image correctly
- Shows placeholder during load
- Shows error icon on failure
- **Successful run on emulator verified before PR**

---

#### T-12: Build AnswerButton widget
**Phase:** 4 — UI
**Dependencies:** T-09, T-10
**Parallel Group:** F

Create `lib/views/widgets/answer_button.dart`:
- States: default, correct, wrong, disabled
- Visual feedback for each state (color, icon)
- Callback on tap
- Disabled state prevents re-tap

**Acceptance Criteria:**
- All four states render correctly
- Tap callback fires only when enabled
- **Successful run on emulator verified before PR**

---

#### T-13: Build ScoreBar widget
**Phase:** 4 — UI
**Dependencies:** T-09, T-10
**Parallel Group:** F

Create `lib/views/widgets/score_bar.dart`:
- Displays current score with icon
- Animated score change (optional)
- Positioned at top of screen

**Acceptance Criteria:**
- Score displays correctly
- Updates when score changes
- **Successful run on emulator verified before PR**

---

#### T-14: Build RoundResult widget
**Phase:** 4 — UI
**Dependencies:** T-09, T-10
**Parallel Group:** F

Create `lib/views/widgets/round_result.dart`:
- Shows correct/incorrect feedback
- Displays points earned (or "No points")
- "Next" button to advance
- Snackbar or inline banner style

**Acceptance Criteria:**
- Correct state shows green + points
- Failed state shows correct answer
- Next button triggers callback
- **Successful run on emulator verified before PR**

---

#### T-15: Build HomeView screen
**Phase:** 4 — UI
**Dependencies:** T-07, T-11, T-12, T-13, T-14
**Parallel Group:** G

Create `lib/views/home_view.dart`:
- `Scaffold` with `ScoreBar` at top
- `FlagCard` in center
- 2×2 grid of `AnswerButton` widgets
- `RoundResult` shown after round resolves
- `Provider.of<GameViewModel>` for state
- Dispatch `submitAnswer` and `nextRound`

**Acceptance Criteria:**
- Full game screen renders correctly
- Answer taps dispatch to ViewModel
- Next button advances to new round
- Score updates in real-time
- **Successful run on emulator verified before PR**

---

#### T-16: Wire up Provider in main.dart
**Phase:** 4 — UI
**Dependencies:** T-07, T-15
**Parallel Group:** H

Update `lib/main.dart`:
- `MultiProvider` with `ChangeNotifierProvider<GameViewModel>`
- Call `initialize()` in constructor or `main()`
- Pass `HomeView` as home

**Acceptance Criteria:**
- App launches with Provider setup
- ViewModel initializes on startup
- **Successful run on emulator verified before PR**

---

#### T-17: Create app.dart with MaterialApp
**Phase:** 4 — UI
**Dependencies:** T-10, T-16
**Parallel Group:** I

Create `lib/app.dart`:
- `MaterialApp` with theme from `app_theme.dart`
- Set `home` to `HomeView`
- App title: "Country Trivia"

**Acceptance Criteria:**
- App runs with correct theme
- Navigation works
- **Successful run on emulator verified before PR**

---

#### T-18: Add loading & error states
**Phase:** 4 — UI
**Dependencies:** T-15
**Parallel Group:** J

Update `lib/views/home_view.dart`:
- Show `CircularProgressIndicator` while `_isLoading`
- Show error message with "Retry" button on `_errorMessage`
- Disable interaction during loading

**Acceptance Criteria:**
- Loading state shows spinner
- Error state shows message + retry
- Retry re-calls `initialize()`
- **Successful run on emulator verified before PR**

---

#### T-19: Add victory/reset flow
**Phase:** 6 — Polish & Edge Cases
**Dependencies:** T-15
**Parallel Group:** J

Update `lib/views/home_view.dart` and `game_viewmodel.dart`:
- Detect when `_availableCountries` is empty
- Show congratulatory dialog with final score
- "Play Again" button calls `resetGame()`

**Acceptance Criteria:**
- Victory dialog appears when all countries solved
- Reset clears state and starts new game
- **Successful run on emulator verified before PR**

---

#### T-20: Add animations & polish
**Phase:** 6 — Polish & Edge Cases
**Dependencies:** T-18, T-19
**Parallel Group:** K

Enhance UI:
- Flag fade-in animation
- Button press scale animation
- Score increment animation
- Snackbar slide-in
- Accessibility: semantic labels on all interactive elements

**Acceptance Criteria:**
- Animations are smooth (60fps)
- All interactive elements have semantic labels
- `flutter analyze` passes with no warnings
- **Successful run on emulator verified before PR**

---

#### T-21: Write widget tests
**Phase:** 7 — Testing
**Dependencies:** T-15
**Parallel Group:** L

Create `test/views/home_view_test.dart`:
- Test tapping correct answer increases score
- Test tapping wrong answer disables button
- Test 3 wrong answers reveals correct answer
- Test Next button advances to new round
- Test score persists across widget rebuilds

**Acceptance Criteria:**
- All widget tests pass
- Tests cover main user flows
- **Successful run on emulator verified before PR**

---

#### T-22: Write integration test
**Phase:** 7 — Testing
**Dependencies:** T-16, T-21
**Parallel Group:** M

Create `integration_test/app_test.dart`:
- Full game flow: launch → answer → next → answer → ...
- Verify persistence across app restart
- Verify solved flags don't repeat

**Acceptance Criteria:**
- Integration test passes
- Full user journey works end-to-end
- **Successful run on emulator verified before PR**

---

### 16.3 Parallel Execution Groups

```
Group A (Foundation — no dependencies):
├── T-01: Add dependencies to pubspec.yaml
├── T-02: Create lib/ folder structure
├── T-03: Implement Country model
├── T-09: Create constants.dart
└── T-10: Create app_theme.dart

Group B (Services — depends on T-01):
├── T-04: Implement ApiService
└── T-05: Implement StorageService

Group C (Model tests — depends on T-03):
└── T-06: Write Country model unit tests

Group D (ViewModel — depends on T-03, T-04, T-05):
└── T-07: Implement GameViewModel core

Group E (ViewModel tests — depends on T-07):
└── T-08: Write GameViewModel unit tests

Group F (UI Widgets — depends on T-09, T-10):
├── T-11: Build FlagCard widget
├── T-12: Build AnswerButton widget
├── T-13: Build ScoreBar widget
└── T-14: Build RoundResult widget

Group G (Main Screen — depends on T-07, T-11, T-12, T-13, T-14):
└── T-15: Build HomeView screen

Group H (Provider wiring — depends on T-07, T-15):
└── T-16: Wire up Provider in main.dart

Group I (App shell — depends on T-10, T-16):
└── T-17: Create app.dart with MaterialApp

Group J (Edge cases — depends on T-15):
├── T-18: Add loading & error states
└── T-19: Add victory/reset flow

Group K (Polish — depends on T-18, T-19):
└── T-20: Add animations & polish

Group L (Widget tests — depends on T-15):
└── T-21: Write widget tests

Group M (Integration tests — depends on T-16, T-21):
└── T-22: Write integration test
```

---

### 16.4 Execution Order (Critical Path)

```
Wave 1:  T-01, T-02, T-03, T-09, T-10          (Group A — parallel)
Wave 2:  T-04, T-05                             (Group B — parallel)
Wave 3:  T-06                                    (Group C)
Wave 4:  T-07                                    (Group D)
Wave 5:  T-08                                    (Group E)
Wave 6:  T-11, T-12, T-13, T-14                  (Group F — parallel)
Wave 7:  T-15                                    (Group G)
Wave 8:  T-16                                    (Group H)
Wave 9:  T-17                                    (Group I)
Wave 10: T-18, T-19                              (Group J — parallel)
Wave 11: T-20                                    (Group K)
Wave 12: T-21                                    (Group L)
Wave 13: T-22                                    (Group M)
```

**Critical Path:** T-01 → T-04 → T-07 → T-15 → T-16 → T-21 → T-22

**Minimum sequential steps:** 13 waves (with parallelization within each wave)

---

### 16.5 Dependency Graph

```
T-01 ──┬── T-04 ──┬── T-07 ──┬── T-15 ──┬── T-16 ── T-17
       │           │          │          │
T-02   │           │          │          └── T-18 ── T-20
       │           │          │
T-03 ──┼── T-06    │          └── T-19 ── T-20
       │           │
T-09 ──┼── T-11 ───┘
       ├── T-12
       ├── T-13
       └── T-14

T-10 ── T-17

T-07 ── T-08

T-15 ── T-21 ── T-22
```

---

*This plan is the single source of truth for implementation. Update it if requirements change during development.*
