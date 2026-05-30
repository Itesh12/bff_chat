# AppSectionHeader Documentation

## Purpose
`AppSectionHeader` represents subheadings separating categories or listings with clean typography and optional contextual action triggers (like a "See All" text button).

## Constructor Variants
- `AppSectionHeader({required String title, Widget? action, ...})` - Section divider heading module.

## Allowed Usage
- List sections separators, category dashboards, and setting groupings.

## Forbidden Usage
- **NEVER** build headers with manual spacing layouts in list blocks.

## Examples
```dart
AppSectionHeader(
  title: 'Folders',
  action: AppButton.text(
    text: 'Manage',
    onPressed: () => editCategories(),
  ),
)
```

## Future Extension Notes
- Reserved for future collapsible panel headers.
