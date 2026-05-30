# 10 — Change Log

> **Document Status:** Living Document  
> **Last Updated:** 2026-05-30  
> **Format:** [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) — [Semantic Versioning](https://semver.org/)

---

## [Unreleased]

### Added (Phase 1.4 Storage Layer — 2026-05-30)
- `docs/16_phase1_4_storage_layer_plan.md` — Detailed implementation plan for Phase 1.4 Storage Layer (Revised)
- `lib/core/services/preferences_service.dart` — PreferencesService abstract interface
- `lib/core/services/preferences_service_impl.dart` — Implementation of PreferencesService using SharedPreferencesAsync
- `lib/core/services/secure_storage_service.dart` — SecureStorageService abstract interface
- `lib/core/services/secure_storage_service_impl.dart` — Implementation of SecureStorageService using FlutterSecureStorage
- `lib/core/services/database_service.dart` — DatabaseService managing database initialization, key length validation, and ADR-011 recovery flows
- `lib/core/storage/app_database.dart` — Drift database instance with custom WAL and Foreign Key SQL configuration
- `lib/core/storage/tables/app_metadata_table.dart` — Drift table schema for system-wide configuration
- `lib/domain/repositories/local_repository.dart` — Illustrative example repository interface
- `test/core/storage/preferences_service_test.dart` — Unit tests for PreferencesServiceImpl
- `test/core/storage/secure_storage_service_test.dart` — Unit tests for SecureStorageServiceImpl
- `test/core/storage/database_service_test.dart` — Unit tests for DatabaseService, singleton protection, key validation, and ADR-011 recovery wipe flows

### Changed (Phase 1.4 Storage Layer — 2026-05-30)
- `docs/04_architecture_decisions.md` — Appended ADR-011 Encryption Recovery and ADR-012 Database Technology Selection Policies
- `pubspec.yaml` — Added `drift`, `sqflite_sqlcipher`, `drift_sqflite`, `sqlite3`, `flutter_secure_storage`, and `shared_preferences` dependencies, and `drift_dev` as a dev dependency
- `lib/main_dev.dart`, `lib/main_staging.dart`, `lib/main_prod.dart` — Updated startup sequence to bootstrap and register PreferencesService, SecureStorageService, and DatabaseService
- `lib/core/bindings/initial_binding.dart` — Registered storage singletons permanently
- `docs/12_phase1_implementation_plan.md` and `docs/03_development_roadmap.md` — Updated status tables to mark Checkpoint 1.4 complete

### Added (Phase 1.3 Theme & Design System — 2026-05-30)
- `docs/15_phase1_3_theme_design_system_plan.md` — Detailed implementation plan for Phase 1.3 Theme & Design System
- `docs/15_1_theme_compliance_audit.md` — Design system compliance audit and refactoring log
- `lib/core/theme/app_spacing.dart` — Design tokens for layout spacing (multiples of 4dp)
- `lib/core/theme/app_radius.dart` — Design tokens for corner border radiuses (small, medium, large, max)
- `lib/core/theme/app_durations.dart` — Design tokens for animation transitions (fast, medium, slow)
- `lib/core/theme/app_typography.dart` — Outfit (headings) and Inter (body/labels) font styling configurations
- `lib/core/theme/app_color_scheme.dart` — AppColorScheme theme extension for lock status, semantic states (success, warning, error, info, disabled)
- `lib/core/theme/app_theme.dart` — ThemeData builders for Light (Notion Milk) and Dark (Obsidian Dark) modes
- `lib/core/services/theme_service.dart` — Dynamic ThemeService managing active ThemeMode state parameters
- `lib/features/theme_sandbox/views/theme_sandbox_screen.dart` — Dedicated UI sandbox screen for verifying the design system
- `test/core/services/theme_service_test.dart` — Unit tests for ThemeService state transitions
- `test/core/theme/app_color_scheme_test.dart` — Unit tests for AppColorScheme copyWith and lerp interpolations

### Changed (Phase 1.3 Theme & Design System — 2026-05-30)
- `docs/04_architecture_decisions.md` — Appended ADR-010 Theme & Design Compliance Rules
- `lib/app.dart` — Updated to register ThemeService early in App.build and bind light/dark theme parameters to GetMaterialApp
- `lib/core/bindings/initial_binding.dart` — Removed duplicate ThemeService registration
- `lib/core/routes/app_routes.dart` and `lib/core/routes/app_pages.dart` — Added route constants and mapping for the ThemeSandboxScreen
- `docs/12_phase1_implementation_plan.md` and `docs/03_development_roadmap.md` — Updated status tables to mark Checkpoint 1.3 complete

### Added (Phase 1.2 Core Architecture — 2026-05-30)
- `docs/14_phase1_2_core_architecture_plan.md` — Detailed implementation plan for Phase 1.2 Core Architecture
- `lib/core/config/env_config.dart` — Environment configurations abstracting Firebase project details, logging, and analytics settings
- `lib/core/errors/failures.dart` — Generic failure contracts and infrastructure-specific sub-classes
- `lib/core/errors/result.dart` — Functional result wrapper mapping success and failure branches
- `lib/core/services/network_service.dart` — Placeholder for global connectivity monitoring
- `lib/core/bindings/initial_binding.dart` — Initial DI binder registering global singletons permanently
- `lib/core/routes/app_pages.dart` — Centralized Named Router configuration mapping routes to screen pages
- `test/core/errors/result_test.dart` — Unit tests for the Result functional folds
- `test/core/config/env_config_test.dart` — Unit tests for EnvConfig parameters across all three flavor environments

### Changed (Phase 1.2 Core Architecture — 2026-05-30)
- `lib/app.dart` — Updated to use `InitialBinding` and `AppPages.pages` routing table
- `lib/main_dev.dart`, `lib/main_staging.dart`, `lib/main_prod.dart` — Updated to initialize `EnvConfig` with their respective flavor environments at launch
- `README.md` and `docs/12_phase1_implementation_plan.md` — Updated to mark Phase 1.2 complete

### Added (Phase 1.1 Project Bootstrap — 2026-05-30)
- `assets/icons/icon_prod.png`, `icon_dev.png`, `icon_staging.png` — Generated premium icons for each flavor
- `lib/main_dev.dart`, `lib/main_staging.dart`, `lib/main_prod.dart` — Entry point files for each flavor
- `lib/core/routes/app_routes.dart` — App route constants
- `lib/features/home/views/home_screen.dart` — Placeholder home screen
- `android/app/src/dev/AndroidManifest.xml`, `android/app/src/staging/AndroidManifest.xml`, `android/app/src/prod/AndroidManifest.xml` — Flavor manifest overlays enforcing backup exclusion

### Changed (Phase 1.1 Project Bootstrap — 2026-05-30)
- Flutter project initialized with FVM and pinned to SDK version 3.44.0 (stable)
- `pubspec.yaml` updated with pinned dependency versions (`get`, `firebase_core`, `flutter_flavorizr` and configuration)
- `analysis_options.yaml` updated with strict linter rules
- `android/app/build.gradle.kts` updated to configure Android product flavors (`dev`, `staging`, `prod`), package IDs, dynamic app names, minSdkVersion 26, and enable resValues
- `ios/Runner.xcodeproj/project.pbxproj` updated to set IPHONEOS_DEPLOYMENT_TARGET = 15.0
- `lib/app.dart` updated to use GetMaterialApp with a placeholder home route mapping to HomeScreen
- `test/widget_test.dart` updated with a smoke widget test asserting App renders without crashing
- `README.md` and `docs/12_phase1_implementation_plan.md` updated to mark Phase 1.1 complete

### Added (Phase 0 Closure & Phase 1.1 Planning — 2026-05-30)
- `docs/13_phase1_1_bootstrap_plan.md` — Detailed Phase 1.1 Project Bootstrap implementation plan

### Changed (Phase 0 Closure & Phase 1.1 Planning — 2026-05-30)
- **All docs (01–12)** — Document status updated from "Phase 0 ✅ Complete" to **"Phase 0 🔒 LOCKED & APPROVED"** — no further architecture changes without explicit approval
- `docs/03_development_roadmap.md` — Auth inconsistency fixed: Firebase Authentication row in Phase 4 deliverables updated from "Anonymous auth + custom claims for invite gating" to "Invite-only Email/Password Authentication with provisioned credentials, device binding, and remote revocation support"; Phase 1 status updated to checkpoint model; Version Milestones table restored
- `docs/05_security_decisions.md` — Section 3.1 heading and strategy statement updated to canonical auth wording
- `docs/06_firebase_decisions.md` — Section 5.1 updated with canonical auth strategy statement and clarified table descriptions
- `docs/07_feature_specifications.md` — F-401 description updated to canonical auth wording
- `docs/12_phase1_implementation_plan.md` — Restructured from monolithic plan to checkpoint overview; checkpoint table added (1.1–1.6)
- `README.md` — Phase 0 marked LOCKED & APPROVED; Phase 1 checkpoint table shown; doc 13 added to index

### Changed (Phase 0 Pre-Approval Corrections — 2026-05-30)
- `docs/01_project_overview.md` — Internal app name and repository changed from `bff_chat` to `memovault`; repository name rationale added to resolved decisions table
- `docs/02_product_vision.md` — "Trusted Circle" terminology replaced with "Vault Network"; Pillar 4 reference to "messaging system" replaced with "private workspace"; resolved decisions table updated
- `docs/05_security_decisions.md` — Section 7.1 expanded with full hardened activation strategy: salted SHA-256, Remote Config delivery, remote rotation without app update, hash-only validation, decoy hashes, rotation protocol
- `docs/06_firebase_decisions.md` — Remote Config keys table updated with `activation_hash` and `activation_salt`; Section 2.4 added documenting notes conflict resolution and version recovery strategy (last 5 revisions, write-once subcollection, Phase 2 automatic write, future restoration UI)
- `docs/07_feature_specifications.md` — F-803 updated from "Hive AES encryption" to "Isar native encryption"
- `docs/08_coding_standards.md` — `HiveError` removed from error handling example; replaced with `IsarError` + `StorageException`; hardcoded value prohibition updated to reflect Remote Config activation strategy
- `docs/11_risk_register.md` — TR-002 expanded with full version recovery strategy; SR-001 expanded with 6-point activation keyword hardening strategy
- `docs/12_phase1_implementation_plan.md` — Out-of-scope section updated; `firebase_remote_config` purpose updated to include activation hash/salt delivery
- `README.md` — Repository and internal names updated to `memovault`

### Added (Phase 0 Finalization — 2026-05-30)
- `docs/11_risk_register.md` — Technical, security, and operational risk register
- `docs/12_phase1_implementation_plan.md` — Detailed Phase 1 implementation plan

### Changed (Phase 0 Finalization — 2026-05-30)
- **All docs** — Document status updated to "Phase 0 ✅ Complete" across all 10 files
- `docs/01_project_overview.md` — App name changed from "BFF Vault" to **MemoVault**; platform minimums added (iOS 15, Android minSdk 26); Hive replaced with Isar in tech stack; resolved decisions table replaces open questions
- `docs/02_product_vision.md` — Panic mode description updated (no data wipe); resolved decisions table replaces open questions
- `docs/03_development_roadmap.md` — Phase 0 marked ✅ Complete with all deliverables and exit criteria checked; Hive replaced with Isar in Phase 1 deliverables; Phase 1 status updated to 🟡 Planning
- `docs/04_architecture_decisions.md` — ADR-002 (Hive) superseded; ADR-009 (Isar) added; all Hive references replaced with Isar; folder structure updated; code generation packages updated; open questions resolved
- `docs/05_security_decisions.md` — Invite flow updated to manual codes (no QR Phase 4); Hive encryption replaced with Isar encryption; panic mode finalized (no wipe); open questions resolved
- `docs/06_firebase_decisions.md` — Firebase project IDs updated to MemoVault naming; notes sync architecture confirmed (Local-first Isar → Firestore); admin strategy updated (Console + SDK scripts only); invite flow updated; notification title updated to MemoVault; open questions resolved
- `docs/07_feature_specifications.md` — F-307 (Fake Mode UI) updated to full panic mode behavior; F-402 (Invite) updated to manual codes only
- `docs/08_coding_standards.md` — Status updated
- `docs/09_development_workflow.md` — Status updated

---

## Phase 0 Decisions Log (2026-05-30)

| Decision | Resolution |
|---|---|
| App name | **MemoVault** (official) |
| Local database | **Isar** (Hive deprecated — ADR-009) |
| Notes sync | **Cloud sync enabled** — Local-first (Isar) → Firestore |
| iOS minimum | **iOS 15** |
| Android minimum | **minSdkVersion 26** (Android 8.0 Oreo) |
| Expected users | **2–10 prod** / architecture targets **1,000** |
| Admin interface | **Firebase Console + Admin SDK scripts only** |
| Invite flow | **Manual codes only** (Phase 4); QR deferred |
| Panic mode | **Fake vault only** — no local or cloud data deletion |

---

## Version History

> No versions released yet. Project is transitioning from Phase 0 to Phase 1.

---

## Change Log Format Reference

```markdown
## [vX.Y.Z] — YYYY-MM-DD

### Added
### Changed
### Deprecated
### Removed
### Fixed
### Security
```
