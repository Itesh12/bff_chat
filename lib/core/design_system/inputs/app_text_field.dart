import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:memovault/core/extensions/theme_extensions.dart';
import 'package:memovault/core/theme/app_spacing.dart';
import 'package:memovault/core/theme/app_radius.dart';
import 'package:memovault/core/theme/app_typography.dart';

enum _AppTextFieldVariant { standard, search, multiline, password }

/// A unified, highly-robust text input field that wraps raw text input.
/// Natively supports validation states, search debouncing, obscure text visibility toggles, and tokenized focus borders.
class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool readOnly;
  final bool autofocus;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final Widget? prefix;
  final Widget? suffix;
  final Duration debounceDuration;
  final _AppTextFieldVariant _variant;
  final bool borderless;

  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
    this.autofocus = false,
    this.validator,
    this.inputFormatters,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefix,
    this.suffix,
    this.borderless = false,
  })  : _variant = _AppTextFieldVariant.standard,
        debounceDuration = Duration.zero;

  const AppTextField.search({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
    this.autofocus = false,
    this.prefix,
    this.suffix,
    this.debounceDuration = const Duration(milliseconds: 300),
  })  : _variant = _AppTextFieldVariant.search,
        borderless = false,
        labelText = null,
        validator = null,
        inputFormatters = null,
        keyboardType = TextInputType.text,
        textInputAction = TextInputAction.search,
        maxLines = 1,
        minLines = null,
        maxLength = null;

  const AppTextField.multiline({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.onChanged,
    this.readOnly = false,
    this.autofocus = false,
    this.validator,
    this.minLines = 3,
    this.maxLength,
    this.prefix,
    this.suffix,
    this.borderless = false,
  })  : _variant = _AppTextFieldVariant.multiline,
        debounceDuration = Duration.zero,
        onSubmitted = null,
        inputFormatters = null,
        keyboardType = TextInputType.multiline,
        textInputAction = TextInputAction.newline,
        maxLines = null;

  const AppTextField.password({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'Enter password',
    this.labelText = 'Password',
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
    this.autofocus = false,
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.maxLength,
  })  : _variant = _AppTextFieldVariant.password,
        borderless = false,
        inputFormatters = null,
        keyboardType = TextInputType.visiblePassword,
        maxLines = 1,
        minLines = null,
        prefix = null,
        suffix = null,
        debounceDuration = Duration.zero;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _passwordObscure = true;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    if (widget._variant == _AppTextFieldVariant.search && widget.debounceDuration > Duration.zero) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(widget.debounceDuration, () {
        widget.onChanged?.call(value);
      });
    } else {
      widget.onChanged?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final isDark = theme.brightness == Brightness.dark;

    final isPassword = widget._variant == _AppTextFieldVariant.password;
    final isSearch = widget._variant == _AppTextFieldVariant.search;

    // Resolve suffix widget for Password Toggle or Search Clear
    Widget? effectiveSuffix = widget.suffix;
    if (isPassword) {
      effectiveSuffix = IconButton(
        icon: Icon(
          _passwordObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
          color: theme.iconTheme.color?.withValues(alpha: 0.5),
        ),
        onPressed: () {
          setState(() {
            _passwordObscure = !_passwordObscure;
          });
        },
      );
    } else if (isSearch && widget.controller != null) {
      effectiveSuffix = AnimatedBuilder(
        animation: widget.controller!,
        builder: (context, _) {
          if (widget.controller!.text.isEmpty) return const SizedBox.shrink();
          return IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.clear, size: 18),
            onPressed: () {
              widget.controller!.clear();
              _onChanged('');
            },
          );
        },
      );
    }

    final inputDecoration = InputDecoration(
      hintText: widget.hintText,
      labelText: widget.labelText,
      alignLabelWithHint: widget._variant == _AppTextFieldVariant.multiline,
      prefixIcon: isSearch
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
              child: Icon(Icons.search, size: 20, color: theme.iconTheme.color?.withValues(alpha: 0.5)),
            )
          : widget.prefix,
      prefixIconConstraints: isSearch ? const BoxConstraints(minWidth: 40, minHeight: 40) : null,
      suffixIcon: effectiveSuffix,
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: (theme.textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.4),
      ),
      labelStyle: AppTypography.bodyMedium.copyWith(
        color: (theme.textTheme.bodyMedium?.color ?? Colors.grey).withValues(alpha: 0.6),
      ),
      contentPadding: widget.borderless
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s12,
            ),
      filled: !widget.borderless,
      fillColor: widget.borderless
          ? Colors.transparent
          : (isSearch
              ? (isDark ? Colors.grey[900]! : Colors.grey[100]!)
              : theme.scaffoldBackgroundColor),
      border: widget.borderless
          ? InputBorder.none
          : OutlineInputBorder(
              borderRadius: isSearch ? AppRadius.max : AppRadius.medium,
              borderSide: BorderSide(
                color: isSearch
                    ? (isDark ? Colors.grey[800]! : Colors.grey[200]!)
                    : theme.dividerColor,
                width: 1.0,
              ),
            ),
      enabledBorder: widget.borderless
          ? InputBorder.none
          : OutlineInputBorder(
              borderRadius: isSearch ? AppRadius.max : AppRadius.medium,
              borderSide: BorderSide(
                color: isSearch
                    ? (isDark ? Colors.grey[850]! : Colors.grey[200]!)
                    : theme.dividerColor.withValues(alpha: 0.8),
                width: 1.0,
              ),
            ),
      focusedBorder: widget.borderless
          ? InputBorder.none
          : OutlineInputBorder(
              borderRadius: isSearch ? AppRadius.max : AppRadius.medium,
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.5,
              ),
            ),
      errorBorder: widget.borderless
          ? InputBorder.none
          : OutlineInputBorder(
              borderRadius: isSearch ? AppRadius.max : AppRadius.medium,
              borderSide: BorderSide(
                color: colors.error,
                width: 1.0,
              ),
            ),
      focusedErrorBorder: widget.borderless
          ? InputBorder.none
          : OutlineInputBorder(
              borderRadius: isSearch ? AppRadius.max : AppRadius.medium,
              borderSide: BorderSide(
                color: colors.error,
                width: 1.5,
              ),
            ),
    );

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: isPassword ? _passwordObscure : false,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      onChanged: _onChanged,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      inputFormatters: widget.inputFormatters,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      style: widget._variant == _AppTextFieldVariant.multiline
          ? AppTypography.bodyLarge.copyWith(color: theme.textTheme.bodyLarge?.color)
          : AppTypography.bodyMedium.copyWith(color: theme.textTheme.bodyMedium?.color),
      decoration: inputDecoration,
    );
  }
}
