import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens mirrored from the gotan.in website (tailwind.config.js).
class AppColors {
  static const teal = Color(0xFF159A9C);
  static const tealDark = Color(0xFF087477);
  static const tealLight = Color(0xFFDDF3F2);
  static const yellow = Color(0xFFF4D35E);
  static const yellowLight = Color(0xFFFFF5CC);
  static const navy = Color(0xFF16324F);

  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF6F9F9);
  static const border = Color(0xFFDCE6E6);

  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF64748B);
  static const textDisabled = Color(0xFFCBD5E1);

  static const success = Color(0xFF16A765);
  static const successBg = Color(0xFFE7F7EF);
  static const warning = Color(0xFFE9A820);
  static const warningBg = Color(0xFFFFF7E6);
  static const error = Color(0xFFD94A4A);
  static const errorBg = Color(0xFFFCEBEA);

  static const pastelBlue = Color(0xFFE6F3FB);
  static const pastelYellow = Color(0xFFFFF7E6);
  static const pastelPink = Color(0xFFFCEBEA);
  static const pastelGreen = Color(0xFFEAF6EC);
}

class AppRadius {
  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 14.0;
  static const xl = 18.0;
  static const xxl = 24.0;
}

class AppShadows {
  static const soft = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 2)),
  ];
  static const card = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, 4)),
  ];
  static const float = [
    BoxShadow(color: Color(0x14000000), blurRadius: 30, offset: Offset(0, 10)),
  ];
}

class AppTheme {
  static const String fontFamily = 'Inter';
  static const String displayFamily = 'Outfit';

  static const SystemUiOverlayStyle lightStatusBar = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      primary: AppColors.teal,
      onPrimary: Colors.white,
      secondary: AppColors.yellow,
      onSecondary: AppColors.navy,
      error: AppColors.error,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.background,
    );

    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        systemOverlayStyle: lightStatusBar,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        border: outlineBorder,
        enabledBorder: outlineBorder,
        focusedBorder: outlineBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.teal, width: 1.6),
        ),
        errorBorder: outlineBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.textDisabled,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.teal,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: AppColors.teal),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.teal,
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.tealLight,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(fontFamily: fontFamily, fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: const TextStyle(fontFamily: fontFamily, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        titleTextStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.teal),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.teal,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.teal,
        labelStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700),
      ),
    );
  }
}
