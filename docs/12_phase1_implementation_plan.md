# 12 — Phase 1 Implementation Plan: Core Application Framework

> **Document Status:** 🟡 In Progress — Phase 1.1 Approved  
> **Last Updated:** 2026-05-30  
> **Phase:** 1 — Core Application Framework  
> **Owner:** Engineering Team  
> **Prerequisite:** Phase 0 🔒 LOCKED & APPROVED

---

## Checkpoint Structure (Approved)

Phase 1 is executed as **6 independent checkpoints**. Each checkpoint:
- Has its own dedicated implementation plan document
- Is implemented independently
- Is reviewed and approved independently
- Does NOT proceed to the next checkpoint until the current is approved

| Checkpoint | Title | Plan Document | Status |
|---|---|---|---|
| **1.1** | Project Bootstrap | [13_phase1_1_bootstrap_plan.md](13_phase1_1_bootstrap_plan.md) | 🟡 Planning — Awaiting Approval |
| 1.2 | Core Architecture | TBD after 1.1 approval | ⬜ Pending |
| 1.3 | Theme & Design System | TBD after 1.2 approval | ⬜ Pending |
| 1.4 | Storage Layer | TBD after 1.3 approval | ⬜ Pending |
| 1.5 | Observability Layer | TBD after 1.4 approval | ⬜ Pending |
| 1.6 | Framework Validation | TBD after 1.5 approval | ⬜ Pending |

> ⚠️ No checkpoint plan is created until the preceding checkpoint is approved. This document serves as the Phase 1 overview only.

---

---

## Goal

Build the complete, production-grade Flutter application skeleton for MemoVault.

No visible feature screens are built in this phase. The output is a runnable application that proves the entire technical foundation is solid: flavors, routing, DI, themes, offline storage, secure storage, logging, and crash reporting are all operational and tested.

---

## Scope

### In Scope
- Flutter project creation with `fvm` version pinning
- Three-flavor configuration (dev / staging / prod)
- GetX architecture wiring (routing, DI, services)
- Design system (theme, colors, typography, tokens)
- Global error handling and crash reporting (Crashlytics)
- Structured logging framework
- Network connectivity monitoring
- Isar database initialization and schema v1
- Flutter Secure Storage initialization
- SharedPreferences wrapper
- Root/jailbreak detection hook (passive — does not block yet)
- Android backup exclusion configuration
- iOS minimum version configuration
- `.gitignore` for all secrets and credentials

### Out of Scope
- Any feature UI (no notes screens, no messaging screens)
- Firebase Auth integration (Phase 4)
- Firestore integration (Phase 2+)
- Isar collections for notes or messages (Phase 2+)
- Any hidden layer route (Phase 3+)
- Activation keyword hash comparison logic (Phase 3)
- Note revision history subcollection writes (Phase 2)

---

## Requirements

### Functional Requirements
- [ ] App boots to a placeholder home screen in all three flavors
- [ ] Theme switches between light and dark mode
- [ ] Logging emits structured output to console (dev) and Crashlytics (prod)
- [ ] All navigation uses GetX named routes
- [ ] Dependency injection resolves all services at startup
- [ ] Isar database opens successfully with encryption key from Secure Storage
- [ ] Network connectivity state is observable app-wide
- [ ] Crash reporting captures unhandled exceptions in prod flavor

### Non-Functional Requirements
- [ ] App binary size: ≤ reasonable baseline (document at end of phase)
- [ ] Cold start time: ≤ 2 seconds on mid-range device
- [ ] Zero lint warnings (`flutter analyze` clean)
- [ ] All dependencies pinned (no `^` wildcards for critical packages)
- [ ] Flavor-specific app icons and app names visible on device
- [ ] `google-services.json` and `GoogleService-Info.plist` in `.gitignore`

---

## Dependencies

### Packages Required (planned — versions to be confirmed at implementation time)

