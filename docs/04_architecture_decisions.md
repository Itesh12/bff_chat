# 04 — Architecture Decisions

> **Document Status:** Living Document — Phase 0 🔒 LOCKED & APPROVED  
> **Last Updated:** 2026-05-30  
> **Owner:** Engineering Team

---

## 1. Architecture Decision Record (ADR) Format

Each decision is recorded as:

- **ADR-XXX** — Decision title
- **Status** — Proposed / Accepted / Deprecated / Superseded
- **Context** — Why the decision was needed
- **Decision** — What was decided
- **Rationale** — Why this choice was made
- **Consequences** — Trade-offs and implications

---

## ADR-001 — State Management: GetX

**Status:** Accepted

**Context:**
Flutter has many state management options (Provider, Riverpod, Bloc, MobX, GetX). We need a solution that covers state management, dependency injection, and routing in a unified, low-boilerplate package suitable for a complex multi-layer application.

**Decision:**
Use **GetX** as the primary state management, routing, and dependency injection framework.

**Rationale:**
- Single package covers state, routing, DI, utilities (eliminates multiple dependency coordination)
- Reactive state with minimal boilerplate (`Rx` types)
- Named route system supports deep linking and guarded navigation
- `Get.find<T>()` service locator is well-suited to our layered service architecture
- Team familiarity (assumed based on project specification)

**Consequences:**
- Risk: GetX is not the Flutter team's recommended approach; it has had maintenance concerns historically. **Mitigation:** Abstract service interfaces so the DI framework is swappable.
- All controllers must extend `GetxController` and all services registered through `Get.put()` / `Get.lazyPut()`.
- Routing uses `GetMaterialApp` and named routes defined in a central `AppRoutes` class.

---

## ADR-002 — Local Database: Hive

**Status:** Superseded by ADR-009

**Context:**
Hive was originally proposed as the primary local database due to its pure-Dart implementation and low complexity.

**Decision:**
Hive is **no longer used** as the primary local database. See **ADR-009** for the replacement decision (Isar).

**Why Superseded:**
- Hive lacks native query support, requiring complex in-memory filtering for message search
- Hive has no indexing — unacceptable for smart filters and media indexing (Phase 6 / 7)
- Isar provides a superior developer and performance story for our access patterns

**Alternative Considered:**
- **Isar** — Selected. See ADR-009.
- **SQLite (drift)** — Relational power but heavier native dependency; not chosen.

---

## ADR-003 — Backend: Firebase

**Status:** Accepted

**Context:**
We need a real-time backend capable of supporting messaging, file storage, authentication, and push notifications — without managing our own server infrastructure.

**Decision:**
Use **Firebase** as the exclusive backend service provider.

**Services Used:**
| Service | Purpose |
|---|---|
| Firebase Auth | User identity and session management |
| Cloud Firestore | Real-time database for messages, notes metadata, presence |
| Firebase Storage | Media files (images, voice, video, documents) |
| Firebase Cloud Messaging | Push notifications (data-only for stealth) |
| Firebase Remote Config | Feature flags and runtime configuration |
| Firebase Analytics | Privacy-respecting telemetry |
| Firebase Crashlytics | Production crash monitoring |

**Rationale:**
- Firestore real-time listeners are ideal for messaging
- FCM supports data-only (silent) notifications — critical for stealth notification strategy
- Firebase ecosystem is fully integrated — Auth tokens work natively with Firestore rules
- No server to manage — reduces operational overhead and attack surface

**Consequences:**
- Vendor lock-in to Google Firebase. **Mitigation:** Abstract Firebase calls behind repository interfaces.
- Firestore costs scale with reads/writes — security rules must be tight to prevent abuse
- Firebase Auth must be configured to prevent public signup (invite-only requirement)
- Firebase project must be set up per-environment (dev / staging / prod)

---

## ADR-004 — Application Architecture Pattern: Layered + Repository

**Status:** Accepted

**Context:**
We need a consistent, scalable architecture pattern that supports testability, separation of concerns, and the ability to swap implementations (e.g., changing database or backend).

**Decision:**
Use a **Layered Architecture** with the **Repository Pattern**:

```
Presentation Layer (UI / Widgets / Screens)
        ⇕
Controller Layer (GetX Controllers)
        ⇕
Service Layer (Business Logic Services)
        ⇕
Repository Layer (Data access abstraction)
        ⇕
Data Source Layer (Firebase / Isar / Secure Storage)
```

