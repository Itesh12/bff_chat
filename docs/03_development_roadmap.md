# 03 — Development Roadmap

> **Document Status:** Living Document — Phase 0 🔒 LOCKED & APPROVED  
> **Last Updated:** 2026-05-30  
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

**Goal:** Build the technical skeleton — routing, DI, themes, logging, error handling, environment config.

**Status:** ❌ REOPENED — Phase 1.4 Storage Layer (Chosen storage engine does not satisfy the project's encryption requirements)

### Deliverables

| Deliverable | Description |
|---|---|
| Flutter project setup | Clean Flutter project with fvm, flavors (dev/staging/prod) |
| GetX architecture | Controllers, bindings, services wired up |
| Environment config | .env files, flavor-aware Firebase config |
| Theme system | Light mode, dark mode, design tokens |
| Routing system | GetX named routes, guarded navigation |
| Dependency injection | GetX service locator pattern with scoped bindings |
| Logging framework | Structured logging with levels (debug/info/warn/error) |
| Crash handling | Crashlytics integration, global error zone |
| Network monitoring | Connectivity monitoring, offline state detection |
| Local storage | Isar setup, database schema v1, migration strategy |
| Secure storage | Flutter Secure Storage for tokens and keys |

### Exit Criteria
- [ ] App runs on both iOS and Android simulators in all 3 flavors
- [ ] Navigation system operational with guarded routes
- [ ] Theme switching functional
- [ ] Logging and crash reporting verified
- [ ] All dependencies pinned and documented

---

## Phase 2 — Visible Notes Application

**Goal:** Build a fully functional, production-quality notes app — the public face of the product.

**Status:** ⬜ Pending

### Deliverables

| Deliverable | Description |
|---|---|
| Notes dashboard | Home screen with notes grid/list, categories, search bar |
| Note creation | Rich text note creation with title, body, formatting |
| Note editing | Inline editing, autosave, conflict resolution |
| Note search | Full-text local search across all notes |
| Attachments | Image attachments per note |
| Categories | User-defined categories/tags |
| Favorites | Pin / favorite notes |
| Archive | Archive and restore notes |
| Dark/Light mode | Fully themed UI in both modes |
| Empty states | Illustrated empty states for all screens |
| Loading states | Skeleton screens / shimmer effects throughout |

### Exit Criteria
- [ ] Complete CRUD lifecycle for notes verified
- [ ] Search returns correct results
- [ ] No visible indication of any messaging feature
- [ ] UI/UX review completed
- [ ] Performance: note list renders 100 items without jank

---

## Phase 3 — Hidden Access System

**Goal:** Implement the covert entry point to the messaging layer.

**Status:** ⬜ Pending

### Deliverables

| Deliverable | Description |
|---|---|
| Secret keyword activation | Specific keyword typed in notes search triggers hidden entry |
| Search trigger system | Detection logic without any visual cue |
| Hidden navigation | Separate route tree invisible from normal navigation |
| PIN verification | 4–6 digit PIN for messaging access |
| Biometric verification | FaceID / Fingerprint as alternate verification |
| Panic PIN | Alternate PIN that shows fake/empty messaging UI |
| Fake mode | Empty messaging UI shown on panic PIN |
| Stealth mode | All UI indicators suppressed when in messaging layer |

### Exit Criteria
- [ ] Secret activation tested with multiple keyword inputs (correct and incorrect)
- [ ] PIN and biometric flows functional
- [ ] Panic mode correctly shows empty/fake UI
- [ ] No navigation leak from notes to messaging visible to user

---

## Phase 4 — User Security Layer

**Goal:** Implement invite-only, device-bound, remotely revocable authentication.

**Status:** ⬜ Pending

### Deliverables

| Deliverable | Description |
|---|---|
| Firebase Authentication | Invite-only Email/Password Authentication with provisioned credentials, device binding, and remote revocation support |
| Invite-only onboarding | Encrypted invite code, one-time use |
| Device binding | Device fingerprint bound to user account on first activation |
| Session management | Secure token lifecycle, refresh, expiry |
| Device approval | Admin approves/revokes device access |
| Remote logout | Admin can force logout any device |
| Secure token management | Tokens stored in Secure Storage only |
| Security audit logging | All access events logged to Firestore with timestamp + device ID |

### Exit Criteria
- [ ] Only invited users can access messaging layer
- [ ] Device revocation tested — revoked device loses access within one sync cycle
- [ ] All tokens encrypted at rest
- [ ] Security audit log entries verified in Firestore

---

## Phase 5 — Messaging Engine

**Goal:** Core real-time 1-to-1 messaging.

**Status:** ⬜ Pending

### Deliverables

| Deliverable | Description |
|---|---|
| One-to-one chat | Single conversation thread between two users |
| Message sending | Text message composition and delivery |
| Message receiving | Real-time listener on Firestore conversation |
| Read receipts | Double-tick delivery + read indicators |
| Delivery status | Sent / Delivered / Read states |
| Typing indicator | Real-time "is typing" signal |
| Presence system | Online / offline / last seen status |

### Exit Criteria
- [ ] Messages sent and received in real-time with < 500ms latency (good connectivity)
- [ ] Read receipts update correctly
- [ ] Typing indicator triggers and dismisses correctly
- [ ] Offline: messages queued and delivered on reconnect

---

## Phase 6 — Advanced Messaging

**Goal:** Feature-complete messaging experience.

**Status:** ⬜ Pending

### Deliverables

Reply, Edit messages, Reactions (emoji), Mentions, Bookmark messages, Scheduled messages, Search messages, Smart filters (unread / media / links), Archived chats, Hidden chats

---

## Phase 7 — Media & Voice System

**Goal:** Full media exchange and voice note support.

**Status:** ⬜ Pending

### Deliverables

Image sharing, Video sharing, Document sharing, Contact sharing, Location sharing, Voice notes (record / playback), Media previews, Media caching (LRU), Upload queue with retry

---

## Phase 8 — Privacy & Secret Features

**Goal:** Maximum secrecy and data protection.

**Status:** ⬜ Pending

### Deliverables

End-to-end encryption (E2EE) for all messages, Media encryption, Local database encryption, Screenshot blocking, Screenshot detection + alert, Secret media (view-once), Locked conversations (extra PIN), Self-destruct mode (auto-delete after N seconds), Hidden conversations (second layer)

---

## Phase 9 — Notifications & Background System

**Goal:** Stealth notification and background sync system.

**Status:** ⬜ Pending

### Deliverables

Push notifications (FCM), Hidden notification content (generic display text), Notification disguise system (appears as notes app notification), Silent notification processing (data-only FCM), Background sync, Offline message sync on reconnect, Smart notification batching

---

## Phase 10 — Premium Experience

**Goal:** Polish and emotional product experience.

**Status:** ⬜ Pending

### Deliverables

Themes (light / dark / auto), Romantic / intimate themes (custom color palettes), Chat wallpapers, Shared wallpapers (synchronized between users), Stories / Moments system, Status system, Transition animations, UX micro-interactions, Performance optimization pass

---

## Phase 11 — Production Hardening

**Goal:** Release readiness and security certification.

**Status:** ⬜ Pending

### Deliverables

Security audit, Penetration testing, Crash stress testing, Memory profiling and optimization, Performance profiling (frame budget analysis), Battery usage optimization, Firebase Security Rules audit, Encryption implementation audit, Full release checklist, App Store / Play Store submission readiness

---

## Dependency Graph

```
Phase 0 (Foundation)
    └── Phase 1 (Framework)
            ├── Phase 2 (Notes App)
            │       └── Phase 3 (Hidden Access)
            │               └── Phase 4 (Auth + Security)
            │                       └── Phase 5 (Messaging Engine)
            │                               ├── Phase 6 (Advanced Messaging)
            │                               ├── Phase 7 (Media)
            │                               └── Phase 8 (Privacy)
            │                                       └── Phase 9 (Notifications)
            │                                               └── Phase 10 (Premium)
            │                                                       └── Phase 11 (Hardening)
            └── (All phases inherit Phase 1 framework)
```

---

## Version Milestones

| Milestone | Phases Included | Description | Status |
|---|---|---|---|
| **v0.1 — Internal Alpha** | 0, 1 | Framework only, no feature UI | 🟡 In Progress |
| **v0.2 — Notes MVP** | 2 | Functional notes app | ⬜ Pending |
| **v0.3 — Hidden Access Alpha** | 3, 4 | Secret entry + auth | ⬜ Pending |
| **v0.5 — Messaging Beta** | 5, 6 | Core messaging functional | ⬜ Pending |
| **v0.7 — Media Beta** | 7, 8 | Media + privacy features | ⬜ Pending |
| **v0.9 — Release Candidate** | 9, 10 | Notifications + premium | ⬜ Pending |
| **v1.0 — Production Release** | 11 | Hardened, store-ready | ⬜ Pending |
