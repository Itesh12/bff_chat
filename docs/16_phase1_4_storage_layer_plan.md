# 16 — Phase 1.4 Implementation Plan: Storage Layer (Revised)

This plan outlines the architecture, setup, and verification strategy for the local storage and secure storage layers of the MemoVault application. It ensures a hardened, local-first foundation with native encryption, secure key storage, robust failure recovery, and future cloud-sync compatibility.

---

## 1. Storage Architecture Overview

We will configure two distinct storage services alongside our encrypted database:

```
                  ┌────────────────────────────────────────┐
                  │              Application               │
                  └───────────┬────────────────┬───────────┘
                              │                │
                              ▼                ▼
     ┌─────────────────────────────────┐   ┌───────────────────────────┐
     │       PreferencesService        │   │   SecureStorageService    │
     │      (Abstract interface)       │   │  (FlutterSecureStorage)   │
     │   Non-sensitive key-value preferences   │ Sensitive tokens, keys    │
     └─────────────────────────────────┘   └───────────┬───────────────┘
                                                       │
                                                       ▼
                                           [ 32-byte Encryption Key ]
                                                       │
                                                       ▼
                                           ┌───────────────────────────┐
                                           │        IsarService        │
                                           │ (AES-256 Encrypted Local) │
                                           └───────────────────────────┘
```

- **Sensitive vs. Non-Sensitive Isolation:** Non-sensitive preferences (e.g. active theme modes) are handled by `PreferencesService`. Hardware-backed keys are handled by `SecureStorageService`.
- **Database Encryption:** Native database encryption is handled directly by Isar v3 using a cryptographically random AES-256-GCM key.

---

## 2. Dependency Specification

We will add the following pinned packages to `pubspec.yaml`:

```yaml
dependencies:
  # Local encrypted database
  isar: 3.1.0+1
  isar_flutter_libs: 3.1.0+1
  # Hardware-backed secure storage
  flutter_secure_storage: 9.2.2
  # Light-weight system preferences
  shared_preferences: 2.3.2
  # Helper to resolve application folders
  path_provider: 2.1.5

dev_dependencies:
  # Schema and query generators
  isar_generator: 3.1.0+1
  build_runner: 2.4.9
```

---

## 3. Component Specification & API Contracts

### A. Preferences Service (Abstraction)
The application will read and write simple key-value configurations through a clean `PreferencesService` abstraction. The implementation class (`PreferencesServiceImpl`) will wrap `SharedPreferencesAsync` internally to handle non-blocking execution, but this implementation detail is completely hidden from the rest of the codebase.

