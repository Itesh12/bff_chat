# AppButton Documentation

## Purpose
`AppButton` is the universal text and main action trigger primitive in MemoVault. It unifies standard elevations, focus outlines, border lines, text styles, and manages asynchronous loading states dynamically.

## Constructor Variants
- `AppButton.primary({required String text, VoidCallback? onPressed, Future<void> Function()? onPressedAsync, ...})` - Standard high-contrast brand accent button.
- `AppButton.secondary({required String text, VoidCallback? onPressed, Future<void> Function()? onPressedAsync, ...})` - Bordered/outlined secondary action button.
- `AppButton.text({required String text, VoidCallback? onPressed, Future<void> Function()? onPressedAsync, ...})` - Flat, borderless link button.
- `AppButton.danger({required String text, VoidCallback? onPressed, Future<void> Function()? onPressedAsync, ...})` - High-contrast destructive semantic button.

## Allowed Usage
- Form submissions, modal primary choices, navigation routes triggers, and save actions.
- Asynchronous actions that require an overlay loading indicator directly on the button:
  ```dart
  AppButton.primary(
    text: 'Save Details',
    onPressedAsync: () async {
      await controller.saveToDatabase();
    },
  )
  ```

## Forbidden Usage
- **NEVER** use raw Material buttons (`ElevatedButton`, `OutlinedButton`, `TextButton`) in feature screens.
- **NEVER** override text styles, internal paddings, colors, or heights directly in visual layouts.

## Examples
```dart
AppButton.secondary(
  text: 'Cancel',
  onPressed: () => Navigator.pop(context),
)
```

## Future Extension Notes
- Reserved for swipe-to-activate or drag-to-trigger action handlers in upcoming features.
