# Phase 4.4 — Messaging Local Data Model & Synchronization Flow

This document defines the local database schemas, message/attachment lifecycle states, and sync execution rules for the **Secure Messaging Foundation (Phase 4.0)**. It serves as the implementation blueprint for database repository layers and sync tasks.

---

## 1. Local Database Schemas (Drift Tables)

To satisfy the physical isolation criteria, the tables below are registered in both `AppDatabase` (public notes & chat) and `HiddenVaultDatabase` (private notes & chat) using distinct schema contexts.

```text
  +------------------------------------------------------------+
  |                        Participants                        |
  |  - id (text, PK)                                           |
  |  - username (text, unique)                                 |
  |  - identity_key_pub (text)                                 |
  +-----------------------------+------------------------------+
                                |
                                | 1
                                v 0..*
  +------------------------------------------------------------+
  |                        Conversations                       |
  |  - id (text, PK)                                           |
  |  - participant_id (text, FK -> Participants.id)            |
  |  - last_message_id (text, nullable)                        |
  |  - updated_at (datetime)                                   |
  |  - unread_count (int)                                      |
  |  - is_hidden (bool)                                        |
  |  - is_archived (bool)                                      |
  |  - is_muted (bool)                                         |
  |  - is_blocked (bool)                                       |
  +-----------------------------+------------------------------+
                                |
                                | 1
                                v 0..*
  +------------------------------------------------------------+
  |                           Messages                         |
  |  - id (text, PK)                                           |
  |  - conversation_id (text, FK -> Conversations.id)          |
  |  - sender_id (text, FK -> Participants.id)                 |
  |  - encrypted_content (text)                                |
  |  - nonce (text)                                            |
  |  - state (text/enum)                                       |
  |  - created_at (datetime)                                   |
  +------------------+------------------+----------------------+
                     |                  |
                     | 1                | 1
                     v 0..*             v 0..*
  +------------------+-------+  +-------+----------------------+
  |       MessageReceipts    |  |          Attachments         |
  |  - id (text, PK)         |  |  - id (text, PK)             |
  |  - message_id (text, FK) |  |  - message_id (text, FK)     |
  |  - participant_id (text) |  |  - encrypted_remote_url(text)|
  |  - status (text)         |  |  - key_payload (text)        |
  |  - timestamp (datetime)  |  |  - local_cache_path(nullable)|
  +--------------------------+  |  - size_bytes (int)          |
                                |  - state (text/enum)         |
                                +------------------------------+

  +------------------------------------------------------------+
  |                        SyncMetadata                        |
  |  - key (text, PK)                                          |
  |  - value (text)                                            |
  |  - updated_at (datetime)                                   |
  +------------------------------------------------------------+
```

### 1.1 Drift Schema Code Mockup
```dart
class Participants extends Table {
  TextColumn get id => text()();
  TextColumn get username => text().unique()();
  TextColumn get identityKeyPub => text()();
  
  @override
  Set<Column> get primaryKey => {id};
}

class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get participantId => text().references(Participants, #id)();
  TextColumn get lastMessageId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();
  BoolColumn get isBlocked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(Conversations, #id, onDelete: KeyAction.cascade)();
  TextColumn get senderId => text().references(Participants, #id)();
  TextColumn get encryptedContent => text()();
  TextColumn get nonce => text()();
  TextColumn get state => text()(); // sending, sent, delivered, read, failed, expired
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class MessageReceipts extends Table {
  TextColumn get id => text()();
  TextColumn get messageId => text().references(Messages, #id, onDelete: KeyAction.cascade)();
  TextColumn get participantId => text().references(Participants, #id)();
  TextColumn get status => text()(); // delivered, read
  DateTimeColumn get timestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get messageId => text().references(Messages, #id, onDelete: KeyAction.cascade)();
  TextColumn get encryptedRemoteUrl => text()();
  TextColumn get keyPayload => text()(); // AES key encrypted with E2E session key
  TextColumn get localCachePath => text().nullable()();
  IntColumn get sizeBytes => integer()();
  TextColumn get state => text()(); // uploading, uploaded, decrypting, completed, failed

  @override
  Set<Column> get primaryKey => {id}; // ID-based PK supports multiple attachments per message
}

class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}
```

---

## 2. Message & Attachment State Engines

```text
Message States:
[sending] ──> [sent] ──> [delivered] ──> [read]
   │                                       │
   └──> [failed]                           └──> [expired] (TTL trigger)

Attachment States:
[uploading] ──> [uploaded] ──> [decrypting] ──> [completed]
   │                              │
   └───────────────> [failed] <───┘
```

### 2.1 Message States
*   `sending`: Written locally to database, E2E payload is being constructed and sent to Firestore sync queue.
*   `sent`: Written successfully to Firebase `/sync_queues`.
*   `delivered`: Recipient client fetched the message, sent a delivery confirmation back, and updated the sender.
*   `read`: Recipient user opened the conversation and viewed the message.
*   `failed`: Transmission aborted due to key desynchronization, network timeouts, or rate limits.
*   `expired`: Message deleted from local database due to disappearing messages retention thresholds.

### 2.2 Attachment States
*   `uploading`: Dynamic AES key generated; source binary is being encrypted and uploaded to remote cloud storage.
*   `uploaded`: Remote upload complete; metadata is sent as a message reference.
*   `decrypting`: Remote payload downloaded; local decryption task is running in a separate Dart isolate.
*   `completed`: Local file decrypted and cached inside the secure temporary directory.
*   `failed`: Cryptographic failure or upload/download connection failure.

---

## 3. Synchronization Rules (Data Pipeline Flow)

To keep the UI responsive, data sync operations execute asynchronously and propagate via a clean pipeline:

```text
[Firestore sync_queues] (Cloud Event listener)
          │
          ▼
[Local Sync Engine]
  1. Pull payload
  2. Parse Double Ratchet keys
  3. Decrypt in isolated Background Isolate
  4. Write transaction to local DB (SQLCipher)
  5. Delete remote Firestore queue document (Instant)
          │
          ▼
[Drift Reactive Streams]
  - Listens to local Message/Conversation tables
  - Emits modified streams
          │
          ▼
[GetX Binding Controllers]
  - Updates UI state arrays reactively
          │
          ▼
[UI View Elements]
  - Smooth animation insertions in ListView
```

1.  **Strict Local-First Writes**: Every outgoing action (sending message, toggling read) is committed locally in the SQLCipher database before dispatching remote network operations.
2.  **Atomicity of Decryption & Purge**: Incoming sync queue fetches execute the following transactional sequence:
    *   *Step A*: Attempt E2E decryption of payload. If decryption fails due to structural reasons, mark session key desynced and halt.
    *   *Step B*: Insert decrypted message row inside local DB.
    *   *Step C*: Delete corresponding Firestore sync queue document.
3.  **UI Updates**: The UI never binds directly to Firestore notifications or network listeners. It binds exclusively to reactive Drift tables. When new decrypted rows enter SQLCipher, Drift emits reactive triggers, notifying GetX controllers to append messages to UI ListViews smoothly.
