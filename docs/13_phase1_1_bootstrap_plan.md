# 13 — Phase 1.1: Project Bootstrap

> **Document Status:** Awaiting Approval  
> **Last Updated:** 2026-05-30  
> **Checkpoint:** 1.1 of 6 — Project Bootstrap  
> **Owner:** Engineering Team  
> **Prerequisite:** Phase 0 🔒 LOCKED & APPROVED  
> **Next Checkpoint:** 1.2 — Core Architecture (plan created after 1.1 approval)

---

## Goal

Create the absolute minimum production foundation for the MemoVault Flutter application.

No business logic. No feature screens. No services. No state management wiring.

The sole output is a **runnable Flutter application** that boots cleanly across three flavors, passes all static analysis, has a clean Git history, and is built on a locked version of Flutter.

---

## Scope

### In Scope

| Deliverable | Description |
|---|---|
| Flutter project initialization | Clean `flutter create` project in `memovault` directory |
| FVM version pinning | Flutter version locked via `.fvmrc` committed to repo |
| Git repository setup | `.gitignore`, initial commit, conventional commit policy enforced |
| Analysis options | `analysis_options.yaml` with strict linting rules |
| Three-flavor configuration | `dev`, `staging`, `prod` flavors via `flutter_flavorizr` |
| Flavor-specific app names | MemoVault Dev / MemoVault Staging / MemoVault |
| Flavor-specific app icons | Distinct icons per flavor (colored badge for dev/staging) |
| Firebase project wiring | `google-services.json` and `GoogleService-Info.plist` per flavor (gitignored) |
| Basic CI validation script | `flutter analyze` + `flutter test` in a shell script for local use |
| Placeholder entry points | `main_dev.dart`, `main_staging.dart`, `main_prod.dart` |
| Placeholder App widget | `app.dart` — `GetMaterialApp` with hardcoded home placeholder |
| Placeholder home screen | `HomeScreen` — blank scaffold, app name text only |
| `AppRoutes` class | `app_routes.dart` — route name constants only, no pages/bindings |

### Explicitly Out of Scope

| Item | Reason |
|---|---|
| GetX routing (pages, middleware, guards) | Phase 1.2 |
| GetX DI / bindings | Phase 1.2 |
| Any services | Phase 1.2 |
| Controllers | Phase 1.2 |
| Repositories | Phase 1.2 |
| Isar / Secure Storage | Phase 1.4 |
| Theme system | Phase 1.3 |
| Logging / Crashlytics | Phase 1.5 |
| Any feature UI | Phase 2+ |
| Firebase Auth | Phase 4 |
| Firestore | Phase 2+ |

---

## Requirements

### Functional Requirements

- [ ] App boots in `dev` flavor with app name "MemoVault Dev"
- [ ] App boots in `staging` flavor with app name "MemoVault Staging"
- [ ] App boots in `prod` flavor with app name "MemoVault"
- [ ] Each flavor has a visually distinct icon on the device home screen
- [ ] Each flavor connects to its own Firebase project (dev / staging / prod)
- [ ] Placeholder home screen renders — no crashes, no errors

### Non-Functional Requirements

- [ ] `flutter analyze` passes with zero warnings and zero errors
- [ ] `flutter test` passes (no tests yet — passes trivially)
- [ ] Flutter version pinned in `.fvmrc`
- [ ] All dependencies pinned in `pubspec.yaml` (no `^` wildcards for critical packages)
- [ ] `google-services.json` and `GoogleService-Info.plist` are in `.gitignore`
- [ ] Git history is clean with conventional commit messages
- [ ] No TODO, FIXME, or placeholder comments left without an issue reference

---

## External Prerequisites

These must be ready **before implementation begins**:

