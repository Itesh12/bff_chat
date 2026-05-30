# AppSearchBar Documentation

## Purpose
`AppSearchBar` is a visual design system widget wrapper representing search boxes, matching real-time input interactions or read-only gesture trigger zones.

## Constructor Variants
- `AppSearchBar({TextEditingController? controller, ValueChanged<String>? onChanged, VoidCallback? onTap, bool readOnly, ...})` - Configures either standard search textfields or clickable overlay panels.

## Allowed Usage
- Dashboard search entries, AppBar search headers, and triggers that open dedicated search screens.

## Forbidden Usage
- **NEVER** build custom search containers with raw borders or input layouts.

## Examples
```dart
AppSearchBar(
  readOnly: true,
  onTap: () => Get.toNamed(AppRoutes.search),
)
```

## Future Extension Notes
- Reserved for future multi-filter tag capsules or search chips in later phases.
