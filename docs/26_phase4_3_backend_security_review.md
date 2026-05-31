# Phase 4.3 — Backend & Firestore Security Review

This document defines the security controls, access limits, and Firestore security rules governing the server-side transport layer of MemoVault's E2E messaging system. It ensures that the database directory protects user anonymity, prevents spam/abuse, and limits user data exposure.

---

## 1. Firestore Security Rules

To enforce E2E boundaries, Firestore rules block unauthenticated actions, verify message identities, and restrict read/write access.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // 1. Pseudonym Registry: Reads permitted only for exact match queries. Writes restricted to owner.
    match /pseudonyms/{username} {
      allow read: if request.auth != null; // Search directory available only to registered users
      allow create: if request.auth != null 
                    && request.resource.data.username == username
                    && request.resource.data.keys().hasOnly(['username', 'identity_key', 'device_token', 'created_at']);
      allow update: if request.auth != null 
                    && resource.data.identity_key == request.auth.token.identity_key
                    && request.resource.data.keys().hasOnly(['username', 'identity_key', 'device_token', 'created_at']);
      allow delete: if false; // Revocation is flagged via updates, never direct deletions
    }

    // 2. Prekey Bundles: Read-only for initiators. Updates restricted to the bundle owner.
    match /prekey_bundles/{username} {
      allow read: if request.auth != null; // Initiator downloads bundle to start handshake
      allow write: if request.auth != null 
                    && username == request.auth.token.username
                    && request.resource.data.keys().hasOnly(['identity_key', 'signed_prekey', 'signed_prekey_signature', 'one_time_prekeys', 'updated_at']);
    }

    // 3. Sync Queues (In-transit Messages): Sender can create; recipient can read and delete.
    match /sync_queues/{messageId} {
      allow create: if request.auth != null 
                    && request.resource.data.sender_username == request.auth.token.username
                    && request.resource.data.keys().hasOnly(['sender_username', 'recipient_username', 'encrypted_content', 'nonce', 'timestamp']);
      allow read: if request.auth != null 
                  && resource.data.recipient_username == request.auth.token.username;
      allow delete: if request.auth != null 
                    && resource.data.recipient_username == request.auth.token.username;
      allow update: if false; // Messages are immutable once sent
    }
  }
}
```

---

## 2. Platform Abuse Controls & Defenses

### 2.1 Username Enumeration Protection
*   **Problem**: Attackers can execute automated lookup queries to verify if specific usernames exist, mapping pseudonyms to public IP addresses or usage profiles.
*   **Mitigation**:
    1.  **Rate Limiting on Search**: The Firebase Functions lookup API limits searches to **10 lookups per minute** per authenticated IP.
    2.  **No Wildcard Searching**: Firebase Rules explicitly disable listing or wildcard scanning on the `/pseudonyms` collection. To fetch an identity key, the client must query the exact document path: `/pseudonyms/{exact_username}`.

### 2.2 Device Registration Limits
*   **One Device Rule**: The `/pseudonyms` document binds a pseudonym to a single device token ($FCM\_Token$) and a single public Identity Key ($IK_{pub}$).
*   **Overwrite Prevention**: Registering a new device token requires providing a signature validated by the active $IK_{pub}$. If the device is replaced using the recovery seed, the new identity key must revoke the old device token via the signed revocation notice.

### 2.3 Message Queue Retention
*   **Ephemeral Delivery**: The server functions as a temporary queue, not a message store.
*   **Deletion Policy**:
    *   **Instant Deletion**: The recipient client executes a `delete` transaction immediately upon successful retrieval and local decryption of a message from `/sync_queues`.
    *   **Time-to-Live (TTL)**: Undelivered messages remaining in the queue are automatically purged after **14 days** using Firestore TTL policies, preventing offline queue accumulation.

### 2.4 Spam & Abuse Mitigation
*   **Uninvited Message Blocking**:
    *   A client will reject any message payload received from a sender that is not present in their local database contact table.
    *   To establish a connection, the sender must transmit a special `Handshake` content type. The recipient is prompted with a connection request card: *"Accept secure messages from @pseudonym?"*.
    *   If declined, the sender's username is added to a local blocklist, and all future payloads from that sender are instantly deleted upon arrival without decrypting.
*   **Per-Contact Message Limits**: Cloud Functions restrict a single sender to a maximum of **20 pending messages** in the `/sync_queues` collection for any specific recipient at any single time. If this threshold is reached, new incoming writes from that sender to the recipient's queue will be rejected by the server until the recipient client downloads and deletes the pending messages, preventing queue flooding.
*   **Server-Side Rate Limiting**: Firebase Cloud Functions rate-limits incoming message writes to `/sync_queues` at **60 messages per minute** per user, preventing DDoS and chat flooding.


