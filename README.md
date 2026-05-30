# memovault — MemoVault

> **Public App Name:** MemoVault  
> **Internal project name:** memovault  
> **Repository:** memovault  
> **Public identity:** A premium Notes / Vault application  
> **Current Phase:** 1.1 — Project Bootstrap (🟡 Planning — Awaiting Approval)  
> **Phase 0:** 🔒 LOCKED & APPROVED

---

## ⚠️ Mandatory Development Rules

Before doing **anything** in this project, read the rules:

1. **Read documentation first.** `docs/` is the source of truth.
2. **Create an implementation plan before writing code.**
3. **Update documentation after every feature.**
4. **Architecture and security take priority over speed.**
5. **Think like a production engineering team.**

See [docs/09_development_workflow.md](docs/09_development_workflow.md) for the full workflow.

---

## Documentation

| # | Document | Description | Status |
|---|---|---|---|
| 01 | [Project Overview](docs/01_project_overview.md) | App identity, tech stack, phase summary | ✅ Complete |
| 02 | [Product Vision](docs/02_product_vision.md) | Why this exists, product pillars, success metrics | ✅ Complete |
| 03 | [Development Roadmap](docs/03_development_roadmap.md) | Phased delivery plan with exit criteria | ✅ Complete |
| 04 | [Architecture Decisions](docs/04_architecture_decisions.md) | ADRs for all major technical decisions (incl. ADR-009 Isar) | ✅ Complete |
| 05 | [Security Decisions](docs/05_security_decisions.md) | Threat model, encryption, auth, panic mode | ✅ Complete |
| 06 | [Firebase Decisions](docs/06_firebase_decisions.md) | Firestore schema, rules, FCM, Storage strategy | ✅ Complete |
| 07 | [Feature Specifications](docs/07_feature_specifications.md) | Master feature inventory across all phases | ✅ Complete |
| 08 | [Coding Standards](docs/08_coding_standards.md) | Dart standards, GetX conventions, testing | ✅ Complete |
| 09 | [Development Workflow](docs/09_development_workflow.md) | Git strategy, PR process, environment setup | ✅ Complete |
| 10 | [Change Log](docs/10_changelog.md) | Chronological history of all changes | ✅ Active |
| 11 | [Risk Register](docs/11_risk_register.md) | 18 risks across technical, security, and operational categories | ✅ Complete |
| 12 | [Phase 1 Implementation Plan](docs/12_phase1_implementation_plan.md) | Phase 1 checkpoint overview (1.1–1.6) | 🟡 In Progress |
| 13 | [Phase 1.1 Bootstrap Plan](docs/13_phase1_1_bootstrap_plan.md) | Detailed plan for Phase 1.1 Project Bootstrap | ⏳ Awaiting Approval |

---

## Key Decisions (Phase 0 Resolved)

| Decision | Resolution |
|---|---|
| **App name** | MemoVault |
| **Local database** | Isar (see ADR-009) |
| **Notes sync** | Local-first (Isar) → Firestore background sync |
| **iOS minimum** | iOS 15 |
| **Android minimum** | minSdkVersion 26 (Android 8.0) |
| **Admin interface** | Firebase Console + Admin SDK scripts only |
| **Invite flow** | Manual codes (Phase 4) |
| **Panic mode** | Fake vault + fake conversations — no data deletion |

---

## Phase Status

| Phase | Title | Status |
|---|---|---|
| **0** | Product Foundation & Architecture | 🔒 LOCKED & APPROVED |
| **1.1** | Project Bootstrap | 🟡 Planning — Awaiting Approval |
| 1.2 | Core Architecture | ⬜ Pending |
| 1.3 | Theme & Design System | ⬜ Pending |
| 1.4 | Storage Layer | ⬜ Pending |
| 1.5 | Observability Layer | ⬜ Pending |
| 1.6 | Framework Validation | ⬜ Pending |
| 2 | Visible Notes Application | ⬜ Pending |
| 3 | Hidden Access System | ⬜ Pending |
| 4 | User Security Layer | ⬜ Pending |
| 5 | Messaging Engine | ⬜ Pending |
| 6–11 | Advanced Phases | ⬜ Pending |

---

## Quick Start

> Flutter project has not been initialized yet. This begins in **Phase 1** after plan approval.

```bash
# Phase 1 onward:
fvm install        # Install pinned Flutter version
fvm flutter pub get
fvm flutter run --flavor dev -t lib/main_dev.dart
```

---

*This README is maintained as part of the living documentation. Update it when major milestones are reached.*
