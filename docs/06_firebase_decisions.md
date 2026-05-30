# 06 — Firebase Decisions

> **Document Status:** Living Document — Phase 0 🔒 LOCKED & APPROVED  
> **Last Updated:** 2026-05-30  
> **Owner:** Engineering Team

---

## 1. Firebase Project Strategy

### 1.1 Multi-Project Setup

We maintain **three separate Firebase projects** — one per environment:

| Environment | Firebase Project ID (TBD) | Purpose |
|---|---|---|
| `dev` | `memovault-dev` | Local development, emulators, test data |
| `staging` | `memovault-staging` | QA testing, integration tests, UAT |
| `prod` | `memovault-prod` | Production users, hardened rules |

**Rationale:**
- Prevents test data from contaminating production
- Security rules can be tested in staging before production deployment
- Each project has independent billing and quota

### 1.2 Firebase Emulator Suite

Local development in the `dev` flavor uses the **Firebase Emulator Suite**:
- Firestore Emulator
- Authentication Emulator
- Storage Emulator
- FCM (limited — manual testing required for push)

---

## 2. Firestore Data Model

### 2.1 Design Principles

- **Denormalization** for read performance (Firestore is document-oriented)
- **Subcollections** for message threads (avoids document size limits)
- **No joins** — data structured to support the access patterns of the app
- All documents include `createdAt`, `updatedAt` server timestamps
- All documents include `createdBy` (userId) for security rule validation

### 2.2 Planned Collections

> ⚠️ This is the Phase 0 proposed schema. Schemas will be refined before each implementation phase.

```
/users/{userId}
    - displayName: string
    - publicKey: string        (ECDH public key — Phase 8)
    - deviceIds: string[]      (bound device fingerprints)
    - status: "active" | "suspended" | "pending"
    - lastSeen: timestamp
    - createdAt: timestamp

/invites/{inviteCode}
    - hashedCode: string       (SHA-256 of invite code)
    - targetUserId: string
    - expiresAt: timestamp
    - used: boolean
    - usedAt: timestamp?
    - createdBy: string        (admin userId)

/conversations/{conversationId}
    - participants: string[]   (exactly 2 userIds)
    - lastMessage: map         (preview — encrypted)
    - lastMessageAt: timestamp
    - createdAt: timestamp

/conversations/{conversationId}/messages/{messageId}
    - senderId: string
    - ciphertext: string       (encrypted message body)
    - iv: string               (AES initialization vector)
    - type: "text" | "image" | "voice" | "video" | "document" | "location"
    - mediaUrl: string?        (Firebase Storage URL — encrypted filename)
    - status: "sent" | "delivered" | "read"
    - replyToId: string?
    - deletedAt: timestamp?
    - editedAt: timestamp?
    - createdAt: timestamp

/presence/{userId}
    - online: boolean
    - lastSeen: timestamp
    - typing: map              (conversationId → boolean)

/audit_logs/{logId}
    - event: string
    - userId: string
    - deviceId: string
    - metadata: map
    - success: boolean
    - timestamp: timestamp

/notes/{userId}/user_notes/{noteId}
    - title: string
    - body: string             (rich text — encrypted if cloud sync enabled)
    - category: string?
    - tags: string[]
    - isFavorite: boolean
    - isArchived: boolean
    - attachments: string[]    (Storage URLs)
    - createdAt: timestamp
    - updatedAt: timestamp
```

### 2.3 Document Size Considerations

- Firestore maximum document size: **1 MB**
- Messages are always stored as subcollection documents — no size risk
- Notes body is stored locally (Isar) **and** synced to Firestore (cloud sync is enabled — see ADR-009)
- Notes sync architecture: **Local-first (Isar) → Background sync → Firestore**
- Notes remain fully functional offline; sync is best-effort and conflict-resolved server-side
- Media stored in Firebase Storage — Firestore stores only the URL

### 2.4 Notes Conflict Resolution & Version Recovery

**Conflict Resolution Strategy:** Last-write-wins with server timestamp.

- All note writes include `updatedAt` (client timestamp) and the server applies `syncedAt` on receipt
- In the rare event of concurrent offline edits, the last document to reach Firestore wins

**Version Recovery Strategy:**

To protect against accidental overwrites, MemoVault maintains note revision history:

- **Last 5 versions** of every note are retained in Firestore as a subcollection
- Each revision captures: `body`, `title`, `updatedAt`, `deviceId` of the editing device
- Revision documents are write-once (append-only) — no revision can be overwritten
- **Phase 2:** Store revision history automatically on every note save (no UI required)
- **Future phase:** Expose a version history UI allowing the user to preview and restore a previous version

**Firestore Revision Schema:**
```
/notes/{userId}/user_notes/{noteId}/revisions/{revisionId}
    - title: string
    - body: string
    - updatedAt: timestamp    (client timestamp of the edit)
    - syncedAt: timestamp     (server timestamp of the sync)
    - deviceId: string        (which device made the edit)
```

**Retention Policy:** Maximum 5 revisions per note. On write of a 6th revision, the oldest is deleted.

---

## 3. Firebase Security Rules Strategy

### 3.1 Rules Philosophy

