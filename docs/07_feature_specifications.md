# 07 — Feature Specifications

> **Document Status:** Living Document — Phase 0 🔒 LOCKED & APPROVED  
> **Last Updated:** 2026-05-30  
> **Owner:** Product Team / Engineering Team

---

## Overview

This document is the master feature inventory for all planned features across all phases.

Each feature entry includes:
- Feature ID
- Phase
- Priority (P0 = must-have, P1 = should-have, P2 = nice-to-have)
- Status
- Brief specification

---

## Feature Index

### Phase 2 — Notes Application

| ID | Feature | Priority | Status | Description |
|---|---|---|---|---|
| F-201 | Notes Dashboard | P0 | ⬜ | Home screen with list/grid of all notes, search bar, category filter |
| F-202 | Note Creation | P0 | ⬜ | Create note with title + rich text body; auto-save on edit |
| F-203 | Note Editing | P0 | ⬜ | Inline editing with cursor preservation; auto-save |
| F-204 | Note Deletion | P0 | ⬜ | Soft delete (move to trash), permanent delete |
| F-205 | Note Search | P0 | ⬜ | Full-text search across title and body; real-time results |
| F-206 | Note Categories | P1 | ⬜ | User-defined categories/labels; color coded |
| F-207 | Note Tags | P1 | ⬜ | Free-form tags per note |
| F-208 | Favorites | P1 | ⬜ | Pin/favorite notes; separate favorites view |
| F-209 | Archive | P1 | ⬜ | Archive notes; separate archived view; restore action |
| F-210 | Attachments | P1 | ⬜ | Attach images to notes; thumbnail preview |
| F-211 | Dark Mode | P0 | ⬜ | Full dark mode theme; respects system preference |
| F-212 | Light Mode | P0 | ⬜ | Full light mode theme |
| F-213 | Empty States | P0 | ⬜ | Illustrated empty states for all list screens |
| F-214 | Loading States | P0 | ⬜ | Skeleton/shimmer loading for all data-fetching screens |

---

### Phase 3 — Hidden Access System

| ID | Feature | Priority | Status | Description |
|---|---|---|---|---|
| F-301 | Secret Keyword Activation | P0 | ⬜ | Specific keyword typed into notes search bar activates hidden entry |
| F-302 | Zero Visual Cue | P0 | ⬜ | No animation, dialog, or visual indicator on activation — seamless transition |
| F-303 | PIN Entry Screen | P0 | ⬜ | 6-digit PIN screen; no label indicating purpose |
| F-304 | Biometric Auth | P1 | ⬜ | FaceID/Fingerprint as alternate to PIN |
| F-305 | Failed Attempt Throttle | P0 | ⬜ | Exponential backoff on PIN failures; lockout after N attempts |
| F-306 | Panic PIN | P0 | ⬜ | Alternate PIN shows empty/fake messaging UI |
| F-307 | Fake Mode UI | P0 | ⬜ | Panic PIN shows: (1) empty notes vault, (2) empty conversation list, (3) empty media gallery. No data deleted. Indistinguishable from fresh install. |
| F-308 | Stealth Mode | P1 | ⬜ | Suppress all UI indicators (typing, presence) during stealth toggle |

---

### Phase 4 — User Security Layer

| ID | Feature | Priority | Status | Description |
|---|---|---|---|---|
| F-401 | Firebase Auth Integration | P0 | ⬜ | Invite-only Email/Password Authentication with provisioned credentials, device binding, and remote revocation support |
| F-402 | Invite Code Onboarding | P0 | ⬜ | Manual invite code entry on first run; provisioned account activation; no QR code (Phase 4) |
| F-403 | Device Fingerprinting | P0 | ⬜ | Unique device ID generation and binding to account |
| F-404 | Multi-Device Support | P1 | ⬜ | Up to N devices per user (configurable, default 2) |
| F-405 | Remote Logout | P0 | ⬜ | Admin/self can revoke session on specific device |
| F-406 | Device Approval Flow | P1 | ⬜ | New device requires approval from existing device |
| F-407 | Audit Log — Auth Events | P0 | ⬜ | All auth events logged to Firestore with device + timestamp |
| F-408 | Token Secure Storage | P0 | ⬜ | All tokens in Flutter Secure Storage only |

---

### Phase 5 — Messaging Engine

| ID | Feature | Priority | Status | Description |
|---|---|---|---|---|
| F-501 | One-to-One Conversation | P0 | ⬜ | Single conversation thread between exactly 2 users |
| F-502 | Send Text Message | P0 | ⬜ | Compose and send plaintext (encrypted) message |
| F-503 | Receive Message (Realtime) | P0 | ⬜ | Firestore listener delivers messages in real-time |
| F-504 | Message Status: Sent | P0 | ⬜ | Single tick on send |
| F-505 | Message Status: Delivered | P0 | ⬜ | Double tick on recipient device receipt |
| F-506 | Message Status: Read | P0 | ⬜ | Colored double tick on read |
| F-507 | Typing Indicator | P1 | ⬜ | "..." animation when other user is composing |
| F-508 | Online Presence | P1 | ⬜ | Green dot / "Online" shown when user is active |
| F-509 | Last Seen | P1 | ⬜ | "Last seen at HH:MM" when user is offline |
| F-510 | Offline Message Queue | P0 | ⬜ | Messages queued locally and sent on reconnect |

