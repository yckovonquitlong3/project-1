import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/ai/domain/ai_failure.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/quick_entry_suggestion.dart';
import 'package:multi_wallet_tracker/features/ai/domain/quick_entry_matcher.dart';
import 'package:multi_wallet_tracker/features/ai/domain/repositories/ai_settings_store.dart';
import 'package:multi_wallet_tracker/features/ai/domain/services/ai_client.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/category/domain/repositories/category_repository.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_draft.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';

final class ParseQuickEntry {
  const ParseQuickEntry({
    required AiSettingsStore settings,
    required AiClient client,
    required WalletRepository wallets,
    required CategoryRepository categories,
  })  : _settingsStore = settings,
        _aiClient = client,
        _walletRepo = wallets,
        _categoryRepo = categories;

  final AiSettingsStore _settingsStore;
  final AiClient _aiClient;
  final WalletRepository _walletRepo;
  final CategoryRepository _categoryRepo;

  Future<TransactionDraft> call(String input) async {
    final String text = input.trim();
    if (text.isEmpty) {
      throw const AiFailure(
        'Type a short description of the transaction.',
        kind: AiFailureKind.invalidResponse,
      );
    }
    final String prompt =
        text.length <= 400 ? text : text.substring(0, 400);

    final settings = await _settingsStore.load();
    if (!settings.isEnabled) {
      throw const AiFailure(
        'AI quick entry is off.',
        kind: AiFailureKind.disabled,
      );
    }
    if (!await _settingsStore.hasConsent()) {
      throw const AiFailure(
        'Review and accept the AI data notice in Settings first.',
        kind: AiFailureKind.consentRequired,
      );
    }
    final String? apiKey = await _settingsStore.readApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const AiFailure(
        'Add your provider API key in AI settings first.',
        kind: AiFailureKind.noKey,
      );
    }

    final QuickEntrySuggestion suggestion = await _aiClient.parseQuickEntry(
      text: prompt,
      settings: settings,
      apiKey: apiKey,
    );

    final Money amount;
    try {
      amount = Money.parsePesos(suggestion.amountText);
    } on FormatException {
      throw const AiFailure(
        'The AI returned an invalid amount.',
        kind: AiFailureKind.invalidResponse,
      );
    }

    final List<Wallet> wallets = await _walletRepo.all();
    final List<Category> categories = await _categoryRepo.byType(
      suggestion.type == TransactionType.income
          ? CategoryType.income
          : CategoryType.expense,
    );

    final String? walletId = matchLocalName(
      suggestion.walletName,
      wallets.map(
        (Wallet wallet) => (id: wallet.id, name: wallet.name),
      ),
    );
    final String? categoryId = matchLocalName(
      suggestion.categoryName,
      categories.map(
        (Category category) => (id: category.id, name: category.name),
      ),
    );
    final String? note = suggestion.note == null ||
            suggestion.note!.trim().isEmpty
        ? null
        : (suggestion.note!.trim().length <= 200
            ? suggestion.note!.trim()
            : suggestion.note!.trim().substring(0, 200));

    return TransactionDraft(
      type: suggestion.type,
      amount: amount,
      sourceWalletId: walletId,
      categoryId: categoryId,
      note: note,
    );
  }
}
