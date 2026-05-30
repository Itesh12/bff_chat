# 08 — Coding Standards

> **Document Status:** Living Document — Phase 0 🔒 LOCKED & APPROVED  
> **Last Updated:** 2026-05-30  
> **Owner:** Engineering Team

---

## 1. Purpose

This document defines the coding standards, conventions, and quality gates that all code in this project must follow.

These standards are **non-negotiable**. Code that violates these standards must not be merged.

---

## 2. Dart & Flutter Standards

### 2.1 Dart Version

- Minimum Dart SDK: **3.0.0**
- All code must be null-safe
- Use the **latest stable Flutter channel** pinned via `fvm`

### 2.2 Null Safety

```dart
// ✅ Correct
final String? name = user?.displayName;
final String resolved = name ?? 'Anonymous';

// ❌ Incorrect — force unwrap without certainty
final String name = user!.displayName!;
```

- Avoid `!` (force unwrap) unless null is **provably impossible** at that point
- Prefer `?.` (null-aware access) and `??` (null coalescing)
- Use `late` only for values initialized before first use — document why

### 2.3 Immutability

```dart
// ✅ Correct — prefer final
final user = User(name: 'Alice');

// ❌ Incorrect — unnecessary mutability
var user = User(name: 'Alice');
```

- Use `final` for all variables that are not reassigned
- Use `const` for compile-time constants
- Use `Freezed` for immutable model/value objects

### 2.4 Types

- Always specify types explicitly for public APIs and model fields
- Avoid `dynamic` — use typed generics or union types (`sealed class` / `Freezed`)
- `Object?` preferred over `dynamic` when the type is genuinely unknown

---

## 3. File & Folder Naming

| Element | Convention | Example |
|---|---|---|
| Files | `snake_case.dart` | `note_list_screen.dart` |
| Classes | `PascalCase` | `NoteListScreen` |
| Variables | `camelCase` | `noteCount` |
| Constants | `camelCase` (prefixed `k` for app-wide) | `kMaxNoteLength` |
| Enums | `PascalCase` | `MessageStatus` |
| Enum values | `camelCase` | `MessageStatus.delivered` |
| Private members | `_camelCase` | `_isLoading` |
| GetX Controllers | `PascalCase + Controller` | `NotesController` |
| GetX Services | `PascalCase + Service` | `AuthService` |
| Repositories | `PascalCase + Repository` | `MessageRepository` |
| Screens/Views | `PascalCase + Screen` or `View` | `NoteEditorScreen` |

---

## 4. GetX Conventions

### 4.1 Controller Rules

```dart
class NotesController extends GetxController {
  // ✅ Reactive state uses Rx types
  final RxList<Note> notes = <Note>[].obs;
  final RxBool isLoading = false.obs;
  final Rx<Note?> selectedNote = Rx<Note?>(null);

  // ✅ Services injected via Get.find
  final NotesService _notesService = Get.find<NotesService>();

  @override
  void onInit() {
    super.onInit();
    _loadNotes();
  }

  // ✅ Private internal methods prefixed with _
  Future<void> _loadNotes() async { ... }

  // ✅ Public methods for UI interaction
  Future<void> createNote(String title, String body) async { ... }
}
```

- Controllers own **UI state** only
- Business logic lives in **Services**
- Never call Firebase directly from a Controller
- `onInit()` used for initialization; `onClose()` for cleanup

### 4.2 Dependency Injection

```dart
// ✅ Register in a Binding class
class NotesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NotesController>(() => NotesController());
  }
}

// ✅ Retrieve via Get.find
final controller = Get.find<NotesController>();

// ❌ Never use Get.put() inside a widget build method
```

- Use `Get.lazyPut()` for screen-scoped controllers (auto-disposed when route popped)
- Use `Get.put(permanent: true)` for app-wide services only
- All service registrations happen in a root `AppBinding` or feature-level `Binding`

### 4.3 Navigation

```dart
// ✅ Named routes only
Get.toNamed(AppRoutes.noteEditor, arguments: {'noteId': note.id});

// ❌ No anonymous routes
Get.to(() => NoteEditorScreen());
```

- All navigation via named routes defined in `AppRoutes`
- Route guards implemented as `GetMiddleware` subclasses
- Never use `Navigator.push` — always use GetX routing

---

## 5. Error Handling

### 5.1 Error Taxonomy

```dart
// Core failure types (Freezed union)
@freezed
sealed class AppFailure with _$AppFailure {
  const factory AppFailure.network({required String message}) = NetworkFailure;
  const factory AppFailure.auth({required String message}) = AuthFailure;
  const factory AppFailure.storage({required String message}) = StorageFailure;
  const factory AppFailure.notFound() = NotFoundFailure;
  const factory AppFailure.unknown({required String message}) = UnknownFailure;
}
```

### 5.2 Result Type Pattern

