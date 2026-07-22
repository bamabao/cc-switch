import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../widgets/medicine_checkin_card.dart';
import '../medicines/medicines_screen.dart';
import '../medicines/add_medicine_screen.dart';
import '../medicines/record_screen.dart';
import '../medicines/medicine_detail_screen.dart';
import '../profile/settings_screen.dart';

/// 首页 — 完全对齐设计稿
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _greeting = '早上好！';
  final ValueNotifier<int> _medicationCountNotifier = ValueNotifier<int>(4);
  List<dynamic> _checkinItems = [];

  @override
  void initState() {
    super.initState();
    _updateGreeting();
    _checkinItems = [
      {
        'medication_id': 1, 'name': '阿莫西林',
        'dosage_per_take': 1, 'unit': '粒',
        'total_slots': 1, 'checked_slots': 0,
        'schedules': [
          {'schedule_id': 101, 'time': '08:00', 'checked': false, 'dosage': 1, 'dosage_display': '1粒'},
        ],
      },
      {
        'medication_id': 2, 'name': '氨氯地平',
        'dosage_per_take': 1, 'unit': '片',
        'total_slots': 2, 'checked_slots': 2,
        'schedules': [
          {'schedule_id': 102, 'time': '08:00', 'checked': true, 'dosage': 1, 'dosage_display': '1片'},
          {'schedule_id': 103, 'time': '18:00', 'checked': true, 'dosage': 0.5, 'dosage_display': '0.5片'},
        ],
      },
      {
        'medication_id': 3, 'name': '二甲双胍',
        'dosage_per_take': 0.5, 'unit': '片',
        'total_slots': 1, 'checked_slots': 0,
        'schedules': [
          {'schedule_id': 104, 'time': '12:00', 'checked': false, 'dosage': 0.5, 'dosage_display': '0.5片'},
        ],
      },
      {
        'medication_id': 4, 'name': '阿托伐他汀',
        'dosage_per_take': 10, 'unit': 'mg',
        'total_slots': 1, 'checked_slots': 1,
        'schedules': [
          {'schedule_id': 105, 'time': '20:00', 'checked': true, 'dosage': 10, 'dosage_display': '10mg'},
        ],
      },
    ];
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = '早上好！';
    } else if (hour < 18) {
      _greeting = '下午好！';
    } else {
      _greeting = '晚上好！';
    }
  }

  @override
  void dispose() {
    _medicationCountNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Mock — UI demo mode
  }

  void _handleCheckinTap(dynamic item, int scheduleIndex) {
    final schedules = item['schedules'] as List<dynamic>;
    if (scheduleIndex >= schedules.length) return;
    final schedule = schedules[scheduleIndex];
    final currentlyChecked = schedule['checked'] as bool;

    schedule['checked'] = !currentlyChecked;
    if (currentlyChecked) {
      item['checked_slots'] = (item['checked_slots'] as int) - 1;
    } else {
      item['checked_slots'] = (item['checked_slots'] as int) + 1;
    }
    _medicationCountNotifier.value = _checkinItems.where((i) {
      final slots = i['schedules'] as List<dynamic>;
      return slots.any((s) => s['checked'] == false);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.bgGradientTop,
              AppTheme.bgGradientBottom,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildTopBar(context),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    _buildGreetingCard(context),
                    const SizedBox(height: 12),
                    _buildRecordCard(context),
                    const SizedBox(height: 12),
                    // 今日用药区域标题
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '今日用药',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(width: 10),
                    const Text(
                            '共 4 种药品',
                            style: TextStyle(
                              fontSize: 20,
                              color: AppTheme.textLightGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ..._buildCheckinCards(context),
                    const SizedBox(height: 16),
                    _buildBottomButtons(context),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 50),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部暖橙色栏 — 扁胶囊 + 3D立体光泽文字
  Widget _buildTopBar(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        bottom: 2,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryLight,
            AppTheme.primaryColor,
            AppTheme.primaryDark,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          // 顶部细高光边（黏土凸起感）
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.6),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
          // 左上内高光（立体弧面）
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(-2, -2),
          ),
          // 主下沉阴影（悬浮感）
          BoxShadow(
            color: AppTheme.primaryDark.withValues(alpha: 0.55),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
          // 底部深色阴影（厚度感）
          BoxShadow(
            color: AppTheme.primaryDark.withValues(alpha: 0.40),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
          // 右下重阴影（黏土挤压感）
          BoxShadow(
            color: const Color(0xFFCC7020).withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(3, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 40),
          const Spacer(),
          // 3D 立体光泽文字（多层叠加）
          Stack(
            children: [
              // 深色阴影层（深度）
              Transform.translate(
                offset: const Offset(2, 3.5),
                child: Text(
                  '爸妈宝',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryDark.withValues(alpha: 0.5),
                  ),
                ),
              ),
              // 中层阴影
              Transform.translate(
                offset: const Offset(1, 1.5),
                child: Text(
                  '爸妈宝',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryDark.withValues(alpha: 0.3),
                  ),
                ),
              ),
              // 主体文字 + 顶部光泽
              Text(
                '爸妈宝',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textOnDark,
                  shadows: [
                    // 顶部高光（浮雕凸起光泽）
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.5),
                      offset: const Offset(0, -0.8),
                      blurRadius: 1,
                    ),
                    // 左上光泽
                    Shadow(
                      color: Colors.white.withValues(alpha: 0.3),
                      offset: const Offset(-0.5, -0.5),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.settings, size: 20, color: AppTheme.textOnDark),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              tooltip: '设置',
            ),
          ),
        ],
      ),
    );
  }

  /// 问候卡片 — 淡绿色浮雕立体风格
  Widget _buildGreetingCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E0), // 淡薄荷绿
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF0FAEA),
            Color(0xFFE0F0D6),
          ],
        ),
        boxShadow: [
          // 顶部高光（浮雕凸起）
          BoxShadow(
            color: Colors.white, // white full alpha for top edge
            blurRadius: 2,
            offset: Offset(0, -1),
          ),
          // 左上高光
          BoxShadow(
            color: Color(0x80FFFFFF),
            blurRadius: 6,
            offset: Offset(-1, -1),
          ),
          // 主下沉阴影（悬浮感）
          BoxShadow(
            color: Color(0x598BB578),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
          // 底部深色阴影（厚度）
          BoxShadow(
            color: Color(0x406B9458),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _greeting,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          ValueListenableBuilder<int>(
            valueListenable: _medicationCountNotifier,
            builder: (context, count, child) {
              return Text(
                count > 0
                    ? '今天有 $count 种药需要服用'
                    : '还没有添加药品哦',
                style: const TextStyle(
                  fontSize: 22,
                  color: Color(0xFFE53935),
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 用药记录区：绿色胶囊按钮（去掉上面的大标题）
  Widget _buildRecordCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 绿色胶囊按钮
        Container(
          decoration: BoxDecoration(
            color: AppTheme.recordCardBg,
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.recordCardBg,
                AppTheme.recordCardBg.withValues(
                  red: (AppTheme.recordCardBg.red * 0.92).toDouble(),
                  green: (AppTheme.recordCardBg.green * 0.92).toDouble(),
                  blue: (AppTheme.recordCardBg.blue * 0.92).toDouble(),
                ),
              ],
            ),
            boxShadow: [
              // 顶部高光
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.6),
                blurRadius: 1,
                offset: const Offset(0, -1),
              ),
              // 主下沉阴影
              BoxShadow(
                color: const Color(0xFF4A7A42).withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
              // 底部阴影
              BoxShadow(
                color: const Color(0xFF4A7A42).withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecordScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Text(
                    '用药记录',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '"查看历史用药情况"',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    size: 24,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 底部双按钮 — 黏土3D立体风格
  Widget _buildBottomButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MedicinesScreen()),
                );
              },
              child: _build3DButton(
                icon: Icons.medication_outlined,
                text: '今日用药',
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final added = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
                );
                if (added == true) _loadData();
              },
              child: _build3DButton(
                icon: Icons.add_circle_outline,
                text: '添加药品',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3D 立体黏土按钮
  Widget _build3DButton({required IconData icon, required String text}) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryLight,
            AppTheme.primaryColor,
            AppTheme.primaryDark,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        boxShadow: [
          // 顶部高光边（凸起感）
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.6),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
          // 左上高光
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(-1, -1),
          ),
          // 主下沉大阴影（悬浮感）
          BoxShadow(
            color: AppTheme.primaryDark.withValues(alpha: 0.50),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          // 底部深阴影（厚度感）
          BoxShadow(
            color: AppTheme.primaryDark.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          // 右下重阴影（黏土挤压）
          BoxShadow(
            color: const Color(0xFFCC7020).withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(3, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.textOnDark, size: 26),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppTheme.textOnDark,
            ),
          ),
        ],
      ),
    );
  }

  /// 药品卡片列表 — 展示每时段独立剂量 + 时间
  List<Widget> _buildCheckinCards(BuildContext context) {
    return _checkinItems.map((item) {
      final medicationId = item['medication_id'] as int;
      final name = item['name'] as String? ?? '';
      final schedules = item['schedules'] as List<dynamic>? ?? [];
      final totalSlots = item['total_slots'] as int? ?? 0;
      final checkedSlots = item['checked_slots'] as int? ?? 0;

      // 使用时段的 dosage_display + time 构建剂量信息
      // 例如：「1粒 08:00 | 0.5片 18:00」
      final doseInfo = schedules.map((s) {
        final time = s['time'] as String? ?? '';
        final doseDisplay = s['dosage_display'] as String? ?? '';
        if (doseDisplay.isNotEmpty && time.isNotEmpty) {
          return '$doseDisplay  $time';
        } else if (doseDisplay.isNotEmpty) {
          return doseDisplay;
        }
        return time;
      }).join(' | ');

      // 全部已打卡 = 绿色
      final allDone = totalSlots > 0 && checkedSlots >= totalSlots;

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: MedicineCheckinCard(
          medicationId: medicationId,
          medicationName: name,
          doseInfo: doseInfo,
          initialChecked: allDone,
          onCheckinChanged: (checked) {
            _handleCheckinTap(item, 0);
          },
          onDetailTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MedicineDetailScreen(
                  medicationId: medicationId,
                  medicationName: name,
                ),
              ),
            );
          },
        ),
      );
    }).toList();
  }
}
