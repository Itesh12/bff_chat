# 11 — Risk Register

> **Document Status:** Living Document — Phase 0 🔒 LOCKED & APPROVED  
> **Last Updated:** 2026-05-30  
> **Owner:** Engineering Team / Security Lead

---

## Overview

This register documents all identified risks across three categories:

- **Technical Risks** — Risks related to technology choices, architecture, and implementation
- **Security Risks** — Risks related to confidentiality, integrity, and access control
- **Operational Risks** — Risks related to infrastructure, administration, and usage patterns

Each risk is assessed by:

| Field | Scale |
|---|---|
| **Probability** | Low / Medium / High |
| **Impact** | Low / Medium / High / Critical |
| **Overall** | Low / Medium / High / Critical |

Mitigation strategies are defined for all Medium and above risks.

---

## 1. Technical Risks

### TR-001 — Firebase Quota Exhaustion

| Field | Detail |
|---|---|
| **Description** | Unexpected growth or a bug causes Firestore reads/writes, Storage bandwidth, or FCM send rates to exceed Firebase's free-tier or budgeted quota, resulting in service disruption |
| **Probability** | Low (2–10 users) |
| **Impact** | High (messaging goes offline, notes sync stops) |
| **Overall** | Medium |

**Mitigation:**
- Set Firebase budget alerts at $5, $10, and $25 thresholds to detect anomalies early
- Implement Firestore Security Rules that prevent runaway reads (e.g., unbounded collection scans)
- Use Firestore pagination — never read an entire collection in one request
- Cache aggressively in Isar to minimize redundant Firestore reads
- Monitor Firebase Usage dashboard at least weekly during early phases
- Design architecture for 1,000 users (quota headroom far exceeds actual user count)

---

### TR-002 — Isar / Firestore Sync Conflicts

| Field | Detail |
|---|---|
| **Description** | A note is edited offline on two devices simultaneously. When both come online, conflicting versions are pushed to Firestore, resulting in data loss or corruption |
| **Probability** | Low (only 2–10 users, typically single device per person) |
| **Impact** | Medium (note content loss is a real UX failure) |
| **Overall** | Low-Medium |

**Mitigation:**
- Implement **last-write-wins with server timestamp** as the conflict resolution strategy (simplest, acceptable for low user count)
- Store `updatedAt` (client) and `syncedAt` (server) separately on every note document
- Display a conflict indicator in UI if server version differs from local on sync (Phase 2 stretch goal)
- Evaluate CRDTs or operational transforms only if conflicts become a real problem post-launch

**Version Recovery Strategy:**
- Maintain the **last 5 revisions** of every note as a write-once Firestore subcollection (`/notes/{userId}/user_notes/{noteId}/revisions/{revisionId}`)
- Each revision captures: `title`, `body`, `updatedAt` (client timestamp), `deviceId`
- **Phase 2:** Revision history written automatically on every note save — no UI required
- **Future phase:** Version history UI allows users to preview and restore a previous version
- **Retention:** On write of a 6th revision, the oldest is deleted (max 5 retained)
- This provides recovery from accidental overwrites even though last-write-wins is the sync strategy

---

### TR-003 — Push Notification Delivery Failure

| Field | Detail |
|---|---|
| **Description** | FCM data-only (silent) notifications are not delivered reliably on iOS due to system restrictions on background execution and battery optimization |
| **Probability** | Medium (iOS has strict background push limitations) |
| **Impact** | High (users miss messages without opening the app) |
| **Overall** | High |

**Mitigation:**
- Use FCM `content-available: 1` flag for iOS silent pushes (triggers background refresh)
- Implement **polling fallback**: when app foregrounds, always fetch missed messages from Firestore regardless of push receipt
- Use Firestore real-time listeners as the primary delivery mechanism — push is supplementary
- Test notification delivery on actual iOS devices (not simulator) in Phase 9
- Consider APNs priority settings (high priority for messages, normal for background sync)
- Document known iOS limitations; set user expectations accordingly

