# Phase 4.2 — Key Management & Server Schema Architecture

This document defines the lifecycle, rotation parameters, revocation procedures, and server-side data models for managing cryptographic keys inside the **Secure Messaging Foundation (Phase 4.0)**. It details X3DH handshake primitives and their integration with the database storage layer.

---

## 1. Key Primitives Specification

MemoVault uses the **Extended Triple Diffie-Hellman (X3DH)** protocol for initial key agreement. The client manages three distinct classes of keys:

| Key Type | Protocol Code | Cryptographic Algorithm | Storage Location | Lifetime / Rotation |
| :--- | :---: | :--- | :--- | :--- |
| **Identity Key** | $IK$ | Ed25519 (Signature) & X25519 (DH) | Hardware Enclave (Keystore/Keychain) | Permanent (unless device is replaced) |
| **Signed Prekey** | $SPK$ | X25519 | Local SQLCipher Database | Rotated every 7 days |
| **One-Time Prekey** | $OPK$ | X25519 | Local SQLCipher Database | Destroyed upon use (single-use) |

---

## 2. Key Lifecycle & Rotation Policy

To preserve Forward Secrecy and mitigate replay attacks, prekeys are systematically rotated:

```text
                  +--------------------------------+
                  |  Background Rotation Engine    |
                  +---------------+----------------+
                                  |
            +---------------------+---------------------+
            | Every 7 Days                              | OPK Pool Count < 25
            v                                           v
+-----------------------+                   +-----------------------+
|  Generate New SPK     |                   |  Generate 75 New OPKs |
|  Sign SPK with IK     |                   |                       |
|  Upload SPK + Sig     |                   |  Upload OPKs to Server|
+-----------------------+                   +-----------------------+
```

1.  **Signed Prekey ($SPK$) Rotation**:
    *   **Interval**: Generated and rotated every **7 days** by the client's background synchronization runner.
    *   **Signature**: The client signs the public key $SPK_{pub}$ with the private Identity Key ($IK_{priv}$) using Ed25519.
    *   **Upload**: The client uploads the new signed prekey and signature to the server. Old signed prekeys are stored locally for up to 14 days to decrypt incoming messages delayed in transit, then purged.
2.  **One-Time Prekeys ($OPK$) Rotation**:
    *   **Pool Size**: The client initially uploads a bundle of **100 One-Time Prekeys** ($OPK_{pub}$) to the server directory.
    *   **Depletion Trigger**: When the server detects that the available $OPK$ count for a user drops below **25**, it triggers a sync payload to the client.
    *   **Replenishment**: The client generates **75 new $OPKs$** and uploads them to restore the server-side pool to 100.

---

## 3. Revocation & Device Replacement Flow

If a device is lost, stolen, or replaced, the user initiates a cryptographic key revocation process to restore identity and secure existing channels:

```text
1. User enters 12-word seed on new device
   ↓
2. Derive master identity seed and verify username ownership
   ↓
3. Generate new ephemeral Identity Key (IK_new)
   ↓
4. Client signs a Revocation Notice:
   RevocationNotice = Sign(IK_old_pub + "REVOKED", IK_new_priv)
   ↓
5. Upload Revocation Notice to server
   ↓
6. Server marks IK_old_pub as invalid and flushes active prekey bundles
   ↓
7. Contacts' clients sync notice, prompt user: "Identity Key changed"
```

1.  **Identity Restoration**: The user downloads the app on a new device and enters their **12-word BIP-39 recovery seed**.
2.  **Derivation**: The client derives the identity parameters. Since the old device's private keys are gone, the client generates a new ephemeral $IK_{new}$ and signs a revocation notice containing the old identity key hash.
3.  **Server Revocation**: Upon receipt of the validated revocation payload, the server:
    *   Invalidates $IK_{old}$.
    *   Deletes all pending $OPKs$ and $SPKs$ linked to the old identity.
    *   Updates the public pseudonym directory mapping to point to $IK_{new}$.
4.  **Peer Synchronization**: During the next routine sync, peers download the revocation signature. The client UI registers the identity change, displays an alert warning inside the conversation view, and prompts the user to re-verify the contact via QR code.

---

## 4. Server Storage Schema (Firestore JSON Models)

The server acts as a zero-knowledge directory service. It stores public keys, signatures, and unconsumed prekey bundles.

### 4.1 `/pseudonyms` Collection
Tracks registered pseudonyms and active public identity keys.
```json
{
  "username": "@shield_4821",
  "identity_key": "MEYCIQCc9dF23...", // Base64 public Ed25519 identity key
  "created_at": "2026-05-31T11:00:00Z",
  "revoked": false,
  "revocation_notice": {
    "revocation_signature": "MEYCIQ...", // Signature validating key destruction
    "revoked_at": null
  }
}
```

### 4.2 `/prekey_bundles` Collection
Maintains the active signed prekey and the queue of unconsumed one-time prekeys.
```json
{
  "username": "@shield_4821",
  "signed_prekey": "X25519_PUBLIC_KEY_BASE64",
  "signed_prekey_signature": "ED25519_SIGNATURE_BASE64",
  "signed_prekey_created_at": "2026-05-31T11:00:00Z",
  "one_time_prekeys": [
    "OPK_1_BASE64",
    "OPK_2_BASE64",
    "OPK_3_BASE64"
    // ... Up to 100 keys
  ]
}
```

### 4.3 `/sync_queues` Collection
Holds E2E encrypted messages in transit (wiped instantly upon delivery confirmation).
```json
{
  "message_id": "uuid_v4_string",
  "recipient_username": "@shield_4821",
  "sender_username": "@agent_x",
  "encrypted_payload": "AES_GCM_CIPHERTEXT_BASE64",
  "nonce": "INITIALIZATION_VECTOR_BASE64",
  "one_time_prekey_used": "OPK_X_BASE64", // Null if session was already established
  "created_at": "2026-05-31T11:02:00Z"
}
```
