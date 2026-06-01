# ADR-024 — Compliance Access & Administrative Decryption

**Status:** Accepted

**Date:** 2026-06-01

---

## Context

MemoVault is transitioning from a zero-knowledge private messaging app to a compliance-auditable communications platform to satisfy auditability requirements in business environments. 

However, a pure compliance-access model that opens up all user data conflicts with the primary value proposition of the **Hidden Vault** (which was designed as a secure, local-only, coercion-resistant storage space).

To address both compliance auditability and local security needs, we require a architecture that separates messaging from local secure vault storage. This decision record establishes a **dual-security model** and defines the cryptographic and operational designs for administrative decryption of messaging data.

---

## Decision

We will implement a dual-security model that isolates the local Hidden Vault from compliance access, while enabling administrative auditability for all network messaging.

```text
                               +-----------------------------+
                               |     MemoVault Application   |
                               +--------------+--------------+
                                              |
                     +------------------------+------------------------+
                     |                                                 |
                     v                                                 v
       +---------------------------+                     +---------------------------+
       |    1. Hidden Vault        |                     |   2. Messaging System     |
       |  (No Administrative Access)|                     |   (Compliance-Auditable)  |
       +-------------+-------------+                     +-------------+-------------+
                     |                                                 |
                     v                                                 v
       - Local-only database                               - Ephemeral message keys (MK)
       - SQLCipher (PIN key)                               - Dual-encrypted MK for:
       - No cloud sync / No R2 upload                        1. Recipient (Double Ratchet)
       - Immune to escrow/KMS decryption                     2. Compliance Escrow (X25519 ECIES)
```

### 1. Dual-Security Model Boundary

*   **Private Hidden Vault Storage**: Hidden notes and associated vault assets are stored strictly in `hidden_vault.db` on local device storage. They are encrypted using SQLCipher with a key derived from the user's PIN (ADR-017). They **never** sync to Firestore, **never** upload media to Cloudflare R2, and are entirely immune to administrative decryption.
*   **Compliance-Auditable Messaging**: All text and media messages sent over the network (whether originating from a public or private conversation view) are subject to compliance escrow decryption. The symmetric payload encryption keys are dual-encrypted at the client side before upload.

---

### 2. Cryptographic Envelope (X25519 ECIES)

To encrypt the Message Key (MK) for compliance access without introducing the complexity of RSA-4096, we implement **X25519 Elliptic Curve Integrated Encryption Scheme (ECIES)**. This aligns with the existing Curve25519 cryptography used in the Signal Double Ratchet protocol.

```text
Message Text ──> [AES-256-GCM] ──> Ciphertext Envelope
                       ▲
                       │ (Message Key - MK)
                +──────┴──────+
                │  Generate   │
                │ Ephemeral   │
                │  MK (Raw)   │
                +───┬─────┬───+
                    │     │
       ┌────────────┘     └────────────┐
       ▼                               ▼
[Recipient Public Key]       [Compliance Public Key]
       │                               │
(Double Ratchet Cipher)        (X25519 ECIES Envelope)
       │                               │
       ▼                               ▼
Encrypted MK (Recipient)      Encrypted MK (Compliance)
```

#### Client Encryption Flow:
1.  Generate a cryptographically secure, random 256-bit symmetric **Message Key (MK)**.
2.  Encrypt the plaintext message content with the **MK** using **AES-256-GCM** to produce the ciphertext.
3.  Encrypt the **MK** for the recipient using the active Double Ratchet session key.
4.  Encrypt the **MK** for the compliance escrow using X25519 ECIES:
    *   Retrieve the compiled-in **Compliance Public Key** (X25519).
    *   Generate a single-use **ephemeral X25519 keypair** (Private: $d_e$, Public: $Q_e$).
    *   Compute ECDH between the ephemeral private key $d_e$ and the Compliance Public Key $Q_c$ to get a shared secret $SS$.
    *   Derive a symmetric **Key-Encrypting Key (KEK)** from $SS$ using **HKDF-SHA256** with info parameter `MemoVault Compliance Envelope Key`.
    *   Encrypt the raw **MK** with the **KEK** using **AES-256-GCM** (producing ciphertext $C_{escrow}$ and authentication tag $T_{escrow}$).
