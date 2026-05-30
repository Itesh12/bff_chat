# AppIconButton Documentation

## Purpose
`AppIconButton` standardizes icon triggers by enforcing minimum accessible touch targets, matching theme palettes, and ensuring consistent hover effects.

## Constructor Variants
- `AppIconButton.primary({required IconData icon, VoidCallback? onPressed, ...})` - Standard primary filled/accent icon button.
- `AppIconButton.secondary({required IconData icon, VoidCallback? onPressed, ...})` - Bordered/outlined circular icon button.
- `AppIconButton.danger({required IconData icon, VoidCallback? onPressed, ...})` - Semantic destructive action icon button.

## Allowed Usage
- AppBar actions, Floating favoriting markers, category delete/edit buttons, and standard back navigation buttons.

## Forbidden Usage
- **NEVER** use raw `IconButton` or nested `GestureDetector(child: Icon(...))` triggers.
- **NEVER** pass raw spacing padding variables.

## Examples
```dart
AppIconButton.secondary(
  icon: Icons.edit,
  tooltip: 'Edit Folder',
  onPressed: () => editFolder(),
)
```

## Future Extension Notes
- Reserved for dynamic badge counts or state badges on the icon.