| Prerequisite | Owner | Notes |
|---|---|---|
| Firebase project: `memovault-dev` created | Admin | Enable Firestore, Auth, Crashlytics, Analytics, Remote Config |
| Firebase project: `memovault-staging` created | Admin | Same services as dev |
| Firebase project: `memovault-prod` created | Admin | Same services, hardened rules |
| `google-services.json` downloaded (dev, staging, prod) | Admin | One file per flavor |
| `GoogleService-Info.plist` downloaded (dev, staging, prod) | Admin | One file per flavor |
| Flutter stable version confirmed (latest stable at start) | Engineering | Record exact version in `.fvmrc` |

> ⚠️ If Firebase projects are not yet created, implementation may proceed with **placeholder Firebase configs** (emulator mode only). Production configs must be wired before Phase 1.1 is marked complete.

---

## Packages

Only the absolute minimum packages required for project bootstrap:

| Package | Version | Purpose | Type |
|---|---|---|---|
| `firebase_core` | pinned | Firebase SDK initialization | Runtime |
| `get` | pinned | `GetMaterialApp` root widget + route name constants | Runtime |
| `flutter_flavorizr` | pinned | Flavor configuration tooling | Dev |

> **Note on `get`:** Only `GetMaterialApp` and `AppRoutes` string constants are used in Phase 1.1. No controllers, bindings, services, repositories, or DI are wired. The full GetX architecture is Phase 1.2.

> All other packages (GetX, Isar, logger, etc.) are declared in their respective checkpoint plans and added to `pubspec.yaml` at that time — not before.

---

## File Structure (End State of Phase 1.1)

```
memovault/
├── .fvmrc                              [NEW] Flutter version pin
├── .gitignore                          [NEW] Secrets, build artifacts, generated files
├── analysis_options.yaml               [NEW] Strict linting configuration
├── pubspec.yaml                        [NEW] Dependencies — firebase_core + get
├── README.md                           [NEW] Project-level quick-start
│
├── android/
│   ├── app/
│   │   ├── build.gradle                [MODIFY] Flavor config: dev / staging / prod
│   │   ├── src/
│   │   │   ├── dev/                    [NEW] Dev flavor resources
│   │   │   │   ├── AndroidManifest.xml (app name: MemoVault Dev)
│   │   │   │   └── res/mipmap-*/       (dev app icon)
│   │   │   ├── staging/                [NEW] Staging flavor resources
│   │   │   │   ├── AndroidManifest.xml (app name: MemoVault Staging)
│   │   │   │   └── res/mipmap-*/       (staging app icon)
│   │   │   └── prod/                   [NEW] Prod flavor resources
│   │   │       ├── AndroidManifest.xml (app name: MemoVault)
│   │   │       └── res/mipmap-*/       (prod app icon)
│   │   └── google-services.json        [GITIGNORED] Prod Firebase config
│
├── ios/
│   ├── Runner.xcodeproj/               [MODIFY] Flavor scheme config
│   ├── config/
│   │   ├── dev/
│   │   │   └── GoogleService-Info.plist   [GITIGNORED]
│   │   ├── staging/
│   │   │   └── GoogleService-Info.plist   [GITIGNORED]
│   │   └── prod/
│   │       └── GoogleService-Info.plist   [GITIGNORED]
│   └── Runner/
│       └── Info.plist                  [MODIFY] Deployment target: iOS 15.0
│
└── lib/
    ├── main_dev.dart                   [NEW] Dev entry point
    ├── main_staging.dart               [NEW] Staging entry point
    ├── main_prod.dart                  [NEW] Prod entry point
    ├── app.dart                        [NEW] Root GetMaterialApp widget
    ├── core/
    │   └── routes/
    │       └── app_routes.dart         [NEW] Route name constants only
    └── features/
        └── home/
            └── views/
                └── home_screen.dart    [NEW] Placeholder home screen
```

---

## Implementation Steps

### Step 1 — FVM Setup

```bash
# Install fvm if not installed
dart pub global activate fvm

# Install latest stable Flutter
fvm install stable

# Pin the version in the project
fvm use stable --force
```

