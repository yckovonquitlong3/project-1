import 'package:multi_wallet_tracker/features/category/data/category_model.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:sqflite/sqflite.dart';

class CategoryDao {
  const CategoryDao();

  static const String table = 'categories';

  Future<List<Category>> all(
    DatabaseExecutor db, {
    bool includeArchived = false,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      table,
      where: includeArchived ? null : 'is_archived = 0',
      orderBy: 'type ASC, sort_order ASC, name ASC',
    );
    return rows.map(CategoryModel.fromRow).toList(growable: false);
  }

  Future<List<Category>> byType(
    DatabaseExecutor db,
    CategoryType type, {
    bool includeArchived = false,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      table,
      where: includeArchived ? 'type = ?' : 'type = ? AND is_archived = 0',
      whereArgs: <Object?>[type.dbValue],
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(CategoryModel.fromRow).toList(growable: false);
  }

  Future<Category?> byId(DatabaseExecutor db, String id) async {
    final List<Map<String, Object?>> rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return CategoryModel.fromRow(rows.first);
  }
}