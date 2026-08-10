import 'package:flutter_test/flutter_test.dart';
import 'package:grupo_alessat_app/main.dart';

void main() {
  testWidgets('exibe a trava temporaria na tela de login',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Usuário ou chave de acesso'), findsNothing);
    expect(find.text('Senha'), findsNothing);
    expect(find.text('Acesso temporariamente suspenso.'), findsOneWidget);
    expect(find.text('Acesso temporariamente bloqueado'), findsOneWidget);
    expect(
      find.text(
        'O acesso está temporariamente indisponível enquanto realizamos ajustes no servidor. Tente novamente mais tarde.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Acesso temporariamente bloqueado'));
    await tester.pump();

    // A segunda ocorrencia vem do aviso; nenhuma chamada de login e iniciada.
    expect(
      find.text(
        'O acesso está temporariamente indisponível enquanto realizamos ajustes no servidor. Tente novamente mais tarde.',
      ),
      findsNWidgets(2),
    );
  });
}
