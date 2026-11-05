import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'migrations.dart';
import 'seed.dart';

/// Owns the single SQLite connection for the app.
///
/// Tests pass an in-memory [dbFactory] and [path] so the real schema is
/// exercised without touching device storage.
class AppDatabase {
  AppDatabase({DatabaseFactory? dbFactory, String? path})
      : _dbFactory = dbFactory ?? databaseFactory,
        _overridePath = path;

  static const String fileName = 'multi_wallet_tracker.db';

  final DatabaseFactory _dbFactory;
  final String? _overridePath;
  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final String dbPath =
        _overridePath ?? p.join(await _dbFactory.getDatabasesPath(), fileName);
    return _dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: kSchemaVersion,
        onConfigure: (Database db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (Database db, int version) async {
          await createSchemaV1(db);
          await seedCategories(db);
        },
        onUpgrade: migrate,
      ),
    );
  }

  Future<void> close() async {
    final Database? db = _database;
    _database = null;
    await db?.close();
  }
}