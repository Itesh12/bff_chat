# 05 — Security Decisions

> **Document Status:** Living Document — Phase 0 🔒 LOCKED & APPROVED  
> **Last Updated:** 2026-05-30  
> **Owner:** Engineering Team / Security Lead

---

## 1. Security Philosophy

Security is a **first-class architectural concern**, not a retrofit.

Every feature, data model, and API surface must be evaluated against the threat model before implementation begins.

The primary threats are:

| Threat | Description |
|---|---|
| **Physical device inspection** | Device falls into hands of an adversary who opens the app |
| **Account compromise** | Someone obtains user credentials |
| **Traffic interception** | Man-in-the-middle attack on communication |
| **Notification interception** | Notifications reveal communication metadata |
| **Data exfiltration** | Firebase data accessed without authorization |
| **Insider threat** | A user leaks invite codes or screenshots the messaging layer |
| **App reverse engineering** | APK/IPA decompiled to discover hidden feature structure |

---

## 2. Security Layers

The security model is structured in **defense in depth** — multiple independent layers, each of which must be breached independently:

```
Layer 1 — App Appearance (Plausible Deniability)
Layer 2 — Secret Activation (Hidden Entry)
Layer 3 — Authentication (PIN / Biometric)
Layer 4 — Identity (Invite-Only Firebase Auth)
Layer 5 — Device Binding (One account per device)
Layer 6 — Transport Security (TLS + Firebase Auth tokens)
Layer 7 — End-to-End Encryption (Message content)
Layer 8 — At-Rest Encryption (Local database)
Layer 9 — Notification Stealth (No content in push)
Layer 10 — Panic Mode (Fake UI on wrong PIN)
```

A casual attacker who bypasses Layer 1 (opens the app) is still blocked by every subsequent layer.

---

## 3. Authentication Strategy

### 3.1 Firebase Authentication

**Strategy:** Invite-only Email/Password Authentication with provisioned credentials, device binding, and remote revocation support.

- **Anonymous Auth is NOT used** — all users must have proper, provisioned identity.
- **Custom token authentication** may be used for invite-code-to-account bootstrapping during the activation flow.
- **Email/password auth** is the mechanism, but the email is system-generated and never shown in the app UI.
- Users do not "sign up" — they receive an invite that provisions their credentials and account.
- All devices are bound on first activation; access can be remotely revoked per-device.

### 3.2 Invite-Only Flow

```
Admin creates invite
    → Encrypted invite payload generated (contains userId + secret)
    → Admin delivers invite code via out-of-band channel (direct message / in-person)
    → User manually enters invite code in app (no QR code in Phase 4)
    → App decrypts invite payload
    → App calls Firebase Auth with provisioned credentials
    → Device fingerprint recorded in Firestore
    → Account marked as "activated" — invite code invalidated
```

- Each invite code is **single-use**.
- Invite codes expire after 48 hours.
- Invite codes are hashed in Firestore — plaintext never stored server-side.

### 3.3 PIN / Biometric Authentication

- PIN is a 6-digit code (configurable: 4–8 digits in Phase 3).
- PIN hash stored in Flutter Secure Storage (never in SharedPreferences).
- Biometric auth (FaceID / Fingerprint) is offered as a convenience layer over PIN.
- **Panic PIN** — alternate PIN that opens a **fake vault** showing empty notes, fake conversations, and believable empty media. No data is deleted.

### 3.4 Session Management

- Firebase ID tokens are refreshed automatically by the Firebase SDK.
- Refresh tokens stored exclusively in **Flutter Secure Storage**.
- Session revocation is supported via Firebase Auth admin SDK — remote logout possible.
- Token expiry behavior: on expiry, app locks to PIN screen (does not return to notes).

---

## 4. Encryption Strategy

### 4.1 Transport Encryption

