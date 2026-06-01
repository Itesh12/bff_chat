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

Underneath, it contains a **hidden, invite-only, compliance-auditable private messaging system** alongside a **completely secure, local-only Hidden Vault**, accessible only through a secret activation mechanism unknown to casual users.

This design is intentional and central to the product strategy:

- **Public Layer** → A polished, fully functional notes/vault app that justifies the app's existence on the device and on the App/Play Store.
- **Hidden Vault** → A secure, local-only, coercion-resistant storage space with no administrative access, no cloud sync, and absolute privacy.
- **Messaging System** → A private, compliance-auditable communications platform where message keys are dual-encrypted to support authorized administrative auditing.

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
- **Double Ratchet / ECDH & X25519 ECIES** — key exchange for messaging and compliance escrow envelope encryption
- **Flutter Secure Storage** — cryptographic device identity key storage
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
| 1 | Core Application Framework | ✅ Complete |
| 2 | Visible Notes Application | ✅ Complete |
| 3 | Hidden Access System | ✅ Complete |
| 4 | Secure Messaging Foundation & Hardening | ✅ Complete |
| 4.5 | Messaging UX | 🟡 Active |
| 4.6 | Encrypted Media (Cloudflare R2) | ⬜ Pending |
| 4.7 | Voice Notes | ⬜ Pending |
| 4.8 | Status / Moments | ⬜ Pending |
| 4.9 | Compliance & Admin Platform | ⬜ Pending |
| 5.0 | Production Hardening & Launch | ⬜ Pending |

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
| **Admin interface** | Phase 4.9 Compliance & Admin Platform (Level 1 metadata & Level 2 authorized KMS decryption with immutable audit logging) |
| **Invite flow** | Manual invite codes only (Phase 4); QR onboarding deferred |
| **Panic mode** | Wipes local `hidden_vault.db` and active session records immediately (ADR-020, ADR-023) |
| **Security Model** | Dual-Security: Private local Hidden Vault (no administrative access) and Compliance-Auditable Messaging (ADR-024) |
| **Monetization** | Not applicable for initial release |
| **Store accounts** | To be confirmed by team |
| **Repository name** | `memovault` (internal naming neutral, no reference to messaging purpose) |
