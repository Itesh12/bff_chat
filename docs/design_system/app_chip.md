# AppChip Documentation

## Purpose
`AppChip` is a unified pill capsule tag container. It standardizes category tags, favorites count, and metadata markers with proper padding, border colors, and text scales.

## Constructor Variants
- `AppChip({required String label, Color? color, ...})` - Basic indicator tag capsule.

## Allowed Usage
- Displaying folders names, tags, status identifiers, note categories.

## Forbidden Usage
- **NEVER** use raw `Chip`, `FilterChip`, or `ActionChip` widgets.
- **NEVER** build manually bordered and rounded container tags in feature screens.

## Examples
```dart
const AppChip(
  label: 'Personal',
  color: Colors.green,
)
```

## Future Extension Notes
- Reserved for future close action buttons on tags or selectable filter tags.
