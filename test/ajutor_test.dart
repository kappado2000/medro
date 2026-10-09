import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medro/help/ajutor.dart';
import 'package:medro/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const toate = [
    ajutorMedicamente,
    ajutorPaginaMedicament,
    ajutorInteractiuni,
    ajutorCalculatoare,
    ajutorIcd,
    ajutorAsistent,
  ];

  test('fiecare pagina de ajutor are continut si un capitol de limite', () {
    for (final a in toate) {
      expect(a.rezumat.length, greaterThan(60), reason: a.titlu);
      expect(a.capitole, isNotEmpty, reason: a.titlu);
      expect(
        a.capitole.where((c) => c.avertizare),
        hasLength(1),
        reason: a.titlu,
      );
      for (final c in a.capitole) {
        expect(
          c.text != null || c.puncte.isNotEmpty,
          isTrue,
          reason: '${a.titlu} / ${c.titlu}',
        );
        for (final (termen, explicatie) in c.puncte) {
          expect(termen.trim(), isNotEmpty, reason: c.titlu);
          expect(
            explicatie.trim().length,
            greaterThan(15),
            reason: '${c.titlu} / $termen',
          );
        }
      }
    }
  });

  testWidgets('pagina de ajutor afiseaza toate capitolele', (tester) async {
    for (final a in toate) {
      await tester.pumpWidget(
        MaterialApp(key: ValueKey(a.titlu), home: AjutorScreen(a)),
      );
      expect(find.text('Despre ${a.titlu}'), findsOneWidget);
      expect(find.text(a.rezumat), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(a.capitole.last.titlu),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(a.capitole.last.titlu), findsOneWidget);
    }
  });

  testWidgets('semnul intrebarii din antet deschide ajutorul sectiunii', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MedRoApp());
    await tester.pump();
    // fiecare sectiune are un singur buton de ajutor vizibil in antet
    final etichete = {
      'Medicamente': 'Despre Medicamente',
      'Interacțiuni': 'Despre Interacțiuni',
      'Calculatoare': 'Despre Calculatoare',
      'ICD-10': 'Despre ICD-10',
      'Asistent': 'Despre Asistent',
    };
    for (final e in etichete.entries) {
      await tester.tap(find.bySemanticsLabel(e.key).last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byIcon(Icons.help_outline).hitTestable());
      await tester.pumpAndSettle();
      expect(find.text(e.value), findsOneWidget, reason: e.key);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