---

### TR-004 — Offline Synchronization Failures

| Field | Detail |
|---|---|
| **Description** | Device goes offline mid-message-send or mid-note-edit. Local state diverges from server state in a way that cannot be cleanly reconciled on reconnect |
| **Probability** | Medium (mobile devices go offline regularly) |
| **Impact** | Medium (message loss or duplicate messages) |
| **Overall** | Medium |

**Mitigation:**
- Assign locally-generated UUIDs to all messages and notes before any network call — enables idempotent writes
- Use Firestore offline persistence (enabled by default) for the messaging layer
- Implement an outbound message queue in Isar for messages pending delivery — retry on reconnect
- Deduplicate on server using the client-generated UUID as the Firestore document ID
- Monitor connectivity using `connectivity_plus` and communicate offline state clearly in UI
- Never delete a local message from Isar until Firestore confirms write success

---

### TR-005 — Encryption Key Loss

| Field | Detail |
|---|---|
| **Description** | The Isar encryption key or ECDH private key stored in Flutter Secure Storage is lost due to device wipe, OS upgrade, or Secure Storage corruption. Encrypted local data becomes permanently inaccessible |
| **Probability** | Low-Medium (Secure Storage is reliable but not infallible) |
| **Impact** | Critical (all local data permanently lost; cloud messages unreadable without private key) |
| **Overall** | High |

**Mitigation:**
- **Isar encryption key loss:** Only loses local cache — data is re-syncable from Firestore (notes) or re-receivable for new messages. Historical message ciphertext without key is irrecoverable; this is an accepted trade-off for security
- **ECDH private key loss (Phase 8):** Design key rotation as a first-class feature; allow users to request re-provisioning through admin
- Use Android Keystore / iOS Secure Enclave as hardware-backed storage — significantly reduces corruption risk
- Do NOT back up Secure Storage to iCloud/Google Drive (prevents backup extraction attacks); Secure Storage does NOT backup by default
- Clearly communicate to users during onboarding: "If you factory reset your device, message history cannot be recovered"
- Evaluate encrypted key backup strategy (admin-held recovery shard) in Phase 8

---

### TR-006 — Device Binding Edge Cases

| Field | Detail |
|---|---|
| **Description** | Legitimate scenarios (new phone, broken phone, factory reset) prevent the user from accessing the messaging layer on their new device because device binding prevents unapproved registration |
| **Probability** | Medium (phones are replaced/reset periodically) |
| **Impact** | Medium (user locked out; admin intervention required) |
| **Overall** | Medium |

**Mitigation:**
- Admin can revoke old device binding and generate a new invite code via Firebase Admin SDK script
- Document the device transfer process in an admin runbook (Phase 4)
- Implement a "request device transfer" flow in-app (Phase 4) that sends a notification to admin
- Cap max devices per user at 2 (configurable) to limit abuse while supporting real-world usage
- Always provide admin with visibility into bound devices via Firestore Console

---

### TR-007 — Flutter / Dependency Compatibility

| Field | Detail |
|---|---|
| **Description** | A Flutter SDK upgrade or package upgrade breaks existing functionality, particularly for packages with native code (Isar, Flutter Secure Storage, local_auth) |
| **Probability** | Medium (Flutter evolves rapidly) |
| **Impact** | Medium (build failures or runtime crashes) |
| **Overall** | Medium |

**Mitigation:**
- Pin Flutter version using `fvm` and commit `.fvmrc` to the repository
- Pin all dependency versions in `pubspec.yaml` (no `^` wildcards for critical packages)
- Upgrade dependencies deliberately and one at a time, never in bulk
- Run full test suite after any dependency upgrade before committing
- Maintain a `DEPENDENCIES.md` file logging each package, its version, and why it was chosen

---

## 2. Security Risks

### SR-001 — App Reverse Engineering

