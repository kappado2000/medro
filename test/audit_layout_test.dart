import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medro/calculators/lista_calculatoare.dart';
import 'package:medro/help/ajutor.dart';
import 'package:medro/providers/asistent_provider.dart';
import 'package:medro/providers/icd_provider.dart';
import 'package:medro/providers/interactiuni_provider.dart';
import 'package:medro/providers/medicamente_provider.dart';
import 'package:medro/screens/calculator_screen.dart';
import 'package:medro/screens/home_shell.dart';
import 'package:medro/screens/icd_screen.dart';
import 'package:medro/screens/medicament_detail_screen.dart';
import 'package:medro/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ecranele nu trebuie sa aiba depasiri de aspect nici pe cel mai ingust
/// telefon, nici cu textul marit din setarile sistemului.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MedicamenteProvider med;
  late IcdProvider icd;
  late InteractiuniProvider inter;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    med = MedicamenteProvider();
    await med.incarca();
    icd = IcdProvider();
    await icd.incarca();
    inter = InteractiuniProvider();
    await inter.incarca();
  });

  Widget cadru(Widget ecran, double scara) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: med),
        ChangeNotifierProvider.value(value: icd),
        ChangeNotifierProvider.value(value: inter),
        ChangeNotifierProvider(create: (_) => AsistentProvider()..cheie = 'x'),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scara)),
          child: child!,
        ),
        home: ecran,
      ),
    );
  }

  for (final (latime, scara) in [
    (320.0, 1.0),
    (320.0, 1.35),
    (390.0, 1.35),
    (430.0, 1.0),
  ]) {
    final eticheta = 'latime $latime, text x$scara';

    Future<void> pregateste(WidgetTester tester) async {
      tester.view.physicalSize = Size(latime * 3, 700 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      addTearDown(() => tabCurent.value = 0);
    }

    testWidgets('cele cinci sectiuni: $eticheta', (tester) async {
      await pregateste(tester);
      await tester.pumpWidget(cadru(const HomeShell(), scara));
      for (var i = 0; i < 5; i++) {
        tabCurent.value = i;
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: 'sectiunea $i');
      }
    });

    testWidgets('pagina unui medicament: $eticheta', (tester) async {
      await pregateste(tester);
      final exemple = [
        // cu contraindicatii si compensare
        med
            .cauta('', FiltruMedicamente.compensate, atcPrefix: 'N0')
            .firstWhere((m) => med.contraindicatii(m) != null),
        // denumirea cea mai lunga
        med
            .cauta('', FiltruMedicamente.toate, atcPrefix: 'J')
            .reduce((a, b) => a.denumire.length >= b.denumire.length ? a : b),
        // autorizat centralizat
        med.cauta('keytruda', FiltruMedicamente.toate).first,
      ];
      for (final m in exemple) {
        await tester.pumpWidget(
          cadru(
            MedicamentDetailScreen(key: ValueKey(m.id), medicament: m),
            scara,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: m.denumire);
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -1500),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '${m.denumire} (derulat)',
        );
      }
    });

    testWidgets('toate calculatoarele: $eticheta', (tester) async {
      await pregateste(tester);
      for (final c in calculatoare) {
        await tester.pumpWidget(
          cadru(CalculatorScreen(key: ValueKey(c.id), calculator: c), scara),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: c.titlu);
      }
    });

    testWidgets('ICD-10 si ajutor: $eticheta', (tester) async {
      await pregateste(tester);
      final f = icd.capitole.first;
      await tester.pumpWidget(
        cadru(
          IcdListaScreen(
            titlu: 'Capitolul ${f.numar}',
            subtitlu: '${f.titlu} (${f.interval})',
            coduri: icd.categorii(f),
          ),
          scara,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'capitolul F');
      await tester.pumpWidget(
        cadru(
          IcdListaScreen(
            key: const ValueKey('lungi'),
            titlu: 'V86',
            subtitlu: 'titluri lungi',
            coduri: icd.cauta('V86'),
          ),
          scara,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'titluri lungi');
      for (final a in [ajutorMedicamente, ajutorAsistent]) {
        await tester.pumpWidget(
          cadru(AjutorScreen(key: ValueKey(a.titlu), a), scara),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'ajutor ${a.titlu}');
      }
    });
  }
}