- Commit `.fvmrc` immediately after pinning
- Record the exact Flutter version in this document after pinning

---

### Step 2 — Flutter Project Creation

```bash
fvm flutter create \
  --org com.memovault \
  --project-name memovault \
  --platforms android,ios \
  .
```

- Organization: `com.memovault`
- Project name: `memovault`
- Platforms: Android and iOS only (no web, desktop)
- Delete auto-generated test file content but keep `test/` directory
- Delete auto-generated `lib/main.dart` content (replaced by flavor entry points)

---

### Step 3 — .gitignore

Create `.gitignore` before the first commit. Must include:

```gitignore
# Flutter / Dart
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
build/
*.g.dart
*.freezed.dart

# Firebase credentials — NEVER commit these
**/google-services.json
**/GoogleService-Info.plist
**/*.env
**/.env.*

# FVM
.fvm/flutter_sdk

# IDE
.idea/
.vscode/
*.iml

# macOS
.DS_Store

# Generated
coverage/
doc/api/
```

---

### Step 4 — analysis_options.yaml

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  errors:
    # Treat warnings as errors in CI
    unused_import: error
    unused_local_variable: error
    dead_code: error
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"

linter:
  rules:
    # Style
    - always_declare_return_types
    - prefer_final_locals
    - prefer_const_constructors
    - prefer_single_quotes
    # Safety
    - avoid_print
    - avoid_dynamic_calls
    - cast_nullable_to_non_nullable
    # Architecture
    - avoid_relative_lib_imports
    - always_use_package_imports
```

---

### Step 5 — pubspec.yaml

```yaml
name: memovault
description: MemoVault — Your secure personal vault.
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  firebase_core: 3.6.0   # Pin exact version — no ^
  get: 4.6.6             # Pin exact version — GetMaterialApp + route constants only

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: 4.0.0   # Pin exact version
  flutter_flavorizr: 2.2.3   # Pin exact version

flutter:
  uses-material-design: true
```

> All versions pinned exactly (no `^`). Versions confirmed at implementation time — update this document with the exact versions used.

---

### Step 6 — Flavor Setup (flutter_flavorizr)

Add `flavorizr` config to `pubspec.yaml`:

```yaml
flavorizr:
  app:
    android:
      flavorDimensions: "flavor-type"
    ios: {}

  flavors:
    dev:
      app:
        name: "MemoVault Dev"
      android:
        applicationId: "com.memovault.dev"
        icon: "assets/icons/icon_dev.png"
      ios:
        bundleId: "com.memovault.dev"
        icon: "assets/icons/icon_dev.png"

    staging:
      app:
        name: "MemoVault Staging"
      android:
        applicationId: "com.memovault.staging"
        icon: "assets/icons/icon_staging.png"
      ios:
        bundleId: "com.memovault.staging"
        icon: "assets/icons/icon_staging.png"

    prod:
      app:
        name: "MemoVault"
      android:
        applicationId: "com.memovault"
        icon: "assets/icons/icon_prod.png"
      ios:
        bundleId: "com.memovault"
        icon: "assets/icons/icon_prod.png"
