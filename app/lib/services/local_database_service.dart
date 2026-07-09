import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// 爸妈宝 — 本地 SQLite 数据库缓存服务
///
/// 离线缓存药品列表 + 打卡记录
/// 读取策略：先读本地 → 有网时后台异步更新
///
/// 数据表：
/// - medications_cache: 缓存药品列表
/// - logs_cache: 缓存打卡/用药记录
class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Database? _db;

  /// 获取或初始化数据库（惰性初始化）
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'bamabao_cache.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // 药品缓存表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS medications_cache (
            id INTEGER PRIMARY KEY,
            elder_id INTEGER NOT NULL DEFAULT 1,
            data TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');

        // 打卡/用药记录缓存表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS logs_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            elder_id INTEGER NOT NULL DEFAULT 1,
            data TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  药品缓存操作
  // ═══════════════════════════════════════════════════════════

  /// 保存药品列表到本地缓存
  Future<void> saveMedications(List<dynamic> medications, {int elderId = 1}) async {
    final db = await database;
    await db.transaction((txn) async {
      // 先清除该用户的旧缓存
      await txn.delete('medications_cache', where: 'elder_id = ?', whereArgs: [elderId]);

      // 逐条插入
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final med in medications) {
        final id = med['id'] as int? ?? 0;
        await txn.insert('medications_cache', {
          'id': id,
          'elder_id': elderId,
          'data': jsonEncode(med),
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// 读取缓存的药品列表
  Future<List<Map<String, dynamic>>> getMedications({int elderId = 1}) async {
    final db = await database;
    final rows = await db.query(
      'medications_cache',
      where: 'elder_id = ?',
      whereArgs: [elderId],
    );

    return rows.map((row) {
      return jsonDecode(row['data'] as String) as Map<String, dynamic>;
    }).toList();
  }

  /// 清除药品缓存
  Future<void> clearMedications({int? elderId}) async {
    final db = await database;
    if (elderId != null) {
      await db.delete('medications_cache', where: 'elder_id = ?', whereArgs: [elderId]);
    } else {
      await db.delete('medications_cache');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  打卡/用药记录缓存操作
  // ═══════════════════════════════════════════════════════════

  /// 保存打卡记录列表
  Future<void> saveLogs(List<dynamic> logs, {int elderId = 1}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('logs_cache', where: 'elder_id = ?', whereArgs: [elderId]);

      final now = DateTime.now().millisecondsSinceEpoch;
      for (final log in logs) {
        await txn.insert('logs_cache', {
          'elder_id': elderId,
          'data': jsonEncode(log),
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// 读取缓存的打卡记录列表
  Future<List<Map<String, dynamic>>> getLogs({int elderId = 1}) async {
    final db = await database;
    final rows = await db.query(
      'logs_cache',
      where: 'elder_id = ?',
      whereArgs: [elderId],
    );
    return rows.map((row) {
      return jsonDecode(row['data'] as String) as Map<String, dynamic>;
    }).toList();
  }

  /// 清除打卡记录缓存
  Future<void> clearLogs({int? elderId}) async {
    final db = await database;
    if (elderId != null) {
      await db.delete('logs_cache', where: 'elder_id = ?', whereArgs: [elderId]);
    } else {
      await db.delete('logs_cache');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  全表清理
  // ═══════════════════════════════════════════════════════════

  /// 清除所有缓存数据
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('medications_cache');
    await db.delete('logs_cache');
  }

  /// 获取缓存更新时间（最近一条记录的时间）
  Future<int?> getLastUpdateTime(int elderId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(updated_at) as max_time FROM medications_cache WHERE elder_id = ?',
      [elderId],
    );
    return result.first['max_time'] as int?;
  }

  /// 关闭数据库
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
