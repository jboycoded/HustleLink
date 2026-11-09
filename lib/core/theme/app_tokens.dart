import 'package:flutter/material.dart';

/// Non-colour design values: radii, borders, spacing, shadows.
abstract final class AppTokens {
  static const borderWidth = 2.5;
  static const rLg = 28.0;
  static const rMd = 16.0;
  static const space = 16.0;

  /// The hard, blur-free offset shadow used on cards and buttons.
  static List<BoxShadow> hardShadow(Color color, [double offset = 5]) =>
      [BoxShadow(color: color, offset: Offset(offset, offset), blurRadius: 0)];
}
