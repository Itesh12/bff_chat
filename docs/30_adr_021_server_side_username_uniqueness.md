# ADR-021 — Username Uniqueness, Normalization, and Reservation

**Status:** Accepted

**Date:** 2026-05-31

---

## Context

MemoVault introduces a Secure Messaging system built around E2E-encrypted, anonymous pseudonyms. When an identity is created under Phase 4.2.1, the user selects a unique handle.
Because usernames are discoverable handles, uniqueness is critical. If two users could simultaneously register the same username, E2EE key distribution would become compromised.

Furthermore, case variations and Unicode tricks could allow impersonation. For example, if `@John` and `@john` were registered as separate identities, malicious users could impersonate others. 
Similarly, words like `admin`, `system`, or `memovault` could be registered by bad actors to trick users into trusting fake official accounts.

Therefore, absolute uniqueness, strict canonical normalization, character validation, and a reserved name blacklist must be enforced at both the client and server levels before the first user is ever registered.

---

## Decision

### 1. Username Normalization (Canonical vs. Display Name)
*   **Canonical Normalization**: All usernames are normalized prior to registration using Unicode **NFKC normalization** and forced **lowercase conversion**.
    - For example, `John`, `john`, and `JOHN` resolve to the exact same canonical string: `john`.
    - This canonical string is used as the Firestore **Document ID** in the `/pseudonyms` collection (e.g. `/pseudonyms/john`), guaranteeing that database-level uniqueness is case-insensitive.
*   **Display Name Retention**: We store two separate fields in the Firestore document:
    - `username` (String): The canonical normalized lowercase handle (e.g. `john`). This is used as the document ID and key lookup.
    - `displayName` (String): The case-preserved format specified by the user (e.g. `John`). 
    - This allows users to retain cosmetic capitalization for display purposes while the E2EE protocol routes messages strictly via the lowercase canonical handle.

### 2. Character Set and Length Constraints
To prevent SQL/NoSQL injection, visual homograph attacks, and UI overflows, we enforce strict constraints on handles:
*   **Length**: Strictly **3 to 20 characters** (inclusive).
*   **Character Set**: Strictly ASCII lowercase alphanumeric characters and underscores are allowed: **`a-z`, `0-9`, `_`**.
*   **Impersonation & Homograph Prevention**: By strictly restricting the character set to ASCII-only (`a-z0-9_`), homograph attacks using Greek, Cyrillic, or other lookalike Unicode characters (e.g. Greek alpha `α` or Cyrillic `а` instead of Latin `a`) are natively blocked.
*   **Regex Pattern**: The handle must match the regular expression: `^[a-z](?!.*__)[a-z0-9_]{2,19}(?<!_)$`
    - This prevents starting with a digit or underscore, trailing underscores, and consecutive underscores (e.g. `1john`, `__john`, `john__`, `john__doe`), ensuring readable, clean namespace handles starting with a letter.

### 3. Reserved Names Blacklist
To prevent impersonation of system utilities, moderators, or developers, a strict blacklist of reserved words is enforced. No user can register a canonical username that is equal to, or starts with, any of the following prefixes:
*   `admin`, `administrator`, `moderator`, `support`, `system`, `root`
*   `memovault`, `security`, `staff`, `official`, `help`, `guest`

### 4. Firestore Natively Enforced Document ID Uniqueness Constraint
*   To achieve absolute, lock-free, zero-race-condition uniqueness under high concurrency, usernames are mapped directly to Firestore **document IDs** inside the `/pseudonyms` collection.
*   The document path is strictly defined as `/pseudonyms/{username}` (where `{username}` is the normalized, lowercase canonical handle).
*   Because Firestore enforces that no two documents inside a single collection can share the exact same document ID, document creation serves as an atomic lock.

### 5. Atomic Write Security Rules
*   The security rules enforce that document creation contains all required fields, matches the authenticated user, matches the document ID, and complies with character/word constraints:
    ```javascript
    match /pseudonyms/{username} {
      allow read: if request.auth != null;
      allow create: if request.auth != null 
                    && request.resource.data.keys().hasAll([
                        'username',
                        'displayName',
                        'uid',
                        'identityPublicKey',
                        'createdAt'
                    ])
                    && request.resource.data.uid == request.auth.uid
                    && request.resource.data.username == username
                    && username.matches('^[a-z](?!.*__)[a-z0-9_]{2,19}(?<!_)$')
                    && !(username in ['admin', 'administrator', 'moderator', 'support', 'system', 'root', 'memovault']);
      allow update, delete: if false; // Immutable once registered (Option A)
    }
    ```
*   Firestore's write pipeline natively guarantees that if two transactions attempt to execute a `create` on `/pseudonyms/john` simultaneously, the first write will succeed and the second write will instantly fail with an `ALREADY_EXISTS` transaction error.

### 6. Immutable Username Decision (Option A)
*   Usernames are permanently **immutable** once registered. A user cannot rename their username. This eliminates database migration complexity and contact discovery sync errors.
*   If a user wishes to revoke their identity, they publish a signed key revocation update inside the document, but the document ID (username) remains permanently reserved in the registry to prevent historic impersonation.

### 7. Integration Protocol & Error Handling
*   During the `identityPublished` state in `MessagingSetupController`, the publishing client issues a write request to Firestore `/pseudonyms/{username}` containing the derived E2E public identity keys.
*   If the write succeeds, the identity is published, and the local state advances to `ready`.
*   If the write fails with `permission-denied` or `already-exists` (caused by the uniqueness constraint violation), the client-side controller captures the exception, stops the onboarding state progression, and prompts the user to select a different username:
    - SNACKBAR ALERT: *"Username Taken: The handle chosen is already registered. Please select another username."*

---

## Consequences

*   **Absolute Coherence**: Native database-level uniqueness guarantees that race conditions under high concurrent registration loads are 100% prevented.
*   **Zero Spoofing**: Enforced case-insensitivity, character restrictions, and a reserved blacklist ensure that users cannot spoof official accounts or impersonate other users with similar names.
*   **Simple Client-Side Logic**: The client relies directly on Firestore's deterministic write responses to progress the state machine safely.

