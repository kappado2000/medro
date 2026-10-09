import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medro/main.dart';
import 'package:medro/providers/setari_text_provider.dart';
import 'package:medro/screens/setari_text_screen.dart';
import 'package:medro/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SetariTextProvider', () {
    test('valorile initiale, salvarea si resetarea', () async {
      SharedPreferences.setMockInitialValues({});
      final p = SetariTextProvider();
      await p.incarca();
      expect(p.scara, 1);
      expect(p.grosime, GrosimeText.normal);
      expect(p.implicite, isTrue);

      await p.seteazaScara(1.2);
      await p.seteazaGrosime(GrosimeText.subtire);
      expect(p.implicite, isFalse);

      final alta = SetariTextProvider();
      await alta.incarca();
      expect(alta.scara, 1.2);
      expect(alta.grosime, GrosimeText.subtire);

      await alta.reseteaza();
      final dupa = SetariTextProvider();
      await dupa.incarca();
      expect(dupa.implicite, isTrue);
    });

    test('marimea ramane in limite si pe pasi de 5%', () async {
      SharedPreferences.setMockInitialValues({});
      final p = SetariTextProvider();
      await p.seteazaScara(9);
      expect(p.scara, SetariTextProvider.scaraMaxima);
      await p.seteazaScara(0.1);
      expect(p.scara, SetariTextProvider.scaraMinima);
      await p.seteazaScara(1.07);
      expect(p.scara, 1.05);
      // o valoare stricata din stocare nu scoate aplicatia din limite
      SharedPreferences.setMockInitialValues({
        'text_scara': 55.0,
        'text_grosime': 'altceva',
      });
      final q = SetariTextProvider();
      await q.incarca();
      expect(q.scara, SetariTextProvider.scaraMaxima);
      expect(q.grosime, GrosimeText.normal);
    });
  });

  test('tema foloseste grosimea aleasa pentru scrisul obisnuit', () {
    for (final g in GrosimeText.values) {
      final t = buildAppTheme(grosime: g.grosime).textTheme;
      expect(t.bodyMedium!.fontWeight, g.grosime, reason: g.name);
      expect(t.bodyLarge!.fontWeight, g.grosime, reason: g.name);
      expect(t.labelLarge!.fontWeight, g.grosime, reason: g.name);
      expect(t.titleLarge!.fontWeight, g.grosime, reason: g.name);
    }
    expect(buildAppTheme().textTheme.bodyMedium!.fontWeight, FontWeight.w400);
  });

  testWidgets('aplicatia ignora setarile de text ale telefonului', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(boldText: true);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(const MedRoApp());
    await tester.pump();

    final mq = MediaQuery.of(tester.element(find.text('MedRO').first));
    expect(mq.boldText, isFalse);
    expect(mq.textScaler.scale(10), 10);
  });

  testWidgets('marimea si grosimea alese se aplica in toata aplicatia', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'text_scara': 1.2,
      'text_grosime': 'ingrosat',
    });
    await tester.pumpWidget(const MedRoApp());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    // tema noua se asaza printr-o tranzitie scurta
    await tester.pump(const Duration(milliseconds: 500));

    final context = tester.element(find.text('MedRO').first);
    expect(MediaQuery.of(context).textScaler.scale(10), closeTo(12, 0.001));
    expect(Theme.of(context).textTheme.bodyMedium!.fontWeight, FontWeight.w600);
  });

  testWidgets('pagina de setari schimba valorile si le poate reseta', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final p = SetariTextProvider();
    await p.incarca();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: p,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const SetariTextScreen(),
        ),
      ),
    );
    expect(find.text('MĂRIME: 100%'), findsOneWidget);

    await tester.tap(find.byTooltip('Mai mare'));
    await tester.pump();
    expect(p.scara, 1.05);
    expect(find.text('MĂRIME: 105%'), findsOneWidget);

    await tester.tap(find.byTooltip('Mai mic'));
    await tester.tap(find.byTooltip('Mai mic'));
    await tester.pump();
    expect(p.scara, 0.95);

    await tester.tap(find.text('Îngroșat'));
    await tester.pump();
    expect(p.grosime, GrosimeText.ingrosat);

    await tester.ensureVisible(find.text('Revino la valorile inițiale'));
    await tester.tap(find.text('Revino la valorile inițiale'));
    await tester.pump();
    expect(p.implicite, isTrue);
    expect(find.text('MĂRIME: 100%'), findsOneWidget);
  });

  testWidgets('pagina de setari incape pe un ecran ingust la marimea maxima', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'text_scara': 1.4});
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final p = SetariTextProvider();
    await p.incarca();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: p,
        child: MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(p.scara)),
            child: child!,
          ),
          home: const SetariTextScreen(),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
