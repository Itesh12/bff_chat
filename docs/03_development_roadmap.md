# 03 — Development Roadmap

> **Document Status:** Living Document — Phase 0 🔒 LOCKED & APPROVED  
> **Last Updated:** 2026-06-01  
> **Owner:** Engineering Team

---

## Overview

This roadmap defines the official phased delivery plan for the MemoVault application.

Each phase has a clearly defined goal, deliverables, and exit criteria. **No phase may begin until the previous phase's exit criteria are met and approved.**

---

## Phase 0 — Product Foundation & Architecture

**Goal:** Establish the complete technical and product blueprint before any code is written.

**Status:** ✅ Complete

### Deliverables

| Deliverable | Description | Status |
|---|---|---|
| Product specification | Documented product vision, personas, and pillars | ✅ Done |
| Security specification | Encryption, auth, secret access, and data protection strategy | ✅ Done |
| Feature specification | Full feature inventory for all phases | ✅ Done |
| Firebase architecture | Firestore data model, security rules strategy, and service map | ✅ Done |
| Encryption strategy | E2E encryption design, key management, at-rest encryption | ✅ Done |
| Authentication strategy | Auth flow design, invite-only system, device binding design | ✅ Done |
| Notification strategy | Hidden notification design, disguise system design | ✅ Done |
| Hidden activation strategy | Secret keyword design, navigation hiding strategy | ✅ Done |
| Offline strategy | Local-first (Isar) design, sync conflict resolution approach | ✅ Done |
| Error handling strategy | Error taxonomy, reporting, and recovery strategy | ✅ Done |
| Analytics strategy | Privacy-respecting telemetry design | ✅ Done |
| Release strategy | Environment setup, CI/CD pipeline design, store strategy | ✅ Done |

### Exit Criteria
- [x] All documentation files created and reviewed
- [x] Open questions resolved or formally deferred
- [x] Architecture decisions logged with rationale
- [x] Team sign-off on security strategy
- [x] Phase 1 plan approved

---

## Phase 1 — Core Application Framework

**Goal:** Build the technical skeleton — routing, DI, themes, logging, error handling, environment config, secure storage.

**Status:** ✅ Complete

### Deliverables

| Deliverable | Description | Status |
|---|---|---|
| Flutter project setup | Clean Flutter project with fvm, flavors (dev/staging/prod) | ✅ Done |
| GetX architecture | Controllers, bindings, services wired up | ✅ Done |
| Environment config | .env files, flavor-aware Firebase config | ✅ Done |
| Theme system | Light mode, dark mode, design tokens | ✅ Done |
| Routing system | GetX named routes, guarded navigation | ✅ Done |
| Dependency injection | GetX service locator pattern with scoped bindings | ✅ Done |
| Logging framework | Structured logging with levels and redaction filters | ✅ Done |
| Crash handling | Crashlytics integration, global error zone | ✅ Done |
| Network monitoring | Connectivity monitoring, offline state detection | ✅ Done |
| Local storage | Drift + SQLCipher setup, database schema v1, migration strategy | ✅ Done |
| Secure storage | Flutter Secure Storage for tokens and keys | ✅ Done |

### Exit Criteria
- [x] App runs on both iOS and Android devices in all 3 flavors
- [x] Navigation system operational with guarded routes
- [x] Theme switching functional
- [x] Logging and crash reporting verified
- [x] All dependencies pinned and documented

---

## Phase 2 — Visible Notes Application

**Goal:** Build a fully functional, production-quality notes app — the public face of the product.

**Status:** ✅ Complete

### Deliverables

| Deliverable | Description | Status |
|---|---|---|
| Notes dashboard | Home screen with notes grid/list, categories, search bar | ✅ Done |
| Note creation | Rich text note creation with title, body, formatting | ✅ Done |
| Note editing | Inline editing, autosave, conflict resolution | ✅ Done |
| Note search | Full-text local search across all notes | ✅ Done |
| Categories | User-defined categories/tags | ✅ Done |
| Favorites | Pin / favorite notes | ✅ Done |
| Archive | Archive and restore notes | ✅ Done |
| Dark/Light mode | Fully themed UI in both modes | ✅ Done |
| Empty states | Illustrated empty states for all screens | ✅ Done |

### Exit Criteria
- [x] Complete CRUD lifecycle for notes verified
- [x] Search returns correct results
- [x] No visible indication of any messaging feature
- [x] UI/UX review completed
- [x] Performance: note list renders 100 items without jank

---

## Phase 3 — Hidden Access System

**Goal:** Implement the covert entry point to the messaging layer and local secure vault.

**Status:** ✅ Complete

### Deliverables