```

Run:

```bash
fvm flutter pub get
fvm flutter pub run flutter_flavorizr
```

**Flavor Icons:**
- `icon_prod.png` — MemoVault primary icon (1024×1024 PNG)
- `icon_dev.png` — Same icon with a yellow "DEV" banner overlay
- `icon_staging.png` — Same icon with an orange "STG" banner overlay
- Place all icons in `assets/icons/` before running flavorizr

---

### Step 7 — Firebase Integration Per Flavor

**Android:**

Each flavor reads its own `google-services.json`. Place files at:
```
android/app/src/dev/google-services.json       ← gitignored
android/app/src/staging/google-services.json   ← gitignored
android/app/src/prod/google-services.json      ← gitignored
```

In `android/app/build.gradle`:
```groovy
android {
    flavorDimensions "flavor-type"

    productFlavors {
        dev {
            dimension "flavor-type"
            applicationId "com.memovault.dev"
            // google-services.json is read from src/dev/ automatically
        }
        staging {
            dimension "flavor-type"
            applicationId "com.memovault.staging"
        }
        prod {
            dimension "flavor-type"
            applicationId "com.memovault"
        }
    }
}
```

**iOS:**

Add a Run Script Build Phase in Xcode to copy the correct `GoogleService-Info.plist` based on the active scheme:

```bash
# Xcode Run Script (Build Phase — before Compile Sources)
case "${CONFIGURATION}" in
    "Debug-dev" | "Release-dev" )
      cp "${PROJECT_DIR}/config/dev/GoogleService-Info.plist" \
         "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
      ;;
    "Debug-staging" | "Release-staging" )
      cp "${PROJECT_DIR}/config/staging/GoogleService-Info.plist" \
         "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
      ;;
    * )
      cp "${PROJECT_DIR}/config/prod/GoogleService-Info.plist" \
         "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
      ;;
esac
```

---

### Step 8 — AppRoutes Class

**`lib/core/routes/app_routes.dart`:**

```dart
/// Route name constants for MemoVault.
///
/// Phase 1.1: Constants only — no GetPage list, no bindings, no middleware.
/// Full routing wiring is Phase 1.2.
abstract final class AppRoutes {
  static const String home = '/home';
}
```

> **Scope boundary:** This file defines string constants only. `GetPage` definitions, `GetMiddleware` guards, and binding associations are all Phase 1.2. Do NOT add them here.

---

### Step 9 — Flavor Entry Points & App Widget

**`lib/main_dev.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:memovault/app.dart';

/// Development flavor entry point.
/// Firebase initialization: configure memovault-dev credentials before enabling.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO(phase-1.1): Uncomment when google-services.json is configured
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptionsDev.currentPlatform,
  // );
  runApp(const App());
}
```

> `main_staging.dart` and `main_prod.dart` follow the identical pattern with their respective comments referencing the correct Firebase project.

**`lib/app.dart`:**

```dart
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:memovault/core/routes/app_routes.dart';
import 'package:memovault/features/home/views/home_screen.dart';

/// Root application widget.
///
/// Uses [GetMaterialApp] as the foundation for Phase 1 GetX integration.
/// Route pages and bindings are wired in Phase 1.2.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'MemoVault',
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.home,
      // GetPages populated in Phase 1.2
      home: const HomeScreen(),
    );
  }
}
```

**`lib/features/home/views/home_screen.dart`:**

```dart
import 'package:flutter/material.dart';

/// Placeholder home screen — Phase 1.1 bootstrap only.
/// All real UI is implemented in Phase 2+.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('MemoVault — Framework Checkpoint 1.1'),
      ),
    );
  }
}
```

---

### Step 9 — Git Initialization

```bash
git init
git add .gitignore
git commit -m "chore: add gitignore"

git add analysis_options.yaml pubspec.yaml .fvmrc
git commit -m "chore: initialize flutter project with fvm and strict linting"

git add android/ ios/
git commit -m "chore: configure three-flavor setup (dev/staging/prod)"

