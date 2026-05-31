# ADR-020 — Panic PIN & Coercion Resistance

**Status:** Accepted

**Date:** 2026-05-31

---

## Context

A key threat vector for a secure vault application is physical coercion—where the user is forced by an adversary to unlock the private storage space under duress. To counter this threat, MemoVault requires a coercion resistance mechanism: a "Panic PIN" that appears to unlock the vault normally, but instead executes a destructive wipe, returning the application to a clean, public-only state without raising suspicion or displaying error messages.

---

## Decision

1. **Dual PIN Verification System**:
   - The application configuration stores two distinct PIN salt-hash records: the **Real PIN** and the **Panic PIN** inside `hidden_vault_config_v1` within secure storage.
   - Entering the **Real PIN** validates the user, derives the decryption keys, initializes the SQLCipher connection, and routes the user to the Vault Dashboard.
   - Entering the **Panic PIN** bypasses database decryption entirely and immediately triggers the panic sequence.

2. **Destructive Panic Sequence (Wipe Scope)**:
   - **Database Erasure**: Physically deletes `hidden_vault.db` and its companion WAL/Journal files (`hidden_vault.db-wal`, `hidden_vault.db-shm`) from local storage. Deletions are executed with secure page overwrite rules (`PRAGMA secure_delete = ON`) to overwrite sectors with zeroes.
   - **Key Purging**: Deletes all secure configuration keys, hashes, and salts associated with the Hidden Vault (specifically `hidden_vault_encryption_key_v1` and `hidden_vault_config_v1`) from secure storage.
   - **Memory Eviction**: Flushes all active GetX controllers, caches, and repository instances from RAM.
   - **Server Unregister**: Sends a fire-and-forget payload to the server database to flush prekey bundles and mark the cryptographic identity as revoked.

3. **Behavior & Coercion Camouflage**:
   - **Visual Deception**: To prevent the adversary from realizing a wipe has occurred, the application must **NOT** display any "Wiping database" or error dialogues. Instead, it completes the unlock animation and redirects the user to the public Notes dashboard as if the vault is simply empty, or shows a mocked screen indicating "No private data is configured."
   - **Notification Masking**: Erases all generic notifications from the device tray.
   - **Analytics & Logs**: The dynamic event `panic_pin_triggered` is logged in volatile runtime memory only (non-persistent RAM logs) to facilitate development debugging. Wiping actions are **never** written to local disk files, never persisted in databases, and never transmitted to Firebase or remote server-side analytics. No user identifiers or secrets are attached.

4. **ADR-020.1 — Post Panic State**:
   Immediately after the panic sequence executes, the application establishes the following state guidelines:
   - **Hidden Vault**: Reset to `Unconfigured` state inside persistent app state services.
   - **Hidden PIN**: Completely `Removed` and cleared from secure storage enclaves.
   - **Hidden Database**: Fully `Deleted` and unlinked from the local file directory.
   - **Messaging Identity**: Cryptographically `Revoked` on both client database and server storage directories.
   - **Hidden Activation Search Trigger**: `Disabled` and de-registered from all search handlers.
   - **Seed Recovery Screen**: Made `Available` so that users can input their 12-word seed to restore their messaging identity when setup flow is re-initiated, while the base application remains in standard public notes mode.

---

## Consequences

*   **Plausible Deniability**: The user can input the Panic PIN under duress, destroying the vault content without showing any error or warning messages.
*   **Irreversible Action**: Once triggered, all local vault notes, conversations, and attachments are permanently gone from the device. Messaging recovery is only possible if the 12-word seed (generated during secure messaging setup) is input on the Seed Recovery screen.
*   **Restores Baseline Safety**: Returns the app to a normal notes application state.