**Layer Responsibilities:**

| Layer | Responsibility |
|---|---|
| **Presentation** | Renders UI, observes controller state, dispatches user actions |
| **Controller** | Holds screen state, calls services, exposes reactive state to UI |
| **Service** | Encapsulates business rules, orchestrates repositories |
| **Repository** | Abstracts data access, provides clean interface regardless of source |
| **Data Source** | Direct Firebase / Isar / HTTP calls |

**Consequences:**
- Controllers never call Firebase directly
- Services contain all business logic
- Repositories can be mocked for testing
- Adds initial boilerplate — offset by long-term maintainability

---

## ADR-005 — Environment Configuration: Flavors

**Status:** Accepted

**Context:**
We need separate environments for development, staging, and production — each with its own Firebase project, API keys, and feature flags.

**Decision:**
Use **Flutter Flavors** with environment-specific configuration:

| Flavor | Purpose |
|---|---|
| `dev` | Local development — Firebase emulators, verbose logging |
| `staging` | QA and testing — real Firebase staging project |
| `prod` | Production — hardened Firebase project, analytics on |

**Implementation:**
- Use `flutter_flavorizr` package to generate flavor configuration
- Each flavor has its own `google-services.json` / `GoogleService-Info.plist`
- App icons differ per flavor (dev = debug icon, prod = store icon)
- Use `const String flavor = String.fromEnvironment('FLAVOR')` for runtime config

**Consequences:**
- Each environment needs its own Firebase project configured
- Build commands must always specify flavor: `flutter run --flavor dev`
- CI/CD pipelines must build correct flavor per environment

---

## ADR-006 — Project Folder Structure

**Status:** Proposed

**Context:**
A consistent, scalable folder structure is required from day one to avoid refactoring pain as the project grows.

**Decision:**
Feature-first folder structure within `lib/`:

```
lib/
├── core/
│   ├── constants/          # App-wide constants
│   ├── errors/             # Error classes and failure types
│   ├── extensions/         # Dart extension methods
│   ├── theme/              # ThemeData, colors, typography
│   ├── routes/             # AppRoutes, AppPages (GetX)
│   ├── bindings/           # Root-level GetX bindings
│   ├── services/           # App-wide services (auth, storage, network)
│   ├── utils/              # Utility functions
│   └── widgets/            # Shared reusable widgets
│
├── data/
│   ├── models/             # Data models (Isar collections, Firestore mapping)
│   ├── repositories/       # Repository implementations
│   └── sources/
│       ├── local/          # Isar data sources
│       └── remote/         # Firebase data sources
│
├── features/
│   ├── notes/              # Phase 2 — Notes feature
│   │   ├── controllers/
│   │   ├── views/
│   │   └── widgets/
│   ├── hidden/             # Phase 3+ — Hidden messaging layer
│   │   ├── auth/
│   │   ├── messaging/
│   │   ├── media/
│   │   └── settings/
│   └── onboarding/         # First-run experience
│
└── main_*.dart             # Flavor entry points (main_dev.dart, etc.)
```

**Consequences:**
- Feature isolation reduces merge conflicts in team development
- `core/` and `data/` are shared across all features
- The `hidden/` feature subtree should have no imports from the `notes/` tree at the UI layer

---

## ADR-007 — Code Generation Strategy

**Status:** Accepted

**Context:**
Multiple packages require code generation (Isar schema, JSON serialization, Freezed).

**Decision:**
Use `build_runner` for all code generation. Generated files are **committed to the repository**.

Packages using generation:
- `isar_generator` — Isar collection schema generation
- `json_serializable` — JSON serialization for API models
- `freezed` — Immutable value objects and union types *(for error/state types)*

**Rationale:**
- Committing generated code ensures CI builds don't require running generators
- Generated code is reviewed in pull requests

**Consequences:**
- Run `dart run build_runner build --delete-conflicting-outputs` after model changes
- Generated files (`*.g.dart`, `*.freezed.dart`) must be committed
- `.gitignore` must NOT exclude generated files

---

## ADR-008 — Dart Version & Null Safety

**Status:** Accepted

**Decision:**
- All code must be **null-safe** (Dart ≥ 3.0)
- Avoid `!` force-unwrap except where null is provably impossible
- Prefer `?.` and `??` operators
- Use `final` for all immutable references

