# 15 — Phase 1.3: Theme & Design System Plan

> **Document Status:** Awaiting Approval  
> **Last Updated:** 2026-05-30  
> **Checkpoint:** 1.3 of 6 — Theme & Design System  
> **Owner:** Engineering Team  
> **Prerequisite:** Phase 1.2 🔒 CLOSED & APPROVED  
> **Next Checkpoint:** 1.4 — Storage Layer  

---

## Goal

Define and implement the visual design system and theme management architecture for MemoVault. 

The application must look publicly like a premium, secure, and professional Notes & Vault application (inspired by Notion, Apple Notes, and Obsidian). It must remain completely free of chat visual cues, message icons, or communication UI signals to preserve its covert identity.

---

## MemoVault Visual Identity

Our goal is a visual experience that is clean, secure, and extremely premium.

* **Design Inspiration:** Apple Notes (paper-like clean grids, rich text elements) × Notion (minimalism, clean typography, light dividers) × Obsidian (obsidian/dark-mode styling, raw text aesthetics).
* **Tone:** Professional, private, minimal, calm, and functional.
* **Primary Brand Accent:** Slate Blue (Light: `#4F6BED` / Dark: `#6E8CFF`).
* **Secondary Brand Accent:** Muted Amber / Gold (Gold is only for special status/locked states).
* **Prohibited Visual Cues:** No chat bubble shapes, no avatar lists indicating conversation circles, no blue/green messaging dots, no contact list layouts, and no romantic or conversational typography.

---

## Design Tokens

We define a strict system of design tokens to establish consistency across light and dark modes.

### 1. Color Palette

We utilize curated, harmonious HSL tailored colors.

| Token | Light Mode (Notion Milk) | Dark Mode (Obsidian Dark) | Purpose |
|---|---|---|---|
| **Primary Background** | `HSL(0, 0%, 98%)` (Alabaster) | `HSL(220, 15%, 8%)` (Obsidian) | Root screen canvas |
| **Secondary Background** | `HSL(0, 0%, 95%)` (Warm Light) | `HSL(220, 12%, 12%)` (Charcoal) | Nested lists/cards |
| **Surface** | `HSL(0, 0%, 100%)` (Pure White) | `HSL(220, 10%, 15%)` (Graphite) | Cards, dialogs, sheets |
| **Accent Primary** | `HSL(229, 81%, 62%)` (Slate Blue) | `HSL(228, 100%, 71%)` (Neon Slate) | Interactive icons, buttons, active indicators |
| **Accent Secondary** | `HSL(42, 85%, 42%)` (Amber Gold) | `HSL(42, 90%, 55%)` (Gold Glow) | Key vault status, locked indicators |
| **Primary Text** | `HSL(220, 15%, 15%)` (Near Black) | `HSL(0, 0%, 90%)` (Soft White) | Main titles, body text |
| **Secondary Text** | `HSL(220, 10%, 45%)` (Slate Grey) | `HSL(220, 8%, 60%)` (Warm Grey) | Subtitles, helper text, dates |
| **Divider** | `HSL(220, 10%, 90%)` (Soft Grey) | `HSL(220, 10%, 20%)` (Dark Charcoal) | Thin borders, separations |

### 2. Semantic Colors

Used strictly for system states, alerts, and operational feedback.

| Token | Light Mode | Dark Mode | Purpose |
|---|---|---|---|
| **Success** | `HSL(142, 70%, 40%)` (Emerald) | `HSL(142, 60%, 50%)` (Bright Green) | Sync complete, verification successful |
| **Warning** | `HSL(38, 90%, 50%)` (Warm Amber) | `HSL(38, 85%, 60%)` (Amber Glow) | Unsynchronized changes, auth warnings |
| **Error** | `HSL(0, 75%, 45%)` (Crimson) | `HSL(0, 85%, 60%)` (Bright Red) | Destructive action, failed operation |
| **Info** | `HSL(200, 80%, 45%)` (Teal Sky) | `HSL(200, 75%, 55%)` (Sky Blue) | Informational tags, tips |
| **Disabled** | `HSL(220, 10%, 80%)` (Light Grey) | `HSL(220, 8%, 30%)` (Dark Grey) | Unclickable controls, secondary tags |

---

### 3. Typography Hierarchy (`AppTypography`)

We use Google Fonts (or system defaults styled strictly) mapping to the following hierarchy:
- **Headings Font:** `Outfit` (sleek, modern sans-serif for titles)
- **Body Font:** `Inter` (readable, clean for body notes)

Exposed under the `AppTypography` class inside `lib/core/theme/app_typography.dart`:

```dart
// lib/core/theme/app_typography.dart
import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle buttonText = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
}
```

---