| Package | Purpose | Category |
|---|---|---|
| `get` | State, routing, DI | Core |
| `isar` | Local database | Storage |
| `isar_flutter_libs` | Isar native binaries | Storage |
| `isar_generator` | Code generation | Dev |
| `flutter_secure_storage` | Encrypted key/token storage | Security |
| `shared_preferences` | Lightweight preferences | Storage |
| `firebase_core` | Firebase SDK bootstrap | Firebase |
| `firebase_crashlytics` | Crash reporting | Observability |
| `firebase_analytics` | Usage telemetry | Observability |
| `firebase_remote_config` | Feature flags + activation hash/salt delivery | Config |
| `connectivity_plus` | Network monitoring | Network |
| `flutter_jailbreak_detection` | Root/jailbreak detection hook | Security |
| `logger` | Structured logging | Observability |
| `freezed` | Immutable value objects | Architecture |
| `freezed_annotation` | Freezed annotations | Architecture |
| `json_annotation` | JSON serialization annotations | Architecture |
| `json_serializable` | JSON code generation | Dev |
| `build_runner` | Code generation runner | Dev |
| `flutter_flavorizr` | Flavor setup tooling | Build |
| `google_fonts` | Typography | UI |

### External Prerequisites
- Flutter installed via `fvm` (specific version TBD — latest stable at implementation start)
- Firebase projects created: `memovault-dev`, `memovault-staging`, `memovault-prod`
- `google-services.json` downloaded per flavor (Android)
- `GoogleService-Info.plist` downloaded per flavor (iOS)
- Crashlytics enabled in Firebase console for all three projects

---

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| `flutter_jailbreak_detection` conflicts with flavor config | Low | Low | Test early; remove if unresolvable — it's a passive hook only |
| Isar native binary size increases app size significantly | Medium | Low | Measure and document; acceptable per ADR-009 |
| Firebase project credentials not available at implementation start | Medium | High | Create placeholder flavor config; Firebase team creates projects in parallel |
| `flutter_flavorizr` generates incorrect Xcode config | Medium | Medium | Test each flavor on actual iOS simulator immediately after generation |
| GetX routing incompatibility with latest Flutter | Low | High | Pin Flutter version before any work; test navigation immediately after framework setup |

---

## Edge Cases

- [ ] App launched for the first time — Isar encryption key does not yet exist → must generate and persist before database open
- [ ] Secure Storage read fails on first launch (rare device issue) → app must handle gracefully with a meaningful error, not crash
- [ ] Device has no internet on first launch → app must reach home screen without hanging on Firebase initialization
- [ ] Dev flavor Firebase emulator not running → app must fall back gracefully, not crash
- [ ] App killed mid-Isar initialization → on next launch, database must re-open cleanly (no corruption)
- [ ] Light/dark mode changes while app is running → theme must update reactively without restart

---

## Security Considerations

- [ ] `google-services.json` and `GoogleService-Info.plist` are in `.gitignore` from commit 1
- [ ] `android:allowBackup="false"` set in `AndroidManifest.xml` (prevents Auto Backup of Isar DB)
- [ ] Isar encryption key generated using `dart:math` `Random.secure()` — not `Random()`
- [ ] Encryption key stored with `FlutterSecureStorage` option `accessibleAfterFirstUnlock: true` (iOS) to allow background access
- [ ] No secrets hardcoded anywhere in source code
- [ ] Crashlytics configured to NOT collect personally identifiable information
- [ ] Analytics collection disabled in `dev` flavor; enabled in `prod`
- [ ] `--obfuscate --split-debug-info` flags added to prod build script from day one

---

## Data Flow

```
App Launch
    │
    ├── 1. runZonedGuarded() wraps everything (global crash catch)
    │
    ├── 2. WidgetsFlutterBinding.ensureInitialized()
    │
    ├── 3. Firebase.initializeApp() (flavor-aware config)
    │
    ├── 4. AppBinding.dependencies() registered
    │       ├── LogService (permanent)
    │       ├── SecureStorageService (permanent)
    │       ├── IsarService (permanent) ← reads encryption key from SecureStorageService
    │       ├── ConnectivityService (permanent)
    │       └── RemoteConfigService (permanent)
    │
    ├── 5. FlutterError.onError → Crashlytics
    │
    ├── 6. GetMaterialApp initializes
    │       ├── Theme (light/dark from system preference)
    │       └── Initial route: AppRoutes.home
    │
    └── 7. Home screen renders (placeholder)
```

---

## Testing Strategy

### Unit Tests
- `SecureStorageService` — test key generation, read, write, delete
- `IsarService` — test database open, encryption key loading, graceful failure handling
- `ConnectivityService` — test observable state changes (mock connectivity)
- `LogService` — test log level filtering per flavor
- `ThemeService` — test theme mode switching and persistence

