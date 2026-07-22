import 'package:flutter/material.dart';

/// 爸妈宝 — 黏土软萌主题配置 (v2)
/// 对标 3D 黏土 Logo：暖橙 #FF9F40 / 嫩绿 #76D160 / 浅薄荷底 #E6F7DD
/// 原则：适老尺寸不动（字号≥32px、按钮≥80px）
class AppTheme {
  // ─── 颜色 — 对标 Logo 色值 ───
  static const Color primaryColor = Color(0xFFFF9A3C); // 暖橙 — 设计稿标准色
  static const Color primaryLight = Color(0xFFFFB866);
  static const Color primaryDark = Color(0xFFE68A30);
  static const Color secondaryColor = Color(0xFF76D160); // 嫩绿 — 确认/完成/勾选
  static const Color warningColor = Color(0xFFE53935); // 红色 — 紧急/SOS
  static const Color dangerColor = warningColor; // 别名
  static const Color bgColor = Color(0xFFE8F5E0); // 淡薄荷绿 — 全局页面底色
  static const Color bgGradientTop = Color(0xFFE8F5E0); // 背景渐变顶部
  static const Color bgGradientBottom = Color(0xFFDCEFD0); // 背景渐变底部（稍深）
  static const Color cardColor = Color(0xFFFFFFFF); // 纯白 — 卡片/弹窗底色
  static const Color textPrimary = Color(0xFF1A1A1A); // 纯黑 — 药品名称
  static const Color textSecondary = Color(0xFF666666); // 中灰 — 正文
  static const Color textOnDark = Color(0xFFFFFBF5); // 柔和米白 — 按钮文字
  static const Color textGray = Color(0xFF666666); // 规格时间中灰
  static const Color textLightGray = Color(0xFF999999); // 副标题浅灰

  // 专用色
  static const Color recordCardBg = Color(0xFFD5EBCB); // 用药记录模块-抹茶绿（加深）
  static const Color recordCardText = Color(0xFF4A7A42); // 用药记录模块-深绿文字
  static const Color checkinUnchecked = Color(0xFFFF7A5C); // 打卡按钮未打卡-橙红圆环
  static const Color checkinUncheckedDark = Color(0xFFE56048); // 打卡按钮未打卡-暗部
  static const Color checkinChecked = Color(0xFF76D160); // 打卡按钮已打卡-嫩绿
  static const Color checkinCheckedDark = Color(0xFF5AB048); // 打卡按钮已打卡-暗部

  // ─── 字号 — 正常2倍 ───
  static const double displayLarge = 48;
  static const double displayMedium = 40;
  static const double headlineLarge = 36;
  static const double headlineMedium = 28;
  static const double titleLarge = 24;
  static const double titleMedium = 22;
  static const double bodyLarge = 20;
  static const double bodyMedium = 18;
  static const double bodySmall = 14;
  static const double labelLarge = 18;

  // ─── 间距 ───
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;

  // ─── 按钮尺寸 ───
  static const double buttonHeight = 80; // 适老规范 ≥80px
  static const double buttonMinWidth = 200;
  static const double iconSize = 32;

  // ─── 圆角 — 黏土椭圆大圆角 ───
  static const double radiusSm = 8;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusButton = 22;
  static const double radiusCard = 22;

  // ─── 阴影 — 柔和黏土悬浮阴影 ───
  static const Color shadowColor = Color(0xFF3A4437);
  // 柔和立体阴影 — 双层阴影模拟黏土立体感
  static List<BoxShadow> shadowCard = [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.15),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.08),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  static List<BoxShadow> shadowButton = [
    BoxShadow(
      color: const Color(0xFFFF9A3C).withValues(alpha: 0.45),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  static List<BoxShadow> shadowElevated = [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.14),
      blurRadius: 28,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.06),
      blurRadius: 6,
      offset: const Offset(0, 4),
    ),
  ];

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
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(buttonMinWidth, buttonHeight),
          backgroundColor: primaryColor,
          foregroundColor: textOnDark,
          elevation: 4,
          shadowColor: const Color(0xFFFF9A3C).withValues(alpha: 0.30),
          textStyle: const TextStyle(
            fontSize: titleMedium,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                color: Color(0xFF3A4437),
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
          padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingMd),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        shadowColor: const Color(0xFF3A4437).withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusCard)),
        margin: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingSm),
        color: cardColor,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: textOnDark,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 3,
        titleTextStyle: TextStyle(
          fontSize: titleLarge,
          fontWeight: FontWeight.w600,
          color: textOnDark,
        ),
        toolbarHeight: 72,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        selectedLabelStyle: TextStyle(fontSize: bodyMedium, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: bodyMedium, fontWeight: FontWeight.w400),
        elevation: 8,
      ),
      iconTheme: const IconThemeData(size: iconSize, color: primaryColor),
    );
  }
}
