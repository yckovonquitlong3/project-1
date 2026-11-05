import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/category/domain/repositories/category_repository.dart';

final class GetCategories {
  const GetCategories({required CategoryRepository categories})
      : _categoryRepo = categories;

  final CategoryRepository _categoryRepo;

  Future<List<Category>> call(
    CategoryType type, {
    bool includeArchived = false,
  }) =>
      _categoryRepo.byType(type, includeArchived: includeArchived);
}
