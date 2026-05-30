# 10 — Change Log

> **Document Status:** Living Document  
> **Last Updated:** 2026-05-30  
> **Format:** [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) — [Semantic Versioning](https://semver.org/)

---

## [Unreleased]

### Added (Phase 0 Closure & Phase 1.1 Planning — 2026-05-30)
- `docs/13_phase1_1_bootstrap_plan.md` — Detailed Phase 1.1 Project Bootstrap implementation plan

### Changed (Phase 0 Closure & Phase 1.1 Planning — 2026-05-30)
- **All docs (01–12)** — Document status updated from "Phase 0 ✅ Complete" to **"Phase 0 🔒 LOCKED & APPROVED"** — no further architecture changes without explicit approval
- `docs/03_development_roadmap.md` — Auth inconsistency fixed: Firebase Authentication row in Phase 4 deliverables updated from "Anonymous auth + custom claims for invite gating" to "Invite-only Email/Password Authentication with provisioned credentials, device binding, and remote revocation support"; Phase 1 status updated to checkpoint model; Version Milestones table restored
- `docs/05_security_decisions.md` — Section 3.1 heading and strategy statement updated to canonical auth wording
- `docs/06_firebase_decisions.md` — Section 5.1 updated with canonical auth strategy statement and clarified table descriptions
- `docs/07_feature_specifications.md` — F-401 description updated to canonical auth wording
- `docs/12_phase1_implementation_plan.md` — Restructured from monolithic plan to checkpoint overview; checkpoint table added (1.1–1.6)
- `README.md` — Phase 0 marked LOCKED & APPROVED; Phase 1 checkpoint table shown; doc 13 added to index

### Changed (Phase 0 Pre-Approval Corrections — 2026-05-30)
- `docs/01_project_overview.md` — Internal app name and repository changed from `bff_chat` to `memovault`; repository name rationale added to resolved decisions table
- `docs/02_product_vision.md` — "Trusted Circle" terminology replaced with "Vault Network"; Pillar 4 reference to "messaging system" replaced with "private workspace"; resolved decisions table updated
- `docs/05_security_decisions.md` — Section 7.1 expanded with full hardened activation strategy: salted SHA-256, Remote Config delivery, remote rotation without app update, hash-only validation, decoy hashes, rotation protocol
- `docs/06_firebase_decisions.md` — Remote Config keys table updated with `activation_hash` and `activation_salt`; Section 2.4 added documenting notes conflict resolution and version recovery strategy (last 5 revisions, write-once subcollection, Phase 2 automatic write, future restoration UI)
- `docs/07_feature_specifications.md` — F-803 updated from "Hive AES encryption" to "Isar native encryption"
- `docs/08_coding_standards.md` — `HiveError` removed from error handling example; replaced with `IsarError` + `StorageException`; hardcoded value prohibition updated to reflect Remote Config activation strategy
- `docs/11_risk_register.md` — TR-002 expanded with full version recovery strategy; SR-001 expanded with 6-point activation keyword hardening strategy
- `docs/12_phase1_implementation_plan.md` — Out-of-scope section updated; `firebase_remote_config` purpose updated to include activation hash/salt delivery
- `README.md` — Repository and internal names updated to `memovault`

### Added (Phase 0 Finalization — 2026-05-30)
- `docs/11_risk_register.md` — Technical, security, and operational risk register
- `docs/12_phase1_implementation_plan.md` — Detailed Phase 1 implementation plan

### Changed (Phase 0 Finalization — 2026-05-30)
- **All docs** — Document status updated to "Phase 0 ✅ Complete" across all 10 files
- `docs/01_project_overview.md` — App name changed from "BFF Vault" to **MemoVault**; platform minimums added (iOS 15, Android minSdk 26); Hive replaced with Isar in tech stack; resolved decisions table replaces open questions
- `docs/02_product_vision.md` — Panic mode description updated (no data wipe); resolved decisions table replaces open questions
- `docs/03_development_roadmap.md` — Phase 0 marked ✅ Complete with all deliverables and exit criteria checked; Hive replaced with Isar in Phase 1 deliverables; Phase 1 status updated to 🟡 Planning
- `docs/04_architecture_decisions.md` — ADR-002 (Hive) superseded; ADR-009 (Isar) added; all Hive references replaced with Isar; folder structure updated; code generation packages updated; open questions resolved
- `docs/05_security_decisions.md` — Invite flow updated to manual codes (no QR Phase 4); Hive encryption replaced with Isar encryption; panic mode finalized (no wipe); open questions resolved
- `docs/06_firebase_decisions.md` — Firebase project IDs updated to MemoVault naming; notes sync architecture confirmed (Local-first Isar → Firestore); admin strategy updated (Console + SDK scripts only); invite flow updated; notification title updated to MemoVault; open questions resolved
- `docs/07_feature_specifications.md` — F-307 (Fake Mode UI) updated to full panic mode behavior; F-402 (Invite) updated to manual codes only
- `docs/08_coding_standards.md` — Status updated
- `docs/09_development_workflow.md` — Status updated

---

## Phase 0 Decisions Log (2026-05-30)

| Decision | Resolution |
|---|---|
| App name | **MemoVault** (official) |
| Local database | **Isar** (Hive deprecated — ADR-009) |
| Notes sync | **Cloud sync enabled** — Local-first (Isar) → Firestore |
| iOS minimum | **iOS 15** |
| Android minimum | **minSdkVersion 26** (Android 8.0 Oreo) |
| Expected users | **2–10 prod** / architecture targets **1,000** |
| Admin interface | **Firebase Console + Admin SDK scripts only** |
| Invite flow | **Manual codes only** (Phase 4); QR deferred |
| Panic mode | **Fake vault only** — no local or cloud data deletion |

---

## Version History

> No versions released yet. Project is transitioning from Phase 0 to Phase 1.

---

## Change Log Format Reference

```markdown
## [vX.Y.Z] — YYYY-MM-DD

### Added
### Changed
### Deprecated
### Removed
### Fixed
### Security
```
