import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color darkSurface = Color(0xFF1C1C1E);

  static const Color primary = Color(0xFFD97706);
  static const Color primaryDark = Color(0xFF78350F);
  static const Color primaryPressed = Color(0xFFB45309);
  static const Color primaryLight = Color(0xFFFEF3C7);
  static const Color primaryLighter = Color(0xFFFFFBEB);
  static const Color primaryBorder = Color(0xFFFDE68A);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);

  // success/error kept for form validation messages only — not status badges
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEF2F2);

  // Status badge colors — amber-family for active states, grey for terminal/inactive.
  // No green/blue/purple: brand identity stays in the amber spectrum.
  static const Color statusPendingBg = Color(0xFFFEF3C7);    // light amber
  static const Color statusPendingText = Color(0xFF92400E);   // amber-800
  static const Color statusConfirmedBg = Color(0xFFFEF3C7);  // same light amber
  static const Color statusConfirmedText = Color(0xFFD97706); // amber (brand)
  static const Color statusPreparingBg = Color(0xFFFEF3C7);  // light amber
  static const Color statusPreparingText = Color(0xFFD97706); // amber (brand)
  static const Color statusReadyBg = Color(0xFFFEF3C7);      // light amber
  static const Color statusReadyText = Color(0xFF78350F);     // dark amber — most prominent active
  static const Color statusServedBg = Color(0xFFF3F4F6);     // grey — nearing done
  static const Color statusServedText = Color(0xFF6B7280);    // grey text
  static const Color statusCompletedBg = Color(0xFFF3F4F6);  // grey
  static const Color statusCompletedText = Color(0xFF6B7280); // grey
  static const Color statusCancelledBg = Color(0xFFF3F4F6);  // grey — neutral, not alarming
  static const Color statusCancelledText = Color(0xFF9CA3AF); // lighter grey
}
