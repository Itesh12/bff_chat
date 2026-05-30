# 09 — Development Workflow

> **Document Status:** Living Document — Phase 0 🔒 LOCKED & APPROVED  
> **Last Updated:** 2026-05-30  
> **Owner:** Engineering Team

---

## 1. Mandatory Pre-Task Checklist

Before starting **any** task — feature, bug fix, refactor, enhancement, or architectural change — the following steps are **mandatory**:

```
[ ] 1. Read all relevant documentation in docs/
[ ] 2. Identify the current phase and active deliverables
[ ] 3. Confirm the feature ID from 07_feature_specifications.md
[ ] 4. Create a detailed implementation plan (see section 3)
[ ] 5. Obtain approval for the implementation plan
[ ] 6. Only then begin writing code
```

**No exceptions. No shortcuts.**

---

## 2. Git Workflow

### 2.1 Branch Strategy

```
main                    ← Production-ready code only
  └── develop           ← Integration branch
        └── feature/F-XXX-short-description    ← Feature branches
        └── fix/issue-description              ← Bug fix branches
        └── refactor/description               ← Refactor branches
        └── docs/description                   ← Documentation only
```

### 2.2 Branch Naming Convention

| Type | Pattern | Example |
|---|---|---|
| Feature | `feature/F-XXX-description` | `feature/F-202-note-creation` |
| Bug Fix | `fix/short-description` | `fix/note-save-crash` |
| Refactor | `refactor/description` | `refactor/notes-controller-split` |
| Documentation | `docs/description` | `docs/firebase-schema-update` |
| Phase | `phase/N-description` | `phase/1-core-framework` |

### 2.3 Commit Message Convention

Format: `type(scope): description`

```
feat(notes): add note creation with auto-save
fix(auth): resolve token refresh race condition
refactor(routing): extract route guards to middleware
docs(security): update encryption strategy for Phase 8
test(notes): add repository unit tests for CRUD operations
chore(deps): update firebase_core to 3.x
```

**Types:** `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`

### 2.4 Merge Policy

- Direct commits to `main` or `develop` are **not allowed**
- All changes via Pull Request
- PR requires at least **1 approval** before merge
- PR must pass all CI checks before merge
- Squash merge preferred to keep `develop` history clean

---

## 3. Implementation Plan Template

Every task requires an implementation plan in this format:

```markdown
## Implementation Plan — [Feature ID]: [Feature Name]

### Goal
[One sentence describing what this plan achieves]

### Scope
[What is included / what is explicitly excluded]

### Requirements
- [ ] Requirement 1
- [ ] Requirement 2

### Dependencies
- Packages required
- Features that must exist first
- Firebase collections that must exist

### Risks
| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| ... | Low/Med/High | Low/Med/High | ... |

### Edge Cases
- [ ] Edge case 1
- [ ] Edge case 2

### Security Considerations
- [ ] Security check 1
- [ ] Security check 2

### Data Flow
[Describe data flow from UI → Controller → Service → Repository → Data Source]

### Testing Considerations
- Unit tests: ...
- Widget tests: ...
- Integration tests: ...

### Files Expected to Change
- [NEW] lib/features/X/views/X_screen.dart
- [MODIFY] lib/core/routes/app_pages.dart
- [NEW] test/unit/features/X/X_controller_test.dart
```

---

## 4. Code Review Checklist

The **author** must verify before opening a PR:

```
[ ] All tests pass locally
[ ] No new lint warnings
[ ] No print() statements
[ ] No hardcoded strings in business logic
[ ] No sensitive data in logs
[ ] Documentation updated (if feature changes existing documented behavior)
[ ] CHANGELOG.md updated
[ ] Implementation plan requirements all checked off
```

The **reviewer** must verify:

```
[ ] Code follows architecture (layers not violated)
[ ] Error handling present (no silent failures)
[ ] Loading states handled in UI
[ ] Empty states handled in UI
[ ] Offline scenario considered
[ ] Security considerations addressed
[ ] Tests cover the new logic
[ ] No TODO without linked issue
```

---

## 5. Environment Setup (Developer Onboarding)

### 5.1 Prerequisites

```bash
# 1. Install Flutter via FVM (Flutter Version Manager)
dart pub global activate fvm

# 2. Install the project Flutter version
fvm install  # reads .fvmrc

# 3. Use project Flutter
fvm use

# 4. Install dependencies
fvm flutter pub get

# 5. Run code generation
dart run build_runner build --delete-conflicting-outputs
```

### 5.2 Running the App

```bash
# Development flavor (Firebase emulators)
fvm flutter run --flavor dev -t lib/main_dev.dart

# Staging flavor
fvm flutter run --flavor staging -t lib/main_staging.dart

# Production flavor
fvm flutter run --flavor prod -t lib/main_prod.dart
```

### 5.3 Running Tests

```bash
# All tests
fvm flutter test

# Specific test file
fvm flutter test test/unit/repositories/notes_repository_test.dart

# With coverage
fvm flutter test --coverage
```

### 5.4 Firebase Emulators (Dev Only)

```bash
# Start Firebase emulators
firebase emulators:start --import=./firebase_emulator_data

# Export emulator state (to preserve test data between sessions)
firebase emulators:export ./firebase_emulator_data
```

---

## 6. CI/CD Pipeline (Phase 11 — Planned)

### 6.1 Planned Pipeline Stages

```
On PR → develop:
  1. dart format --check .          (formatting check)
  2. flutter analyze                (lint check)
  3. flutter test                   (unit + widget tests)
  4. Build APK (dev flavor)         (compilation check)

On merge → develop:
  1. All PR checks
  2. Build staging APK + IPA
  3. Deploy to Firebase App Distribution (internal testers)

On merge → main:
  1. All develop checks
  2. Build production APK + IPA (obfuscated)
  3. Upload to Play Store (internal track) / TestFlight
  4. Tag release
```

### 6.2 Tool Stack (Planned)

- **GitHub Actions** — CI runner
- **Fastlane** — iOS/Android build automation and store deployment
- **Firebase App Distribution** — Internal distribution

---

## 7. Documentation Maintenance Rules

After every completed feature:

```
[ ] Update docs/07_feature_specifications.md — mark feature as complete
[ ] Update docs/10_changelog.md — add entry for the change
[ ] If architecture changed: update docs/04_architecture_decisions.md
[ ] If security changed: update docs/05_security_decisions.md
[ ] If Firebase schema changed: update docs/06_firebase_decisions.md
[ ] Update docs/03_development_roadmap.md phase status if phase milestone reached
```

Documentation review is part of the PR checklist and must be completed before a PR is approved.

---

## 8. Issue & Task Tracking

- All work items must be tracked (GitHub Issues or equivalent)
- Issues must reference the Feature ID (e.g., `F-202`)
- Implementation plans are attached to issues before work begins
- PRs must reference the issue they close (`Closes #issue-number`)

---

## 9. Release Process (Phase 11 — Planned)

1. Feature freeze on `develop`
2. Create `release/vX.Y.Z` branch
3. QA testing on release branch
4. Bug fixes applied to release branch
5. Security audit and penetration test
6. Merge to `main` with version tag
7. Fastlane deploys to stores
8. Monitor Crashlytics for 48 hours post-release
9. Merge release branch back to `develop`
