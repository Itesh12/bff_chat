# AppSnackBar Documentation

## Purpose
`AppSnackBar` offers static convenience methods to prompt success, alert warning, error, or info overlays with exact colors and icon representations.

## Constructor Variants
- `AppSnackBar.success({required String title, required String message, ...})` - Green successful notification toast.
- `AppSnackBar.error({required String title, required String message, ...})` - Red failure notification toast.
- `AppSnackBar.info({required String title, required String message, ...})` - Blue educational notification toast.

## Allowed Usage
- Notifying the user about asynchronous success, network errors, validation flags, database wipes, or biometric logins.

## Forbidden Usage
- **NEVER** use `Get.snackbar` or raw `SnackBar` directly in features.

## Examples
```dart
AppSnackBar.success(
  title: 'Note Saved',
  message: 'Note saved securely.',
)
```

## Future Extension Notes
- Reserved for dynamic action buttons inside notifications.
