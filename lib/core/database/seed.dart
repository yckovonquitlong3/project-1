import 'package:sqflite/sqflite.dart';

/// Reserved category used for the opening balance of a new wallet.
const String kOpeningBalanceCategoryId = 'cat-income-opening-balance';

class SeedCategory {
  const SeedCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.sortOrder,
    this.isSystem = false,
  });

  final String id;
  final String name;
  final String type;
  final String icon;
  final String color;
  final int sortOrder;
  final bool isSystem;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'name': name,
        'type': type,
        'icon_identifier': icon,
        'color_hex': color,
        'is_system': isSystem ? 1 : 0,
        'is_archived': 0,
        'sort_order': sortOrder,
      };
}

const List<SeedCategory> kSeedCategories = <SeedCategory>[
  SeedCategory(id: 'cat-exp-groceries', name: 'Groceries', type: 'EXPENSE', icon: 'shopping_basket', color: '#4CAF50', sortOrder: 1),
  SeedCategory(id: 'cat-exp-transportation', name: 'Transportation', type: 'EXPENSE', icon: 'directions_bus', color: '#2196F3', sortOrder: 2),
  SeedCategory(id: 'cat-exp-utilities', name: 'Utilities', type: 'EXPENSE', icon: 'bolt', color: '#FF9800', sortOrder: 3),
  SeedCategory(id: 'cat-exp-food-dining', name: 'Food & Dining', type: 'EXPENSE', icon: 'restaurant', color: '#F44336', sortOrder: 4),
  SeedCategory(id: 'cat-exp-education', name: 'School/Education', type: 'EXPENSE', icon: 'school', color: '#3F51B5', sortOrder: 5),
  SeedCategory(id: 'cat-exp-online-shopping', name: 'Online Shopping', type: 'EXPENSE', icon: 'shopping_cart', color: '#9C27B0', sortOrder: 6),
  SeedCategory(id: 'cat-exp-subscriptions', name: 'Subscriptions', type: 'EXPENSE', icon: 'autorenew', color: '#607D8B', sortOrder: 7),
  SeedCategory(id: 'cat-exp-entertainment', name: 'Entertainment', type: 'EXPENSE', icon: 'movie', color: '#E91E63', sortOrder: 8),
  SeedCategory(id: 'cat-exp-miscellaneous', name: 'Miscellaneous', type: 'EXPENSE', icon: 'more_horiz', color: '#795548', sortOrder: 9),
  SeedCategory(id: 'cat-inc-salary', name: 'Salary', type: 'INCOME', icon: 'work', color: '#00897B', sortOrder: 1),
  SeedCategory(id: 'cat-inc-allowance', name: 'Allowance', type: 'INCOME', icon: 'wallet', color: '#43A047', sortOrder: 2),
  SeedCategory(id: 'cat-inc-freelance', name: 'Freelance/Side Hustle', type: 'INCOME', icon: 'laptop', color: '#1E88E5', sortOrder: 3),
  SeedCategory(id: 'cat-inc-selling', name: 'Selling', type: 'INCOME', icon: 'storefront', color: '#FB8C00', sortOrder: 4),
  SeedCategory(id: 'cat-inc-gifts', name: 'Gifts', type: 'INCOME', icon: 'card_giftcard', color: '#8E24AA', sortOrder: 5),
  SeedCategory(id: kOpeningBalanceCategoryId, name: 'Opening Balance', type: 'INCOME', icon: 'account_balance', color: '#546E7A', sortOrder: 99, isSystem: true),
];

/// Inserts the default categories. Safe to call more than once: existing rows
/// are ignored by primary key and by the (name, type) unique index.
Future<void> seedCategories(DatabaseExecutor db) async {
  final Batch batch = db.batch();
  for (final SeedCategory category in kSeedCategories) {
    batch.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
  await batch.commit(noResult: true);
}