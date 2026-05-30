# AppDialog Documentation

## Purpose
`AppDialog` is a static design-system helper offering custom, unified modal popups. It ensures identical button configurations, spacing guidelines, titles, and retry behaviors.

## Constructor Variants
- `AppDialog.info(BuildContext context, {required String title, required String message, String buttonText, VoidCallback? onPressed})` - Simple info popup.
- `AppDialog.confirm(BuildContext context, {required String title, required String message, String confirmLabel, String cancelLabel, required VoidCallback onConfirm, VoidCallback? onCancel})` - Dialog to prompt confirmation before safe mutation actions.
- `AppDialog.delete(BuildContext context, {required String title, required String message, String deleteLabel, String cancelLabel, required VoidCallback onDelete, VoidCallback? onCancel})` - Specialized danger action delete dialog utilizing `AppButton.danger`.

## Allowed Usage
- Deleting items, confirming major changes, alert information overlays.

## Forbidden Usage
- **NEVER** use raw `AlertDialog` or `SimpleDialog` directly in feature screens.

## Examples
```dart
AppDialog.delete(
  context,
  title: 'Delete Item?',
  message: 'This cannot be undone.',
  onDelete: () => controller.deleteItem(),
)
```

## Future Extension Notes
- Reserved for future biometric authentication overlays or prompt triggers.
