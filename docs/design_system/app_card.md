# AppCard Documentation

## Purpose
`AppCard` is the fundamental containment surface block. It handles uniform shadows, standard rounded borders (`AppRadius.large`), custom background/border overrides, and click touch ink ripples.

## Constructor Variants
- `AppCard({required Widget child, EdgeInsetsGeometry? padding, EdgeInsetsGeometry? margin, VoidCallback? onTap, ...})` - Containment card primitive.

## Allowed Usage
- Dashboard note items, folder slots, category panels, and detail statistics tiles.

## Forbidden Usage
- **NEVER** use raw `Card` widgets.
- **NEVER** apply custom container decorations mimicking cards on pages.

## Examples
```dart
AppCard(
  onTap: () => viewDetails(),
  child: Text('Card Content'),
)
```

## Future Extension Notes
- Reserved for future swipe-to-reveal gestures or drag-and-drop ordering.
