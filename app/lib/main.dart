import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/theme.dart';
import 'screens/home/home_screen.dart';
import 'screens/medicines/medicines_screen.dart';
import 'screens/mall/mall_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/medicines/record_screen.dart';
import 'screens/profile/settings_screen.dart';
import 'screens/emergency/emergency_screen.dart';
import 'screens/auth/login_screen.dart';
import 'widgets/clay_icons/clay_icons.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BamabaoApp());
}

class BamabaoApp extends StatelessWidget {
  const BamabaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '爸妈宝',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
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
  }
}

/// 主屏幕 — 底部 Tab 导航（黏土泡泡图标）
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    MedicinesScreen(),
    MallScreen(),
    ProfileScreen(),
  ];

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
                isSelected ? Icons.shopping_bag : Icons.shopping_bag_outlined,
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
