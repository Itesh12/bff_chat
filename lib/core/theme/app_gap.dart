import 'package:flutter/widgets.dart';
import 'package:memovault/core/theme/app_spacing.dart';

/// AppGap is a spacing widget replacement for [SizedBox].
/// It maps spacing sizes strictly to [AppSpacing] tokens, ensuring no hardcoded spacing dimensions in UI layouts.
class AppGap extends StatelessWidget {
  final double? width;
  final double? height;


  // ── Vertical Spacings ──────────────────────────────────────────────────────

  const AppGap.v4({super.key}) : width = null, height = AppSpacing.s4;
  const AppGap.v8({super.key}) : width = null, height = AppSpacing.s8;
  const AppGap.v12({super.key}) : width = null, height = AppSpacing.s12;
  const AppGap.v16({super.key}) : width = null, height = AppSpacing.s16;
  const AppGap.v24({super.key}) : width = null, height = AppSpacing.s24;
  const AppGap.v32({super.key}) : width = null, height = AppSpacing.s32;
  const AppGap.v48({super.key}) : width = null, height = AppSpacing.s48;
  const AppGap.v64({super.key}) : width = null, height = AppSpacing.s64;

  // ── Horizontal Spacings ────────────────────────────────────────────────────

  const AppGap.h4({super.key}) : width = AppSpacing.s4, height = null;
  const AppGap.h8({super.key}) : width = AppSpacing.s8, height = null;
  const AppGap.h12({super.key}) : width = AppSpacing.s12, height = null;
  const AppGap.h16({super.key}) : width = AppSpacing.s16, height = null;
  const AppGap.h24({super.key}) : width = AppSpacing.s24, height = null;
  const AppGap.h32({super.key}) : width = AppSpacing.s32, height = null;
  const AppGap.h48({super.key}) : width = AppSpacing.s48, height = null;
  const AppGap.h64({super.key}) : width = AppSpacing.s64, height = null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
    );
  }
}
