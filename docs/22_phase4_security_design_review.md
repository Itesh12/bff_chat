# Phase 4.0 — Security & Messaging Design Review (Pre-Implementation)

This document provides a comprehensive security design review, threat model, and execution roadmap for the **Secure Messaging Foundation (Phase 4.0)** in MemoVault. It addresses identity validation, cryptographic handshakes, network transmission boundaries, push notifications, and visual integration within the hidden vault to ensure zero-trust compliance.

---

## 1. User Identity Model

MemoVault enforces a zero-knowledge user identity model that operates independently of third-party identifiers (such as phone numbers, emails, or hardware-backed device UUIDs).

```text
+-------------------------------------------------------------+
|                     On-Device Registration                  |
|                                                             |
| 1. Generate Master Key (via Cryptographic Entropy Source)   |
| 2. Derive Identity Keypair (IK) via Ed25519                |
| 3. Register Username (@pseudonym) mapped to IK on Server   |
+-------------------------------------------------------------+
```

*   **Long-Term Identity Key ($IK$)**: An Ed25519 keypair generated on-device during the initial application setup. The private component is stored inside the hardware-backed keystore/keychain, and the public component is uploaded to the server directory.
*   **Pseudonym System**: Users identify themselves using a self-selected unique username (e.g. `@shield_4821`). The server directories store only the username mapping to the public identity key ($IK_{pub}$).
*   **Key Storage Isolation**:
    *   **Private Identity Keys**: Stored in [SecureStorageService](file:///c:/bff_chat/lib/core/storage/secure_storage_service.dart), bound to the Android Keystore or iOS Keychain. They are marked as non-exportable.
    *   **Public Key Directory**: Published to a read-only Firestore directory, searchable only via exact username matches to prevent directory harvesting.

---

## 2. Pairing Model (How Users Connect)

To establish a communication channel, users must execute a bidirectional cryptographic pairing handshake:

```text
[User A (Initiator)]                                            [User B (Recipient)]
       |                                                                 |
       |  1. Generate QR Code / 12-Char Invite Code                      |
       |     Contains: Username + Identity Key (IK) + Temp Secret        |
       |     (e.g., ABCD-EFGH-IJKL)                                      |
       |                                                                 |
       |  2. Send pairing link / present QR code to B                    |
       +---------------------------------------------------------------->|
       |                                                                 |
       |  3. Decrypt/Scans QR, verify IK signature                       |
       |  4. Generate Handshake Request (encrypt via Temp Secret)        |
       |<----------------------------------------------------------------+
       |                                                                 |
       |  5. Confirm request in UI, calculate shared secret              |
       |  6. Initialize Double Ratchet session                           |
       +---------------------------------------------------------------->|
```

1.  **Pairing Invites**: User A generates a temporary pairing invite containing their username, public Identity Key ($IK_{A\_pub}$), and a cryptographically secure 128-bit single-use passcode (rendered as a QR code or a 12-character alphanumeric code `ABCD-EFGH-IJKL`).
2.  **Handshake Transmission**: User B scans the QR code or enters the invite code. This unlocks the temporary passcode, allowing User B to encrypt their public key bundle and transmit it back to User A via the server.
3.  **Authentication**: Both clients compute the initial Shared Secret ($SS$) using the temporary passcode and their respective Identity Keys, creating the cryptographic foundation for the Double Ratchet session.

---

## 3. Device Binding

*   **Hardware Isolation**: The user's Identity Key is directly bound to the device's hardware enclave. Private components cannot be transferred, backed up, or exported.
*   **Revocation and Replacement**: If a user switches to a new device:
    *   A new Identity Key ($IK_{new}$) must be generated.
    *   The user must notify their contacts to update key mappings.
    *   The server invalidates the old $IK$ and updates the registry.
    *   Existing chat screens in contact devices will display a warning badge: *"Warning: Identity Key for @pseudonym has changed. Re-verify identity via QR code."* This prevents active Man-in-the-Middle impersonation.

---

## 4. Multi-Device Policy

*   **Single-Device Constraint**: MemoVault enforces a strict **"One User, One Device"** policy.
*   **Rationale**: Distributing message keys across multiple active devices requires multi-recipient encryption (multiplying ciphertext sizes) or key synchronization servers, both of which increase the system's attack surface. Restricting sessions to a single hardware device guarantees forward secrecy and minimizes data exposure vectors.

---

## 5. Key Backup & Recovery Strategy

*   **Zero Cloud Backups**: The server never stores private keys, and message databases are never backed up to the cloud in plaintext. If the physical device is lost or destroyed, local message history is lost forever.
*   **Identity Recovery (BIP-39 Mnemonic)**:
    *   Upon registration, the app generates a 12-word recovery mnemonic seed (BIP-39 standard).
    *   The Identity Keypair ($IK$) is derived deterministically from this seed.
    *   If a user loses their phone, they can restore their `@pseudonym` mapping and Identity Key on a new device by entering the 12-word seed.
    *   Historical messages remain unrecoverable, but contacts will not receive a security warning as the Identity Key ($IK$) remains unchanged.

---

## 6. Contact Discovery

To maintain user anonymity, MemoVault does not access the device's address book or contacts database.

1.  **Direct Pseudonym Search**: Users must manually enter the exact pseudonym (e.g. `@alex_vault`). Partial searches are disabled to prevent bulk contact harvesting.
2.  **Visual QR Exchange**: Direct face-to-face scanning of a user's identity card.
3.  **Secure Invite Link**: Out-of-band delivery of an invite token.

---

## 7. Push Notification Payloads

FCM/APNs notifications must not leak plaintext data or metadata. All payloads are masked.

### Notification JSON Format
```json
{
  "to": "device_registration_token",
  "priority": "high",
  "data": {
    "t": "msg_alert",
    "c_id": "8f8303ad8f902ba7c80287a9b8e8f810", 
    "m_id": "01af38bc901a89c87f",
    "h": "true"
  }
}
```
*   `t`: Message type (e.g., `msg_alert`).
*   `c_id`: SHA-256 hash of the Conversation ID.
*   `m_id`: SHA-256 hash of the Message ID.
*   `h`: Boolean flag (`true` or `false`) indicating if the thread is hidden.
*   **Local Processing**: When `h` is `true`, the local client intercepts the push payload, bypasses the system's default notification parser, and displays a generic status message: *"System Sync: Completed"*. Tapping the notification launches the app and navigates directly to the Hidden Vault PIN keypad.

---

## 8. Attachment Encryption Details

Media files are encrypted using a separate, fast symmetric cipher before uploading to storage.

1.  **Limits**:
    *   **Images**: Max 10MB.
    *   **Audio/Voice Logs**: Max 15MB.
    *   **Videos/Documents**: Max 50MB.
2.  **Thumbnail Strategy**: The sender generates a 128x128 pixel thumbnail (JPEG) on-device. This thumbnail is encrypted and embedded directly in the E2E message JSON metadata. This permits immediate local preview rendering upon decryption without initiating a separate remote file download.
3.  **Cache Eviction**: Decrypted media assets are written to the application's secure cache directory. The files are automatically deleted after 7 days, or instantly upon locking the vault or triggering a panic wipe.

---

## 9. Conversation Migration Algorithm

Moving a conversation from the public space into the Hidden Vault must be treated as an atomic operation:

```text
1. Start Transaction (Public DB & Private DB)
   ↓
2. Read metadata + message rows from public tables
   ↓
3. Encrypt data payload with Private SQLCipher Key
   ↓
4. Write new encrypted records to hidden tables
   ↓
5. Perform secure page overwrite on public DB tables
   ↓
6. Commit Transaction (both databases)
   ↓
[Success]
   * If any step fails, roll back both transactions to prevent duplicate states.
```

To prevent page recovery on SQLite databases, public deletes are executed using:
`PRAGMA secure_delete = ON;`
This ensures deleted records are overwritten with zeros, preventing raw block analysis.

---

## 10. Message Retention Strategy

To minimize local data exposure, MemoVault provides multiple retention policies:

1.  **Disappearing Messages**: Per-conversation configurations. Message rows are automatically deleted from local databases after a set duration (Options: Off, 1 Hour, 24 Hours, 7 Days).
2.  **Burn After Reading (BAR)**: Once the recipient reads the message, a local countdown (e.g., 30 seconds) triggers. Once completed, the message row is deleted.
3.  **Wipe-on-Lock**: If enabled, all cached message rows are wiped from active volatile memory immediately when the screen is locked, requiring re-decryption from SQLCipher upon the next vault opening.

---

## 11. Hidden Messaging UX Flows (Option B)

Option B (Vault Dashboard Model) integrates Notes, Messaging, and Media into a single secure workspace.

```text
                    +-----------------------------+
                    |    PIN Authentication       |
                    +--------------+--------------+
                                   |
                                   v
                    +-----------------------------+
                    |       Vault Dashboard       |
                    +-----------------------------+
                    | [ Notes ] [ Chats ] [ Media]| <-- Segment Control
                    +--------------+--------------+
                                   |
                                   +---> [ Chats Selected ]
                                         |
                                         v
                    +-----------------------------+
                    |   Secure Conversations      |
                    |                             |
                    | - @anon_one (2 unread)      |
                    | - @agent_x                  |
                    +-----------------------------+
```

*   **Segmented Layout**: The main viewport utilizes a segmented header button control: `Notes` | `Chats` | `Media`.
*   **Interception Navigation**: When a masked notification is clicked, the app displays the PIN keypad. If validation succeeds, the application launches the Vault Dashboard and defaults to the `Chats` segment, opening the target conversation thread.

---

## 12. Threat Model

| Threat | Vector | Mitigation Strategy |
| :--- | :--- | :--- |
| **Physical Seizure** | Attacker extracts database files from device storage. | Databases are encrypted with SQLCipher using a key stored in the hardware-backed keystore. The key is only present in volatile memory while the session is unlocked. |
| **Server Hijacking** | Malicious administrator intercepts messaging traffic. | Double Ratchet E2E encryption ensures the server only receives encrypted ciphertexts ($C$) and initialization vectors ($IV$). |
| **Identity Impersonation** | Attacker performs a Man-in-the-Middle attack during registration. | Bidirectional verification of public keys ($IK_{pub}$) is enforced via visual QR verification. |
| **Coerced Unlock** | User is forced to open the app by an adversary. | A specific panic PIN triggers a full database and secure key wipe, leaving the app in a clean, public-only state. |

---

## 13. Security Assumptions

1.  **Hardware Integrity**: The host operating system isolates process memory correctly. Secure enclave storage cannot be dumped via root exploits.
2.  **Cryptographic Primitives**: SHA-256, Ed25519, and AES-256-GCM are secure against mathematical attacks.
3.  **PIN Strength**: The user selects a non-obvious 4-digit PIN. Cooldown limits prevent automated brute-forcing.

---

## 14. Failure Scenarios

*   **Ratchet Desynchronization**: If a message fails to decrypt due to missed keys or state mismatch, the client sends a `RatchetException` code. The recipient client automatically initiates a request for a new key bundle to reset the ratchet.
*   **Database Corruption**: If SQLCipher throws a decryption or corruption exception, **ADR-011** triggers. The app database files and keys are wiped. The user is prompted to restore their profile using their 12-word recovery seed.

---

## 15. Phase 4 Execution Order

1.  **Milestone 4.1: Cryptography Engine**: Implement the X3DH key agreement and Double Ratchet protocol in pure Dart.
2.  **Milestone 4.2: Local Database Schemas**: Configure public and private SQLCipher tables for messages and conversations.
3.  **Milestone 4.3: Connection Exchange UI**: Build QR generation and scanning interfaces for pairing invites.
4.  **Milestone 4.4: Synchronization Layer**: Set up WebSockets or Firebase sync handlers for message transit queues.
5.  **Milestone 4.5: Push Notification Handler**: Implement generic notification masking and route interception.
6.  **Milestone 4.6: Messaging UX Integration**: Construct the Vault Dashboard view (Notes/Chats/Media tabs) and chat UI screens.
