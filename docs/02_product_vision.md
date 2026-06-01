# 02 — Product Vision

> **Document Status:** Living Document — Phase 0 🔒 LOCKED & APPROVED  
> **Last Updated:** 2026-05-30  
> **Owner:** Product Team

---

## 1. Vision Statement

Build a **dual-purpose mobile application** that delivers a premium, convincing notes and vault experience to all users, while simultaneously providing a **covert, compliance-auditable, real-time private messaging platform** alongside a **completely secure, local-only Hidden Vault**, accessible only to an invited Vault Network.

The notes application must be genuinely useful — not a hollow shell. A user who discovers the app must conclude it is simply a well-crafted productivity tool.

---

## 2. Problem Statement

Private communication in modern applications suffers from one or more of these problems:

| Problem | Description |
|---|---|
| **Discoverability** | Secure messaging apps are identifiable as messaging apps, attracting scrutiny. |
| **No plausible deniability** | If a device is inspected, a messaging app immediately reveals its purpose. |
| **Weak security layers** | Most apps protect only transit data, leaving at-rest data and metadata exposed. |
| **Open access** | Anyone can create an account, reducing trust within closed circles. |
| **Notification exposure** | Notifications reveal message senders and content previews. |

---

## 3. Proposed Solution

An application that:

1. **Looks like a Notes app.** The App Store listing, icon, screenshots, and default UI all describe a note-taking / vault experience.
2. **Functions as a Notes app.** The notes functionality is real, complete, and polished — it is not a placeholder.
3. **Hides a messaging layer.** Accessible only via a secret activation mechanism known only to invited users.
4. **Protects access at every level.** Invite-only accounts, device binding, biometric/PIN locks, secure storage, and compliance-auditable messaging.
5. **Leaves no visible trace.** Notifications disguised, no visible messaging indicators, panic mode available.

---

## 4. Target Users

### Primary User Persona — "The Vault Network"

- Adults who wish to communicate privately within a small, known group
- Values security and discretion
- Comfortable with a slightly higher onboarding friction in exchange for privacy
- Will receive an invite — they do not "discover" this app organically

### Secondary User Persona — "The Casual Observer"

- Someone who finds or inspects the device
- Must only see a notes application
- Must have no path to discover the hidden layer without the secret activation

---

## 5. Product Pillars

### Pillar 1 — Genuine Notes Experience
The visible notes application must be production-quality:
- Full CRUD for notes
- Rich text support
- Categories, tags, favorites, archive
- Search
- Dark / light mode
- Attachment support

### Pillar 2 — Invisible Messaging Layer
The messaging layer must be entirely invisible:
- No UI element hints at messaging
- No notification content exposure
- Activation is secret-keyword driven
- Hidden navigation routes

### Pillar 3 — Uncompromising Security
Every layer of the stack must be secured:
- Compliance-auditable messaging encryption (X25519 ECIES escrow)
- AES-256 encryption at rest (SQLCipher database for local data)
- Biometric + PIN protection
- Panic mode (Wipes local `hidden_vault.db` and active session records immediately)
- Screenshot blocking
- Device binding
- Remote revocation

### Pillar 4 — Invitation-Only Access
The private workspace is closed:
- No public registration flow
- Users receive an encrypted invite
- Invite is device-bound on first activation
- Admin can revoke access remotely

### Pillar 5 — Premium Polish
The product must feel premium at every touchpoint:
- Smooth animations
- Thoughtful micro-interactions
- Romantic / intimate themes (Phase 10)
- Shared wallpapers, moments/stories
- Consistent, high-quality design system

---

## 6. Success Metrics

| Metric | Definition |
|---|---|
| **Security Confidence** | Zero known vectors for casual discovery of the messaging layer |
| **Notes App Credibility** | Independent user testing: non-invited users identify it as a notes app |
| **Messaging Reliability** | Message delivery rate ≥ 99.9% when both devices online |
| **Crash-Free Sessions** | ≥ 99.5% crash-free sessions in production |
| **Onboarding Completion** | ≥ 90% of invited users complete setup on first attempt |

---

## 7. Non-Goals

The following are explicitly **out of scope** for this product:

- ❌ Group chats (beyond 1-to-1 in core scope — reassess in Phase 6+)
- ❌ Public profile or social discovery
- ❌ In-app purchases or subscription billing (reassess post-launch)
- ❌ Web version
- ❌ Desktop version

---

## 8. Resolved Decisions

| Decision | Resolution |
|---|---|
| **Notes cloud sync** | Enabled — Local-first (Isar) → Firestore background sync; fully functional offline |
| **Max vault network users** | 2–10 production users; architecture designed for 1,000 |
| **Admin dashboard** | Phase 4.9 Compliance & Admin Platform with Level 1 metadata and Level 2 authorized KMS content decryption under audit logging |
| **Invite flow** | Manual invite codes (Phase 4); QR onboarding deferred to future phase |
| **Panic mode data** | Wipes local `hidden_vault.db` and active session records immediately (does NOT wipe public notes or public messages on the server) |
| **Security Model** | Dual-Security: Private local Hidden Vault (no administrative access) and Compliance-Auditable Messaging (ADR-024) |
