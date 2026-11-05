import 'package:multi_wallet_tracker/core/database/app_database.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/features/category/data/category_dao.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/category/domain/repositories/category_repository.dart';
import 'package:sqflite/sqflite.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl({
    required AppDatabase database,
    CategoryDao categoryDao = const CategoryDao(),
  })  : _db = database,
        _dao = categoryDao;

  final AppDatabase _db;
  final CategoryDao _dao;

  @override
  Future<List<Category>> all({bool includeArchived = false}) async {
    final Database db = await _db.database;
    try {
      return await _dao.all(db, includeArchived: includeArchived);
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not load categories', cause: error);
    }
  }

  @override
  Future<List<Category>> byType(
    CategoryType type, {
    bool includeArchived = false,
  }) async {
    final Database db = await _db.database;
    try {
      return await _dao.byType(
        db,
        type,
        includeArchived: includeArchived,
      );
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not load categories', cause: error);
    }
  }

  @override
  Future<Category?> byId(String id) async {
    final Database db = await _db.database;
    try {
      return await _dao.byId(db, id);
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not load the category', cause: error);
    }
  }
}
