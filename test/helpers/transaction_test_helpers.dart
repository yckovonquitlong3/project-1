import 'package:mocktail/mocktail.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/category/domain/repositories/category_repository.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/add_expense.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/add_income.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/delete_transaction.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/edit_transaction.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/get_recent_transaction_records.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/transfer_money.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/cubit/transaction_cubit.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/cubit/transaction_list_cubit.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';

class MockTransactionRepository extends Mock
    implements TransactionRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

Category categoryFixture({
  String id = 'cat-exp-food-dining',
  String name = 'Food & Dining',
  CategoryType type = CategoryType.expense,
  bool isArchived = false,
}) {
  return Category(
    id: id,
    name: name,
    type: type,
    iconIdentifier: 'restaurant',
    colorHex: '#F44336',
    sortOrder: 1,
    isArchived: isArchived,
  );
}

TransactionRecord recordFixture({
  String id = 'tx-1',
  TransactionType type = TransactionType.expense,
  int amountMinor = 15000,
  String sourceWalletId = 'w1',
  String? targetWalletId,
  String? categoryId = 'cat-exp-food-dining',
  String? note,
}) {
  final DateTime when = DateTime(2026, 11, 5, 10);
  return TransactionRecord(
    id: id,
    amount: Money(amountMinor),
    type: type,
    sourceWalletId: sourceWalletId,
    targetWalletId: targetWalletId,
    categoryId: categoryId,
    occurredAt: when,
    localDate: localDateOf(when),
    note: note,
    createdAt: when,
    updatedAt: when,
  );
}

TransactionCubit buildTransactionCubit({
  required TransactionRepository transactions,
  required WalletRepository wallets,
  required CategoryRepository categories,
}) {
  return TransactionCubit(
    addExpense: AddExpense(
      transactions: transactions,
      wallets: wallets,
      categories: categories,
    ),
    addIncome: AddIncome(
      transactions: transactions,
      wallets: wallets,
      categories: categories,
    ),
    transferMoney: TransferMoney(transactions: transactions, wallets: wallets),
    editTransaction: EditTransaction(
      transactions: transactions,
      wallets: wallets,
      categories: categories,
    ),
    deleteTransaction: DeleteTransaction(transactions: transactions),
  );
}

TransactionListCubit buildTransactionListCubit({
  required TransactionRepository transactions,
  LedgerBus? ledgerBus,
}) {
  return TransactionListCubit(
    getRecentTransactions: GetRecentTransactionRecords(
      transactions: transactions,
    ),
    ledgerBus: ledgerBus ?? LedgerBus(),
  );
}
