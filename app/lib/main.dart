import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config/theme.dart';
import 'config/api_config.dart';
import 'services/api_service.dart';
import 'screens/home/home_screen.dart';
import 'screens/medicines/medicines_screen.dart';
import 'screens/mall/mall_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/medicines/record_screen.dart';
import 'screens/profile/settings_screen.dart';
import 'screens/emergency/emergency_screen.dart';
import 'screens/auth/login_screen.dart';
import 'widgets/clay_icons/clay_icons.dart';
import 'services/notification_service.dart';
import 'services/font_scale_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化本地通知（精确闹钟+开机恢复）
  await NotificationService.instance.init();
  // 读取长辈模式设置
  await FontScaleController.instance.load();
  runApp(const BamabaoApp());
}

class BamabaoApp extends StatelessWidget {
  const BamabaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: FontScaleController.instance.scale,
      builder: (context, scale, _) {
        return MaterialApp(
          title: '爸妈宝',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          builder: (context, child) {
            // 应用全局字号倍率（长辈模式）
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            );
          },
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
          home: const MainScreen(), // TEMP: show home for review
          routes: {
            '/home': (_) => const MainScreen(),
            '/record': (_) => const RecordScreen(),
            '/settings': (_) => const SettingsScreen(),
            '/emergency': (_) => const EmergencyScreen(),
          },
        );
      },
    );
  }
}

/// 主屏幕 — 底部 Tab 导航（黏土泡泡图标）
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ApiService _api = ApiService();
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    MedicinesScreen(),
    MallScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    try {
      const currentVersion = '3.9'; // 当前版本号，发版时更新
      final resp = await _api.get(ApiConfig.appVersion);
      final latestVersion = resp['version'] as String? ?? '';
      if (latestVersion.isEmpty || latestVersion == currentVersion) return;
      
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.system_update, color: AppTheme.primaryColor, size: 28),
              SizedBox(width: 10),
              Expanded(child: Text('发现新版本', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('当前版本: $currentVersion  →  最新版本: $latestVersion',
                      style: const TextStyle(fontSize: 15, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Text(resp['update_log'] as String? ?? '',
                      style: const TextStyle(fontSize: 14, height: 1.5, color: AppTheme.textSecondary)),
                ],
              ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('稍后再说', style: TextStyle(fontSize: 17)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                final url = resp['download_url'] as String? ?? ApiConfig.baseUrl;
                // 用浏览器打开下载页
                launchUrl(Uri.parse(url));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('立即更新', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } catch (_) {
      // 版本检查失败不阻塞app启动
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: EdgeInsets.only(
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navItem(0, ClayIconType.home, '首页',
              isClay: true, isMall: false),
          _navItem(1, ClayIconType.medicine, '药品',
              isClay: true, isMall: false),
          _navItem(2, ClayIconType.medicine, '商城',
              isClay: false, isMall: true),
          _navItem(3, ClayIconType.profile, '我的',
              isClay: true, isMall: false),
        ],
      ),
    );
  }

  Widget _navItem(int index, ClayIconType clayType, String label,
      {required bool isClay, required bool isMall}) {
    final isSelected = index == _currentIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isClay)
              ClayBubbleIcon(
                type: clayType,
                size: 36,
                cornerRadius: 10,
                animationIntensity: isSelected
                    ? ClayAnimationIntensity.full
                    : ClayAnimationIntensity.subtle,
                iconColorOverride: isSelected ? null : const Color(0xFF999999),
                bgColorOverride:
                    isSelected ? null : const Color(0xFFF0F0F0),
              )
            else
              Icon(
                isSelected ? Icons.local_mall : Icons.local_mall_outlined,
                size: 32,
                color: isSelected ? ClayColors.orange : const Color(0xFF999999),
              ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppTheme.primaryColor : const Color(0xFF999999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
