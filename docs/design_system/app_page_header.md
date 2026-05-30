# AppPageHeader Documentation

## Purpose
`AppPageHeader` unifies large page title headings with standard subtitle counters and secondary descriptions.

## Constructor Variants
- `AppPageHeader({required String title, String? subtitle, ...})` - Main screen heading module.

## Allowed Usage
- Placement at the very top of primary dashboards, archive screens, and setup grids.

## Forbidden Usage
- **NEVER** build custom page headers using raw `Text` and `Padding` widgets with unlinked sizes.

## Examples
```dart
const AppPageHeader(
  title: 'Secure Notes',
  subtitle: '12 active entries',
)
```

## Future Extension Notes
- Reserved for future search toggle animations or user profile chips.
