import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Brand colours that Material's ColorScheme has no slot for.
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

  static const light = AppColors(
    peach: AppPalette.peach,
    peachSoft: AppPalette.peachSoft,
    peachDeep: AppPalette.peachDeep,
    muted: AppPalette.muted,
  );

  @override
  AppColors copyWith({
    Color? peach,
    Color? peachSoft,
    Color? peachDeep,
    Color? muted,
  }) =>
      AppColors(
        peach: peach ?? this.peach,
        peachSoft: peachSoft ?? this.peachSoft,
        peachDeep: peachDeep ?? this.peachDeep,
        muted: muted ?? this.muted,
      );

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

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