| Field | Detail |
|---|---|
| **Description** | Attacker decompiles the APK or IPA and discovers the existence of the hidden messaging feature, route names, or activation keyword |
| **Probability** | Medium (APK decompilation is straightforward; IPA is harder) |
| **Impact** | High (hidden layer exposed; trust model broken) |
| **Overall** | High |

**Mitigation:**
- Enable Flutter's `--obfuscate --split-debug-info` on all release builds — makes decompiled Dart code unreadable
- **Activation keyword protection (full strategy):**
  1. Keyword is **never stored in plaintext** anywhere in source, binary, or local storage
  2. Only a **salted SHA-256 hash** of the keyword is used for comparison
  3. The hash and salt are **delivered via Firebase Remote Config** — not embedded in the binary
  4. Admin can **rotate the keyword without an app update** by changing Remote Config values
  5. Local validation computes `SHA-256(input + salt)` and compares to the Remote Config hash — plaintext never transmitted
  6. Multiple **decoy hashes** in Remote Config confuse reverse engineering analysis
- Use non-descriptive route names (e.g., `/vault/v` instead of `/messaging/chat`)
- Avoid Dart class names that hint at purpose (e.g., `MessagingController` → obfuscated to `_Ctrl_xyz`)
- Firebase security rules protect server data even if client is reverse-engineered
- Conduct reverse engineering testing in Phase 11 (penetration test)

---

### SR-002 — Rooted / Jailbroken Devices

| Field | Detail |
|---|---|
| **Description** | A rooted Android or jailbroken iOS device bypasses app-level security, including Flutter Secure Storage protections, screen recording blocks, and sandbox isolation |
| **Probability** | Low (target users unlikely to have rooted devices) |
| **Impact** | Critical (all encryption keys extractable; all security layers bypassable) |
| **Overall** | High |

**Mitigation:**
- Implement root/jailbreak detection using `flutter_jailbreak_detection` package (Phase 4)
- If rooted device detected: refuse to open the hidden messaging layer; show generic notes app only
- Log root detection events to Firestore audit log
- Accepted residual risk: determined attacker with root + physical access can eventually bypass software protections; the primary defense is the multi-layer model making this non-trivial
- Document this as a known limitation — hardware-level attacks are out of scope

---

### SR-003 — Screenshot Bypass

| Field | Detail |
|---|---|
| **Description** | User circumvents screenshot blocking in the messaging layer using external tools, screen mirroring, or a second camera |
| **Probability** | Medium (second camera is always possible) |
| **Impact** | High (message content exposed) |
| **Overall** | High |

**Mitigation:**
- `FLAG_SECURE` (Android) and iOS equivalent block software screenshots and screen recording — implement in Phase 8
- Detect screenshot attempts and log them; notify sender that a screenshot was taken (Phase 8, F-805)
- Accepted residual risk: physical camera pointed at screen cannot be blocked by software
- Educate users (via in-app tooltip on first open) that physical camera capture is not preventable
- Consider view-once media (F-806) for the most sensitive content

---

### SR-004 — Backup Extraction

| Field | Detail |
|---|---|
| **Description** | Android Auto Backup or iTunes/Finder backup captures app data, including Isar database files and Secure Storage contents, which are then restored to another device |
| **Probability** | Low-Medium |
| **Impact** | High (encrypted data extractable; Secure Storage may be included in backup on some configs) |
| **Overall** | Medium |

**Mitigation:**
- Configure `android:allowBackup="false"` and `android:fullBackupContent` exclusion rules in `AndroidManifest.xml` to exclude Isar database and Secure Storage from Auto Backup
- iOS: Flutter Secure Storage is configured with `.afterFirstUnlock` accessibility and `synchronizable: false` — prevents iCloud sync of keys
- Isar database files are encrypted at rest — even if extracted, decryption without the key (not in backup) is not possible
- Document backup exclusion configuration in Phase 1 checklist

---

### SR-005 — Credential Leakage

| Field | Detail |
|---|---|
| **Description** | Firebase API keys, Auth credentials, or invite codes are leaked through logs, crash reports, or repository commits |
| **Probability** | Low-Medium |
| **Impact** | Critical (full access to Firebase project) |
| **Overall** | High |

