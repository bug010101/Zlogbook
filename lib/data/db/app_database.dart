import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zlogbook/core/app_info.dart';
import 'package:zlogbook/core/utils/ids.dart';

/// 数据库连接与建表、快照管理。全应用只有这一个连接入口。
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const int schemaVersion = 1;

  Database? _db;
  Directory? _rootDir;

  /// 桌面端需要先注册 FFI 工厂；Android / iOS 用系统自带引擎。
  static void initFactory() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Directory> rootDir() async {
    final Directory? cached = _rootDir;
    if (cached != null) {
      return cached;
    }
    final Directory dir = await getApplicationSupportDirectory();
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    _rootDir = dir;
    return dir;
  }

  Future<String> databasePath() async {
    final Directory dir = await rootDir();
    return p.join(dir.path, AppInfo.dbFileName);
  }

  Future<Database> open() async {
    final Database? existing = _db;
    if (existing != null) {
      return existing;
    }
    final String path = await databasePath();
    final Database db = await openDatabase(
      path,
      version: schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
    _db = db;
    return db;
  }

  /// 仓储层通过它拿连接，避免每个 DAO 各自开库。
  Future<Database> get database => open();

  Future<void> close() async {
    final Database? db = _db;
    _db = null;
    await db?.close();
  }

  static Future<void> _onCreate(Database db, int version) async {
    final Batch batch = db.batch();
    for (final String statement in _schemaStatements) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(Database db, int from, int to) async {
    // 版本 1 为初始版本，后续升级在这里按 from 递增补齐迁移语句。
    if (from < 1) {
      await _onCreate(db, to);
    }
  }

  static const List<String> _schemaStatements = <String>[
    '''
    CREATE TABLE folders (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      icon TEXT,
      color TEXT,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE records (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      folder_id TEXT,
      status TEXT NOT NULL DEFAULT 'active',
      importance INTEGER NOT NULL DEFAULT 3,
      notes TEXT,
      url TEXT,
      value REAL,
      expires_at TEXT,
      tags TEXT,
      logins_json TEXT NOT NULL DEFAULT '[]',
      extra_json TEXT NOT NULL DEFAULT '{}',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted_at TEXT
    )
    ''',
    'CREATE INDEX idx_records_folder ON records(folder_id)',
    'CREATE INDEX idx_records_deleted ON records(deleted_at)',
    '''
    CREATE TABLE identities (
      id TEXT PRIMARY KEY,
      kind TEXT NOT NULL,
      value TEXT NOT NULL,
      label TEXT,
      status TEXT NOT NULL DEFAULT 'active',
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE field_defs (
      id TEXT PRIMARY KEY,
      key TEXT NOT NULL,
      label TEXT NOT NULL,
      kind TEXT NOT NULL DEFAULT 'text',
      options TEXT,
      scope_type TEXT NOT NULL DEFAULT 'all',
      scope_folder_id TEXT,
      sort_order INTEGER NOT NULL DEFAULT 0
    )
    ''',
    '''
    CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT
    )
    ''',
  ];

  // -------------------------------------------------------------- 快照

  Future<Directory> snapshotDir() async {
    final Directory root = await rootDir();
    final Directory dir = Directory(p.join(root.path, 'snapshots'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 落库前的数据库文件快照，保留最近 [keep] 份。
  Future<File> createSnapshot({String reason = 'manual', int keep = 5}) async {
    final Database db = await open();
    try {
      await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {
      // 非 WAL 模式下该语句无意义，忽略。
    }
    final Directory dir = await snapshotDir();
    final String sourcePath = await databasePath();
    final String tag = reason.replaceAll(RegExp(r'[^\w-]'), '_');
    final File target = File(
      p.join(dir.path, '${timestampForFileName(DateTime.now())}-$tag.db'),
    );
    await File(sourcePath).copy(target.path);
    await _trimSnapshots(keep);
    return target;
  }

  Future<List<File>> listSnapshots() async {
    final Directory dir = await snapshotDir();
    final List<File> files = dir
        .listSync()
        .whereType<File>()
        .where((File file) => file.path.endsWith('.db'))
        .toList();
    files.sort((File a, File b) => b.path.compareTo(a.path));
    return files;
  }

  /// 删除单份快照。文件已不存在或正被占用都不算失败。
  Future<void> deleteSnapshot(File snapshot) async {
    try {
      if (snapshot.existsSync()) {
        await snapshot.delete();
      }
    } catch (_) {
      // 占用中或已删除，忽略。
    }
  }

  Future<void> _trimSnapshots(int keep) async {
    final List<File> files = await listSnapshots();
    for (int i = keep; i < files.length; i++) {
      try {
        await files[i].delete();
      } catch (_) {
        // 清理失败不影响主流程。
      }
    }
  }

  /// 用快照覆盖当前数据库并重新打开连接。
  Future<void> restoreSnapshot(File snapshot) async {
    await close();
    final String target = await databasePath();
    await snapshot.copy(target);
    // 快照可能带 WAL 残留，删除旁路文件避免读到旧页。
    for (final String suffix in <String>['-wal', '-shm']) {
      final File side = File('$target$suffix');
      if (side.existsSync()) {
        await side.delete();
      }
    }
    await open();
  }
}
