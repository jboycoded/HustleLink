
import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Semantic brand colours that complement Flutter's ColorScheme.
///
/// Every screen should obtain these colours through:
/// Theme.of(context).extension<AppColors>()
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.peach,
    required this.peachSoft,
    required this.peachDeep,
    required this.muted,
  });

  final Color peach;
  final Color peachSoft;
  final Color peachDeep;
  final Color muted;

  /// Light theme brand colours.
  static const light = AppColors(
    peach: AppPalette.peach,
    peachSoft: AppPalette.peachSoft,
    peachDeep: AppPalette.peachDeep,
    muted: AppPalette.muted,
  );

  /// Dark theme brand colours.
  ///
  /// Peach remains consistent to preserve HustleLink's identity.
  /// Muted text becomes lighter for readability on dark surfaces.
  static const dark = AppColors(
    peach: AppPalette.peach,
    peachSoft: AppPalette.peachSoft,
    peachDeep: AppPalette.peachDeep,
    muted: Color(0xFFB8B8B0),
  );

  @override
  AppColors copyWith({
    Color? peach,
    Color? peachSoft,
    Color? peachDeep,
    Color? muted,
  }) {
    return AppColors(
      peach: peach ?? this.peach,
      peachSoft: peachSoft ?? this.peachSoft,
      peachDeep: peachDeep ?? this.peachDeep,
      muted: muted ?? this.muted,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;

    return AppColors(
      peach: Color.lerp(peach, other.peach, t)!,
      peachSoft: Color.lerp(peachSoft, other.peachSoft, t)!,
      peachDeep: Color.lerp(peachDeep, other.peachDeep, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}

/// Convenient access to HustleLink's custom theme colours.
extension AppColorsContext on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>()!;
}
