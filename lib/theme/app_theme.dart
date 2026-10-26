import 'package:flutter/material.dart';

/// Tokens de Color Oficiales de Lorivery
/// Cliente: Tema Claro con acentos en Rojo Lorivery (#E60000)
/// Repartidor: Tema Oscuro Táctico de Alto Contraste estilo Soy Rappi (#0E1217 y Verde #00E676)
class AppColors {
  // --- Lorivery Brand (Cliente) ---
  static const Color loriveryRed = Color(0xFFE60000);
  static const Color loriveryRedDark = Color(0xFFB30000);
  static const Color loriveryRedLight = Color(0xFFFFEBEE);

  // Cliente Neutros
  static const Color clientScaffoldBg = Color(0xFFF8F9FA);
  static const Color clientSurface = Colors.white;
  static const Color clientSearchBg = Color(0xFFF1F3F5);
  static const Color clientTextPrimary = Color(0xFF14181B);
  static const Color clientTextSecondary = Color(0xFF718096);
  static const Color clientBorder = Color(0xFFE2E8F0);

  // --- Soy Rappi Brand (Repartidor) ---
  static const Color courierScaffoldBg = Color(0xFF0E1217);
  static const Color courierSurface = Color(0xFF141920);
  static const Color courierSurfaceElevated = Color(0xFF1A212A);
  static const Color courierCardBg = Color(0xFF151A21);
  static const Color courierBorder = Color(0xFF263238);

  // Repartidor Acentos Operativos
  static const Color courierGreenNeon = Color(0xFF00E676);
  static const Color courierGreen = Color(0xFF00C853);
  static const Color courierCyan = Color(0xFF00B0FF);
  static const Color courierAmber = Color(0xFFFF9100);
  static const Color courierDanger = Color(0xFFFF3B30);

  // Repartidor Neutros
  static const Color courierTextPrimary = Colors.white;
  static const Color courierTextSecondary = Color(0xFF8B9BB4);
}

/// Radios de Curvatura extraídos del Design System de Rappi y Soy Rappi
class AppRadius {
  static const double xs = 6.0;
  static const double sm = 10.0;
  static const double md = 14.0;
  static const double card = 18.0;     // Tarjetas de restaurantes Rappi
  static const double button = 16.0;   // Botones táctiles
  static const double input = 16.0;    // Buscador y cajas de texto
  static const double modal = 28.0;    // Modales y bottom sheets
  static const double full = 999.0;    // Píldoras y badges circulares
}

/// Elevaciones y Sombras Suaves (Rappi 8% Opacity) y Tácticas (Soy Rappi)
class AppShadows {
  // Sombras Cliente (Rappi Soft Floating)
  static final List<BoxShadow> clientCard = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> clientFloating = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 14,
      offset: const Offset(0, 3),
    ),
  ];

  static final List<BoxShadow> clientRedButton = [
    BoxShadow(
      color: AppColors.loriveryRed.withValues(alpha: 0.35),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];

  // Sombras Repartidor (Soy Rappi High Contrast)
  static final List<BoxShadow> courierCard = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.55),
      blurRadius: 22,
      offset: const Offset(0, 8),
    ),
  ];

  static final List<BoxShadow> courierNeonGreen = [
    BoxShadow(
      color: AppColors.courierGreen.withValues(alpha: 0.45),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}

class AppTheme {
  // Compatibilidad hacia atrás
  static const Color primaryOrange = AppColors.loriveryRed;
  static const Color backgroundLight = AppColors.clientScaffoldBg;
  static const Color backgroundDark = AppColors.courierScaffoldBg;
  static const Color surfaceLight = AppColors.clientSurface;
  static const Color surfaceDark = AppColors.courierSurface;
  static const Color textPrimaryLight = AppColors.clientTextPrimary;
  static const Color textSecondaryLight = AppColors.clientTextSecondary;

  static ThemeData get lightTheme => clientTheme;
  static ThemeData get darkTheme => courierTheme;

  /// =========================================================================
  /// TEMA 1: LORICA CLIENTE (Inspirado en Rappi con Paleta Rojo Lorivery)
  /// =========================================================================
  static ThemeData get clientTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.loriveryRed,
        primary: AppColors.loriveryRed,
        onPrimary: Colors.white,
        primaryContainer: AppColors.loriveryRedLight,
        secondary: const Color(0xFF111111),
        surface: AppColors.clientSurface,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.clientScaffoldBg,

      // Tipografía limpia y moderna
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.clientTextPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: AppColors.clientTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          color: AppColors.clientTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: AppColors.clientTextPrimary,
          fontSize: 15,
        ),
        bodyMedium: TextStyle(
          color: AppColors.clientTextSecondary,
          fontSize: 13,
        ),
      ),

      // Tarjetas con bordes redondeados de 18px y sombra al 8%
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.clientSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.clientBorder, width: 0.8),
        ),
        margin: EdgeInsets.zero,
      ),

      // Botones Elevados (Rojo Lorivery)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.loriveryRed,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AppColors.loriveryRed.withValues(alpha: 0.4),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),

      // Buscadores y Campos de Entrada (Estilo Rappi 48px)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.clientSearchBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.clientTextSecondary, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.loriveryRed, width: 1.5),
        ),
      ),

      // Bottom Sheet con curvatura superior de 28px
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.clientSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.clientSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.clientTextPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.clientTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  /// =========================================================================
  /// TEMA 2: LORICA REPARTIDOR (Inspirado en Soy Rappi Táctico de Alto Contraste)
  /// =========================================================================
  static ThemeData get courierTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.courierGreen,
        primary: AppColors.courierGreen,
        onPrimary: Colors.white,
        secondary: AppColors.courierCyan,
        surface: AppColors.courierSurface,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.courierScaffoldBg,

      // Tipografía de Alto Contraste para la Calle
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.courierTextPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
        titleLarge: TextStyle(
          color: AppColors.courierTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: AppColors.courierTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: AppColors.courierTextPrimary,
          fontSize: 15,
        ),
        bodyMedium: TextStyle(
          color: AppColors.courierTextSecondary,
          fontSize: 13,
        ),
      ),

      // Tarjetas Oscuras Tácticas con bordes definidos
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.courierCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.courierBorder, width: 1.2),
        ),
        margin: EdgeInsets.zero,
      ),

      // Botón Masivo Operativo (Verde Neón / Aceptar)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.courierGreen,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppColors.courierGreen.withValues(alpha: 0.45),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),

      // Entradas Oscuras para el PIN OTP o Formularios
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.courierSurfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.courierTextSecondary, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.courierBorder, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.courierBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.courierGreenNeon, width: 2.0),
        ),
      ),

      // Modal Táctico Inferior
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.courierSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.courierSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
