import 'package:flutter_test/flutter_test.dart';
import 'package:carregou/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CarregouApp());
    await tester.pumpAndSettle();
    expect(find.text('Carregou'), findsAny);
    expect(find.text('Entrar'), findsWidgets);
    expect(find.text('Não tem conta?'), findsOneWidget);
    expect(find.text('Clique aqui'), findsOneWidget);
  });
}
