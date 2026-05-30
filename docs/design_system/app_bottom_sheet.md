# AppBottomSheet Documentation

## Purpose
`AppBottomSheet` standardizes modal overlay layouts with centering drag handles, rounded corners, spacing insets, and keyboard-dismiss overlay buffers.

## Constructor Variants
- `AppBottomSheet.show(BuildContext context, {required Widget child, String? title, List<Widget>? actions, bool isScrollControlled})` - Static bottom sheet modal trigger.

## Allowed Usage
- Multi-option folders, filter settings, quick categories setup, and sorting choices.

## Forbidden Usage
- **NEVER** call raw `showModalBottomSheet` directly in visual pages.

## Examples
```dart
AppBottomSheet.show(
  context,
  title: 'Filters',
  child: FilterSettingsWidget(),
)
```

## Future Extension Notes
- Reserved for future multi-step sheets or expandable bottom panels.