### Widget Tests
- `HomeScreen` placeholder — renders without error in all three themes

### Integration Tests
- App boots cleanly in all three flavors on Android emulator
- App boots cleanly in all three flavors on iOS simulator
- Theme switches correctly on system preference change

### Manual Verification Checklist
- [ ] Run `flutter run --flavor dev` — app launches on Android emulator
- [ ] Run `flutter run --flavor dev` on iOS simulator
- [ ] Run `flutter run --flavor staging` — different app name/icon visible
- [ ] Run `flutter run --flavor prod` — prod flavor uses prod Firebase config
- [ ] Toggle system dark mode — app theme updates reactively
- [ ] Kill app mid-run — re-launch, Isar opens cleanly
- [ ] Run `flutter analyze` — zero warnings
- [ ] Run `flutter test` — all tests pass

---

## Sub-Phases

### Phase 1.1 — Environment & Flavors

**Goal:** Working Flutter project with three flavors, fvm version pinning, and correct Firebase config per flavor.

**Files Expected:**
- `[NEW]` `.fvmrc` — Flutter version pin
- `[NEW]` `pubspec.yaml` — all dependencies declared
- `[NEW]` `analysis_options.yaml` — linting rules
- `[NEW]` `.gitignore` — secrets, build artifacts, generated files excluded
- `[NEW]` `android/app/build.gradle` — flavor config
- `[NEW]` `android/app/src/dev/` — dev-flavor Android resources
- `[NEW]` `android/app/src/staging/` — staging-flavor Android resources
- `[NEW]` `android/app/src/prod/` — prod-flavor Android resources
- `[NEW]` `android/app/google-services-dev.json` *(gitignored)*
- `[NEW]` `android/app/google-services-staging.json` *(gitignored)*
- `[NEW]` `android/app/google-services-prod.json` *(gitignored)*
- `[NEW]` `ios/config/dev/GoogleService-Info.plist` *(gitignored)*
- `[NEW]` `ios/config/staging/GoogleService-Info.plist` *(gitignored)*
- `[NEW]` `ios/config/prod/GoogleService-Info.plist` *(gitignored)*
- `[NEW]` `lib/main_dev.dart` — dev entry point
- `[NEW]` `lib/main_staging.dart` — staging entry point
- `[NEW]` `lib/main_prod.dart` — production entry point
- `[NEW]` `lib/app.dart` — root `GetMaterialApp`

**Acceptance Criteria:**
- [ ] `fvm flutter run --flavor dev -t lib/main_dev.dart` boots on Android
- [ ] `fvm flutter run --flavor dev -t lib/main_dev.dart` boots on iOS
- [ ] Each flavor shows its unique app name and icon
- [ ] Firebase initialized with the correct project per flavor

---

### Phase 1.2 — Core Architecture

**Goal:** GetX DI and service locator operational; all core services registered.

**Files Expected:**
- `[NEW]` `lib/core/services/log_service.dart`
- `[NEW]` `lib/core/services/secure_storage_service.dart`
- `[NEW]` `lib/core/services/connectivity_service.dart`
- `[NEW]` `lib/core/services/remote_config_service.dart`
- `[NEW]` `lib/core/bindings/app_binding.dart` — root DI binding
- `[NEW]` `lib/core/errors/app_failure.dart` — Freezed failure types
- `[NEW]` `lib/core/errors/app_failure.freezed.dart` *(generated)*
- `[NEW]` `lib/core/constants/app_constants.dart`
- `[NEW]` `lib/core/constants/storage_keys.dart`

**Acceptance Criteria:**
- [ ] `Get.find<LogService>()` resolves without error
- [ ] `Get.find<SecureStorageService>()` resolves without error
- [ ] `Get.find<ConnectivityService>()` resolves without error
- [ ] All failures use `AppFailure` sealed types — no raw exceptions across layers

---

### Phase 1.3 — Routing & Navigation

**Goal:** GetX named route system operational with route guard infrastructure.

**Files Expected:**
- `[NEW]` `lib/core/routes/app_routes.dart` — route name constants
- `[NEW]` `lib/core/routes/app_pages.dart` — route definitions with bindings
- `[NEW]` `lib/core/routes/middlewares/auth_middleware.dart` — auth guard (stub for now)
- `[NEW]` `lib/features/home/views/home_screen.dart` — placeholder home screen

