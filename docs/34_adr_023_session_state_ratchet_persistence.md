# ADR-023 — Session State & Ratchet Persistence Storage Split

**Status:** Accepted

**Date:** 2026-05-31

---

## Context & Problem Statement

MemoVault provides a highly secure Hidden Vault environment with coercion resistance and Panic PIN destructive wipes. In Phase 4.3B, cryptographic session states, One-Time Prekeys (OTPs), Signed Prekeys, and Kyber Prekeys were stored temporarily inside `SecureStorageService` (backed by platform Keychain/Keystore) to defer local database schema migrations. 

However, this architecture introduces the **Background Processing Paradox**:
* If the Hidden Vault is locked, the underlying SQLCipher-encrypted message store (`hidden_vault.db`) is closed and unkeyable.
* Even if session keys reside in `SecureStorage` and incoming messages can be decrypted in the background, they **cannot be persisted** without holding plaintext in memory or unencrypted caches.
* Because messages must wait in the Firestore sync queue until the vault is unlocked, background decryption while the vault is locked offers no value and splits the cryptographic boundary.

Furthermore, a Panic PIN trigger that destroys the SQLCipher database would leave residual session records and ratchet keys inside `SecureStorage` intact, compromising coercion resistance.

---

## Decision

We will explicitly segregate cryptographic materials into two layers: the **Device Identity Layer** (persisted in system-backed `SecureStorage`) and the **Active Messaging Layer** (persisted inside SQLCipher-encrypted database stores).

| Cryptographic Material | Storage Location | Cryptographic Owner / Store |
| :--- | :--- | :--- |
| **Identity Private Key** | SecureStorage | `MessagingIdentityService` |
| **Identity Public Key** | SecureStorage | `MessagingIdentityService` |
| **Signed Prekeys** | SecureStorage | `SignalStoreImpl` (System Keystore) |
| **Kyber Prekeys** | SecureStorage | `SignalStoreImpl` (System Keystore) |
| **Session Records** (Double Ratchet) | **SQLCipher Database** | `SignalStoreImpl` (Drift Table) |
| **OTP Inventory** | **SQLCipher Database** | `SignalStoreImpl` (Drift Table) |
| **Skipped Message Keys** (Phase 4.4) | **SQLCipher Database** | `SignalStoreImpl` (Drift Table) |
| **Ratchet Chain States** (Phase 4.4) | **SQLCipher Database** | `SignalStoreImpl` (Drift Table) |
| **Conversations & Messages** | **SQLCipher Database** | `MessagingRepositoryImpl` (Drift Table) |

---

## Consequences

### 1. Unified Security Boundary
When the Hidden Vault is locked, all active session records, ratchet keys, skipped keys, and message histories are completely inaccessible. A Panic PIN trigger destroys the SQLCipher database, instantly wiping all active session credentials and histories in a single atomic transaction.

### 2. Offline Sync Model
Incoming message syncing is blocked while the vault is locked. Ciphertext envelopes accumulate securely on the Firestore `/sync_queues` collection. Upon vault unlock, the client establishes DB connections, retrieves session keys, and executes the **Fetch ➔ Decrypt ➔ Store in SQLCipher ➔ Delete from Firestore** pipeline.

### 3. Medium-Term Key Rotation
Since Signed Prekeys and Kyber Prekeys reside in `SecureStorage`, they will be updated periodically by a background **Prekey Rotation Service** in Phase 4.4. Every 7 days, the client rotates these prekeys, signs them using the long-term Identity Key, and updates the public prekey bundle on Firestore.

### 4. Skipped Keys Lifecycle
To prevent database bloat from long-running conversations accumulating skipped message keys (e.g. from lost packets or network jumps), we enforce a strict **Skipped Key TTL of 30 days**. An automated database sweep `deleteExpiredSkippedKeys()` will purge expired skipped keys on database initialization.

### 5. Session Rotation Triggers
To protect against key-material exposure over long durations, the Double Ratchet session state will be rotated and a new handshake initiated under these explicit triggers:
* **Identity Change**: Mismatched identity key detected on target user lookup.
* **Prekey Bundle Update**: Target user publishes a new Signed Prekey or Kyber Prekey on Firestore.
* **Mnemonic Recovery**: Active user restores their identity from seed/recovery mnemonic.
* **Inactivity Expiry**: Session remains inactive for longer than 30 days.
