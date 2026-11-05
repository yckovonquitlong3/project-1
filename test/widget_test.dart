import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/app.dart';

void main() {
  testWidgets('app boots to the placeholder screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MultiWalletApp());
    expect(find.text('Multi-Wallet Tracker'), findsOneWidget);
    expect(find.text('Ledger setup in progress'), findsOneWidget);
  });
}