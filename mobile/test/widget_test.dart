import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/main.dart';

void main() {
  testWidgets('Nataal Agro app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const NataalAgroApp());
    expect(find.text('Accueil'), findsOneWidget);
  });
}
