import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';

abstract final class TransactionModel {
  static TransactionRecord fromRow(Map<String, Object?> row) {
    return TransactionRecord(
      id: row['id']! as String,
      amount: Money(row['amount_minor']! as int),
      type: TransactionType.fromDb(row['transaction_type']! as String),
      sourceWalletId: row['source_wallet_id']! as String,
      targetWalletId: row['target_wallet_id'] as String?,
      categoryId: row['category_id'] as String?,
      occurredAt: fromEpochMillis(row['occurred_at_ms']! as int),
      localDate: row['local_date']! as String,
      note: row['note'] as String?,
      createdAt: fromEpochMillis(row['created_at_ms']! as int),
      updatedAt: fromEpochMillis(row['updated_at_ms']! as int),
    );
  }

  static Map<String, Object?> toRow(TransactionRecord record) {
    return <String, Object?>{
      'id': record.id,
      'amount_minor': record.amount.minorUnits,
      'transaction_type': record.type.dbValue,
      'source_wallet_id': record.sourceWalletId,
      'target_wallet_id': record.targetWalletId,
      'category_id': record.categoryId,
      'occurred_at_ms': epochMillis(record.occurredAt),
      'local_date': record.localDate,
      'note': record.note,
      'created_at_ms': epochMillis(record.createdAt),
      'updated_at_ms': epochMillis(record.updatedAt),
    };
  }
}