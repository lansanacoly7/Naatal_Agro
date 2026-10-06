import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/features/finances/data/models/financial_summary.dart';

void main() {
  group('TransactionItem.fromJson', () {
    test('lit un montant décimal renvoyé sous forme de texte par l\'API', () {
      final item = TransactionItem.fromJson({
        'id': 'abc',
        'transaction_type': 'income',
        'amount': '5689.00',
        'date': '2026-10-06',
        'description': 'Vente',
      });
      expect(item.amount, 5689.0);
    });

    test('lit un montant numérique', () {
      final item = TransactionItem.fromJson({'id': 'abc', 'amount': 1200, 'date': '', 'description': ''});
      expect(item.amount, 1200.0);
    });

    test('montant absent : 0', () {
      final item = TransactionItem.fromJson({'id': 'abc', 'date': '', 'description': ''});
      expect(item.amount, 0.0);
    });
  });
}