| Deliverable | Description | Status |
|---|---|---|
| Secret keyword activation | Specific keyword typed in notes search triggers hidden entry | ✅ Done |
| Search trigger system | Detection logic without any visual cue | ✅ Done |
| Hidden navigation | Separate route tree invisible from normal navigation | ✅ Done |
| PIN verification | 4–6 digit PIN for messaging and vault access | ✅ Done |
| Biometric verification | FaceID / Fingerprint as alternate verification | ✅ Done |
| Panic PIN | Alternate PIN that wipes hidden database | ✅ Done |
| Fake mode | Camouflage notes UI shown on panic PIN | ✅ Done |
| Stealth mode | All UI indicators suppressed when in messaging layer | ✅ Done |

### Exit Criteria
- [x] Secret activation tested with multiple keyword inputs
- [x] PIN and biometric flows functional
- [x] Panic mode correctly wipes the hidden database
- [x] No navigation leak from notes to messaging visible to user

---

## Phase 4 — Secure Messaging Foundation & Hardening

**Goal:** Build the cryptographic and database foundations for secure, compliance-auditable communications.

**Status:** ✅ Complete

### Deliverables

| Deliverable | Description | Status |
|---|---|---|
| Identity Onboarding | Cryptographic pseudonym generation and identity registration on Firestore | ✅ Done |
| Handshake Protocols | X3DH and post-quantum Kyber (PQXDH) handshakes for session creation | ✅ Done |
| Session Persistence | SQLCipher-backed session record, prekey, and skipped key storage (ADR-023) | ✅ Done |
| Replay Protection | Sequential message tracking and skipped key sequence storage | ✅ Done |
| Key Rotation | Weekly automated Signed Prekey and Kyber Prekey rotation service | ✅ Done |

### Exit Criteria
- [x] Onboarding flow creates and publishes identity bundles
- [x] X3DH/PQXDH handshake computes shared master secret successfully
- [x] Session data and ratchet state survive app restarts in SQLCipher
- [x] Out-of-order delivery correctly retrieves and cleans up skipped keys
- [x] Replayed messages are rejected by the ratchet session

---

## Phase 4.5 — Messaging UX

**Goal:** Core real-time 1-to-1 messaging user interface and presence systems.

**Status:** 🟡 Active

### Deliverables

| Deliverable | Description |
|---|---|
| Conversations List | Render public and hidden chat lists dynamically with search and status indicators |
| Chat View | Live 1-to-1 conversation view with bubble layouts, timestamps, and status ticks |
| Send / Receive | Real-time text transmission and listener updates via Firestore |
| Typing Indicator | Live "is typing..." signals synchronized between participants |
| Presence System | Online, offline, and last seen presence tracking |
| Read Receipts | Double-tick delivery and read indicators triggered by on-screen visibility |

### Exit Criteria
- [ ] Messages delivered in real-time with < 500ms latency (good connectivity)
- [ ] Read receipts and delivery indicators update correctly in the database and UI
- [ ] Typing indicators trigger and dismiss reliably
- [ ] Offline outgoing messages queue locally and deliver on reconnect

---

## Phase 4.6 — Encrypted Media (Cloudflare R2)

**Goal:** Secure, on-device encrypted media attachment transmission using Cloudflare R2.

**Status:** ⬜ Pending

### Deliverables

| Deliverable | Description |
|---|---|
| Media Encryption | Local AES-256-GCM encryption of media (images, video, documents) with randomized Media Key |
| Cloudflare R2 Upload | Direct multipart secure upload of ciphertext binary blobs to R2 storage buckets |
| Escrowed Key Share | Dual-encryption of Media Keys for recipient (Double Ratchet) and compliance (X25519 ECIES) |
| Download & Decrypt | Media download from R2, hash validation, and local decryption to device cache |
| Inline Previews | Shimmer skeletons and media caching (LRU) with fast secure thumbnail rendering |

### Exit Criteria
- [ ] Media encrypts on-device and uploads successfully to R2
- [ ] Recipient successfully decrypts and displays downloaded media
- [ ] Escrowed Media Key is readable by the Compliance Vault under authorized Level 2 review
- [ ] Cached media files are swept on session lock

---

## Phase 4.7 — Voice Notes

**Goal:** Recording, playback, and secure exchange of voice messages.

**Status:** ⬜ Pending

### Deliverables

| Deliverable | Description |
|---|---|
| Voice Recording | In-app microphone audio capture with wave visualizers |
| Playback Controller | Seek, speed adjustments, and pause/resume audio playback |
| Voice Note Encryption | AES-256-GCM encryption of audio files before upload |
| Metadata Exchange | Duration and waveform map storage in message metadata |

