# 17 — Phase 1.5 Implementation Plan: Observability, Logging & Telemetry

This plan outlines the design, dependency structure, and verification strategy to establish a premium logging, global crash interception, and telemetry abstraction layer for the MemoVault application.

---

## 1. Observability Architecture

```
                    ┌────────────────────────────────────────┐
                    │          Global Error Interceptor       │
                    │   (FlutterError / PlatformDispatcher)   │
                    └───────────────────┬────────────────────┘
                                        │
                                        ▼
  ┌────────────────────────────────────────────────────────────────────────┐
  │                              AppLogger                                 │
  │                     (Log Sanitisation & Redaction)                      │
  └───────┬─────────────────────────────┬───────────────────────────┬──────┘
          │                             │                           │
          ▼                             ▼                           ▼
┌───────────────────┐         ┌───────────────────┐       ┌───────────────────┐
│   ConsoleOutput   │         │ CrashlyticsOutput │       │  AnalyticsService │
│ (ANSI Color Dev)  │         │  (Release Errors) │       │ (Decoupled Event) │
└───────────────────┘         └───────────────────┘       └───────────────────┘
```

The system separates debugging log outputs from operational monitoring telemetry. It guarantees that sensitive user parameters are aggressively redacted prior to any output stream dispatch.

---

## 2. Dependency Specification

We will add the following pinned packages to `pubspec.yaml`:

```yaml
dependencies:
  # Crash reporting and remote diagnostics
  firebase_crashlytics: ^4.1.3
  # Behavior telemetry and feature tracking
  firebase_analytics: ^11.3.3
```

---

## 3. Privacy Sanitisation & Logging Levels (ADR-013)

Under **ADR-013**, logs must adhere to the following rules:

1. **Levels:**
   - `trace`: extremely detailed execution flow.
   - `debug`: general development inspection.
   - `info`: system-level state alterations.
   - `warning`: non-fatal recovered issues.
   - `error`: operation failures.
   - `fatal`: boot or runtime crashes that require user intervention.

2. **Data Redaction:**
   The `AppLogger` will automatically scan all log messages and metadata maps using regular expressions. Any strings matching base64 signatures (such as encryption keys), passwords, vault metadata paths, or raw email addresses will be replaced with `[REDACTED]`.

---

## 4. Proposed File Mappings

### 4.1. Core Logger & Outputs
- `lib/core/observability/log_level.dart` — Supported enum values.
- `lib/core/observability/app_logger.dart` — Main API for log dispatching and text scrubbing.
- `lib/core/observability/logger_output.dart` — Interface for log targets.
- `lib/core/observability/console_output.dart` — Pretty console formatting for dev builds.
- `lib/core/observability/crashlytics_output.dart` — Non-fatal logs mapped to Firebase Crashlytics.

### 4.2. Telemetry Abstraction
- `lib/core/services/analytics_service.dart` — Abstract interface for screen and custom event tracking.
- `lib/core/services/firebase_analytics_service.dart` — Production implementation executing Firebase SDK queries.

### 4.3. Instrumentation & Performance Metrics
- `lib/core/observability/performance_tracker.dart` — Measures startup durations and SQLCipher access overheads.

### 4.4. Boot-time Error Hooking
- `lib/main_dev.dart` / `lib/main_staging.dart` / `lib/main_prod.dart` — Bind `FlutterError.onError` and `PlatformDispatcher.instance.onError` to process and log failures automatically.

---

## 5. Verification Plan

### Automated Tests
- Assert logger removes 256-bit encryption keys inside messages and JSON parameters.
- Verify screen and event logs decouple successfully when Firebase is stubbed.
- Verify startup latency tracker logs exact duration.
