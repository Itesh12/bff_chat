import 'package:flutter/material.dart';
import 'package:memovault/core/design_system/inputs/app_text_field.dart';

/// A reusable global search bar component.
/// Wraps [AppTextField.search] inside a clean gesture listener to enable read-only navigation triggers.
class AppSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;

  const AppSearchBar({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'Search notes...',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (readOnly && onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: IgnorePointer(
          child: AppTextField.search(
            controller: controller,
            focusNode: focusNode,
            hintText: hintText,
            readOnly: true,
          ),
        ),
      );
    }

    return AppTextField.search(
      controller: controller,
      focusNode: focusNode,
      hintText: hintText,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      readOnly: readOnly,
    );
  }
}
