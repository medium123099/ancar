import 'package:flutter/material.dart';

/// Базовые числа и цвета палитры.
class AppTokens {
  static const indigo = Color(0xFF4F46E5);
  static const mint = Color(0xFF10B981);
  static const red = Color(0xFFEF4444);
  static const amber = Color(0xFFF59E0B);
  static const bgLight = Color(0xFFF8FAFC);
  static const bgDark = Color(0xFF0B1020);

  static const radius = 16.0;
  static const minTap = 48.0;
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);

  static const fontFamily = 'Inter';
}

/// Смысловые цвета приложения: цена упала, выросла, ожидание и т.д.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.down,
    required this.downBg,
    required this.up,
    required this.upBg,
    required this.waiting,
    required this.waitingBg,
    required this.card,
    required this.border,
    required this.muted,
  });

  final Color down; // цена упала (текст, значки)
  final Color downBg;
  final Color up; // цена выросла
  final Color upBg;
  final Color waiting; // ожидание
  final Color waitingBg;
  final Color card;
  final Color border;
  final Color muted; // второстепенный текст

  static const light = AppColors(
    down: Color(0xFF047857),
    downBg: Color(0xFFD1FAE5),
    up: Color(0xFFB91C1C),
    upBg: Color(0xFFFEE2E2),
    waiting: Color(0xFFB45309),
    waitingBg: Color(0xFFFEF3C7),
    card: Colors.white,
    border: Color(0xFFE2E8F0),
    muted: Color(0xFF475569),
  );

  static const dark = AppColors(
    down: Color(0xFF34D399),
    downBg: Color(0x3310B981),
    up: Color(0xFFF87171),
    upBg: Color(0x33EF4444),
    waiting: Color(0xFFFBBF24),
    waitingBg: Color(0x33F59E0B),
    card: Color(0xFF131A2E),
    border: Color(0xFF243049),
    muted: Color(0xFF94A3B8),
  );

  @override
  AppColors copyWith({
    Color? down,
    Color? downBg,
    Color? up,
    Color? upBg,
    Color? waiting,
    Color? waitingBg,
    Color? card,
    Color? border,
    Color? muted,
  }) {
    return AppColors(
      down: down ?? this.down,
      downBg: downBg ?? this.downBg,
      up: up ?? this.up,
      upBg: upBg ?? this.upBg,
      waiting: waiting ?? this.waiting,
      waitingBg: waitingBg ?? this.waitingBg,
      card: card ?? this.card,
      border: border ?? this.border,
      muted: muted ?? this.muted,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      down: Color.lerp(down, other.down, t)!,
      downBg: Color.lerp(downBg, other.downBg, t)!,
      up: Color.lerp(up, other.up, t)!,
      upBg: Color.lerp(upBg, other.upBg, t)!,
      waiting: Color.lerp(waiting, other.waiting, t)!,
      waitingBg: Color.lerp(waitingBg, other.waitingBg, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}

/// Короткий доступ: context.colors.down и т.п.
extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

/// Стили текста, которых нет в стандартной теме.
class AppText {
  /// Крупная жирная цена с табличными цифрами (цифры не «прыгают»).
  static TextStyle price(BuildContext context, {double size = 24}) {
    return TextStyle(
      fontFamily: AppTokens.fontFamily,
      fontSize: size,
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: Theme.of(context).colorScheme.onSurface,
    );
  }
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;
    final bg = isDark ? AppTokens.bgDark : AppTokens.bgLight;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppTokens.indigo,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? const Color(0xFF818CF8) : AppTokens.indigo,
      onPrimary: isDark ? AppTokens.bgDark : Colors.white,
      surface: c.card,
      error: c.up,
      outline: c.border,
    );

    final base = ThemeData(brightness: brightness);
    final textTheme = base.textTheme.apply(
      fontFamily: AppTokens.fontFamily,
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    const buttonText = TextStyle(
      fontFamily: AppTokens.fontFamily,
      fontWeight: FontWeight.w600,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppTokens.fontFamily,
      scaffoldBackgroundColor: bg,
      textTheme: textTheme,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: isDark ? 0 : 2,
        shadowColor: const Color(0x140F172A),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          side: BorderSide(color: c.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.up),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.up, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppTokens.minTap),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppTokens.minTap),
          shape: buttonShape,
          side: BorderSide(color: c.border),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, AppTokens.minTap),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: c.border),
        backgroundColor: c.card,
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        labelStyle: TextStyle(
          fontFamily: AppTokens.fontFamily,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: AppTokens.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}