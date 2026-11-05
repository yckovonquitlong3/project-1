import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';

abstract final class CategoryModel {
  static Category fromRow(Map<String, Object?> row) {
    return Category(
      id: row['id']! as String,
      name: row['name']! as String,
      type: CategoryType.fromDb(row['type']! as String),
      iconIdentifier: row['icon_identifier']! as String,
      colorHex: row['color_hex']! as String,
      sortOrder: row['sort_order']! as int,
      isSystem: (row['is_system']! as int) == 1,
      isArchived: (row['is_archived']! as int) == 1,
    );
  }
}