**Acceptance Criteria:**
- [ ] App navigates to `/home` on launch
- [ ] `Get.toNamed()` navigates between routes without error
- [ ] Route middleware infrastructure in place (even if not enforcing yet)
- [ ] No `Navigator.push()` calls anywhere in codebase

---

### Phase 1.4 — Theme System

**Goal:** Complete design system with light/dark modes, typography, and color tokens.

**Files Expected:**
- `[NEW]` `lib/core/theme/app_theme.dart` — `ThemeData` for light and dark
- `[NEW]` `lib/core/theme/app_colors.dart` — color palette constants
- `[NEW]` `lib/core/theme/app_typography.dart` — text styles (Google Fonts)
- `[NEW]` `lib/core/theme/app_spacing.dart` — spacing tokens
- `[NEW]` `lib/core/services/theme_service.dart` — reactive theme mode controller

**Design Tokens — MemoVault Aesthetic:**
- Font: `Lora` (serif — premium, intimate feel for a vault/notes app)
- Accent: Deep burgundy / rose gold palette (warm, private, premium)
- Dark mode: Near-black `#0D0D0D` with warm grey surfaces
- Light mode: Warm white `#FAFAF8` with soft cream surfaces
- Corner radius: 16px (cards), 12px (inputs), 8px (chips)

**Acceptance Criteria:**
- [ ] Theme switches between light and dark reactively
- [ ] All text uses defined typography styles (no raw `TextStyle` in screens)
- [ ] All colors reference `AppColors` constants (no hex codes in screen code)
- [ ] Theme persists across app restarts via `SharedPreferences`

---

### Phase 1.5 — Storage & Security Layer

**Goal:** Isar database and Flutter Secure Storage both initialized and operational.

**Files Expected:**
- `[NEW]` `lib/core/services/isar_service.dart` — database open, encryption key management
- `[NEW]` `lib/core/services/preferences_service.dart` — SharedPreferences wrapper
- `[NEW]` `lib/data/models/.gitkeep` — placeholder (collections added Phase 2+)
- `[MODIFY]` `android/app/src/main/AndroidManifest.xml` — `allowBackup="false"`
- `[MODIFY]` `ios/Runner/Info.plist` — iOS minimum version 15.0 deployment target

**Isar Initialization Flow:**
```dart
Future<void> _openDatabase() async {
  // 1. Try to read existing key from Secure Storage
  String? encodedKey = await _secureStorage.read(key: StorageKeys.isarKey);

  // 2. If no key exists, generate and persist one
  if (encodedKey == null) {
    final key = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    encodedKey = base64Encode(key);
    await _secureStorage.write(key: StorageKeys.isarKey, value: encodedKey);
  }

  // 3. Open Isar with encryption key
  _isar = await Isar.open(
    schemas,  // Empty in Phase 1; collections added per-phase
    encryptionKey: base64Decode(encodedKey),
    directory: (await getApplicationDocumentsDirectory()).path,
  );
}
```

**Acceptance Criteria:**
- [ ] Isar opens successfully on fresh install
- [ ] Isar opens with same encryption key on subsequent launches
- [ ] If Secure Storage read fails → error logged, user informed (no silent crash)
- [ ] `android:allowBackup="false"` verified in built APK manifest
- [ ] iOS deployment target is 15.0 in Xcode project settings

---

### Phase 1.6 — Logging & Crash Handling

**Goal:** Structured logging and Crashlytics crash reporting operational.

**Files Expected:**
- `[MODIFY]` `lib/core/services/log_service.dart` — full implementation with level filtering
- `[MODIFY]` `lib/main_dev.dart`, `lib/main_staging.dart`, `lib/main_prod.dart` — `runZonedGuarded` wrapper
- `[NEW]` `lib/core/utils/crash_handler.dart` — Crashlytics + FlutterError integration

**Log Level Policy:**
| Flavor | Levels Active |
|---|---|
| `dev` | verbose, debug, info, warning, error, fatal |
| `staging` | info, warning, error, fatal |
| `prod` | warning, error, fatal |

**Crashlytics Integration:**
```dart
// In main_prod.dart only
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
runZonedGuarded(
  () => runApp(const App()),
  (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  },
);
```

**Acceptance Criteria:**
- [ ] `LogService.debug('test')` in dev produces console output
- [ ] `LogService.debug('test')` in prod produces NO console output
- [ ] Throwing an unhandled exception in prod → appears in Crashlytics dashboard within 2 minutes
- [ ] Crashlytics user identifier is NOT set (privacy — no PII in crash reports)

