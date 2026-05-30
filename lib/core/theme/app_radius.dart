import 'package:flutter/widgets.dart';

abstract final class AppRadius {
  static const double rNone = 0.0;
  static const double rSmall = 4.0;
  static const double rMedium = 8.0;
  static const double rLarge = 12.0;
  static const double rMax = 999.0;

  static const BorderRadius small = BorderRadius.all(Radius.circular(rSmall));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(rMedium));
  static const BorderRadius large = BorderRadius.all(Radius.circular(rLarge));
  static const BorderRadius max = BorderRadius.all(Radius.circular(rMax));
}
