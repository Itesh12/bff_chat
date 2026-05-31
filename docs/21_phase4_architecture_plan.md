# Phase 4.0 — Secure Messaging Foundation Architecture Plan

This document outlines the detailed architecture, database design, cryptographic models, and synchronization strategies for the **Secure Messaging Foundation (Phase 4.0)** in MemoVault. This plan ensures maximum data confidentiality, structural isolation, and feature parity between public and hidden spaces.

---

## 1. Message Schema

Messages will be stored in SQLite/SQLCipher databases using Drift tables. The schema supports end-to-end encrypted text, media attachments, delivery status, and foreign key relations.

### Drift Table Definition Mockup
```dart
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(Conversations, #id, onDelete: KeyAction.cascade)();
  TextColumn get senderId => text()();
  TextColumn get recipientId => text()();
  TextColumn get encryptedContent => text()(); // AES-GCM encrypted payload
  TextColumn get nonce => text()(); // Initialization vector (IV) for decryption
  TextColumn get contentType => text().map(const MessageContentTypeConverter())(); // text, image, file, system
  TextColumn get status => text().map(const MessageStatusConverter())(); // pending, sent, delivered, read
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  DateTimeColumn get readAt => dateTime().nullable()();
  TextColumn get encryptedAttachmentPath => text().nullable()(); // Local/remote encrypted asset pointer
  TextColumn get attachmentDecryptionKey => text().nullable()(); // Single-use encrypted key for the media
}
```

---

## 2. Conversation Schema

Conversations define the thread hierarchy, tracking active threads, typing indicators, unread states, and hidden status.

### Drift Table Definition Mockup
```dart
class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get participantId => text()(); // ID of the other user
  TextColumn get lastMessageId => text().nullable()(); // Fast dashboard rendering
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))(); // Migration trigger flag
}
```

---

## 3. SQLCipher Storage Strategy

To uphold the physical isolation principles established in **ADR-019 (Separate Data Sources)**, messaging data will be divided along security boundaries:

```text
               +--------------------------------------+
               |          Messaging Router            |
               +------------------+-------------------+
                                  |
            +---------------------+---------------------+
            | isHidden = false                          | isHidden = true
            v                                           v
+-----------------------+                   +-----------------------+
|  Public SQL Database  |                   | Encrypted SQLCipher   |
|   (memovault.db)      |                   |   (hidden_vault.db)   |
|                       |                   |                       |
| - Conversations Table |                   | - Conversations Table |
| - Messages Table      |                   | - Messages Table      |
+-----------------------+                   +-----------------------+
```

*   **Public Threads**: Stored directly in `memovault.db`. Encrypted locally using the public DB's SQLCipher key.
*   **Hidden Threads**: Stored in `hidden_vault.db`. Decryption keys are fetched on-demand when the PIN is entered. Memory pointers are nullified on logout.
*   **Memory Isolation**: Messages in hidden threads are loaded into memory *only* while the vault session is unlocked. Closing the session immediately executes `Get.delete<HiddenMessagingController>()` and flushes database connections.

---

## 4. End-to-End (E2E) Encryption Architecture

MemoVault utilizes a zero-trust E2E encryption architecture for the wire-transit layer:

```text
[Alice Client]                                                [Bob Client]
      |  Encrypted Payload (AES-256-GCM)                           |
      +-------------------------> [Firebase/Server] --------------->|
      |                                                            |
```

1.  **Symmetric Encryption**: Message text/media is encrypted client-side using **AES-256-GCM** (Galois/Counter Mode).
2.  **Unique Keys per Message**: Each message uses a distinct key derived from a Double Ratchet session, ensuring Perfect Forward Secrecy (PFS).
3.  **Authentication/Integrity**: AES-GCM provides an authentication tag to ensure the message payload has not been tampered with in transit.

---

## 5. Key Exchange Model

MemoVault implements the **Extended Triple Diffie-Hellman (X3DH)** protocol for initial secure key agreement:

```text
[Alice]                                [Server]                                [Bob]
   |                                      |  Bob Prekey Bundle                   |
   | 1. Fetch Bob Bundle                  |<-------------------------------------+
   |------------------------------------->|                                      |
   |                                      |                                      |
   | 2. Compute Master Secret             |                                      |
   | 3. Send Handshake Message            |                                      |
   +------------------------------------->|------------------------------------->|
```

1.  **Prekey Bundles**: Every user generates and uploads their Identity Key, Signed Prekey, and a set of One-Time Prekeys to the server.
2.  **Handshake**: Initiator fetches the bundle of the recipient, executes Diffie-Hellman computations, and initiates a local Double Ratchet session.
3.  **Local Storage**: Session states, ratchet keys, and shared keys are written directly to the SQLCipher database (Public or Hidden depending on conversation classification).

---

## 6. Media & Message Attachment Architecture

To scale message size without impacting database performance:

1.  **Encryption**: Media files (images, audio, files) are encrypted on-device before upload using a unique, cryptographically secure symmetric key generated via `Random.secure()`.
2.  **Upload**: The encrypted binary blob is uploaded to cloud storage (e.g. Firebase Storage).
3.  **Reference Exchange**: The message body contains:
    *   The download URL of the encrypted blob.
    *   The symmetric decryption key (encrypted via E2E channel for the recipient).
    *   A SHA-256 hash of the encrypted file to verify download integrity.
4.  **Decryption**: The recipient downloads the encrypted blob, verifies the hash, and decrypts the file directly to local cached storage.

---

## 7. Offline-First Synchronization Strategy

The sync engine uses a local-first queue model to operate smoothly under poor network conditions:

1.  **Pending State**: Outgoing messages are written to local SQLite/SQLCipher tables with a `pending` status.
2.  **Background Queue**: A queue worker processes pending messages, executing E2E encryption and delivering them to the network layer (WebSocket or Firebase).
3.  **Exponential Backoff**: If transmission fails, the worker backs off, retrying when network availability resumes.
4.  **Idempotency**: All messages carry a client-generated UUID. If the server receives duplicate messages, it ignores duplicates but confirms receipt to the client.

---

## 8. Read Receipts

*   **Trigger**: Fired when a message is rendered on-screen (via a visibility tracking widget).
*   **Delivery**: A status packet is transmitted to the sender containing the message ID and timestamp.
*   **Database Update**: Upon receipt, the sender updates the local message record: `status = read` and `readAt = currentDateTime()`.

---

## 9. Delivery Receipts

*   **Trigger**: Fired immediately when the recipient client receives the message payload (even in a background push handler).
*   **Delivery**: A delivery confirmation packet is sent back.
*   **Database Update**: The sender updates the message record: `status = delivered` and `deliveredAt = currentDateTime()`.

---

## 10. Panic Mode Interaction with Messaging

1.  **Panic Trigger**: Multiple invalid PIN entries, trigger keywords, or manual distress buttons.
2.  **Execution**:
    *   `hidden_vault.db` and its corresponding SQLCipher key are instantly deleted from physical storage.
    *   All memory pointers, encryption key indices, and active session objects are purged.
    *   A distress signal is sent to the server to un-register or flush the user's prekeys, stopping active deliveries.
3.  **Restoration**: After a panic wipe, the application boots as a clean, public-only notes app. No traces of messaging threads or contacts remain.

---

## 11. Hidden Vault Integration Rules

*   **Stealth Notifications**: When a message arrives for a hidden conversation:
    *   The push notification must **never** contain the sender's name or message snippet.
    *   It must display a generic mask text (e.g., "System Update Check complete" or "Sync success").
    *   Tapping the notification launches the app and, if configured, intercepts via the PIN lock screen.
*   **Dynamic Migration**: Users can migrate a public conversation to hidden. When triggered:
    *   The conversation and its history are read from `memovault.db`, written to `hidden_vault.db`, and deleted from `memovault.db`.

---

## 12. Future Firebase Sync Boundaries

*   **No Plaintext on Server**: Firestore and Firebase Cloud Storage act as transport/holding layers only.
*   **Content Isolation**: Firebase never receives the decryption key, prekey master secrets, or plain content.
*   **Anonymity**: User relations and session routes are hashed where possible to prevent traffic analysis on the server database.