### 4. Layout Grid & Spacing System
All margins, padding, and spacers use multiples of **4dp**:
- `spacing4` = 4.0
- `spacing8` = 8.0
- `spacing12` = 12.0
- `spacing16` = 16.0 (Default page margins)
- `spacing24` = 24.0
- `spacing32` = 32.0
- `spacing48` = 48.0

### 5. Corner Radius System
Corners follow a clean, geometric curve strategy:
- `radiusNone` = 0.0 (Flat)
- `radiusSmall` = 4.0 (Checkboxes, small tags)
- `radiusMedium` = 8.0 (Input fields, standard buttons)
- `radiusLarge` = 12.0 (Cards, dialog windows, bottom sheets)
- `radiusMax` = 999.0 (Circular/Pill shapes)

### 6. Border & Shadow System (Elevation)
We avoid heavy, colorful shadows. Instead, we use thin outlines for structural separation:
- **Border Stroke:** `0.75dp` with divider color.
- **Shadow Light:** `offset: (0, 1), blur: 3, color: black.withOpacity(0.04)`
- **Shadow Dark:** `offset: (0, 2), blur: 6, color: black.withOpacity(0.2)`

### 7. Animation Durations
Transitions should feel immediate and fluid:
- `durationFast` = 150ms (Button presses, hover states)
- `durationMedium` = 250ms (Page transitions, bottom sheet slides)
- `durationSlow` = 400ms (Detailed custom layouts)

---

## Theme Architecture

We build the themes using standard `ThemeData` styled to our tokens, supplemented with custom GetX `ThemeExtension` classes.

### Custom Color Scheme Extensions (`app_color_scheme.dart`)
We define a custom theme extension to handle semantic colors and vault-specific indicator states:

```dart
// lib/core/theme/app_color_scheme.dart
import 'package:flutter/material.dart';

class AppColorScheme extends ThemeExtension<AppColorScheme> {
  final Color vaultStatusLocked;
  final Color vaultStatusUnlocked;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color disabled;

  const AppColorScheme({
    required this.vaultStatusLocked,
    required this.vaultStatusUnlocked,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.disabled,
  });

  @override
  AppColorScheme copyWith({
    Color? vaultStatusLocked,
    Color? vaultStatusUnlocked,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? disabled,
  }) {
    return AppColorScheme(
      vaultStatusLocked: vaultStatusLocked ?? this.vaultStatusLocked,
      vaultStatusUnlocked: vaultStatusUnlocked ?? this.vaultStatusUnlocked,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      disabled: disabled ?? this.disabled,
    );
  }

  @override
  AppColorScheme lerp(ThemeExtension<AppColorScheme>? other, double t) {
    if (other is! AppColorScheme) return this;
    return AppColorScheme(
      vaultStatusLocked: Color.lerp(vaultStatusLocked, other.vaultStatusLocked, t)!,
      vaultStatusUnlocked: Color.lerp(vaultStatusUnlocked, other.vaultStatusUnlocked, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
    );
  }
}
```

---

## Theme Service & Persistence

A global, permanent `ThemeService` manages the runtime theme mode toggles.

### `lib/core/services/theme_service.dart`
```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ThemeService extends GetxService {
  final Rx<ThemeMode> _themeMode = ThemeMode.system.obs;

  ThemeMode get themeMode => _themeMode.value;

  Future<void> init() async {
    // Phase 1.3: Initialize default system mode.
    // Phase 1.4: Load saved theme preference (light/dark/system) from storage.
    _themeMode.value = ThemeMode.system;
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode.value = mode;
    Get.changeThemeMode(mode);
  }

  void toggleTheme() {
    if (_themeMode.value == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }
}
```

---

## Theme Sandbox Screen

Instead of hijacking the `HomeScreen`, we will create a dedicated `ThemeSandboxScreen` under a new feature slice: `lib/features/theme_sandbox/views/theme_sandbox_screen.dart`.

### Features of the Sandbox:
- **Theme Controls**: Buttons to trigger Light/Dark/System themes via `ThemeService`.
- **Typography Matrix**: Renders headers and body notes with the defined `AppTypography` styles.
- **Color Swatches**: Visual boxes displaying secondary brand colors, slate blue accent, and all 5 semantic colors.
- **Component Previews**: Renders standard widgets (cards, text fields, outlined buttons, chips, dividers) formatted with our radius, shadow, and divider styling tokens.

### Route Mapping
- Route Constant: `static const String themeSandbox = '/theme-sandbox';` inside `lib/core/routes/app_routes.dart`.
- Root page set to `themeSandbox` during local testing.

---

## Verification Plan

### Automated Tests
- Create unit tests for:
  - `ThemeService` mode switches (light, dark, system).
  - `AppColorScheme` color extension resolution across light and dark templates.
- Run `fvm flutter analyze` and `fvm flutter test`.

### Manual Verification
- Launch the application and boot directly into `ThemeSandboxScreen`.
- Toggle theme mode to verify slate blue and semantic colors switch correctly.
