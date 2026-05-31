# Phase 4.1 — Cryptographic Library Review

This document evaluates the available choices for integrating the **Signal Protocol (X3DH + Double Ratchet)** into the MemoVault codebase. Rather than implementing these cryptographic state machines in custom pure Dart, we analyze existing open-source implementations, native wrappers, and platform bindings to select the most secure, maintainable, and robust library for Phase 4.1.

---

## 🔍 Candidate Evaluation Matrix

We analyze four main pathways for integrating the Signal Protocol:

| Evaluation Metric | Option 1: `libsignal` Native FFI (Rust/C) | Option 2: `signal_protocol_dart` (Pure Dart) | Option 3: Platform Channel Wrappers (Java/Swift) | Option 4: OMEMO Dart forks (`omemo_dart`) |
| :--- | :--- | :--- | :--- | :--- |
| **Security Auditing** | High (Officially audited Rust/C libraries) | Medium (Port of Java code, needs verification) | High (Leverages official Android/iOS SDKs) | Medium-High (Audited for XMPP OMEMO clients) |
| **Maintenance & Health**| Active (Signal Foundation) | Low-Medium (Sparse commits, community forks) | Medium (Dependent on third-party bridge libs) | Active (Maintained by the XMPP community) |
| **Cross-Platform Support**| High (Multi-arch compiling required) | Maximum (Compiles to all Flutter targets) | Low (Mobile-only: Android and iOS) | Maximum (Compiles to all Flutter targets) |
| **Setup Complexity** | High (Requires building FFI libraries) | Very Low (Standard pub package) | Medium-High (Requires Swift/Kotlin bridging) | Low (Standard pub package) |
| **Performance** | High (Native speed, hardware crypto) | Medium (Slight VM overhead) | High (Native platform hardware engines) | Medium (Slight VM overhead) |

---

## 📋 Comprehensive Option Analysis

### Option 1: `libsignal` Native FFI Wrapper (Rust/C Bindings)
*   **Description**: Compiling the official Rust implementation of `libsignal` (or the legacy C library `libsignal-protocol-c`) into native binaries and accessing them in Flutter using Dart's Foreign Function Interface (FFI).
*   **Security Review**: Excellent. The Rust implementation is maintained and audited directly by the Signal Foundation. It contains industry-standard resistance to side-channel attacks and timing exploits.
*   **Risks & Drawbacks**: High tooling overhead. Compilation requires active toolchains for Android NDK, Apple LLVM (XCode), and Windows MSVC. Managing native build errors inside CI/CD pipelines represents significant development drag.

### Option 2: `signal_protocol_dart` (Pure Dart Port)
*   **Description**: A pure Dart port of the Java implementation of the Signal Protocol (`libsignal-protocol-java`).
*   **Security Review**: Good cryptographic translation. However, it relies heavily on third-party Dart dependencies (such as `pointycastle` and the `cryptography` package) for baseline Curve25519, AES-GCM, and SHA-256 primitives.
*   **Risks & Drawbacks**: The original repository has low maintenance activity. Several forks exist to fix Dart null-safety and package updates. Vetting and maintaining the fork is required to prevent security regressions.

### Option 3: Platform Channel Wrappers
*   **Description**: Writing Flutter MethodChannels to delegate all cryptographic handshakes and ratchet state updates directly to native Java (`libsignal-protocol-android`) and iOS Swift libraries.
*   **Security Review**: Leverages the official, secure native libraries built into standard clients.
*   **Risks & Drawbacks**: Breaks cross-platform flexibility. This approach is strictly limited to iOS and Android, preventing MemoVault from running on Windows, macOS, or development emulators without mock engines.

### Option 4: `omemo_dart` (OMEMO Protocol Fork)
*   **Description**: A modified fork of `signal_protocol_dart` maintained by XMPP client developers to support OMEMO (which builds on the Double Ratchet).
*   **Security Review**: Heavily reviewed by XMPP developers. Key schedules are compatible, and it includes modern updates for current Dart SDK versions.
*   **Risks & Drawbacks**: Extraneous XML/XMPP payload bindings must be stripped or ignored, as MemoVault uses a custom server architecture.

---

## 🎯 Recommended Approach

**Selected Option**: **Option 2/4 Hybrid (Vetted `signal_protocol_dart` Community Fork)**

### Rationale:
1.  **Platform Parity**: A pure Dart library guarantees that the messaging engine will run consistently across Android, iOS, and development desktop/web environments without native compile failures.
2.  **No Native Pipeline Risks**: Avoids the compile-time complexity of FFI compilation pipelines, keeping local development fast and clean.
3.  **Encapsulation**: The Double Ratchet is a purely logical state machine (managing keys, ratchets, and sequence counts). The library is only responsible for state logic, while the actual heavy encryption (AES-256-GCM, SHA-256) is delegated to the highly audited Dart [cryptography](https://pub.dev/packages/cryptography) package, which utilizes hardware-accelerated platform APIs under the hood.

---

## 🛡️ Hardening Plan for Pure Dart Ratchet

To mitigate risks associated with the pure Dart implementation:

1.  **Unit Tests Validation**: Integrate official [Signal Test Vectors](https://github.com/signalapp/libsignal) into our test suite to verify that our Dart ratchet matches the behavior of the official Signal client exactly.
2.  **State Isolation**: Do not write the state machine classes (`SessionStore`, `PreKeyStore`) as separate files. Store their serialized outputs directly inside our secure [HiddenVaultDatabase](file:///c:/bff_chat/lib/features/hidden/data/hidden_vault_database.dart), encrypting all ratchet states at rest via SQLCipher.
3.  **Strict Memory Clearance**: Once a message is decrypted or encrypted, immediately override the temporary byte arrays in memory using `Uint8List.fillRange(0, length)` to prevent key remnants from lingering in the Dart VM heap.