**Consequences:**
- No pre-null-safety packages may be used
- Third-party packages must be null-safe compatible

---

## Resolved Architecture Decisions

| Decision | Resolution |
|---|---|
| **Isar vs Hive** | Isar selected — see ADR-009 below |
| **Offline-first for notes** | Cloud sync enabled — Local-first (Isar) → Firestore background sync |
| **Folder structure `hidden/`** | Remains a feature subfolder; separate Dart package deferred to Phase 8 evaluation |
| **Web admin panel** | No custom dashboard — Firebase Console + Admin SDK scripts only |

---

## ADR-009 — Local Database: Isar (Replaces Hive)

**Status:** Accepted

**Context:**
ADR-002 provisionally selected Hive as the local database, noting that Isar should be revisited before Phase 1. The feature set of MemoVault requires:

1. Full-text message search (Phase 5/6)
2. Smart filter queries — unread, media type, links (Phase 6)
3. Media indexing for the per-conversation gallery (Phase 7)
4. Notes full-text search with category/tag filtering (Phase 2)
5. Cloud sync conflict resolution requiring ordered, indexed queries

Hive cannot satisfy requirements 1–5 natively. All complex filtering would need to be implemented in application memory, introducing performance risk and code complexity.

**Decision:**
Use **Isar** as the primary local database for all local data storage across the application.

**Isar replaces Hive entirely. Hive is not used in this project.**

**Rationale:**

| Criterion | Hive | Isar | Winner |
|---|---|---|---|
| Full-text search | ❌ None | ✅ Built-in | Isar |
| Indexed queries | ❌ None | ✅ Composite indexes | Isar |
| Type safety | ⚠️ Via adapters | ✅ Native typed collections | Isar |
| Query performance | ⚠️ In-memory | ✅ Native database layer | Isar |
| Encryption at rest | ✅ AES via cipher | ✅ Isar encryption (Phase 8) | Tied |
| Flutter-first | ✅ Yes | ✅ Yes | Tied |
| Code generation | ✅ `hive_generator` | ✅ `isar_generator` | Tied |
| Binary size impact | ✅ Smaller | ⚠️ Slightly larger (native layer) | Hive |
| Scalability | ❌ Poor (in-memory queries) | ✅ Good (indexed) | Isar |

Binary size tradeoff is acceptable given the significant query capability and scalability improvements.

**Isar Collections Planned:**

| Collection | Phase |
|---|---|
| `NoteCollection` | Phase 2 |
| `MessageCollection` | Phase 5 |
| `ConversationCollection` | Phase 5 |
| `MediaCacheCollection` | Phase 7 |
| `AuditLogCollection` | Phase 4 |

**Encryption Strategy with Isar:**
- Isar v3+ supports native encryption via a key parameter on database open
- The encryption key is generated on first run and stored in Flutter Secure Storage
- This replaces the `HiveAesCipher` approach from ADR-002

**Migration Strategy:**
- No migration from Hive is needed (greenfield project)
- Isar schema versioning managed via `@Collection` version annotation
- Schema migrations defined before each phase that changes the data model
- `isar.writeTxn()` used for atomic writes across collections

**Consequences:**
- Isar requires native binaries (iOS/Android) — slightly larger app binary
- All models are `@Collection`-annotated Dart classes (code generation required)
- Generated files (`*.g.dart`) must be committed
- Run `dart run build_runner build --delete-conflicting-outputs` after schema changes
- No Hive dependency in `pubspec.yaml`

---

## ADR-010 — Theme & Design Compliance Rules

**Status:** Accepted

**Context:**
A common failure in software development is the drift between a defined design system and its actual usage. Creating centralized token classes (for spacing, radius, durations, typography, and colors) has no value if developers continue to hardcode layout margins, corner shapes, transitions, colors, and styles throughout screens and custom widgets. We need explicit, statically checked rules to prevent design system drift from day one.

**Decision:**
Formalize design system compliance rules as an Architectural Decision Record:

1. **No Hardcoded Spacing:** Layout margins, paddings, gap dimensions (`SizedBox` sizes) must strictly use constants from `AppSpacing`. Direct double/integer literals (e.g. `16.0`, `12.0`) in widgets are prohibited.
2. **No Hardcoded Corner Radiuses:** Borders and card shapes must use standard constants and `BorderRadius` instances from `AppRadius` (`small`, `medium`, `large`, `max`). Direct `Radius.circular` or `BorderRadius.circular` usage in widgets is prohibited.
3. **No Hardcoded Animation Durations:** Component transition and animation settings must use standard values from `AppDurations` (`fast`, `medium`, `slow`).
4. **No Raw TextStyles:** Custom widget typography must inherit from or reference defined styles in `AppTypography`. Direct instantiations of raw `TextStyle(...)` (except copyWith calls to alter colors/families defined in `AppTypography`) are prohibited.
5. **No Direct Material Colors:** Direct Material palette references (e.g. `Colors.blue`, `Colors.red`, `Colors.black26`) are prohibited. Colors must resolve dynamically from the active `ThemeData` (e.g. `theme.colorScheme.primary`, `theme.dividerColor`) or custom `ThemeExtension` definitions (`customColors.success`, `customColors.vaultStatusLocked`).

**Rationale:**
- Prevents design system drift as the codebase expands.
- Simplifies application-wide visual changes (e.g., changing primary accent or rounding corners can be done in a single location).
- Establishes a clear boundary: the theme system files are the exclusive authority for raw styling variables.

**Consequences:**
- New visual features and screen mockups must conform to token definitions by default.
- Build-phase compliance audits can be run as part of quality gates.
- Legacy or placeholder views must be refactored to comply with tokens before starting new layers.

---

## ADR-011 — Local Database Encryption Recovery Policy

**Status:** Accepted

**Context:**
The MemoVault local database (Isar) is fully encrypted using a device-bound 256-bit key stored in hardware-backed Secure Storage. In production scenarios, a device's secure storage can be wiped, the app's credentials deleted, or database headers corrupted. When the encryption key is lost, the local database becomes permanently unrecoverable. We need to decide whether to attempt local recovery (which is cryptographically impossible without the key) or declare a data-loss recovery policy that resets the local database to avoid crash loops, relying on cloud synchronization for data restoration in later phases.

**Decision:**
Establish a **No Local Recovery** policy for lost or corrupted encryption keys:

1. **Decryption Failure = Local Reset:** If the database throws a decryption/header error on boot, or if the encryption key is missing from Secure Storage but a database file already exists, the application will execute a local reset. The corrupted/unkeyable database files will be physically deleted, a fresh 256-bit key generated and stored, and a blank database created.
2. **Cloud-First Recovery:** The official recovery path for user data (notes, messages, configurations) is remote backup and synchronization via Cloud Firestore (scheduled for Phase 2+). Local storage is treated as a local cache/vault; the system makes no attempt to recover local records if the cryptographic key is destroyed.

**Rationale:**
- Decrypting an AES-256-GCM database without its key is cryptographically impossible.
- Throwing unhandled errors on launch leads to fatal crash loops, ruining the user experience.
- Resetting the database ensures the application remains functional and lets the user re-authenticate to sync their records from the cloud.

**Consequences:**
- Wiping the local database causes data loss for any records that have not yet been synced to the cloud.
- Safe logging must record database resets without exposing any private user data.
- The startup bootstrap sequence must handle SQLCipher boot failures gracefully, ensuring the wipe and re-initialize flow executes.

---

## ADR-012: Database Technology Selection

**Context:**
Phase 1.4 requires establishing a core storage foundation that can securely power a vault-style application with features such as encrypted notes, hidden vaults, encrypted messaging, media encryption, and offline-first synchronization.

**Decision:**
We have selected **Drift** paired with **SQLCipher** (via sqflite_sqlcipher) as the local storage engine.

Rejected:
- **Hive**: Excellent for small caches or simple settings, but weak querying capabilities (lack of complex indices, filtering, pagination, reactive updates) make it unsuitable for a production-grade encrypted messenger/vault.
- **Isar**: While fast and modern, it lacks transparent at-rest encryption and has significant AGP compatibility issues (e.g., AGP 9 namespace errors with isar_flutter_libs).

Selected:
- **Drift + SQLCipher**

**Rationale:**
- **True At-Rest Encryption**: SQLCipher natively provides robust AES-256-GCM encryption on disk, preventing raw file data extraction.
- **Mature Ecosystem**: Drift is a stable, type-safe SQLite ORM that easily integrates with SQLCipher.
- **Complex Queries**: Fully supports relational data, indexing, and complex queries essential for messaging workloads.
- **Reactive Streams**: Drift seamlessly supports reactive database streams.
- **Future Proof**: Solves long-term compatibility requirements (AGP 9+), future messaging, offline synchronization, and secure media metadata handling.