**Mitigation:**
- Add `google-services.json`, `GoogleService-Info.plist`, and all `.env` files to `.gitignore` immediately in Phase 1
- Use GitHub secret scanning and pre-commit hooks to prevent accidental commits of secrets
- Firebase API keys are restricted via Firebase Security Rules — key alone does not grant data access
- Never log Firebase tokens, encryption keys, PINs, or invite codes (enforced by coding standards in `08_coding_standards.md`)
- Rotate Firebase API keys if a suspected leak occurs (Firebase Console → Project Settings)
- Store production credentials only in secure secret management (not in repository, not in plaintext files)

---

### SR-006 — Insider Threat — Invite Code Sharing

| Field | Detail |
|---|---|
| **Description** | A legitimate user shares their invite code or the secret activation keyword with an unauthorized person |
| **Probability** | Low (small Vault Network — 2–10 users) |
| **Impact** | High (unauthorized access to private workspace) |
| **Overall** | Medium |

**Mitigation:**
- Invite codes are single-use and expire after 48 hours — sharing is only useful within the window
- Device binding ensures even a shared code only activates on one device
- Admin receives an audit log event when an invite code is used — anomalous activations detectable
- Admin can immediately revoke any account showing unexpected activity
- Secret keyword is not stored anywhere — users must memorize it; cannot be "copied and shared"

---

## 3. Operational Risks

### OR-001 — Firebase Service Outage

| Field | Detail |
|---|---|
| **Description** | Firebase / Google Cloud experiences an outage, making Firestore, Auth, Storage, or FCM unavailable |
| **Probability** | Low (Firebase SLA is high; full outages are rare) |
| **Impact** | High (messaging completely unavailable; notes sync stops) |
| **Overall** | Medium |

**Mitigation:**
- **Notes:** Local-first architecture means notes remain fully accessible offline — Isar is the primary store
- **Messaging:** Implement message queue in Isar; messages sent during outage are queued and delivered when Firebase recovers
- Monitor Firebase Status Dashboard (`status.firebase.google.com`) during active development
- Design all UI to handle Firebase errors gracefully with clear offline indicators
- Accepted residual risk: during auth outages, users already logged in retain their session; new logins fail

---

### OR-002 — Lost Device

| Field | Detail |
|---|---|
| **Description** | A user loses their phone. The device may contain encrypted local message data and an active Firebase session |
| **Probability** | Medium (devices are lost regularly) |
| **Impact** | High (risk of unauthorized access if device is found and unlocked) |
| **Overall** | High |

**Mitigation:**
- Admin can immediately revoke the device's Firebase session via Admin SDK (remote logout)
- PIN/biometric requirement means the hidden layer requires authentication even on an unlocked device
- Isar database is encrypted — without the encryption key (in Secure Storage, hardware-backed), data is not accessible
- Advise users to report a lost device to admin immediately
- Admin runbook for device revocation documented in Phase 4
- Accepted residual risk: if device is unlocked and the user has active biometric bypass, the notes layer is accessible

---

### OR-003 — Invite Code Compromise

| Field | Detail |
|---|---|
| **Description** | An in-transit invite code is intercepted (e.g., shared via an insecure channel) before the legitimate user can activate it |
| **Probability** | Low-Medium (depends on delivery channel) |
| **Impact** | High (attacker activates before legitimate user; legitimate user locked out) |
| **Overall** | Medium |

**Mitigation:**
- Invite codes expire after 48 hours — delivery should happen close to expected activation time
- Deliver invite codes only via trusted channels (in-person preferred; end-to-end encrypted messaging as fallback)
- If a code is compromised before use, admin generates a new code and invalidates the old one via Admin SDK
- If compromised after use: admin revokes the fraudulent device, generates a new invite for the legitimate user
- Audit log captures device fingerprint on activation — admin can compare expected vs actual device

---

