import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grupo_alessat_app/main.dart';

void main() {
  testWidgets('permite preencher os campos da tela de login',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Usuário ou chave de acesso'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Acesso temporariamente suspenso.'), findsNothing);
    expect(find.text('Acesso temporariamente bloqueado'), findsNothing);

    await tester.enterText(find.byType(TextFormField).at(0), 'usuario');
    await tester.enterText(find.byType(TextFormField).at(1), 'senha');
    expect(find.text('usuario'), findsOneWidget);
    expect(find.text('senha'), findsOneWidget);
  });
}
