import 'package:flutter/material.dart';

/// 爸妈宝 — 适老化主题配置
/// 原则：超大字体、高对比配色、按钮≥80px、圆角友好
class AppTheme {
  // ─── 颜色 — 高对比 ───
  static const Color primaryColor = Color(0xFF1565C0); // 深蓝 — 主色调
  static const Color primaryLight = Color(0xFF5E92F3);
  static const Color primaryDark = Color(0xFF003C8F);
  static const Color secondaryColor = Color(0xFF43A047); // 绿色 — 确认/完成
  static const Color warningColor = Color(0xFFEF6C00); // 橙色 — 提醒
  static const Color dangerColor = Color(0xFFE53935); // 红色 — 紧急/SOS
  static const Color bgColor = Color(0xFFFAFAFA);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF616161);
  static const Color textOnDark = Colors.white;

  // ─── 字号 — 正常2倍 ───
  static const double displayLarge = 48;
  static const double displayMedium = 40;
  static const double headlineLarge = 36;
  static const double headlineMedium = 28;
  static const double titleLarge = 24;
  static const double titleMedium = 22;
  static const double bodyLarge = 20;
  static const double bodyMedium = 18;
  static const double labelLarge = 18;

  // ─── 间距 ───
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;

  // ─── 按钮尺寸 ───
  static const double buttonHeight = 56; // 不小于80px建议，56为Material默认大按钮
  static const double buttonMinWidth = 200;
  static const double iconSize = 32;

  // ─── 圆角 ───
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 20;

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: bgColor,
      ),
      scaffoldBackgroundColor: bgColor,
      fontFamily: 'Roboto',

      // ─── 文字样式 ───
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: displayLarge, fontWeight: FontWeight.bold, color: textPrimary),
        displayMedium: TextStyle(fontSize: displayMedium, fontWeight: FontWeight.bold, color: textPrimary),
        headlineLarge: TextStyle(fontSize: headlineLarge, fontWeight: FontWeight.bold, color: textPrimary),
        headlineMedium: TextStyle(fontSize: headlineMedium, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: TextStyle(fontSize: titleLarge, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: TextStyle(fontSize: titleMedium, fontWeight: FontWeight.w500, color: textPrimary),
        bodyLarge: TextStyle(fontSize: bodyLarge, color: textPrimary),
        bodyMedium: TextStyle(fontSize: bodyMedium, color: textSecondary),
        labelLarge: TextStyle(fontSize: labelLarge, fontWeight: FontWeight.w500, color: textPrimary),
      ),

      // ─── 按钮 ───
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(buttonMinWidth, buttonHeight),
          backgroundColor: primaryColor,
          foregroundColor: textOnDark,
          textStyle: const TextStyle(fontSize: titleMedium, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingMd),
        ),
      ),

      // ─── 卡片 ───
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        margin: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingSm),
        color: cardColor,
      ),

      // ─── AppBar ───
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: textOnDark,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: titleLarge,
          fontWeight: FontWeight.w600,
          color: textOnDark,
        ),
        toolbarHeight: 72,
      ),

      // ─── 底部导航 ───
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        selectedLabelStyle: TextStyle(fontSize: bodyMedium, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: bodyMedium, fontWeight: FontWeight.w400),
      ),

      // ─── ICON ───
      iconTheme: const IconThemeData(size: iconSize, color: primaryColor),
    );
  }
}