- All Firebase communication occurs over **TLS 1.2+** (enforced by Firebase SDK).
- Firebase Auth tokens validate every Firestore request — no anonymous read is possible.
- Certificate pinning: **evaluate for Phase 11** (adds complexity, may conflict with Firebase SDK updates).

### 4.2 End-to-End Encryption (E2EE)

**Status:** Planned for Phase 8

**Algorithm:** ECDH (Elliptic-Curve Diffie-Hellman) for key exchange + AES-256-GCM for message encryption.

**Key Exchange Flow:**
```
User A generates ECDH key pair (private key stored in Secure Storage)
User A publishes public key to Firestore user document
User B retrieves User A's public key
User B derives shared secret using User B's private key + User A's public key
Shared secret used to derive AES-256 session key (via HKDF)
Messages encrypted with AES-256-GCM before write to Firestore
Messages decrypted after read from Firestore
```

**Properties:**
- Private keys **never leave the device**
- Firebase stores only ciphertext — Firebase admin cannot read messages
- Each conversation has a unique derived key
- Key rotation strategy to be designed in Phase 8

### 4.3 At-Rest Encryption (Local Database)

- **Isar** is the primary local database. Isar v3+ supports native encryption via an encryption key passed on database open.
- The Isar encryption key is generated on first run using a cryptographically secure random generator.
- The Isar encryption key is stored in **Flutter Secure Storage** (backed by Android Keystore / iOS Secure Enclave).
- Media files cached locally are encrypted before write to disk.

### 4.4 Key Management

| Key Type | Storage | Rotation |
|---|---|---|
| Firebase Auth refresh token | Flutter Secure Storage | On forced logout |
| Isar database encryption key | Flutter Secure Storage | On account reset |
| ECDH private key | Flutter Secure Storage | On key rotation (Phase 8) |
| PIN hash | Flutter Secure Storage | On user PIN change |

---

## 5. Data Protection

### 5.1 Screenshot & Screen Recording

- **Screenshot blocking** enabled in messaging screens (Android: `FLAG_SECURE`, iOS: `UIScreen` recording protection).
- Screenshot attempts in messaging layer are detected and logged (Phase 8).
- Notes layer: screenshots allowed (notes app must behave normally).

### 5.2 Clipboard Protection

- Message content must not be accessible via clipboard on Android without user action.
- Auto-clear clipboard after pasting sensitive content: **evaluate for Phase 8**.

### 5.3 App Backgrounding

- When app enters background, **messaging layer screens are obscured** (solid overlay or blur).
- Notes layer: standard background behavior.

### 5.4 Memory

- Sensitive strings (PIN, keys) must not be held in memory longer than necessary.
- Avoid caching decrypted message payloads beyond the current session view.

---

## 6. Firebase Security Rules Strategy

All Firestore collections must be secured with the principle of **least privilege**:

| Rule Type | Policy |
|---|---|
| **Default** | Deny all reads and writes |
| **Authenticated reads** | Only authenticated users may read their own data |
| **Cross-user reads** | Only permitted on whitelisted fields (e.g., public key, display name) |
| **Admin writes** | Invite management only via Firebase Admin SDK (server-side) |
| **Message writes** | Only sender may write a message; only recipient may mark as read |
| **Media uploads** | Only authenticated users; file size and type restrictions enforced in rules |

Security rules must be code-reviewed before each Firebase deployment.

---

## 7. Hidden Feature Protection

### 7.1 Secret Keyword — Activation Security Strategy

The secret activation keyword is the most sensitive runtime secret in the application. It must be protected at every level:

**Strategy:**

1. **Never stored in plaintext** — The keyword is never written as a string literal anywhere in the source code, binary, or local storage.
2. **SHA-256 hash with salt** — The keyword is stored only as a salted SHA-256 hash. The salt is fixed per-environment and delivered alongside the hash.
3. **Delivered via Firebase Remote Config** — The hashed keyword (and its salt) are NOT embedded in the app binary. They are fetched from Firebase Remote Config at runtime.
4. **Remote rotation without app update** — Because the hash is in Remote Config, the admin can change the activation keyword at any time by updating the Remote Config value. No app release is required.
5. **Hash-only local validation** — When a user types a keyword in the search bar, the app computes `SHA-256(userInput + salt)` and compares it to the Remote Config hash. The plaintext keyword is never stored or transmitted.
6. **No logging of activation attempts** — The activation check function is stateless and produces no logs of what keyword was typed (success/failure is logged, not content).

