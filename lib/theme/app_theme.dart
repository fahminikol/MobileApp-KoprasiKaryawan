import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Primary & Accent Colors (Modern Fintech Palette)
  static const Color primaryBlue = Color(0xFF2563EB); // Vibrant Royal Cobalt
  static const Color primaryBlueDark = Color(0xFF1E3A8A); // Deep Midnight Navy
  static const Color primaryBlueLight = Color(0xFFEFF6FF); // Crisp Ice Blue
  static const Color primaryAccent = Color(0xFF38BDF8); // Sky Cyan Glow

  // Backgrounds & Surfaces
  static const Color scaffoldBackground = Color(0xFFF8FAFC); // Clean Slate-50
  static const Color surfaceElevated = Colors.white;
  static const Color cardBackground = Colors.white;
  
  // High-Contrast Modern Typography Colors
  static const Color textDark = Color(0xFF0F172A); // Slate-900
  static const Color textBody = Color(0xFF334155); // Slate-700
  static const Color textMuted = Color(0xFF64748B); // Slate-500
  static const Color textLight = Color(0xFF94A3B8); // Slate-400
  static const Color borderColor = Color(0xFFE2E8F0); // Slate-200
  static const Color borderLight = Color(0xFFF1F5F9); // Slate-100

  // Status & Financial Accents
  static const Color successGreen = Color(0xFF10B981); // Emerald 500
  static const Color successBg = Color(0xFFECFDF5);
  static const Color warningOrange = Color(0xFFF59E0B); // Amber 500
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color dangerRed = Color(0xFFEF4444); // Red 500
  static const Color dangerBg = Color(0xFFFEF2F2);
  static const Color purpleAccent = Color(0xFF8B5CF6); // Violet 500
  static const Color purpleBg = Color(0xFFF5F3FF);

  // Modern Pastel Badges & Icon Containers (2x4 Grid & Categories)
  static const Color pastelBlueBg = Color(0xFFEFF6FF);
  static const Color pastelBlueIcon = Color(0xFF2563EB);

  static const Color pastelPinkBg = Color(0xFFFFF1F2);
  static const Color pastelPinkIcon = Color(0xFFE11D48);

  static const Color pastelYellowBg = Color(0xFFFEFCE8);
  static const Color pastelYellowIcon = Color(0xFFCA8A04);

  static const Color pastelGreenBg = Color(0xFFECFDF5);
  static const Color pastelGreenIcon = Color(0xFF059669);

  static const Color pastelPurpleBg = Color(0xFFFAF5FF);
  static const Color pastelPurpleIcon = Color(0xFF7C3AED);

  static const Color pastelCyanBg = Color(0xFFECFEFF);
  static const Color pastelCyanIcon = Color(0xFF0891B2);

  static const Color pastelIndigoBg = Color(0xFFEEF2FF);
  static const Color pastelIndigoIcon = Color(0xFF4F46E5);

  static const Color pastelCoralBg = Color(0xFFFFF7ED);
  static const Color pastelCoralIcon = Color(0xFFEA580C);

  // Gradients (Fintech Signature Cards & Banners)
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E3A8A), // Deep Navy
      Color(0xFF1D4ED8), // Royal Blue
      Color(0xFF2563EB), // Cobalt
    ],
  );

  static const LinearGradient cardGradientGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F172A),
      Color(0xFF1E293B),
      Color(0xFF334155),
    ],
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF047857), Color(0xFF10B981)],
  );

  static const LinearGradient onboardingGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
  );

  // Box Shadows (Multi-layered elevation for 60/120 FPS high refresh rate)
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x080F172A),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x050F172A),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x0D0F172A),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x060F172A),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x331E3A8A),
      blurRadius: 22,
      offset: Offset(0, 10),
    ),
    BoxShadow(
      color: Color(0x1A2563EB),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  // Theme Data with GoogleFonts Plus Jakarta Sans
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: scaffoldBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        surface: scaffoldBackground,
        brightness: Brightness.light,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: textDark,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          color: textDark,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          color: textDark,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: textDark,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: textDark,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: textDark,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: textDark,
          fontSize: 14,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: textBody,
          fontSize: 13,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          color: textMuted,
          fontSize: 11.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textDark),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: textDark,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderColor, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderColor, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: textMuted,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: textLight,
          fontSize: 13,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderLight, width: 1),
        ),
        color: Colors.white,
      ),
    );
  }
}
