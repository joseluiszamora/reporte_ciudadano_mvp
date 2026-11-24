import 'package:flutter/material.dart';

/// Paleta oficial del MVP. No duplicar valores hexadecimales en widgets.
abstract final class CivicPalette {
  static const brandLight = Color(0xFF156B80);
  static const brandDark = Color(0xFF7DD0E2);
  static const onBrandLight = Color(0xFFFFFFFF);
  static const onBrandDark = Color(0xFF0D1922);

  static const canvasLight = Color(0xFFF8FAFC);
  static const canvasDark = Color(0xFF0D1922);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF142630);
  static const elevatedLight = Color(0xFFEFF4F7);
  static const elevatedDark = Color(0xFF1B3440);
  static const textLight = Color(0xFF172B3A);
  static const textDark = Color(0xFFE8F1F5);
  static const secondaryTextLight = Color(0xFF526575);
  static const secondaryTextDark = Color(0xFFA5B8C2);
  static const borderLight = Color(0xFFD7E1E8);
  static const borderDark = Color(0xFF39505C);
  static const errorLight = Color(0xFFB42318);
  static const errorDark = Color(0xFFFF8B91);
}

/// Colores semánticos del seguimiento ciudadano.
/// Status visual y estado de la entidad de dominio deben mantenerse separados.
@immutable
class CivicStatusColors extends ThemeExtension<CivicStatusColors> {
  const CivicStatusColors({
    required this.reported,
    required this.followUp,
    required this.resolved,
    required this.reportedContainer,
    required this.followUpContainer,
    required this.resolvedContainer,
  });

  final Color reported;
  final Color followUp;
  final Color resolved;
  final Color reportedContainer;
  final Color followUpContainer;
  final Color resolvedContainer;

  @override
  CivicStatusColors copyWith({
    Color? reported,
    Color? followUp,
    Color? resolved,
    Color? reportedContainer,
    Color? followUpContainer,
    Color? resolvedContainer,
  }) => CivicStatusColors(
    reported: reported ?? this.reported,
    followUp: followUp ?? this.followUp,
    resolved: resolved ?? this.resolved,
    reportedContainer: reportedContainer ?? this.reportedContainer,
    followUpContainer: followUpContainer ?? this.followUpContainer,
    resolvedContainer: resolvedContainer ?? this.resolvedContainer,
  );

  @override
  CivicStatusColors lerp(ThemeExtension<CivicStatusColors>? other, double t) {
    if (other is! CivicStatusColors) return this;
    return CivicStatusColors(
      reported: Color.lerp(reported, other.reported, t)!,
      followUp: Color.lerp(followUp, other.followUp, t)!,
      resolved: Color.lerp(resolved, other.resolved, t)!,
      reportedContainer: Color.lerp(
        reportedContainer,
        other.reportedContainer,
        t,
      )!,
      followUpContainer: Color.lerp(
        followUpContainer,
        other.followUpContainer,
        t,
      )!,
      resolvedContainer: Color.lerp(
        resolvedContainer,
        other.resolvedContainer,
        t,
      )!,
    );
  }
}

abstract final class AppTheme {
  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final primary = dark ? CivicPalette.brandDark : CivicPalette.brandLight;
    final onPrimary = dark
        ? CivicPalette.onBrandDark
        : CivicPalette.onBrandLight;
    final canvas = dark ? CivicPalette.canvasDark : CivicPalette.canvasLight;
    final surface = dark ? CivicPalette.surfaceDark : CivicPalette.surfaceLight;
    final onSurface = dark ? CivicPalette.textDark : CivicPalette.textLight;
    final outline = dark ? CivicPalette.borderDark : CivicPalette.borderLight;
    final elevated = dark
        ? CivicPalette.elevatedDark
        : CivicPalette.elevatedLight;

    // ColorScheme.fromSeed aporta roles Material 3 no explicitados en la guía.
    final scheme =
        ColorScheme.fromSeed(
          seedColor: CivicPalette.brandLight,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: onPrimary,
          surface: surface,
          onSurface: onSurface,
          onSurfaceVariant: dark
              ? CivicPalette.secondaryTextDark
              : CivicPalette.secondaryTextLight,
          outline: outline,
          outlineVariant: outline,
          surfaceContainer: elevated,
          surfaceContainerHigh: elevated,
          error: dark ? CivicPalette.errorDark : CivicPalette.errorLight,
          onError: dark ? CivicPalette.canvasDark : Colors.white,
        );

    final statuses = dark
        ? const CivicStatusColors(
            reported: Color(0xFFFFC66B),
            followUp: Color(0xFF83BDFA),
            resolved: Color(0xFF73DB99),
            reportedContainer: CivicPalette.elevatedDark,
            followUpContainer: CivicPalette.elevatedDark,
            resolvedContainer: CivicPalette.elevatedDark,
          )
        : const CivicStatusColors(
            reported: Color(0xFF925D00),
            followUp: Color(0xFF1264A3),
            resolved: Color(0xFF147737),
            reportedContainer: Color(0xFFFFF4D8),
            followUpContainer: Color(0xFFE8F2FF),
            resolvedContainer: Color(0xFFEAF8F0),
          );

    const radius = BorderRadius.all(Radius.circular(14));
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: canvas,
      extensions: <ThemeExtension<dynamic>>[statuses],
    );

    TextStyle type(double size, double line, FontWeight weight) => TextStyle(
      fontFamily: 'Inter',
      fontSize: size,
      height: line / size,
      fontWeight: weight,
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
      color: onSurface,
    );

    final label = type(14, 20, FontWeight.w600);
    final secondary = scheme.onSurfaceVariant;
    return base.copyWith(
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: outline),
        backgroundColor: surface,
        selectedColor: scheme.primaryContainer,
        labelStyle: label,
      ),
      dividerTheme: DividerThemeData(color: outline),
      textTheme: base.textTheme
          .apply(bodyColor: onSurface, displayColor: onSurface)
          .copyWith(
            headlineMedium: type(28, 36, FontWeight.w700),
            headlineSmall: type(24, 32, FontWeight.w700),
            titleLarge: type(20, 28, FontWeight.w600),
            titleMedium: type(16, 24, FontWeight.w600),
            bodyLarge: type(16, 24, FontWeight.w400),
            bodyMedium: type(14, 20, FontWeight.w400),
            bodySmall: type(12, 16, FontWeight.w500),
            labelLarge: label,
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: type(20, 28, FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: const RoundedRectangleBorder(borderRadius: radius),
          backgroundColor: primary,
          foregroundColor: onPrimary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontVariations: [FontVariation.weight(600)],
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: const RoundedRectangleBorder(borderRadius: radius),
          foregroundColor: primary,
          side: BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: elevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected) ? primary : secondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) =>
              type(
                12,
                16,
                states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w500,
              ).copyWith(
                color: states.contains(WidgetState.selected)
                    ? primary
                    : secondary,
              ),
        ),
        backgroundColor: surface,
        indicatorColor: dark
            ? CivicPalette.elevatedDark
            : CivicPalette.elevatedLight,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
