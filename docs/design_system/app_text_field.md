# AppTextField Documentation

## Purpose
`AppTextField` unifies text input shapes under standard tokenized focus rings, helper hints, labels, and error states.

## Constructor Variants
- `AppTextField({TextEditingController? controller, String? labelText, String? hintText, ...})` - Standard form text input.
- `AppTextField.search({TextEditingController? controller, ValueChanged<String>? onChanged, Duration debounceDuration, ...})` - Specialized search input with search icons, clear trigger, and a built-in search debouncer (default 300ms).
- `AppTextField.multiline({TextEditingController? controller, ...})` - Editor-focused multi-line textbox that wraps text dynamically.
- `AppTextField.password({TextEditingController? controller, ...})` - Formatted passcode input with built-in show/hide visibility toggle eye.

## Allowed Usage
- Form inputs, note editor writing text, search filters, passcode locks.

## Forbidden Usage
- **NEVER** use raw `TextField` or `TextFormField` in visual layouts.
- **NEVER** use raw `OutlineInputBorder` configuration rules on pages.

## Examples
```dart
AppTextField(
  controller: titleController,
  labelText: 'Note Title',
  hintText: 'Enter title here...',
)
```

## Future Extension Notes
- Reserved for dynamic autocomplete suggestions or pattern validators.
