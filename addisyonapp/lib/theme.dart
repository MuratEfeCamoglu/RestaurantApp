import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Renk paleti, HTML prototipindeki "Limon & Zeytin" tasarımından alınmıştır.
class AppColors {
  AppColors._();

  static const canvas = Color(0xFFEAE6DC); // dış zemin
  static const background = Color(0xFFF7F3EC); // ekran zemini
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFEAE4D8);

  static const textDark = Color(0xFF241F18);
  static const textMuted = Color(0xFF8C8478);
  static const textFaint = Color(0xFFC6BEAF);
  static const placeholder = Color(0xFFB0A99B);
  static const placeholderBg = Color(0xFFF3F0E9);

  static const accent = Color(0xFFC1611F);
  static const accentDark = Color(0xFFA64F17);
  static const copper = Color(0xFFB87333);
  static const chipBg = Color(0xFFF3E9DA);

  static const green = Color(0xFF4C8B5A);
  static const greenBg = Color(0xFFE4EFE6);

  static const red = Color(0xFFB84C3B);
  static const redBg = Color(0xFFF7E4DF);
}

class AppText {
  AppText._();

  /// Başlıklar için serif font (Domine).
  static TextStyle heading({
    double size = 24,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.textDark,
    double? height,
  }) {
    return GoogleFonts.domine(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  /// Gövde metinleri için sans-serif font (Work Sans).
  static TextStyle body({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textDark,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.workSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Üst başlıklarda kullanılan küçük harf aralıklı etiket stili.
  static TextStyle eyebrow({Color color = AppColors.copper, double size = 11}) {
    return body(
      size: size,
      weight: FontWeight.w700,
      color: color,
      letterSpacing: size * 0.011 * 10, // ~0.1em yaklaşık
    );
  }
}

ThemeData buildAppTheme() {
  final base = ThemeData.light();
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      secondary: AppColors.copper,
      surface: AppColors.background,
    ),
    textTheme: GoogleFonts.workSansTextTheme(base.textTheme),
    splashFactory: InkRipple.splashFactory,
    dividerColor: AppColors.border,
  );
}

/// ₺1.025 gibi Türkçe formatlı tutar metni üretir (binlik ayırıcı nokta).
String formatTL(num amount) {
  final rounded = amount.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    if (i > 0 && remaining % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  final sign = rounded < 0 ? '-' : '';
  return '$sign₺$buffer';
}
