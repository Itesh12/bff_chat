# AppEmptyState Documentation

## Purpose
`AppEmptyState` is a visual template displayed when content is missing, standardizing vacancies with standard icons, helper headers, and simple CTA buttons.

## Constructor Variants
- `AppEmptyState({required IconData icon, required String title, required String message, String? ctaLabel, VoidCallback? onCtaTap, ...})` - Standard vacancy layout panel.

## Allowed Usage
- Empty lists, folders, vaults, search screens with no results.

## Forbidden Usage
- **NEVER** build custom empty placeholders using raw column elements on pages.

## Examples
```dart
AppEmptyState(
  icon: Icons.note_alt_outlined,
  title: 'No Notes Found',
  message: 'Tap the button below to add your first secure note.',
  ctaLabel: 'Add Note',
  onCtaTap: () => createNote(),
)
```

## Future Extension Notes
- Reserved for future animated illustration support.