### Exit Criteria
- [ ] Voice notes record and play back with low latency and clear audio quality
- [ ] Voice notes are encrypted and transmitted through the R2 media pipeline
- [ ] Decrypted audio files are held in temporary memory and flushed on session lock

---

## Phase 4.8 — Status / Moments

**Goal:** Shared status updates with contact circles.

**Status:** ⬜ Pending

### Deliverables

| Deliverable | Description |
|---|---|
| Moment Creation | Capture or select photos/text for a status update |
| Status Encryption | Encrypt status content for the designated recipient group |
| Feed View | Carousel UI of active status updates from contacts |
| Ephemeral Auto-Delete | Auto-expiry of moments after 24 hours |

### Exit Criteria
- [ ] Moments publish successfully and resolve for authorized contacts only
- [ ] Ephemeral deletion triggers automatically at the 24-hour mark
- [ ] No historical metadata of expired moments remains in database index

---

## Phase 4.9 — Compliance & Admin Platform

**Goal:** Web administrative interface with role-based metadata access and authorized content decryption.

**Status:** ⬜ Pending

### Deliverables

| Deliverable | Description |
|---|---|
| Admin Authentication | Secure admin-only login via Firebase Auth with Multi-Factor Authentication (MFA) |
| Role-Based Access (Level 1) | Metadata dashboard: view users directory, storage usage, message counts, conversation stats, reports, and flags |
| Role-Based Access (Level 2) | Authorized content request submission: Conversation ID, case number, reason/justification, and authority reference |
| Immutable Audit Logging | System logs of accessor UID, timestamp, reason, case number, and target Conversation ID |
| Decryption Pipeline | Google Cloud KMS-backed decryption of X25519 ECIES escrowed message and media keys |
| Admin Review Panel | Read-only rendering of decrypted text and media for compliance review (decrypted keys kept only in memory) |

### Exit Criteria
- [ ] Level 1 admins are blocked from viewing message content or media
- [ ] Level 2 decryption requests fail without valid reason/case numbers
- [ ] Decryption transactions are logged immutably in the audit collection
- [ ] Compliant decrypted media downloads, decrypts in-memory, and renders in the review panel

---

## Phase 5.0 — Production Hardening & Launch

**Goal:** Security certification, notification polish, performance profiling, and launch.

**Status:** ⬜ Pending

### Deliverables

| Deliverable | Description |
|---|---|
| Push Notifications | FCM push notifications with disguised contents (appears as generic notes sync) |
| Silent Notification Sync | Silent push notifications to wake background sync worker |
| Security Audit | External validation of X3DH, Double Ratchet, and compliance escrow key exchanges |
| Penetration Testing | Penetration testing of API endpoints and Firebase Rules |
| Performance Pass | Profile frame budget, memory allocations, and battery consumption |
| Release Submission | Google Play and Apple App Store production builds and metadata review |

### Exit Criteria
- [ ] Zero compiler warnings or lint errors under static analysis
- [ ] 100% test coverage for cryptographic and data routing components
- [ ] Push notifications disguise sender and message snippets completely
- [ ] Store submission builds pass automated verification checks

---

## Dependency Graph

```
Phase 0 (Foundation)
    └── Phase 1 (Framework)
            └── Phase 2 (Notes App)
                    └── Phase 3 (Hidden Access)
                            └── Phase 4 (Messaging Foundation & Hardening)
                                    └── Phase 4.5 (Messaging UX)
                                            ├── Phase 4.6 (Encrypted Media)
                                            │       └── Phase 4.7 (Voice Notes)
                                            │               └── Phase 4.8 (Status / Moments)
                                            │                       └── Phase 4.9 (Compliance & Admin Platform)
                                            │                               └── Phase 5.0 (Hardening & Launch)
```

---

## Version Milestones

| Milestone | Phases Included | Description | Status |
|---|---|---|---|
| **v0.1 — Internal Alpha** | 0, 1 | Framework only, no feature UI | ✅ Complete |
| **v0.2 — Notes MVP** | 2 | Functional notes app | ✅ Complete |
| **v0.3 — Hidden Access Alpha** | 3, 4 | Secret entry, auth, messaging foundation | ✅ Complete |
| **v0.5 — Messaging Beta** | 4.5 | Core messaging functional (UX) | 🟡 In Progress |
| **v0.7 — Media Beta** | 4.6, 4.7 | Media and voice messaging | ⬜ Pending |
| **v0.9 — Moments & Auditing** | 4.8, 4.9 | Moments feed and admin auditing platform | ⬜ Pending |
| **v1.0 — Production Release** | 5.0 | Hardened, store-ready | ⬜ Pending |