- **File:** [lib/core/services/preferences_service.dart](file:///c:/bff_chat/lib/core/services/preferences_service.dart)
- **Interface Rationale:** Prevents the direct leakage of third-party persistent packages into controllers or views.

```dart
abstract class PreferencesService {
  Future<void> setString(String key, String value);
  Future<String?> getString(String key);
  Future<void> setBool(String key, bool value);
  Future<bool?> getBool(String key);
  Future<void> remove(String key);
}
```

### B. Secure Storage Service
Manages credentials, biometrics, and database keys. Encapsulates `FlutterSecureStorage` with system-hardened parameters:
- **Android:** Uses Android Keystore (`encryptedSharedPreferences: true`).
- **iOS:** Enforces Keychain Access Options (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).

- **File:** [lib/core/services/secure_storage_service.dart](file:///c:/bff_chat/lib/core/services/secure_storage_service.dart)

```dart
abstract class SecureStorageService {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
  Future<void> clearAll();
}
```

### C. Isar Database Service
Responsible for bootstrapper logic, generating encryption keys, and lifecycle management.
- **File:** [lib/core/services/isar_service.dart](file:///c:/bff_chat/lib/core/services/isar_service.dart)

#### Placeholder Collection (Schema v1 Verification)
To verify schema compilation and native binary loading in Checkpoint 1.4, we will introduce a lightweight `StorageMetadata` model:
- **File:** [lib/data/models/storage_metadata.dart](file:///c:/bff_chat/lib/data/models/storage_metadata.dart)

```dart
import 'package:isar/isar.dart';

part 'storage_metadata.g.dart';

@collection
class StorageMetadata {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String configKey;
  
  late String configValue;
  
  late int updatedAtTimestamp;
}
```

---

## 4. Encryption, Recovery, and Versioning

### A. Key Generation & Parameters
- **Source:** Cryptographically secure pseudo-random number generator (CSPRNG) via `dart:math` `Random.secure()`.
- **Length:** Exactly 32 bytes (256 bits) for AES-256-GCM encryption.
- **Frequency:** Generated exactly once per installation when no prior key exists in `SecureStorageService`.

```dart
List<int> generateSecureKey() {
  final random = Random.secure();
  return List<int>.generate(32, (_) => random.nextInt(256));
}
```
The key is base64-encoded for storage in `SecureStorageService` and decoded to a `Uint8List` when opening Isar.

### B. Local Encryption Recovery Policy (ADR-011)
In accordance with **ADR-011**, there is **no local recovery** for lost or corrupted keys. Wiping the database is the only safe alternative to prevent crash loops:
- **Wipe & Re-initialize Strategy:** If Isar throws an `IsarError` indicating decryption failure (e.g. wrong key, corrupted header) or if the database file exists on disk but its key is missing from secure storage, the service will:
  1. Record a fatal event to the logging/crash handler system.
  2. Physically delete all local Isar files in the application documents directory.
  3. Clear secure storage database key references.
  4. Generate a fresh 256-bit key.
  5. Initialize a blank, clean Isar database.
The official recovery path for user data is remote cloud sync (scheduled for Phase 2+).

### C. Key Rotation Protocol (Future Architecture — Out-of-Scope)
Key rotation is deferred to a future development phase to keep implementation complexity low during the bootstrap phase.
*Conceptually:* Rotation requires opening the current database with the active key, opening a secondary temporary database with a newly generated key, copying all records across databases, closing both, replacing the database file on disk, and updating the secure key in the Keychain/Keystore.

### D. Isar Database Versioning & Schema Migration
We will manage schema evolutionary changes using Isar's migration mechanisms during bootstrap:
- **Current Database Version (v1):** Declares `StorageMetadata` collection only.
- **Planned Schema Upgrades:**
  * **Version 2:** Introduces `NoteCollection` (Phase 2 Notes).
  * **Version 3:** Introduces `VaultConfigCollection` (Phase 3 Hidden Activation).
  * **Version 4:** Introduces `MessageCollection` and `ConversationCollection` (Phase 5 Messaging).
- **Migration Execution:** Upgrades are executed synchronously during database initialization before repositories are registered. Complex schema migrations (e.g., column renaming, record transformations) will be handled by a dedicated `StorageMigrationManager` executed before database open.

---

## 5. Repository Abstraction Layer

To ensure future Cloud Firestore synchronization (Phase 2+) does not bleed into local queries, all data operations use Repository interfaces:

```
[UI/Controller] ──> [Domain Repository Contract] 
                            ▲
                            │
              ┌─────────────┴─────────────┐
              │                           │
  [Isar Local Repository]     [Firestore Remote Sync Repository]
      (Phase 1.4 Active)             (Future Phase 2+)
```

### A. Generic Contract Abstraction
- **File:** [lib/domain/repositories/local_repository.dart](file:///c:/bff_chat/lib/domain/repositories/local_repository.dart)
- *Note:* The generic repository interface `LocalRepository<T>` shown below is an **illustrative example only** showing standard CRUD and query patterns. Future feature repositories (such as messages or vaults) will declare custom contracts tailored to their specific querying, sorting, and synchronization requirements.

```dart
abstract class LocalRepository<T> {
  Future<Result<T, Failure>> save(T item);
  Future<Result<List<T>, Failure>> getAll();
  Future<Result<void, Failure>> delete(int id);
  Stream<List<T>> watchAll();
}
```

---

## 6. Startup Sequence

We will update flavor entrypoints (`lib/main_*.dart`) to execute the startup sequence in the following strict order:

```
                  App Launch
                      │
                      ▼
         WidgetsFlutterBinding.init()
                      │
                      ▼
            EnvConfig.initialize()
                      │
                      ▼
          ThemeService registration
                      │
                      ▼
    ┌───────────────────────────────────┐
    │     Asynchronous Storage Boot     │
    │                                   │
    │ 1. Initialize PreferencesService  │
    │ 2. Initialize SecureStorage       │
    │ 3. Resolve Database File Path     │
    │ 4. Read/Generate Encryption Key   │
    │ 5. Execute Schema Migrations      │
    │ 6. Open Encrypted Isar Database   │
    └─────────────────┬─────────────────┘
                      │
                      ▼
        Dependency Injection Bindings
     (Register Services & Repositories)
                      │
                      ▼
               runApp(const App())
```

---

## 7. Verification Plan

### Automated Tests
We will build comprehensive tests under `test/core/storage/`:

1. **`SecureStorageService` Test Suite:**
   - Verify keys are saved and read successfully.
   - Verify clear-all operations wipe keychain entries.
2. **`IsarService` Test Suite:**
   - Verify Isar database initializes with the specified schema (v1).
   - Verify encryption is active: attempting to open the database file with a different key must throw `IsarError`.
   - Verify the database recovery flow wipes and recreates the database cleanly if decryption fails.
   - **Missing Encryption Key Test:** Verify that if the database file exists on disk but the secure storage key is deleted, the recovery flow triggers, deletes the existing database file, generates a new key, and successfully boots into a fresh empty database without causing crash loops.
3. **Repository Tests:**
   - Mock Isar structures to assert CRUD actions return correct `Result` wrappers.

Run execution command:
```bash
fvm flutter test
```

### Manual Verification
1. Boot the application on the emulator (`fvm flutter run --flavor dev`).
2. Verify in the device console that Isar initializes cleanly.
3. Perform a hot restart to verify database re-opens successfully using the persisted key.
4. Manually trigger a key-corruption scenario in tests/dev-harness to verify the database recovery protocol cleans files without hanging or crashing.
