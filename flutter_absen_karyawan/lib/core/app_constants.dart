import 'package:flutter/material.dart';

const String appId = 'ut-hrms-tabalong-flutter';

class AppColors {
  // Slate Colors
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate50 = Color(0xFFF8FAFC);

  // Yellow Colors
  static const Color yellow500 = Color(0xFFFACC15);
  static const Color yellow50 = Color(0xFFFEFCE8);

  // Amber Colors
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber50 = Color(0xFFFFFBEB);

  // Rose Colors
  static const Color rose600 = Color(0xFFE11D48);
  static const Color rose500 = Color(0xFFF43F5E);
  static const Color rose400 = Color(0xFFFB7185);
  static const Color rose200 = Color(0xFFFECDD3);
  static const Color rose100 = Color(0xFFFEE2E2);
  static const Color rose50 = Color(0xFFFEF2F2);

  // Emerald Colors
  static const Color emerald600 = Color(0xFF059669);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald200 = Color(0xFFA7F3D0);
  static const Color emerald50 = Color(0xFFECFDF5);

  // Blue Colors
  static const Color blue500 = Color(0xFF3B82F6);
  static const Color blue50 = Color(0xFFEFF6FF);

  // Indigo Colors
  static const Color indigo600 = Color(0xFF4F46E5);
  static const Color indigo500 = Color(0xFF6366F1);
  static const Color indigo400 = Color(0xFF818CF8);
  static const Color indigo50 = Color(0xFFEEF2FF);

  // Card White
  static const Color cardWhite = Color(0xFFFFFFFF);

  // Black with opacity
  static const Color black12 = Color(0x1F000000);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      scaffoldBackgroundColor: AppColors.slate50,
      fontFamily: 'Inter',
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.slate900),
      useMaterial3: true,
    );
  }
}

class AppStyles {
  static const double borderRadiusLarge = 32.0;
  static const double borderRadiusMedium = 16.0;

  static BoxDecoration cardDecoration = BoxDecoration(
    color: AppColors.cardWhite,
    borderRadius: BorderRadius.circular(borderRadiusLarge),
    border: Border.all(color: Colors.grey.shade200),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.02),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