### OR-004 — Panic Mode Misuse

| Field | Detail |
|---|---|
| **Description** | A user accidentally enters the panic PIN instead of the real PIN, locking themselves out of their real conversation history (they see the fake empty vault) |
| **Probability** | Medium (user error with similar PINs) |
| **Impact** | Low (no data loss; user just needs to close and re-enter with real PIN) |
| **Overall** | Low |

**Mitigation:**
- Panic PIN and real PIN must differ by at least 2 digits (validated at setup time)
- Document the "you have entered panic mode" recovery path in user help text (in-app)
- Panic mode does not lock out the real PIN — user simply exits and re-enters with correct PIN
- Add a subtle visual indicator only visible to the user to confirm they are in real mode (e.g., a personalized wallpaper that is absent in panic mode) — evaluate in Phase 3

---

### OR-005 — Firebase Storage Cost Growth

| Field | Detail |
|---|---|
| **Description** | Users share large media files (videos, documents), causing Firebase Storage costs to grow unexpectedly |
| **Probability** | Medium (media sharing is a core feature from Phase 7) |
| **Impact** | Medium (unexpected billing) |
| **Overall** | Medium |

**Mitigation:**
- Enforce maximum file size limits in the app layer before upload (e.g., images: 10 MB, videos: 100 MB)
- Compress images before upload using Flutter image compression packages
- Set Firebase Storage security rules to reject files above size threshold
- Implement media lifecycle policies: media in self-destruct conversations is deleted from Storage (Phase 8)
- Set Firebase billing alerts and storage usage monitoring
- With 2–10 users, significant costs are unlikely; re-evaluate if user base grows

---

## 4. Risk Summary Matrix

| ID | Risk | Probability | Impact | Overall | Phase to Address |
|---|---|---|---|---|---|
| TR-001 | Firebase Quota Exhaustion | Low | High | **Medium** | Phase 1 (budget alerts) |
| TR-002 | Sync Conflicts | Low | Medium | **Low-Medium** | Phase 2 |
| TR-003 | Push Notification Delivery | Medium | High | **High** | Phase 9 |
| TR-004 | Offline Sync Failures | Medium | Medium | **Medium** | Phase 5 |
| TR-005 | Encryption Key Loss | Low-Medium | Critical | **High** | Phase 1 + Phase 8 |
| TR-006 | Device Binding Edge Cases | Medium | Medium | **Medium** | Phase 4 |
| TR-007 | Flutter Dependency Compatibility | Medium | Medium | **Medium** | Phase 1 (pinning) |
| SR-001 | Reverse Engineering | Medium | High | **High** | Phase 1 + Phase 11 |
| SR-002 | Rooted/Jailbroken Devices | Low | Critical | **High** | Phase 4 |
| SR-003 | Screenshot Bypass | Medium | High | **High** | Phase 8 |
| SR-004 | Backup Extraction | Low-Medium | High | **Medium** | Phase 1 |
| SR-005 | Credential Leakage | Low-Medium | Critical | **High** | Phase 1 |
| SR-006 | Insider Threat / Invite Sharing | Low | High | **Medium** | Phase 4 |
| OR-001 | Firebase Outage | Low | High | **Medium** | Phase 1 (offline design) |
| OR-002 | Lost Device | Medium | High | **High** | Phase 4 |
| OR-003 | Invite Code Compromise | Low-Medium | High | **Medium** | Phase 4 |
| OR-004 | Panic Mode Misuse | Medium | Low | **Low** | Phase 3 |
| OR-005 | Storage Cost Growth | Medium | Medium | **Medium** | Phase 7 |

---

## 5. Risk Review Schedule

| Event | Action |
|---|---|
| Start of each phase | Review all risks tagged for that phase; confirm mitigations are in implementation plan |
| End of each phase | Review all risks; update probabilities based on actual implementation findings |
| Security incident | Immediate risk register update; add new risk if novel threat identified |
| Production launch | Full risk review as part of Phase 11 release checklist |
