# Phase 3.1 QA Sweep & Verification Report

This document records the verification status and findings from a comprehensive QA sweep covering public and hidden notes feature flows, security lockouts, inactivity timeouts, navigation edge cases, and storage recovery layers.

---

## 📋 QA Sweep Scope & Results

| Feature / Scenario | QA Test Objective | Automated Test Reference | Result |
| :--- | :--- | :--- | :--- |
| **Create Note** | Assert note creation inserts row in respective SQLite/SQLCipher DB and reactively increments counts. | `notes_trash_flow_test.dart` | **PASS** ✅ |
| **Edit Note** | Assert title and body edits update content and increment revision number. | `notes_trash_flow_test.dart` | **PASS** ✅ |
| **Archive** | Soft-archive note: hides from dashboard, shows in archive layout. | `hidden_vault_archive_flow_test.dart` | **PASS** ✅ |
| **Unarchive** | Restore from archive to main list, updating chips. | `hidden_vault_archive_flow_test.dart` | **PASS** ✅ |
| **Trash** | Soft-delete note: moves to trash, removes from dashboard, updates counters. | `notes_trash_flow_test.dart` | **PASS** ✅ |
| **Restore** | Recover note from trash: restores category and active status. | `notes_trash_flow_test.dart` | **PASS** ✅ |
| **Category CRUD** | Create category, edit color/name, delete (assert notes set to null category). | `notes_repository_test.dart` | **PASS** ✅ |
| **Search** | Debounced (300ms) keywords scan on title and body. | `notes_search_controller_test.dart` | **PASS** ✅ |
| **Favorites** | Toggle favorite tag, displays in favorites list instantly. | `hidden_home_screen_test.dart` | **PASS** ✅ |
| **Hidden Vault Unlock** | Authenticate PIN: decrypts secure DB and initializes session. | `navigation_stability_test.dart` | **PASS** ✅ |
| **Hidden Vault Lock** | Terminate session: closes DB connection and deletes encryption keys in memory. | `hidden_session_service_test.dart` | **PASS** ✅ |
| **Background App** | Lock vault immediately on app backgrounding/pause to prevent screenshot leakage. | `navigation_stability_test.dart` | **PASS** ✅ |
| **Session Timeout** | Idle auto-lock fires after 5 minutes of inactivity. | `navigation_stability_test.dart` | **PASS** ✅ |
| **PIN Cooldown** | Lock keypad and trigger 30s security cooldown after 5 failed attempts. | `hidden_activation_controller_test.dart`| **PASS** ✅ |
| **Restart App** | Key survival: app restarts preserve DB state and allow clean decryption. | `database_persistence_test.dart` | **PASS** ✅ |
| **ADR-011 Recovery** | Wipe DB/key and regenerate key on SQLiteNotADatabaseException. | `database_service_test.dart` | **PASS** ✅ |

---

## 🔍 Navigation Edge Cases & Security Checks

### 1. Inactivity & Lifecycle Transition Security
- **Goal**: Verify that when the user leaves the app, or leaves it idle, no secret content is exposed.
- **Verification**:
  - The `HiddenSessionService` listens to lifecycle events. On `AppLifecycleState.paused` or `AppLifecycleState.detached`, `lockSession()` is executed instantly.
  - The navigation router ejects any active route matching `/hidden/*` back to the public `/notes` dashboard. A user resuming the app from the task manager sees the public dashboard, never a stale hidden editor or index screen.

### 2. Search Intercept Trigger (`^\.[0-9]{4}$`)
- **Goal**: Confirm that the stealth trigger is handled safely.
- **Verification**:
  - Interception happens *only* on query submission (using exact matches of a dot prefix and exactly 4 digits, e.g. `.4837`).
  - Typing character-by-character (e.g. `.12` -> `.123`) does not navigate or trigger errors.
  - The query is completely erased from search text controllers and is never written to logs or analytics.

### 3. Database Isolation Compliance
- **Keys**: Public database encryption key resolved under key alias `db_encryption_key_v1`. Private database key resolved under `hidden_vault_encryption_key_v1`.
- **Files**:
  - Public: `memovault.db`
  - Hidden: `hidden_vault.db`
- **Instance Decoupling**: Database schemas are managed by distinct executors. The private vault database remains uninstantiated (null references) until the PIN is verified.
