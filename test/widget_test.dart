import 'package:flutter_test/flutter_test.dart';
import 'package:medro/main.dart';
import 'package:medro/providers/medicamente_provider.dart';
import 'package:medro/utils/text_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MedicamenteProvider provider;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    provider = MedicamenteProvider();
    await provider.incarca();
  });

  test('nomenclatorul se incarca din asset', () {
    expect(provider.eroare, isNull);
    expect(provider.total, greaterThan(7000));
    expect(provider.totalSubstante, greaterThan(1500));
    expect(provider.actualizat, isNotEmpty);
  });

  test('cautarea gaseste dupa denumire, substanta si ATC', () {
    final dupaNume = provider.cauta('algocalmin', FiltruMedicamente.toate);
    expect(dupaNume, isNotEmpty);
    expect(dupaNume.first.denumireNorm, startsWith('algocalmin'));

    final dupaDci = provider.cauta('metformin', FiltruMedicamente.toate);
    expect(dupaDci.any((m) => m.dciNorm.contains('metformin')), isTrue);

    final dupaAtc = provider.cauta('M04AA01', FiltruMedicamente.toate);
    expect(dupaAtc, isNotEmpty);
    expect(dupaAtc.every((m) => m.atc == 'M04AA01'), isTrue);

    expect(provider.cauta('zzzzqqq', FiltruMedicamente.toate), isEmpty);
  });

  test('medicamentele autorizate centralizat au PDF de la EMA', () {
    final m = provider.cauta('keytruda', FiltruMedicamente.toate).first;
    expect(m.centralizat, isTrue);
    expect(m.rcpUrl, startsWith('https://www.ema.europa.eu/ro/documents/'));
    expect(m.rcpUrl, endsWith('_ro.pdf'));
    expect(m.prospectUrl, isEmpty);
  });

  test('filtrul pe clasa ATC afiseaza toata clasa', () {
    final antipsihotice = provider.cauta(
      '',
      FiltruMedicamente.toate,
      atcPrefix: 'N05A',
    );
    expect(antipsihotice, isNotEmpty);
    expect(antipsihotice.every((m) => m.atc.startsWith('N05A')), isTrue);
    final anxiolitice = provider.cauta(
      '',
      FiltruMedicamente.toate,
      atcPrefix: 'N05B',
    );
    expect(anxiolitice, isNotEmpty);
    expect(anxiolitice.any(antipsihotice.contains), isFalse);
    final cautare = provider.cauta(
      'olanzapin',
      FiltruMedicamente.toate,
      atcPrefix: 'N05A',
    );
    expect(cautare, isNotEmpty);
    expect(cautare.every((m) => m.dciNorm.contains('olanzapin')), isTrue);
  });

  test('compensarea CNAS se leaga de ambalaje prin codul CIM', () {
    expect(provider.dataCompensare, matches(r'^\d{2}\.\d{2}\.\d{4}$'));
    final compensate = provider.cauta('', FiltruMedicamente.compensate);
    expect(compensate, isNotEmpty);
    expect(compensate.every((m) => m.liste.isNotEmpty), isTrue);

    final m = compensate.first;
    final incadrari = [
      for (final a in m.ambalaje) ...provider.compensareAmbalaj(a.cim),
    ];
    expect(incadrari.map((c) => c.lista).toSet(), m.liste.toSet());
    for (final c in incadrari) {
      expect(c.pret, greaterThan(0));
      expect(c.contributie, inInclusiveRange(0, c.pret));
    }
    expect(provider.compensareAmbalaj('INEXISTENT'), isEmpty);
    expect(provider.listeSubstanta('SERTRALINUM'), isNotEmpty);
    expect(provider.listeSubstanta('INEXISTENTUM'), isEmpty);
  });

  test('cautarea accepta denumirea romaneasca a substantei', () {
    for (final (ro, dci) in [
      ('clozapina', 'CLOZAPINUM'),
      ('olanzapina', 'OLANZAPINUM'),
      ('quetiapina', 'QUETIAPINUM'),
      ('risperidona', 'RISPERIDONUM'),
    ]) {
      final r = provider.cauta(ro, FiltruMedicamente.toate);
      expect(r, isNotEmpty, reason: ro);
      expect(
        r.every((m) => m.dci.contains(dci) || m.denumireNorm.contains(ro)),
        isTrue,
        reason: ro,
      );
    }
    expect(radacinaSubstanta('clozapina'), 'clozapin');
    expect(radacinaSubstanta('doza'), isNull);
    expect(radacinaSubstanta('litiu'), isNull);
  });

  test('filtrele separa OTC de reteta', () {
    final otc = provider.cauta('', FiltruMedicamente.faraReteta);
    final rx = provider.cauta('', FiltruMedicamente.cuReteta);
    expect(otc.every((m) => m.faraReteta), isTrue);
    expect(rx.every((m) => !m.faraReteta), isTrue);
  });

  test('favoritele si echivalentele functioneaza', () async {
    final m = provider.cauta('paracetamol', FiltruMedicamente.toate).first;
    expect(provider.cauta('', FiltruMedicamente.favorite), isEmpty);
    await provider.comutaFavorit(m);
    expect(provider.cauta('', FiltruMedicamente.favorite), [m]);
    await provider.comutaFavorit(m);
    expect(provider.esteFavorit(m), isFalse);

    final echivalente = provider.echivalente(m);
    expect(echivalente, isNot(contains(m)));
    expect(echivalente.every((e) => e.dci == m.dci), isTrue);
  });

  test('normalizarea elimina diacriticele', () {
    expect(normalizeForSearch('  Știință  ȚĂRI® '), 'stiinta tari');
  });

  testWidgets('aplicatia porneste si afiseaza navigarea', (tester) async {
    await tester.pumpWidget(const MedRoApp());
    expect(find.text('MedRO'), findsOneWidget);
    expect(find.text('Interacțiuni'), findsOneWidget);
    expect(find.text('Calculatoare'), findsOneWidget);
  });
}
