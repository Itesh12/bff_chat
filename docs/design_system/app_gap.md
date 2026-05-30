# AppGap Documentation

## Purpose
`AppGap` is a spacing utility widget that enforces the design system's spacing tokens (`AppSpacing`), completely eliminating hardcoded spacing dimensions in UI layouts.

## Constructor Variants
- Vertical Gaps: `AppGap.v4()`, `AppGap.v8()`, `AppGap.v12()`, `AppGap.v16()`, `AppGap.v24()`, `AppGap.v32()`, `AppGap.v48()`, `AppGap.v64()`
- Horizontal Gaps: `AppGap.h4()`, `AppGap.h8()`, `AppGap.h12()`, `AppGap.h16()`, `AppGap.h24()`, `AppGap.h32()`, `AppGap.h48()`, `AppGap.h64()`

## Allowed Usage
- Standard separation between list components, buttons, fields, and headers.

## Forbidden Usage
- **NEVER** use raw `SizedBox(height: ...)` or `SizedBox(width: ...)` outside of the core design system and theme directories.
- **NEVER** use arbitrary double values for margins or paddings.

## Examples
```dart
Column(
  children: [
    Text('Title'),
    const AppGap.v12(),
    Text('Content'),
  ],
)
```

## Future Extension Notes
- Reserved for future auto-adjusting responsive gaps in desktop/tablet layouts.
