import 'package:equatable/equatable.dart';

enum CategoryType {
  expense('EXPENSE'),
  income('INCOME');

  const CategoryType(this.dbValue);

  final String dbValue;

  static CategoryType fromDb(String value) => CategoryType.values.firstWhere(
        (CategoryType type) => type.dbValue == value,
        orElse: () => throw ArgumentError('Unknown category type: $value'),
      );
}

class Category extends Equatable {
  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.iconIdentifier,
    required this.colorHex,
    required this.sortOrder,
    this.isSystem = false,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final CategoryType type;
  final String iconIdentifier;
  final String colorHex;
  final int sortOrder;
  final bool isSystem;
  final bool isArchived;

  @override
  List<Object?> get props => <Object?>[
        id,
        name,
        type,
        iconIdentifier,
        colorHex,
        sortOrder,
        isSystem,
        isArchived,
      ];
}