---

## ADR-013 — Logging & Telemetry Policy

**Status:** Accepted

**Context:**
MemoVault is a security-first note and communication vault app. Telemetry and diagnostics are crucial to catch production bugs, track startup latency, and monitor synchronization states, but any logging that leaks user data (decrypted notes, keys, chat messages, or credentials) completely breaks our security guarantees. We need a clear logging, retention, and telemetry policy that is enforced automatically.

**Decision:**

1. **Strict Data Redaction:**
   - The logging framework will run an automated redaction engine.
   - Any string matching Base64 patterns (like encryption keys), passwords, vault metadata paths, raw emails, or tokens will be replaced with `[REDACTED]`.
   - Logging note bodies, vault structures, or chat text is strictly forbidden.

2. **Logger Usage Rules:**
   - **FORBIDDEN:**
     ```dart
     logger.info(noteContent);
     logger.info(messageText);
     logger.info(encryptionKey);
     logger.info(password);
     ```
   - **ALLOWED:**
     ```dart
     logger.info('Note created', metadata: {'noteId': id});
     logger.warning('Failed to sync batch', error: err);
     ```

3. **Telemetry Opt-Out:**
   - Introduce an `AnalyticsService` contract with a boolean getter `bool get isEnabled;`.
   - Setup a `NoOpAnalyticsService` alongside the real `FirebaseAnalyticsService`.
   - Telemetry must be completely disabled in development/unit tests (running the No-Op adapter) or when the user opt-out flag is set in preferences.

4. **Event Naming Convention:**
   - All custom events must use `snake_case` (e.g. `note_created`, `note_updated`, `vault_opened`, `hidden_access_triggered`, `message_sent`). No PascalCase or camelCase is allowed.

5. **Log Retention Limits:**
   - **Development:** Print to console only; no persistent local log files are kept.
   - **Staging / QA:** Reports errors/warnings to Crashlytics. Logs are retained for a maximum of 30 days.
   - **Production:** No local database persistent log files. No raw user parameters are transmitted. Non-fatal telemetry is strictly metadata-bound.

6. **Database Recovery Telemetry:**
   - When recovery flows (ADR-011) are triggered, the app will log:
     - `database_recovery_triggered`
     - `database_key_regenerated`
     - `database_open_failed`
   - These events are logged with non-sensitive metadata (e.g., attempt number, error signature) but NEVER raw keys or paths.

**Rationale:**
- Automating key redaction and establishing a clean abstraction block prevents developers from leaking keys/contents accidentally.
- Giving the user control over telemetry satisfies modern privacy standards (GDPR, CCPA).
- Standardizing logging rules from day one prevents technical debt.

---

## ADR-014 — Notes Domain Architecture

**Status:** Accepted

**Context:**
Phase 2.0 implements the first user-facing feature on top of the Phase 1 secure foundation: the visible Notes application. It must be a genuinely high-quality notes app on its own, with zero hints of the messaging layer, while staying architecture-ready for Phase 3 secret access, sync conflicts, categories reordering, and performance scaling.

**Decision:**

1. **Client-Generated UUIDs for Note IDs:**
   - Notes use random version-4 UUIDs generated on the client using a cryptographically secure generator (`Random.secure()`).
   - Autoincrement IDs are forbidden to avoid sync conflicts across devices.

2. **Soft Deletion (`isDeleted` + `deletedAt`):**
   - Notes are soft-deleted first rather than purged from SQLite immediately.
   - Enables sync conflict resolution and cross-device synchronization state tracking.

3. **Optimistic Concurrency Control (OCC) via `revision`:**
   - Note schemas track an integer `revision` field (starting at 1, incrementing on every database write).
   - Essential for offline-first conflict resolution, revision history, and recovery.

4. **Statistics Counter Methods:**
   - Repository defines quick-access statistics: `notesCount`, `favoritesCount`, and `archivedCount`.
   - Native SQL aggregate `SELECT COUNT(*)` queries mapped in Drift DAOs for high speed.

5. **`lastOpenedAt` Timestamp Column:**
   - Tracks when a note detail screen is opened without bumping the `revision` or triggering sync alerts.
   - Forward-compatible with "Recently Viewed" and smart suggestions without parsing log files.

