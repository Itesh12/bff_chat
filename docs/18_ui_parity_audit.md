# UI Parity Audit (Phase 2.4 Parity Plan)

This document audit provides formal evidence of visual and structural parity between the **Public Notes** and **Hidden Vault** modules in MemoVault. It tracks compliance with **ADR-018: Shared Presentation Rule**, which states that any presentation component shared between public and private spaces must use the same underlying widget tree with runtime state parameters (such as `isHiddenMode`).

---

## 📦 Shared Components

The following UI components are fully unified and shared between the public and hidden zones:

| Component | Public Mode | Hidden Mode | Reusable Presentation Widget |
| :--- | :--- | :--- | :--- |
| **Dashboard** | `NotesDashboardScreen` | `HiddenHomeScreen` | Uses shared `NoteCard`, `AppScaffold`, and layout primitives. |
| **Archive** | `/notes/archive` | `/hidden/archive` | `NotesArchiveScreen` configured with `isHiddenMode: true`. |
| **Favorites** | `/notes/favorites` | `/hidden/favorites` | `NotesFavoritesScreen` configured with `isHiddenMode: true`. |
| **Trash** | `/notes/trash` | `/hidden/trash` | `NotesTrashScreen` configured with `isHiddenMode: true`. |
| **Search** | `/notes/search` | `/hidden/search` | `NotesSearchScreen` configured with `isHiddenMode: true`. |
| **Editor** | `NoteEditorScreen` | `HiddenNoteEditorScreen` | Both wrap the unified `NoteEditorForm` widget. |

### Presentation Primitives in Use:
- **[NotesListLayout](file:///c:/bff_chat/lib/core/widgets/notes_list_layout.dart)**: Standardizes Swipe-to-Restore, Swipe-to-Delete-Forever, empty state listings, and headers.
- **[NoteSearchLayout](file:///c:/bff_chat/lib/core/widgets/note_search_layout.dart)**: Standardizes debounced searches and result listings.
- **[NoteEditorForm](file:///c:/bff_chat/lib/core/widgets/note_editor_form.dart)**: Form input fields for title and body, word counters, and automatic saving overlays.
- **[NoteCard](file:///c:/bff_chat/lib/core/widgets/note_card.dart)**: Renders standard note items, access times, status badges (e.g. favorite indicators), and titles.
- **[AppEmptyState](file:///c:/bff_chat/lib/core/design_system/feedback/app_empty_state.dart)**: Provides a scrollable, centered layout for empty space listings.
- **[AppScaffold](file:///c:/bff_chat/lib/core/design_system/layout/app_scaffold.dart)**: The central structural shell ensuring identical Title/AppBar layouts.

---

## 🔒 Hidden-Specific Components

The following components are strictly isolated to the Hidden Vault and have no public counterparts:

- **[HiddenPinScreen](file:///c:/bff_chat/lib/features/hidden/views/hidden_pin_screen.dart)**: The secure Pin Pad entry dialer UI featuring throttling banners and a destructive reset CTA.
- **[HiddenSessionService](file:///c:/bff_chat/lib/features/hidden/services/hidden_session_service.dart)**: Manages lock timeouts and background lifecycle state machine transitions.
- **[ActivationTriggerService](file:///c:/bff_chat/lib/features/hidden/services/activation_trigger_service.dart)**: Intercepts search queries matching `^\.[0-9]{4}$` exactly.
- **[HiddenVaultDatabase](file:///c:/bff_chat/lib/features/hidden/data/hidden_vault_database.dart)**: Encrypted SQLCipher database containing tables for hidden categories and notes.

---

## 📊 Duplication Report

```text
Duplicate view screens:          0
Duplicate card widgets:          0
Duplicate dialog templates:      0
Duplicate editor forms:          0
Duplicate search layouts:        0
Duplicate archive/trash views:   0
```

---

## 🧪 Hidden Vault Security Isolation Assurance

We verify that the security isolation rules conform to design boundaries:
1. **Different Encryption Keys**: The public database uses `db_encryption_key_v1` in secure storage, while the hidden database key is stored separately under `hidden_vault_encryption_key_v1`.
2. **Different File Paths**: The public database is written to `memovault.db` and the hidden database is written to `hidden_vault.db` inside the local documents directory.
3. **Different Drift Database Instances**: The databases are instantiated as `AppDatabase` and `HiddenVaultDatabase` respectively.
4. **Valid PIN Hook Lock**: The `HiddenVaultDatabase` is only decrypted and instantiated *after* a PIN validation matches the salt hash stored in `hidden_vault_config_v1`. The database reference is destroyed on lockout or idle timeouts.
