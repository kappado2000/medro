import 'package:flutter_test/flutter_test.dart';
import 'package:medro/providers/medicamente_provider.dart';
import 'package:medro/screens/cautare_rcp_screen.dart';
import 'package:medro/services/cautare_rcp.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cuvintele se pregatesc fara diacritice si fara cele scurte', () {
    expect(cuvinteCautate('  Tulburare BIPOLARĂ, de  tip I '), [
      'tulburare',
      'bipolara',
      'tip',
    ]);
    expect(cuvinteCautate('a și'), isEmpty);
    expect(faraDiacritice('Ședință Țară ÎNTÂI'), 'sedinta tara intai');
    expect(faraDiacritice('Ședință').length, 'Ședință'.length);
  });

  test('potrivirea cere toate cuvintele si intoarce fraza primului', () {
    const text =
        'Tratamentul episoadelor depresive majore. Prevenirea recăderilor în '
        'tulburarea bipolară, la pacienții care au răspuns la tratament.\n'
        'Nu este indicat la copii.';
    expect(
      potriveste(text, ['bipolara', 'prevenirea']),
      'Prevenirea recăderilor în tulburarea bipolară, la pacienții care au răspuns la tratament.',
    );
    expect(potriveste(text, ['copii']), 'Nu este indicat la copii.');
    expect(potriveste(text, ['bipolara', 'schizofrenie']), isNull);
    expect(potriveste(text, const []), isNull);
    // fraza foarte lunga este scurtata
    final lung = 'cuvant ${'x' * 900} tinta ${'y' * 900}.';
    expect(potriveste(lung, ['tinta'])!.length, lessThanOrEqualTo(321));
    expect(fragmentLa('Una. Doua; trei.', 6), 'Doua;');
  });

  test('zonele de cautare acopera sectiunile extrase', () {
    expect(zoneCautare.first.$2, hasLength(9));
    for (final (nume, sectiuni) in zoneCautare.skip(1)) {
      expect(sectiuni, hasLength(1), reason: nume);
      expect(zoneCautare.first.$2, contains(sectiuni.single), reason: nume);
    }
  });

  group('pe datele reale', () {
    late MedicamenteProvider med;
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      med = MedicamenteProvider();
      await med.incarca();
    });

    test(
      'indicatia gaseste medicamentele care o au in sectiunea 4.1',
      () async {
        final progres = await cautaInRcp(
          'schizofrenie',
          sectiuni: const ['4.1'],
        ).toList();
        final final_ = progres.last;
        expect(final_.gata, isTrue);
        expect(final_.parcurs, 1);
        // progresul creste pe masura ce se parcurg pachetele
        expect(progres.length, greaterThan(10));
        expect(final_.potriviri, isNotEmpty);
        expect(final_.potriviri.every((p) => p.sectiune == '4.1'), isTrue);
        expect(
          final_.potriviri.every(
            (p) => faraDiacritice(p.fragment).contains('schizofreni'),
          ),
          isTrue,
        );
        final substante = {
          for (final p in final_.potriviri)
            for (final m in med.produseCuTextul(p.cheie)) m.dci,
        };
        expect(
          substante,
          containsAll(['OLANZAPINUM', 'RISPERIDONUM', 'CLOZAPINUM']),
        );
        expect(substante, isNot(contains('PARACETAMOLUM')));
      },
    );

    test('contraindicatiile se cauta in textele pastrate separat', () async {
      final r = await cautaInRcp(
        'agranulocitoza',
        sectiuni: const ['4.3'],
        contraindicatii: med.toateContraindicatiile,
      ).last;
      expect(r.gata, isTrue);
      expect(r.potriviri, isNotEmpty);
      expect(r.potriviri.every((p) => p.sectiune == '4.3'), isTrue);
      final substante = {
        for (final p in r.potriviri)
          for (final m in med.produseCuTextul(p.cheie)) m.dci,
      };
      expect(substante, contains('CLOZAPINUM'));
    });

    test('cautarile goale sau fara potriviri se incheie curat', () async {
      final gol = await cautaInRcp('a', sectiuni: const ['4.1']).last;
      expect(gol.gata, isTrue);
      expect(gol.potriviri, isEmpty);
      final nimic = await cautaInRcp('qzxwvkj', sectiuni: const ['4.1']).last;
      expect(nimic.potriviri, isEmpty);
      expect(nimic.trunchiat, isFalse);
      // cuvintele foarte frecvente se opresc la limita
      final multe = await cautaInRcp('pacienti', sectiuni: const ['4.2']).last;
      expect(multe.trunchiat, isTrue);
      expect(multe.potriviri, hasLength(maxPotriviri));
      expect(med.produseCuTextul('cheie-inexistenta'), isEmpty);
    });
  });
}