6. **Decoupled `NotesSearchController`:**
   - Completely isolates search reactive state from `NotesController`.
   - Exposes a clean `onQuerySubmitted` hook where Phase 3 attaches covert keyword checks, keeping dashboard and search UI completely clean of messaging leakage.

7. **Search Character Threshold:**
   - Searches only fire when the query is 2+ characters to optimize SQL performance and reduce CPU overhead.

8. **Builder-Based Note Rendering:**
   - UI lists/grids must use `ListView.builder` or `GridView.builder` exclusively.
   - Prevents memory leaks and jank when rendering 100+ secure notes.

**Rationale:**
- Adding columns like `revision`, `lastOpenedAt`, and category `displayOrder` now prevents database migration complications later.
- Isolating search controller ensures complete separation of concerns and reduces the risk of covert code leaking into public notes widgets.
- Pure Dart UUID generation avoids extra external packages.

---

## ADR-015 — Global Design System Components & Versioning

**Status:** Accepted

**Context:**
As MemoVault expands to support multiple features (Notes, Hidden Access, Vault, Messaging, Media, Settings, Security), creating ad-hoc layout components on individual screens introduces styling drift, duplicate layouts, and visual inconsistencies. We need a strict architectural rule ensuring that every single layout element is built strictly using reusable, tokenized components under `lib/core/design_system/`.

**Decision:**

1. **Forbid Raw Material Primitives in Presentation Views:**
   No file outside of `lib/core/theme/` and `lib/core/design_system/` may directly instantiate or invoke raw layout widgets or untokenized visual properties.

   | FORBIDDEN (No direct raw usage in features) | ALLOWED (Design system wrappers only) |
   |---|---|
   | `ElevatedButton`, `OutlinedButton`, `TextButton` | `AppButton` |
   | `IconButton` | `AppIconButton` |
   | `TextField`, `TextFormField` | `AppTextField` |
   | `SearchBar` (or custom search fields) | `AppSearchBar` |
   | `SnackBar`, `Get.snackbar` | `AppSnackBar` |
   | `AlertDialog`, `SimpleDialog` | `AppDialog` |
   | `showModalBottomSheet` | `AppBottomSheet` |
   | `Card` | `AppCard` |
   | `Chip`, `FilterChip`, `ActionChip` | `AppChip` |
   | `Scaffold`, `AppBar` | `AppScaffold` |
   | `CircularProgressIndicator` | `AppLoading` |
   | Direct Spacing/Margin Literals (`16.0`, etc.) | `AppSpacing` tokens (`s4`, `s8`, etc.) |
   | Direct BorderRadius/Radius Literals | `AppRadius` tokens (`small`, `medium`, etc.) |
   | Raw `TextStyle` or `theme.textTheme` calls | `AppTypography` tokens |
   | Direct `Duration(...)` literals | `AppDurations` tokens |
   | `SizedBox(height: xx)`, `SizedBox(width: xx)` | `AppGap` widgets |
   | `Color(...)`, `Colors.*` | `context.colors` / theme properties |

2. **Component Versioning & Public API Treatment:**
   Design system components under `lib/core/design_system/` are treated as locked public APIs. Any breaking changes to component constructors or behavior must strictly require:
   - Corresponding documentation updates under `docs/design_system/`.
   - Widget and unit test validation suite updates under `test/core/design_system/`.
   - Sandbox representation updates in `DesignSystemSandboxScreen`.
   - Visual impact review of all referencing feature screens.

3. **Reserved Names for Future Components:**
   We formally reserve the following names for upcoming modules:
   - `AppAvatar`, `AppBadge`, `AppListTile`, `AppDivider`, `AppSwitch`, `AppDropdown`, `AppImage`.

4. **Automated CI/CD Compliance Enforcer:**
   To guarantee that ADR-015 is actively enforced rather than merely documented, a CI compliance verification check must be established. The check verifies that no features directly use raw Material layout elements, spacing literals, or manual radius overrides. A script or CI step will fail the build if any search matches are found inside `lib/features/`:
   - `git grep "ElevatedButton(" lib/features/`
   - `git grep "TextField(" lib/features/`
   - `git grep "Card(" lib/features/`
   - `git grep "AlertDialog(" lib/features/`
   - `git grep "SizedBox(" lib/features/`

**Consequences:**
- Guarantees 100% theme compliance across the app.
- Screens become highly readable compositions of standard semantic layout wrappers.
- CI/CD enforcer checks will automatically fail if raw primitives or spacing literals are leaked inside feature directories.