---

## Full File Change Expectation

> A complete list of all files that will be created or modified in Phase 1.

```
[NEW] .fvmrc
[NEW] pubspec.yaml
[NEW] analysis_options.yaml
[NEW] .gitignore
[NEW] README.md (update phase status)
[NEW] lib/main_dev.dart
[NEW] lib/main_staging.dart
[NEW] lib/main_prod.dart
[NEW] lib/app.dart
[NEW] lib/core/constants/app_constants.dart
[NEW] lib/core/constants/storage_keys.dart
[NEW] lib/core/errors/app_failure.dart
[NEW] lib/core/errors/app_failure.freezed.dart  (generated)
[NEW] lib/core/extensions/ (placeholder)
[NEW] lib/core/routes/app_routes.dart
[NEW] lib/core/routes/app_pages.dart
[NEW] lib/core/routes/middlewares/auth_middleware.dart
[NEW] lib/core/bindings/app_binding.dart
[NEW] lib/core/services/log_service.dart
[NEW] lib/core/services/secure_storage_service.dart
[NEW] lib/core/services/isar_service.dart
[NEW] lib/core/services/connectivity_service.dart
[NEW] lib/core/services/preferences_service.dart
[NEW] lib/core/services/theme_service.dart
[NEW] lib/core/services/remote_config_service.dart
[NEW] lib/core/theme/app_theme.dart
[NEW] lib/core/theme/app_colors.dart
[NEW] lib/core/theme/app_typography.dart
[NEW] lib/core/theme/app_spacing.dart
[NEW] lib/core/utils/crash_handler.dart
[NEW] lib/core/widgets/ (placeholder)
[NEW] lib/data/models/ (placeholder)
[NEW] lib/data/repositories/ (placeholder)
[NEW] lib/data/sources/local/ (placeholder)
[NEW] lib/data/sources/remote/ (placeholder)
[NEW] lib/features/home/views/home_screen.dart
[NEW] lib/features/home/controllers/home_controller.dart
[NEW] lib/features/home/bindings/home_binding.dart
[MODIFY] android/app/build.gradle  (flavor config)
[MODIFY] android/app/src/main/AndroidManifest.xml  (allowBackup=false)
[MODIFY] ios/Runner.xcodeproj/  (deployment target, flavor schemes)
[MODIFY] ios/Runner/Info.plist  (minimum iOS 15)
[NEW] test/unit/core/services/log_service_test.dart
[NEW] test/unit/core/services/secure_storage_service_test.dart
[NEW] test/unit/core/services/isar_service_test.dart
[NEW] test/unit/core/services/connectivity_service_test.dart
[NEW] test/widget/features/home/home_screen_test.dart
```

---

## Acceptance Criteria (Phase 1 Complete)

- [ ] `fvm flutter analyze` — zero warnings or errors
- [ ] `fvm flutter test` — all tests pass
- [ ] App runs on Android emulator (all 3 flavors)
- [ ] App runs on iOS simulator (all 3 flavors)
- [ ] Each flavor has distinct app name and icon on device home screen
- [ ] Theme switches between light and dark without restart
- [ ] Isar opens and persists encryption key correctly across restarts
- [ ] An intentional crash in prod flavor appears in Firebase Crashlytics
- [ ] `git log --oneline` shows clean, conventional commit history
- [ ] All secrets are gitignored — `git status` shows no credential files
- [ ] All dependencies are pinned in `pubspec.yaml`
- [ ] `DEPENDENCIES.md` created documenting each package and version

---

## Phase 1 Completion Checklist

Before declaring Phase 1 complete, the following must be verified:

```
[ ] All acceptance criteria above checked
[ ] docs/03_development_roadmap.md Phase 1 exit criteria checked
[ ] docs/10_changelog.md updated with Phase 1 changes
[ ] docs/01_project_overview.md phase status updated
[ ] DEPENDENCIES.md created
[ ] No TODO comments without linked issues remain in code
[ ] Security considerations verified (gitignore, backup exclusion, obfuscation flags)
[ ] Phase 2 implementation plan created before Phase 2 begins
```

---

> **⚠️ This plan requires approval before any code is written.**  
> Awaiting confirmation to proceed to Phase 1 execution.