---

### Phase 6 — Advanced Messaging

| ID | Feature | Priority | Status | Description |
|---|---|---|---|---|
| F-601 | Reply to Message | P0 | ⬜ | Swipe to reply; reply preview in message bubble |
| F-602 | Edit Message | P1 | ⬜ | Edit sent message; "edited" label shown |
| F-603 | Delete Message | P0 | ⬜ | Delete for self / delete for everyone |
| F-604 | Emoji Reactions | P1 | ⬜ | Long-press message to react with emoji |
| F-605 | Bookmark Message | P2 | ⬜ | Star/bookmark specific messages; view bookmarks |
| F-606 | Scheduled Messages | P2 | ⬜ | Schedule a message to send at a future time |
| F-607 | Search Messages | P1 | ⬜ | Full-text search within a conversation |
| F-608 | Smart Filters | P1 | ⬜ | Filter by: unread, media, links, voice notes |
| F-609 | Archive Conversation | P1 | ⬜ | Archive a conversation; access via separate view |
| F-610 | Hidden Conversations | P0 | ⬜ | Second-level lock on specific conversations |

---

### Phase 7 — Media & Voice

| ID | Feature | Priority | Status | Description |
|---|---|---|---|---|
| F-701 | Send Image | P0 | ⬜ | Pick from gallery or camera; upload to Firebase Storage |
| F-702 | Send Video | P1 | ⬜ | Pick video; compress before upload; playback in-app |
| F-703 | Send Document | P1 | ⬜ | PDF / file picker; download and open |
| F-704 | Send Contact | P2 | ⬜ | Share contact card |
| F-705 | Send Location | P2 | ⬜ | Share current location pin; open in maps |
| F-706 | Voice Note Record | P0 | ⬜ | Hold-to-record voice message; waveform visualization |
| F-707 | Voice Note Playback | P0 | ⬜ | In-line audio player with waveform and progress |
| F-708 | Media Preview | P0 | ⬜ | Full-screen media viewer with zoom/swipe |
| F-709 | Media Gallery | P1 | ⬜ | Per-conversation media gallery (all shared images/videos) |
| F-710 | Upload Queue | P0 | ⬜ | Background upload with progress; retry on failure |
| F-711 | Media Cache | P0 | ⬜ | LRU cache for received media; cache size limit configurable |

---

### Phase 8 — Privacy & Secret Features

| ID | Feature | Priority | Status | Description |
|---|---|---|---|---|
| F-801 | End-to-End Encryption | P0 | ⬜ | ECDH + AES-256-GCM for all message content |
| F-802 | Media Encryption | P0 | ⬜ | All uploaded media encrypted before Firebase Storage upload |
| F-803 | Database Encryption | P0 | ⬜ | Isar native encryption for local message/note storage (key in Flutter Secure Storage) |
| F-804 | Screenshot Blocking | P0 | ⬜ | FLAG_SECURE (Android) + iOS equivalent in messaging screens |
| F-805 | Screenshot Detection | P1 | ⬜ | Detect screenshot attempts; notify sender |
| F-806 | View-Once Media | P1 | ⬜ | Media deleted from Storage after first open |
| F-807 | Locked Conversations | P1 | ⬜ | Extra PIN/biometric to open specific conversations |
| F-808 | Self-Destruct Mode | P1 | ⬜ | Messages auto-delete after N seconds/minutes |
| F-809 | Hidden Conversations | P0 | ⬜ | Conversation hidden from list; accessible via code |

---

### Phase 9 — Notifications

| ID | Feature | Priority | Status | Description |
|---|---|---|---|---|
| F-901 | FCM Integration | P0 | ⬜ | Firebase Cloud Messaging token registration and receipt |
| F-902 | Data-Only Notifications | P0 | ⬜ | All messaging notifications are data-only (silent) |
| F-903 | Disguised Notifications | P0 | ⬜ | If displayed: generic app name + generic body text |
| F-904 | Background Sync | P0 | ⬜ | Process incoming messages when app is backgrounded |
| F-905 | Offline Sync | P0 | ⬜ | Fetch missed messages on app foreground after offline period |
| F-906 | Notification Badge | P1 | ⬜ | App icon badge count reflects unread (no message content) |
| F-907 | Notification Settings | P1 | ⬜ | User can toggle notification visibility in app settings |

---

### Phase 10 — Premium Experience

| ID | Feature | Priority | Status | Description |
|---|---|---|---|---|
| F-1001 | Theme System | P0 | ⬜ | Light / Dark / Auto + custom accent colors |
| F-1002 | Intimate Themes | P1 | ⬜ | Curated romantic color palettes and typography |
| F-1003 | Chat Wallpapers | P1 | ⬜ | Per-conversation background wallpaper |
| F-1004 | Shared Wallpapers | P1 | ⬜ | Synchronized wallpaper between conversation partners |
| F-1005 | Stories / Moments | P2 | ⬜ | 24-hour ephemeral photo/video status |
| F-1006 | Status System | P1 | ⬜ | Text status visible to conversation partner |
| F-1007 | Smooth Animations | P0 | ⬜ | Hero transitions, message send/receive animations |
| F-1008 | Haptic Feedback | P1 | ⬜ | Subtle haptics on message send, reaction, activation |
| F-1009 | Performance Pass | P0 | ⬜ | Frame budget analysis; eliminate jank |