5.  Upload the final payload to Firestore, containing:
    *   The message ciphertext.
    *   The encrypted MK block for the recipient.
    *   The compliance escrow block: `ephemeralPublicKey` ($Q_e$), `ciphertext` ($C_{escrow}$), `nonce` (IV), and `authTag` ($T_{escrow}$).

---

### 3. Key Management & Vault Storage

*   **Compliance Public Key**: Hardcoded/configured into the client application binary during compilation.
*   **Compliance Private Key**: Held securely in the **Compliance Vault**:
    *   **Development / Staging**: Stored in a local secret configuration file.
    *   **Production**: Protected inside **Google Cloud KMS** (Key Management Service) backed by FIPS 140-2 Level 3 Hardware Security Modules (HSMs). Clients cannot retrieve this private key. Decryption requests must go through a secure Cloud Function that interacts with the KMS API using strict IAM role permissions.

---

### 4. Admin Panel Access Levels

To prevent administrative abuse, the Admin Panel is divided into two distinct levels of access control:

#### Level 1 — Metadata Access
*   **Permissions**: Granted to general administrative accounts.
*   **Visible Data**:
    *   Users Directory & Account Status.
    *   Cloud Storage Usage Metrics.
    *   Aggregate metrics (Message counts, Conversation counts, Active daily users).
    *   Reported spam/abuse flags.
*   **Constraints**: Plaintext message contents, media files, and decryption keys are **completely hidden**.

#### Level 2 — Authorized Content Access
*   **Permissions**: Restricted to authorized compliance officers.
*   **Access Flow**:
    1.  The compliance officer requests access to a specific Conversation ID.
    2.  The officer **must** input: **Case Number**, **Reason/Justification**, and **Authority Reference** (e.g., legal warrant or corporate policy directive).
    3.  The system records this input in an **immutable, append-only Audit Log** (detailing Who, When, Why, and Which conversation was accessed).
    4.  The system calls the KMS-backed decryption endpoint, retrieving the escrowed Message Keys (MK) for that conversation.
    5.  The message payloads are decrypted on-the-fly and displayed in the review panel. Decrypted keys are never persisted in the admin database.

---

### 5. Media & Cloudflare R2 Integration

All media attachments (images, video, documents, and voice notes) sent via messaging follow a similar compliance-escrowed workflow:

```text
Media File ──> [AES-256-GCM] ──> Upload Ciphertext ──> Cloudflare R2
                     ▲
                     │ (Media Key)
              +──────┴──────+
              │  Generate   │
              │  Media Key  │
              +───┬─────┬───+
                  │     │
                  ▼     ▼
             (Recipient) (Compliance Escrow)
```

1.  **On-Device Encryption**: Before uploading, the client encrypts the media file locally using **AES-256-GCM** with a random **Media Key**.
2.  **R2 Upload**: The client uploads the encrypted media ciphertext to Cloudflare R2, generating an object key.
3.  **Metadata Exchange**: The message metadata in Firestore holds the object key, file size, MIME type, and the **Media Key** encrypted twice:
    *   Encrypted via the recipient's Double Ratchet channel.
    *   Encrypted via the **Compliance Public Key** using X25519 ECIES.
4.  **Admin Decryption Flow**:
    *   When an authorized Level 2 review is active, the Admin Panel fetches the encrypted media metadata from Firestore.
    *   The Admin Panel requests decryption of the encrypted Media Key from Google Cloud KMS (conditioned on a logged case session).
    *   The Admin Panel downloads the ciphertext file from Cloudflare R2, decrypts it locally in the browser/client memory using the decrypted Media Key, and displays it.

---

## Consequences

*   **Preserves User Trust**: The core isolation of the local Hidden Vault is maintained. User notes and stored offline documents remain private, satisfying the coercion-resistance guarantees (ADR-020).
*   **Meets Regulatory Standards**: Corporate environments can deploy MemoVault while complying with electronic communications archiving and legal hold requirements.
*   **Cryptographic Simplicity**: By utilizing X25519 for escrow, we avoid pulling in heavy RSA libraries or complicating key generation profiles.
*   **Robust Audit Trail**: Level 2 access controls ensure administrative actions are transparent and traceable.
*   **Increased Subsystem Scope**: Introducing the Compliance & Admin Platform, Level 2 decryption endpoints, and audit logging adds a new milestone (Phase 4.9), adjusting overall project completion to ≈ 80%.
