
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_tokens.dart';

abstract final class AppTheme {
  // Shared theme builder
  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color foreground,
    required Color muted,
    required AppColors appColors,
  }) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? AppPalette.peach : AppPalette.ink,
      onPrimary: isDark ? AppPalette.ink : AppPalette.white,
      secondary: AppPalette.peach,
      onSecondary: AppPalette.ink,
      error: AppPalette.danger,
      onError: AppPalette.white,
      surface: surface,
      onSurface: foreground,
      outline: isDark
          ? const Color(0xFF777777)
          : AppPalette.ink,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );

    final textTheme = GoogleFonts.spaceGroteskTextTheme(
      base.textTheme,
    ).apply(
      bodyColor: foreground,
      displayColor: foreground,
    );

    final border = BorderSide(
      color: scheme.outline,
      width: AppTokens.borderWidth,
    );

    OutlineInputBorder inputBorder(BorderSide side) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.rMd),
        borderSide: side,
      );
    }

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      extensions: [appColors],

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rLg),
          side: border,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
            side: border,
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          minimumSize: const Size.fromHeight(48),
          side: border,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        border: inputBorder(border),
        enabledBorder: inputBorder(border),
        focusedBorder: inputBorder(
          border.copyWith(
            color: scheme.primary,
            width: 3,
          ),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
  backgroundColor: surface,
  indicatorColor: AppPalette.peach,
  indicatorShape: StadiumBorder(side: border),
  height: 72,
  iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
    (states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(
          color: AppPalette.ink,
        );
      }

      return IconThemeData(color: muted);
    },
  ),
  labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
    (states) {
      return GoogleFonts.spaceGrotesk(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: states.contains(WidgetState.selected)
            ? foreground
            : muted,
      );
    },
  ),
),

      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: 0.25),
        thickness: 1,
      ),

      iconTheme: IconThemeData(
        color: foreground,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: foreground,
        contentTextStyle: TextStyle(color: surface),
        behavior: SnackBarBehavior.floating,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
    );
  }

  // LIGHT THEME
  static ThemeData light() {
    return _buildTheme(
      brightness: Brightness.light,
      background: AppPalette.white,
      surface: AppPalette.white,
      foreground: AppPalette.ink,
      muted: AppPalette.muted,
      appColors: AppColors.light,
    );
  }

  // DARK THEME
  static ThemeData dark() {
    const background = Color(0xFF121212);
    const surface = Color(0xFF1E1E1E);
    const foreground = Color(0xFFF5F5F5);
    const muted = Color(0xFFB8B8B0);

    return _buildTheme(
      brightness: Brightness.dark,
      background: background,
      surface: surface,
      foreground: foreground,
      muted: muted,
      appColors: AppColors.dark,
    );
  }
}
