import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';

abstract interface class CategoryRepository {
  Future<List<Category>> all({bool includeArchived = false});

  Future<List<Category>> byType(
    CategoryType type, {
    bool includeArchived = false,
  });

  Future<Category?> byId(String id);
}
