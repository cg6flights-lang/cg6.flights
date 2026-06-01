import 'package:cg6_flights/app/cg6_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows login as the initial public route', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CG6App()));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'cg6_logo/logo_cg6.png',
      ),
      findsOneWidget,
    );
    expect(find.text('CG6 Flights'), findsNothing);
    expect(
      find.text('Centro de Gestion y Control de Vuelos Diarios'),
      findsNothing,
    );
    expect(find.byIcon(Icons.login), findsOneWidget);
  });

  testWidgets('local sign in reaches the protected dashboard', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CG6App()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.login));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard operacional'), findsOneWidget);
    expect(find.text('Lider'), findsWidgets);
  });

  testWidgets('registration creates a pending access state', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CG6App()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registro'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Usuario Nuevo');
    await tester.enterText(find.byType(TextFormField).at(1), 'nuevo@cg6.local');
    await tester.enterText(find.byType(TextFormField).at(2), 'password-local');
    await tester.tap(find.byIcon(Icons.person_add_alt));
    await tester.pumpAndSettle();

    expect(find.text('Acceso pendiente'), findsOneWidget);
  });
}