**Remote Config Keys:**

| Key | Value |
|---|---|
| `activation_hash` | `SHA-256(keyword + salt)` — hex-encoded |
| `activation_salt` | Fixed salt string for this environment |

**Validation Flow:**
```
User types keyword in search bar
    → App computes: candidate = SHA-256(input + remoteConfigSalt)
    → App compares: candidate == remoteConfigHash
    → Match: activate hidden layer (no visual cue)
    → No match: normal search behavior (no indicator)
```

**Decoy Keywords:**
- Multiple decoy hash values may be added to Remote Config to confuse reverse engineering attempts
- Decoy matches trigger a no-op (no hidden layer activation, no log)

**Rotation Protocol:**
1. Admin chooses new keyword
2. Admin computes: `SHA-256(newKeyword + salt)` (salt unchanged or rotated together)
3. Admin updates `activation_hash` (and optionally `activation_salt`) in Firebase Remote Config
4. Next Remote Config fetch (within 1 hour in prod, immediate in dev) delivers new hash
5. Old keyword immediately stops working — no app update required
6. Admin communicates new keyword to Vault Network members via secure out-of-band channel

### 7.2 Code Obfuscation

- Flutter release builds must use `--obfuscate --split-debug-info` to reduce APK/IPA readability.
- Class names and route names related to the hidden layer must be non-descriptive.

### 7.3 Route Isolation

- Hidden messaging routes must not appear in any route definition accessible from the notes layer.
- Route names for messaging must not contain human-readable terms ("message", "chat", "hidden").

---

## 8. Panic Mode

**Panic Mode** is activated by entering the alternate "panic PIN":

| Action | Behavior |
|---|---|
| Enter panic PIN | App opens and shows a **fake vault** with empty notes |
| Fake conversations | Messaging layer shows empty conversation list (no history) |
| Fake media | Media gallery shows empty state |
| Local data | **NOT deleted** — data remains encrypted on device |
| Cloud data | **NOT deleted** — cloud data is fully preserved |
| Appearance | Indistinguishable from a freshly installed app with no data |

> ⚠️ Local wipe functionality may be evaluated in a future phase but is explicitly out of scope for Phase 3/4.

---

## 9. Audit Logging

All security-sensitive events must be logged to Firestore with:
- Event type
- Timestamp (server timestamp)
- Device fingerprint
- User ID
- Success/failure

**Logged Events:**
- Secret activation attempt (success/failure)
- PIN entry (success/failure — no PIN value logged)
- Biometric auth result
- Message sent / received
- Device login
- Forced logout (remote)
- Invite code used
- Key rotation

---

## 10. Resolved Security Questions

| Question | Decision |
|---|---|
| **Panic mode — data wipe?** | No. Panic mode does NOT wipe local or cloud data. Shows fake vault only. |
| **Invite flow** | Manual code entry only (Phase 4). QR code deferred to future phase. |
| **Admin management** | Firebase Console + Admin SDK scripts only. No custom admin interface. |
| **Certificate pinning** | Evaluate in Phase 11. Not implemented until then. |
| **Key rotation frequency** | Event-triggered (device revocation, suspected compromise). Not time-based. |
| **Audit logs encryption** | Plaintext in Firestore for admin review. Encryption deferred to Phase 11 evaluation. |
| **ECDH library** | `cryptography` package preferred over `pointycastle` (better maintained, cleaner API). Decision confirmed in Phase 8. |
| **Duress word** | Deferred — not in scope for current phases. |
