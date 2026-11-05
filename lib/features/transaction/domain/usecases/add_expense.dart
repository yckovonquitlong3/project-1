import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/entry_use_case.dart';

final class AddExpense extends EntryUseCase {
  AddExpense({
    required super.transactions,
    required super.wallets,
    required super.categories,
    super.uuid,
    super.clock,
  }) : super(
          type: TransactionType.expense,
          categoryType: CategoryType.expense,
        );
}