```
// Default deny
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

All access is **deny by default**. Rules are additive.

### 3.2 Planned Rules per Collection

| Collection | Read Rule | Write Rule |
|---|---|---|
| `/users/{userId}` | Authenticated + (own doc OR participants in shared conversation) | Own doc only |
| `/invites/{code}` | Server-side only (Admin SDK) | Server-side only |
| `/conversations/{id}` | Participant only | Participant only |
| `/conversations/{id}/messages/{msgId}` | Participant only | Sender only (create); Recipient only (update status) |
| `/presence/{userId}` | Any authenticated user | Own doc only |
| `/audit_logs/{logId}` | Admin only | Server-side only |
| `/notes/{userId}/user_notes/{noteId}` | Own doc only | Own doc only |

### 3.3 Rule Validation Requirements

Security rules must be unit-tested using the **Firebase Rules Emulator** before deployment. Rule tests committed alongside rule changes.

---

## 4. Firebase Storage Strategy

### 4.1 Bucket Structure

```
gs://memovault-prod/
├── media/
│   └── {conversationId}/
│       └── {messageId}/
│           └── {filename}          ← encrypted filename, encrypted content
├── avatars/
│   └── {userId}/
│       └── avatar.jpg
└── notes_attachments/
    └── {userId}/
        └── {noteId}/
            └── {filename}
```

### 4.2 Storage Security Rules

- Users may only upload to their own `conversationId` subtree (where they are a participant)
- Maximum file size limits enforced in storage rules
- File type validation in application layer (Storage rules cannot inspect MIME type reliably)
- Encrypted filenames in the `media/` bucket — decryption key held client-side

### 4.3 Media Lifecycle

- Media files are not auto-deleted when messages are deleted (soft delete in Firestore)
- Full media purge is a manual admin operation or triggered by self-destruct mode (Phase 8)
- Storage lifecycle rules (Firebase Storage TTL) configured per environment

---

## 5. Firebase Authentication Configuration

### 5.1 Enabled Sign-In Methods

**Strategy:** Invite-only Email/Password Authentication with provisioned credentials, device binding, and remote revocation support.

| Method | Enabled | Purpose |
|---|---|---|
| Email/Password | ✅ | Primary identity method — credentials system-generated, never user-chosen |
| Anonymous | ❌ | Disabled — all users must be fully authenticated with provisioned identity |
| Google | ❌ | Not required |
| Phone | ❌ | Not required |

### 5.2 Invite Provisioning Flow

Admin creates user accounts server-side via **Firebase Admin SDK** (run as scripts locally — no custom admin interface):
1. Admin SDK creates Firebase Auth user with a generated email pattern (hidden from UI)
2. Admin SDK generates invite payload (userId + temp credential + expiry)
3. Invite payload encrypted and encoded for delivery
4. Admin delivers invite code to user via out-of-band channel (direct/in-person)
5. User manually enters invite code in app — app exchanges code for Firebase session

### 5.3 Account Management

- Users cannot change their email through the app (no public-facing email concept)
- Password reset is not applicable — account managed via Firebase Console or Admin SDK scripts
- Account suspension: Firebase Auth user disabled via Admin SDK
- **No custom admin dashboard** — all admin operations via Firebase Console or local Admin SDK scripts

---

## 6. Firebase Cloud Messaging (FCM) Strategy

### 6.1 Notification Architecture

All push notifications for the messaging layer use **data-only (silent) messages**:

```json
{
  "data": {
    "type": "new_message",
    "conversationId": "...",
    "timestamp": "..."
  },
  "notification": null
}
```

**Why data-only?**
- No notification content displayed in the system tray automatically
- App processes the notification in the background and decides what (if anything) to display
- Content is never visible in notification center — no metadata leakage

### 6.2 Disguised Notification Display

If the app determines it should show a visible notification, it constructs a system notification with **disguised content**:

```
Title: "MemoVault"
Body: "You have a new reminder"   ← generic, never reveals messaging
```

The actual notification routing (which conversation to open) is handled by the data payload, not displayed text.

### 6.3 FCM Token Management

- FCM token stored in Firestore under `/users/{userId}` — field `fcmTokens: []` (array for multi-device)
- Token refreshed on app start and stored securely
- Old tokens pruned from Firestore when new token registered

---

## 7. Firebase Remote Config

### 7.1 Use Cases

| Key | Type | Purpose |
|---|---|---|
| `messaging_enabled` | boolean | Global kill switch for the private workspace feature |
| `min_app_version` | string | Force update enforcement |
| `max_message_length` | number | Runtime configurable message size limit |
| `invite_expiry_hours` | number | Invite code TTL |
| `feature_reactions` | boolean | Feature flag for reactions (Phase 6) |
| `feature_voice_notes` | boolean | Feature flag for voice notes (Phase 7) |
| `activation_hash` | string | Salted SHA-256 hash of the secret activation keyword |
| `activation_salt` | string | Salt used in SHA-256 activation hash computation |

### 7.2 Fetch Strategy

- Remote Config fetched on app start with 1-hour minimum fetch interval (production)
- 0-second interval in `dev` flavor for rapid iteration
- Default values hardcoded in app — Remote Config supplements, never replaces defaults

---

## 8. Resolved Firebase Questions

| Question | Decision |
|---|---|
| **Firebase project names** | `memovault-dev`, `memovault-staging`, `memovault-prod` |
| **Notes collection in Firestore** | Yes — notes sync to Firestore via background sync (Local-first / Isar primary) |
| **Firebase Admin SDK hosting** | Local Admin SDK scripts only. No Cloud Functions or custom backend. |
| **Firestore indexing strategy** | Composite indexes defined per-phase before implementation. Planned for Phase 5. |
| **`audit_logs` location** | Firestore (plaintext, admin-readable). Cloud Logging evaluated in Phase 11. |
| **FCM tokens** | Array per user (`fcmTokens: []`) to support up to 2 devices (configurable). |
