# Phase 4.1 — FFI Build & Execution Validation Plan

This document details the build verification and platform validation strategy for integrating the **`libsignal_dart` (Rust FFI)** package into the MemoVault application. It ensures native binaries resolve, build, and execute successfully across target architectures without causing runtime crashes.

---

## 🎯 Verification Matrix by Target Environment

To ensure that precompiled native assets do not cause crashes during release bundling, the compiler must validate the following build scenarios:

| Platform Target | Host OS | Compilation Target | Verification Objective | Success Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **Android Device** | Windows/macOS | `arm64-v8a` / `armeabi-v7a` | Assert native library `.so` resolves and symbols load on physical devices. | App boots, calls `libsignal` constructors, tests pass. |
| **Android Emulator** | Windows/macOS | `x86_64` | Assert compatibility with development emulators. | JNI symbols load, no ABI architecture mismatch errors. |
| **iOS Simulator** | macOS | `arm64` (Apple Silicon) / `x86_64` | Verify framework linkage and dynamic library loading in simulated sandbox. | Cocoapods links target framework, dynamic loader (`dyld`) loads symbols. |
| **iOS Device** | macOS | `arm64` | Verify code-signing and entitlement validation on real hardware. | iOS codesign accepts dynamic framework, no dynamic signature load rejection. |
| **CI/CD Pipeline** | Linux Runner | Android Bundle (`aab`) | Assert headless build pipelines fetch precompiled assets without local Rust compiler. | Build script compiles without requiring local `rustc` / Cargo. |

---

## 🛠️ Validation Procedures

### 1. Android Native Verification
*   **Asset Extraction**: Verify that the Gradle script extracts the dynamic libraries (`libsignal_ffi.so`) into the corresponding JNI directories:
    *   `/lib/arm64-v8a/libsignal_ffi.so`
    *   `/lib/x86_64/libsignal_ffi.so`
*   **Symbol Check**: Execute dynamic linking testing on booting:
    ```bash
    # Extract built APK to check JNI architecture folders
    unzip -l build/app/outputs/flutter-apk/app-release.apk "lib/*"
    ```
*   **Symptom Protection**: Watch for `java.lang.UnsatisfiedLinkError` which indicates missing native libraries or ABI mismatch.

### 2. iOS Native Verification
*   **Framework Search Path**: Verify that `libsignal_dart` dynamic frameworks (`libsignal_ffi.framework`) are embedded and signed inside the iOS app bundle:
    *   Path: `Runner.app/Frameworks/libsignal_ffi.framework`
*   **Simulator (macOS Host)**: Ensure the compiler creates a fat library or simulator slice:
    ```bash
    # Validate dynamic library architectures
    lipo -info ios/Pods/libsignal_dart/libsignal_ffi.framework/libsignal_ffi
    ```
    *Result must output: `arm64` and `x86_64`.*
*   **Codesigning**: Check dynamic library codesigning parameters during build phase to prevent `dyld: Library not loaded` errors on physical iOS launches.

### 3. CI/CD Build Verification
*   **Precompiled Download fallbacks**: Since CI/CD runners (like GitHub Actions) may not have native Rust toolchains installed, the build script must fetch precompiled dynamic binaries using secure HTTP transfers.
*   **Verification Command**:
    ```bash
    # Validate the project builds cleanly for Android in release mode
    flutter build apk --release --target-platform android-arm64
    ```

---

## 🚨 Failure Recovery & Fallback Plans

1.  **ABI Conflict**: If other packages bundle old native `.so` files that conflict with our target architectures, Gradle packaging rules will be modified in `android/app/build.gradle` to exclude or prioritize JNI architectures.
2.  **Code Signing Error**: If dynamic signature checks fail on physical iOS devices, a Xcode build phase shell script will be registered to force-re-sign `libsignal_ffi.framework` using the active developer provisioning profile.
3.  **Local Compilation Override**: If a downloaded dynamic binary is corrupt or missing symbols, a local compile toggle will be provided in the project configurations:
    ```yaml
    # Compile from source toggle inside local config
    libsignal:
      build_from_source: true
    ```
    This forces a local `cargo build` run if Rust/Cargo is detected in the developer's environment.