git add lib/
git commit -m "feat: add placeholder entry points and home screen"
```

**Commit Convention (enforced from day one):**
- `feat:` — new feature
- `fix:` — bug fix
- `chore:` — tooling, config, deps
- `docs:` — documentation only
- `refactor:` — code change with no behaviour change
- `test:` — adding or updating tests

---

## Security Checklist

- [ ] `google-services.json` verified absent from `git status` (gitignored)
- [ ] `GoogleService-Info.plist` verified absent from `git status` (gitignored)
- [ ] `android:allowBackup="false"` set in all three `AndroidManifest.xml` flavor files
- [ ] iOS deployment target set to `15.0` in Xcode project settings
- [ ] No hardcoded strings in any source file
- [ ] `debugShowCheckedModeBanner: false` in all entry points

---

## Edge Cases

| Scenario | Expected Behavior |
|---|---|
| Firebase credentials not yet available | App boots with emulator config; `firebase_options_*.dart` uses emulator host; document as known limitation |
| `flutter_flavorizr` generates incorrect Xcode scheme | Manually verify each scheme in Xcode → Product → Scheme → Manage Schemes; fix before marking complete |
| Dev icon looks identical to prod icon | Use distinct color overlays — unacceptable for dev/staging to look identical to prod |
| `google-services.json` accidentally staged | `git rm --cached` immediately; verify `.gitignore` rule; audit history before any push |

---

## Risks

| Risk | Probability | Mitigation |
|---|---|---|
| `flutter_flavorizr` generates malformed Xcode config | Medium | Test boot on iOS simulator immediately after generation |
| Firebase iOS plist copy script silently fails | Low | Verify correct plist used by logging Firebase project ID on app boot |
| FVM not installed on dev machine | Low | Document install instructions in `README.md` |
| App icon generation tool produces incorrect sizes | Low | Verify icons appear correctly on both Android emulator and iOS simulator |

---

## Testing

### No Unit Tests in Phase 1.1

Unit tests are added starting Phase 1.2 (architecture layer). Phase 1.1 has no business logic to test.

The `test/` directory must exist with an empty `widget_test.dart` file that passes:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/app.dart';

void main() {
  testWidgets('App renders without crashing', (tester) async {
    await tester.pumpWidget(const App());
    expect(find.byType(App), findsOneWidget);
  });
}
```

> This test will fail until Firebase is initialized. Wrap with a mock Firebase initializer if needed.

---

## Acceptance Criteria

All of the following must be true before Phase 1.1 is marked complete and Phase 1.2 begins:

```
[ ] fvm flutter run --flavor dev -t lib/main_dev.dart
    → App launches on Android emulator
    → App name on home screen: "MemoVault Dev"
    → Dev icon visible

[ ] fvm flutter run --flavor dev -t lib/main_dev.dart
    → App launches on iOS simulator
    → App name: "MemoVault Dev"

[ ] fvm flutter run --flavor staging -t lib/main_staging.dart
    → App launches on Android emulator
    → App name: "MemoVault Staging"
    → Staging icon visible (visually distinct from dev and prod)

[ ] fvm flutter run --flavor prod -t lib/main_prod.dart
    → App launches on Android emulator
    → App name: "MemoVault"
    → Prod icon visible

[ ] fvm flutter analyze
    → Exit code: 0
    → Output: "No issues found!"

[ ] fvm flutter test
    → Exit code: 0
    → All tests pass

[ ] git log --oneline
    → Clean conventional commits, no "WIP" or "temp" messages

[ ] git status
    → No google-services.json or GoogleService-Info.plist visible
    → No untracked credential files

[ ] android:allowBackup="false" in all three AndroidManifest.xml files

[ ] iOS deployment target = 15.0 in Xcode project settings
```

---

## Phase 1.1 Completion Checklist

Before requesting Phase 1.2 plan creation:

```
[ ] All acceptance criteria above are verified
[ ] Flutter version recorded in .fvmrc and in this document
[ ] Exact package versions recorded in pubspec.yaml
[ ] docs/10_changelog.md updated with Phase 1.1 changes
[ ] docs/12_phase1_implementation_plan.md checkpoint table updated (1.1 → ✅ Complete)
[ ] docs/13_phase1_1_bootstrap_plan.md status updated (✅ Complete)
[ ] README.md phase status updated (1.1 → ✅ Complete, 1.2 → 🟡 Planning)
[ ] Request Phase 1.2 plan creation
```

---

> **⚠️ This plan requires approval before any code is written.**  
> Awaiting confirmation to proceed to Phase 1.1 implementation.