```dart
// Use Either<AppFailure, T> from the 'fpdart' package or a simple Result wrapper
Future<Either<AppFailure, List<Note>>> getNotes() async {
  try {
    final notes = await _localSource.getAllNotes();
    return Right(notes);
  } on IsarError catch (e) {
    // Isar-specific database error (schema mismatch, write conflict, etc.)
    return Left(AppFailure.storage(message: e.message));
  } on StorageException catch (e) {
    // Generic local storage failure (encryption key missing, IO error, etc.)
    return Left(AppFailure.storage(message: e.toString()));
  } catch (e) {
    return Left(AppFailure.unknown(message: e.toString()));
  }
}
```

- All repository methods return `Either<AppFailure, T>` or a typed `Result<T>`
- Never throw exceptions across layer boundaries
- Services fold the `Either` and handle failures before exposing to controllers
- Controllers never see raw exceptions — only translated failure states

### 5.3 Global Error Handling

```dart
// In main()
void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // ... setup
      runApp(const App());
    },
    (error, stack) {
      LogService.error('Uncaught error', error: error, stackTrace: stack);
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}
```

---

## 6. Logging Standards

### 6.1 Log Levels

| Level | When to Use |
|---|---|
| `verbose` | Detailed flow tracing (dev only, never in prod) |
| `debug` | Developer-relevant state (dev/staging only) |
| `info` | Significant business events (app start, user actions) |
| `warning` | Unexpected but recoverable situations |
| `error` | Failures that affect user experience |
| `fatal` | Unrecoverable crashes |

### 6.2 Logging Rules

```dart
// ✅ Correct — structured log with context
LogService.info('Note created', data: {'noteId': note.id});

// ❌ Incorrect — print statement
print('Note created');

// ❌ Incorrect — sensitive data in logs
LogService.info('User logged in', data: {'password': password}); // NEVER
```

- No `print()` statements in production code
- No sensitive data (passwords, PINs, tokens, encryption keys, message content) in logs
- Use the central `LogService` wrapper
- In production flavor: info/warning/error/fatal only; debug/verbose filtered out

---

## 7. Testing Standards

### 7.1 Test Coverage Requirements

| Layer | Coverage Target |
|---|---|
| Repositories | ≥ 80% |
| Services | ≥ 80% |
| Controllers | ≥ 70% |
| Utilities / Extensions | ≥ 90% |
| UI (Widget tests) | Critical user flows |

### 7.2 Test Naming Convention

```dart
// Format: 'given [context] when [action] then [expected result]'
test('given empty note title when saving then returns ValidationFailure', () {
  ...
});
```

### 7.3 Test File Structure

```
test/
├── unit/
│   ├── repositories/
│   ├── services/
│   └── controllers/
├── widget/
│   └── features/
└── integration/
    └── flows/
```

---

## 8. Code Review Standards

Every pull request must:

- [ ] Include a clear description of what changed and why
- [ ] Reference the relevant feature ID (e.g., `F-202`)
- [ ] Pass all existing tests
- [ ] Include tests for new logic
- [ ] Have no new `print()` statements
- [ ] Have no hardcoded strings (use constants or localization keys)
- [ ] Have no TODO comments without a linked issue
- [ ] Be approved by at least one reviewer before merge

---

## 9. Linting Configuration

The project uses `flutter_lints` plus custom rules defined in `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    # Style
    - always_declare_return_types
    - prefer_final_locals
    - prefer_const_constructors
    - avoid_print
    # Safety
    - avoid_dynamic_calls
    - cast_nullable_to_non_nullable
    # Architecture
    - avoid_relative_lib_imports
```

**All lint warnings must be resolved before a PR is merged.** No warnings in production code.

---

## 10. Hardcoded Value Prohibition

```dart
// ❌ Incorrect — magic string embedded in binary
if (keyword == 'open sesame') { ... }

// ❌ Incorrect — hash embedded in binary (still reversible via binary analysis)
if (keyword == AppSecrets.activationKeywordHash) { ... }

// ✅ Correct — hash and salt fetched from Remote Config; never in source
final salt = remoteConfig.getString('activation_salt');
final expected = remoteConfig.getString('activation_hash');
final candidate = sha256.convert(utf8.encode(keyword + salt)).toString();
if (candidate == expected) { activateHiddenLayer(); }
```

- No hardcoded strings in business logic
- Strings belong in: constants file, localization, or Remote Config
- **Activation keyword:** hash AND salt must come from Remote Config only — never from source code or local constants
- This enables keyword rotation without an app update (see `05_security_decisions.md` §7.1)

---

## 11. Comments & Documentation

```dart
/// Creates a new [Note] with the given [title] and [body].
///
/// Returns [Right<Note>] on success or [Left<AppFailure>] on failure.
/// Throws [AssertionError] if [title] is empty.
Future<Either<AppFailure, Note>> createNote({
  required String title,
  required String body,
}) async { ... }
```

- All public methods must have dartdoc comments
- Complex business logic must have inline explanatory comments
- Comments explain **why**, not **what** (the code shows what)
- No commented-out code in committed files
