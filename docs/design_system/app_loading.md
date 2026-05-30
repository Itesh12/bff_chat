# AppLoading Documentation

## Purpose
`AppLoading` encapsulates `CircularProgressIndicator` configurations inside styled shape layouts and modal blocking barriers.

## Constructor Variants
- `AppLoading.small()` - For buttons or inline status indicators.
- `AppLoading.medium()` - For center-page placeholder loaders.
- `AppLoading.fullScreen()` - Dark modal barrier overlay shielding double-clicks.

## Allowed Usage
- Loading lists, waiting for auth, inline button indicators.

## Forbidden Usage
- **NEVER** use raw `CircularProgressIndicator` widgets directly on pages.

## Examples
```dart
const AppLoading.medium()
```

## Future Extension Notes
- Reserved for future skeleton load shimmers or visual progress bars.
