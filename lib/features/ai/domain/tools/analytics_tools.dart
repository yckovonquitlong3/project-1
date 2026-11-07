import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_chat.dart';
import 'package:multi_wallet_tracker/features/ai/domain/quick_entry_matcher.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/category/domain/repositories/category_repository.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/month_summary.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';

/// Read-only tools over aggregate data. No raw rows, no SQL, no writes.
class AnalyticsTools {
  const AnalyticsTools({
    required DashboardRepository dashboard,
    required WalletRepository wallets,
    required CategoryRepository categories,
  })  : _dashboardRepo = dashboard,
        _walletRepo = wallets,
        _categoryRepo = categories;

  static const List<AiToolDefinition> definitions = <AiToolDefinition>[
    AiToolDefinition(
      name: 'get_category_spending',
      description: 'Total expense in one category over an inclusive local-date '
          'range. The range may not exceed 366 days. Archived expense '
          'categories are included so historical totals remain available.',
      parameters: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'category_name': <String, Object?>{
            'type': 'string',
            'description': 'Expense category name, e.g. Food & Dining.',
          },
          'start_date': <String, Object?>{
            'type': 'string',
            'description': 'Inclusive start date, YYYY-MM-DD.',
          },
          'end_date': <String, Object?>{
            'type': 'string',
            'description': 'Inclusive end date, YYYY-MM-DD.',
          },
        },
        'required': <String>['category_name', 'start_date', 'end_date'],
        'additionalProperties': false,
      },
    ),
    AiToolDefinition(
      name: 'get_wallet_balances',
      description: 'Current balances for active wallets and archived wallets '
          'with a non-zero balance. Includes total net worth.',
      parameters: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{},
        'additionalProperties': false,
      },
    ),
    AiToolDefinition(
      name: 'get_monthly_summary',
      description: 'Income, expense (including transfer fees), fees, and net '
          'for one calendar month.',
      parameters: <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'year': <String, Object?>{'type': 'integer'},
          'month': <String, Object?>{'type': 'integer', 'minimum': 1, 'maximum': 12},
        },
        'required': <String>['year', 'month'],
        'additionalProperties': false,
      },
    ),
  ];

  final DashboardRepository _dashboardRepo;
  final WalletRepository _walletRepo;
  final CategoryRepository _categoryRepo;

  Future<Map<String, Object?>> execute({
    required String name,
    required Map<String, Object?> arguments,
  }) async {
    try {
      switch (name) {
        case 'get_category_spending':
          return await _categorySpending(arguments);
        case 'get_wallet_balances':
          return await _walletBalances();
        case 'get_monthly_summary':
          return await _monthlySummary(arguments);
        default:
          return _error('Unknown tool: $name');
      }
    } on Failure catch (failure) {
      return _error(failure.message);
    }
  }

  Future<Map<String, Object?>> _categorySpending(
    Map<String, Object?> arguments,
  ) async {
    final String? name = _stringArg(arguments, 'category_name');
    final String? startText = _stringArg(arguments, 'start_date');
    final String? endText = _stringArg(arguments, 'end_date');
    if (name == null || startText == null || endText == null) {
      return _error('category_name, start_date, and end_date are required');
    }
    final DateTime? start = _parseDate(startText);
    final DateTime? end = _parseDate(endText);
    if (start == null || end == null) {
      return _error('Dates must be YYYY-MM-DD');
    }
    final int days = end.difference(start).inDays;
    if (days < 0) {
      return _error('end_date must be on or after start_date');
    }
    if (days > 365) {
      return _error('The date range may not exceed 366 days');
    }

    final List<Category> categories = await _categoryRepo.byType(
      CategoryType.expense,
      includeArchived: true,
    );
    final String? categoryId = matchLocalName(
      name,
      categories.map(
        (Category category) => (id: category.id, name: category.name),
      ),
    );
    if (categoryId == null) {
      return _error('No unique expense category matched "$name"');
    }
    final Category category = categories.firstWhere(
      (Category item) => item.id == categoryId,
    );
    final Money total = await _dashboardRepo.categorySpending(
      categoryId: category.id,
      startDate: startText,
      endDate: endText,
    );

    return <String, Object?>{
      'category': category.name,
      'start_date': startText,
      'end_date': endText,
      'total_minor': total.minorUnits,
      'total_formatted': total.format(),
    };
  }

  Future<Map<String, Object?>> _walletBalances() async {
    final List<Wallet> wallets =
        await _walletRepo.all(includeArchived: true);
    var totalMinor = 0;
    final List<Map<String, Object?>> items = <Map<String, Object?>>[];
    for (final Wallet wallet in wallets) {
      totalMinor += wallet.balance.minorUnits;
      if (wallet.isArchived && !wallet.balance.isPositive) {
        continue;
      }
      items.add(<String, Object?>{
        'name': wallet.name,
        'balance_minor': wallet.balance.minorUnits,
        'balance_formatted': wallet.balance.format(),
        'archived': wallet.isArchived,
      });
    }
    final Money total = Money(totalMinor);
    return <String, Object?>{
      'wallets': items,
      'net_worth_minor': total.minorUnits,
      'net_worth_formatted': total.format(),
    };
  }

  Future<Map<String, Object?>> _monthlySummary(
    Map<String, Object?> arguments,
  ) async {
    final int? year = _intArg(arguments, 'year');
    final int? month = _intArg(arguments, 'month');
    if (year == null || month == null) {
      return _error('year and month are required');
    }
    if (year < 2000 || year > 2100 || month < 1 || month > 12) {
      return _error('Invalid year or month');
    }
    final MonthSummary summary =
        await _dashboardRepo.monthSummary(DateTime(year, month));
    return <String, Object?>{
      'year': year,
      'month': month,
      'income_minor': summary.income.minorUnits,
      'expense_minor': summary.expense.minorUnits,
      'fees_minor': summary.fees.minorUnits,
      'net_minor': summary.net.minorUnits,
      'income_formatted': summary.income.format(),
      'expense_formatted': summary.expense.format(),
      'fees_formatted': summary.fees.format(),
      'net_formatted': summary.net.format(),
    };
  }

  DateTime? _parseDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  String? _stringArg(Map<String, Object?> arguments, String key) {
    final Object? value = arguments[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  int? _intArg(Map<String, Object?> arguments, String key) {
    final Object? value = arguments[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  Map<String, Object?> _error(String message) => <String, Object?>{
        'error': message,
      };
}
