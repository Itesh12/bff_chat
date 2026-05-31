# Phase 4.1 — Cryptographic Library Due Diligence

This document performs an exhaustive due diligence audit of available cryptographic libraries implementing the **Signal Protocol (Double Ratchet + X3DH)** for Flutter and Dart. The evaluation prioritizes cryptographic assurance and audit history over cross-platform simplicity (specifically ignoring Web compilation targets).

---

## 📦 Candidate Due Diligence Profiles

### 1. `djx-y-z/libsignal_dart` (pub.dev: `libsignal`)
*   **Repository URL**: [github.com/djx-y-z/libsignal_dart](https://github.com/djx-y-z/libsignal_dart)
*   **Maintenance Activity**: **Extremely High**. Last commit was on **May 29, 2026** (Version 5.0.1).
*   **Release History**: Active updates matching upstream Rust-based advancements.
*   **Null-Safety & Compatibility**: Fully compatible with **Dart 3.x** and **Flutter 3.x**.
*   **Security Posture**: **Highest**. This package compiles direct FFI bindings to the official Rust **`libsignal`** library maintained by the Signal Foundation. It benefits from the continuous auditing, side-channel resistance, and post-quantum (Kyber) security updates implemented by Signal's core cryptographic team.
*   **Production Adoption**: Used in privacy-focused applications requiring identical cryptographic guarantees to the official Signal app.
*   **Licensing**: **AGPL-3.0**. Matches MemoVault's open-source paradigm.

### 2. `MixinNetwork/libsignal_protocol_dart` (pub.dev: `libsignal_protocol_dart`)
*   **Repository URL**: [github.com/MixinNetwork/libsignal_protocol_dart](https://github.com/MixinNetwork/libsignal_protocol_dart)
*   **Maintenance Activity**: **Moderate**. Last release was version 0.8.0 in **April 2026**.
*   **Release History**: Sparse commits, primarily focused on Dart version upgrades and basic dependency maintenance.
*   **Null-Safety & Compatibility**: Compatible with **Dart >=3.4.0 <4.0.0**.
*   **Security Posture**: **Medium-High**. Pure Dart port of the Java implementation of the Signal Protocol. It relies on community packages (such as `pointycastle`) for Curve25519 and symmetric encryption primitives. It has not undergone formal independent auditing as a standalone package.
*   **Production Adoption**: Used in **Mixin Messenger** (a multi-million user Flutter-based Web3 chat application).
*   **Licensing**: **GPL-3.0**.

### 3. Platform Channel Wrappers (Native Java/Swift)
*   **Repository URL**: N/A (requires custom platform-specific code).
*   **Maintenance Activity**: Custom wrapper code requires manual engineering maintenance.
*   **Null-Safety & Compatibility**: Supported natively on Android (Kotlin/Java) and iOS (Swift).
*   **Security Posture**: **High**. Delegates cryptography directly to official mobile SDKs.
*   **Production Adoption**: Standard for native mobile applications but highly uncommon in unified Flutter codebases.
*   **Licensing**: Varies depending on selected upstream native packages.

---

## 🎯 Recommendation & Verdict

### Selected Choice:
**`djx-y-z/libsignal_dart` (Option 1: Rust FFI Wrapper)**

### Rationale:
1.  **Cryptographic Assurance**: By wrapping the official Rust `libsignal` library, we ensure that our Double Ratchet, X3DH handshake, and post-quantum keys are handled by the same audited and validated code used by millions of devices worldwide. This eliminates "implementation drift" or mathematical flaws in Dart ports.
2.  **Web Support Excluded**: Following architectural adjustments, Flutter Web support is explicitly removed from our requirement matrix. The app focuses entirely on secure mobile platforms (Android/iOS) where native FFI binaries execute at hardware speeds.
3.  **Modern Upgrades**: Unlike the pure Dart port, `libsignal_dart` supports modern post-quantum cryptography (Kyber) and is actively updated to match Signal's evolving standards.

---

## 🛡️ Implementation Safeguards for FFI

To safely integrate the Rust FFI package:

1.  **Version Lock**: Hardcode the library dependency in `pubspec.yaml` to the specific audited release (`libsignal: 5.0.1`) to prevent automatic upgrades to unvetted revisions.
2.  **Binary Integrity Verification**: Configure build hooks to verify the SHA-256 checksums of the precompiled native libraries downloaded from the release pipeline.
3.  **Secure Storage Bridge**: Native `libsignal` relies on persistent database storage for session states. We will bind the library's state providers (`SignalProtocolStore`) to our encrypted **[HiddenVaultDatabase](file:///c:/bff_chat/lib/features/hidden/data/hidden_vault_database.dart)**, ensuring FFI-generated keys are never saved in cleartext storage.
