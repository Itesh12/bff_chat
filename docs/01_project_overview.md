# 01 — Project Overview

> **Document Status:** Living Document — Phase 0 🔒 LOCKED & APPROVED  
> **Last Updated:** 2026-05-30  
> **Owner:** Engineering Team

---

## 1. Application Identity

| Field | Value |
|---|---|
| **App Name (Public)** | MemoVault |
| **App Name (Internal)** | memovault |
| **Repository** | memovault |
| **Platform** | iOS (≥ 15) & Android (minSdkVersion ≥ 26 / Android 8.0+) |
| **Framework** | Flutter (latest stable) |
| **State Management** | GetX |
| **Backend** | Firebase (Firestore, Auth, Storage, FCM, Remote Config) |
| **Current Phase** | Phase 0 — Product Foundation & Architecture ✅ Complete |

---

## 2. Application Concept

The application presents itself publicly as a **premium Notes / Vault application**.

Underneath, it contains a **hidden, invite-only, end-to-end encrypted messaging system** accessible only through a secret activation mechanism unknown to casual users.

This dual-purpose design is intentional and central to the product strategy:

- **Public Layer** → A polished, fully functional notes/vault app that justifies the app's existence on the device and on the App/Play Store.
- **Hidden Layer** → A private, secure, real-time messaging platform accessible only to invited users who know the secret activation sequence.

---

## 3. Core Principles

| Principle | Description |
|---|---|
| **Security First** | No feature is implemented without considering its security implications. |
| **Architecture First** | Scalability and maintainability take priority over delivery speed. |
| **Plausible Deniability** | The app must convincingly appear to be a notes app to any casual observer. |
| **Zero Compromise** | No quick fixes that degrade code quality, security, or performance. |
| **Documentation Driven** | Documentation is written before code, and kept in sync after code changes. |
| **Production Grade** | Every layer is built as if it will serve millions of users in production. |

---

## 4. Technology Stack

### Frontend
- **Flutter** (latest stable channel)
- **Dart** (null-safe, latest stable)
- **GetX** — routing, state management, dependency injection, utilities

### Backend
- **Firebase Authentication** — identity management
- **Cloud Firestore** — real-time database
- **Firebase Storage** — media storage
- **Firebase Cloud Messaging (FCM)** — push notifications
- **Firebase Remote Config** — feature flags and runtime configuration
- **Firebase Analytics** — usage telemetry (privacy-compliant)
- **Firebase Crashlytics** — crash monitoring

### Security
- **AES-256 encryption** — message and media encryption at rest
- **Diffie-Hellman / ECDH** — key exchange for end-to-end encryption *(to be finalized in Phase 8)*
- **Flutter Secure Storage** — cryptographic key storage
- **Biometric authentication** — device-level verification

### Local Storage
- **Isar** — primary offline-capable local database (typed, indexed, high-performance queries)
- **Flutter Secure Storage** — secrets, tokens, encryption keys
- **SharedPreferences** — lightweight non-sensitive preferences

### Notes Synchronization
- **Architecture:** Local-first (Isar) → Background sync → Firestore
- Notes are fully functional offline; sync occurs when connectivity is available
- Conflict resolution: last-write-wins with server timestamp as tiebreaker

### Tooling
- **flutter_flavorizr** — flavor configuration (dev / staging / prod)
- **fvm (Flutter Version Manager)** — consistent Flutter version across team
- **very_good_cli** or custom scaffold — project bootstrapping standards
- **GitHub Actions / Fastlane** — CI/CD pipeline *(Phase 11)*

---

## 5. Development Phases Summary

| Phase | Title | Status |
|---|---|---|
| 0 | Product Foundation & Architecture | ✅ Complete |
| 1 | Core Application Framework | 🟡 Planning |
| 2 | Visible Notes Application | ⬜ Pending |
| 3 | Hidden Access System | ⬜ Pending |
| 4 | User Security Layer | ⬜ Pending |
| 5 | Messaging Engine | ⬜ Pending |
| 6 | Advanced Messaging | ⬜ Pending |
| 7 | Media & Voice System | ⬜ Pending |
| 8 | Privacy & Secret Features | ⬜ Pending |
| 9 | Notifications & Background System | ⬜ Pending |
| 10 | Premium Experience | ⬜ Pending |
| 11 | Production Hardening | ⬜ Pending |

---

## 6. Team & Ownership

> *(To be populated once the team is defined.)*

| Role | Responsible Party |
|---|---|
| Product Owner | TBD |
| Lead Engineer | TBD |
| Security Reviewer | TBD |
| QA Lead | TBD |

---

## 7. Resolved Decisions

| Decision | Resolution |
|---|---|
| **App name** | MemoVault (official) |
| **iOS minimum** | iOS 15 |
| **Android minimum** | minSdkVersion 26 (Android 8.0 Oreo) |
| **Notes sync** | Cloud sync enabled — Local-first (Isar) → Firestore background sync |
| **Local database** | Isar (replaces Hive — see ADR-009 in `04_architecture_decisions.md`) |
| **Expected users** | 2–10 production users; architecture targets 1,000 for scalability |
| **Admin interface** | Firebase Console + Admin SDK scripts only (no custom dashboard) |
| **Invite flow** | Manual invite codes only (Phase 4); QR onboarding deferred |
| **Panic mode** | Shows fake vault + fake conversations — does NOT wipe local or cloud data |
| **Monetization** | Not applicable for initial release |
| **Store accounts** | To be confirmed by team |
| **Repository name** | `memovault` (internal naming neutral, no reference to messaging purpose) |
