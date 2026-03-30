import 'package:flutter_test/flutter_test.dart';

import 'package:projetalto/main.dart';

void main() {
  testWidgets('Home screen affiche le texte de bienvenue', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Bienvenue sur'), findsOneWidget);
  });
}
