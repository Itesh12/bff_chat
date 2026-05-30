# AppScaffold Documentation

## Purpose
`AppScaffold` is the core page layout controller. It coordinates standard AppBars, safe area constraints, focus-dismiss triggers (on tap outside), modal loading states, and retry-capable error display slots.

## Constructor Variants
- `AppScaffold({required Widget body, String? title, List<Widget>? actions, Widget? floatingActionButton, bool isLoading, String? errorMessage, VoidCallback? onRetry, ...})` - Base page layout wrapper.

## Allowed Usage
- Wrap the high-level layout of every screen in MemoVault.

## Forbidden Usage
- **NEVER** use raw `Scaffold` or manual `AppBar` widgets in feature presentation pages.

## Examples
```dart
AppScaffold(
  title: 'Dashboard',
  body: DashboardBodyWidget(),
)
```

## Future Extension Notes
- Reserved for future offline status banners or synchronization headers.
