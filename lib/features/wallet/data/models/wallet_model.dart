import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';

/// SQLite row mapping for [Wallet]. Keeps `sqflite` types out of the domain.
abstract final class WalletModel {
  static Wallet fromRow(Map<String, Object?> row) {
    return Wallet(
      id: row['id']! as String,
      name: row['name']! as String,
      accountType: AccountType.fromDb(row['account_type']! as String),
      iconIdentifier: row['icon_identifier']! as String,
      balance: Money(row['balance_minor']! as int),
      sortOrder: row['sort_order']! as int,
      isArchived: (row['is_archived']! as int) == 1,
      createdAt: fromEpochMillis(row['created_at_ms']! as int),
      updatedAt: fromEpochMillis(row['updated_at_ms']! as int),
    );
  }

  static Map<String, Object?> toRow(Wallet wallet) {
    return <String, Object?>{
      'id': wallet.id,
      'name': wallet.name,
      'account_type': wallet.accountType.dbValue,
      'icon_identifier': wallet.iconIdentifier,
      'balance_minor': wallet.balance.minorUnits,
      'sort_order': wallet.sortOrder,
      'is_archived': wallet.isArchived ? 1 : 0,
      'created_at_ms': epochMillis(wallet.createdAt),
      'updated_at_ms': epochMillis(wallet.updatedAt),
    };
  }
}