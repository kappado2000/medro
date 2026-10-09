import 'package:flutter_test/flutter_test.dart';
import 'package:medro/calculators/lista_calculatoare.dart';
import 'package:medro/providers/medicamente_provider.dart';
import 'package:medro/screens/monitorizare_screen.dart';
import 'package:medro/tools/depot.dart';
import 'package:medro/tools/plan_doze.dart';
import 'package:medro/utils/rcp_extrase.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final inceput = DateTime(2026, 10, 12);

  List<double> doze(List<PasDoza> p) => [for (final x in p) x.doza];

  group('planul de doze', () {
    test('reducere cu pas fix pana la oprire', () {
      final p = planDoze(
        start: 10,
        tinta: 0,
        tip: TipPas.fix,
        pas: 2.5,
        intervalZile: 14,
        inceput: inceput,
      );
      expect(doze(p), [7.5, 5, 2.5, 0]);
      expect(p.first.data, inceput);
      expect(p.last.data, DateTime(2026, 11, 23));
    });

    test('reducere procentuala cu rotunjire, incheiata cu oprire', () {
      final p = planDoze(
        start: 4,
        tinta: 0,
        tip: TipPas.procent,
        pas: 25,
        intervalZile: 7,
        inceput: inceput,
        rotunjire: 0.5,
      );
      expect(doze(p), [3, 2.5, 2, 1.5, 1, 0.5, 0]);
      // dozele scad strict si sunt multipli ai fractiunii
      for (var i = 1; i < p.length; i++) {
        expect(p[i].doza, lessThan(p[i - 1].doza));
        expect(p[i].data.difference(p[i - 1].data).inDays, 7);
      }
    });

    test(
      'reducere procentuala fara rotunjire se opreste sub 10% din start',
      () {
        final p = planDoze(
          start: 100,
          tinta: 0,
          tip: TipPas.procent,
          pas: 50,
          intervalZile: 7,
          inceput: inceput,
        );
        expect(doze(p), [50, 25, 12.5, 6.25, 0]);
      },
    );

    test('reducere pana la o tinta diferita de zero', () {
      final p = planDoze(
        start: 20,
        tinta: 5,
        tip: TipPas.procent,
        pas: 50,
        intervalZile: 28,
        inceput: inceput,
      );
      expect(doze(p), [10, 5]);
    });

    test('titrare cu pas fix nu depaseste tinta', () {
      final p = planDoze(
        start: 25,
        tinta: 200,
        tip: TipPas.fix,
        pas: 50,
        intervalZile: 14,
        inceput: inceput,
      );
      expect(doze(p), [75, 125, 175, 200]);
    });

    test('date care nu permit un plan', () {
      List<PasDoza> plan(double s, double t, TipPas tip, double pas, int z) =>
          planDoze(
            start: s,
            tinta: t,
            tip: tip,
            pas: pas,
            intervalZile: z,
            inceput: inceput,
          );
      expect(plan(10, 10, TipPas.fix, 1, 7), isEmpty);
      expect(plan(10, 0, TipPas.fix, 0, 7), isEmpty);
      expect(plan(10, 0, TipPas.fix, 1, 0), isEmpty);
      expect(plan(10, 0, TipPas.procent, 100, 7), isEmpty);
      expect(plan(0, 10, TipPas.procent, 10, 7), isEmpty);
      // planurile foarte lungi sunt limitate
      expect(plan(1000, 0, TipPas.fix, 1, 1), hasLength(maxPasi));
    });

    test('textul planului si formatarea', () {
      final p = planDoze(
        start: 10,
        tinta: 0,
        tip: TipPas.fix,
        pas: 5,
        intervalZile: 14,
        inceput: inceput,
      );
      expect(
        textPlan(p, 10, 'mg'),
        'Doza actuală: 10 mg\ndin 12.10.2026: 5 mg\ndin 26.10.2026: oprire',
      );
      expect(formatDoza(7.5), '7,5');
      expect(formatDoza(0.125), '0,125');
      expect(formatDoza(10), '10');
      expect(formatData(inceput), 'lun. 12.10.2026');
      // trecerea la ora de iarna nu muta ziua
      expect(adaugaZile(DateTime(2026, 10, 20), 7), DateTime(2026, 10, 27));
    });
  });

  group('calendarul depot', () {
    test('intervale in zile', () {
      final p = programDepot(
        ultima: DateTime(2026, 10, 9, 15, 30),
        interval: 14,
        inLuni: false,
        cate: 3,
      );
      expect(
        [for (final a in p) a.data],
        [DateTime(2026, 10, 23), DateTime(2026, 11, 6), DateTime(2026, 11, 20)],
      );
      expect(p.first.deLa, isNull);
    });

    test('intervale in luni, cu sfarsit de luna si fereastra', () {
      final p = programDepot(
        ultima: DateTime(2026, 1, 31),
        interval: 1,
        inLuni: true,
        zileInainte: 7,
        zileDupa: 7,
        cate: 3,
      );
      expect(
        [for (final a in p) a.data],
        [DateTime(2026, 2, 28), DateTime(2026, 3, 31), DateTime(2026, 4, 30)],
      );
      expect(p.first.deLa, DateTime(2026, 2, 21));
      expect(p.first.panaLa, DateTime(2026, 3, 7));
      expect(adaugaLuni(DateTime(2026, 8, 31), 6), DateTime(2027, 2, 28));
      expect(adaugaLuni(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
    });

    test('lista de preparate este coerenta', () {
      expect(depoturi.map((d) => d.nume).toSet(), hasLength(depoturi.length));
      for (final d in depoturi) {
        expect(d.interval, greaterThan(0), reason: d.nume);
        expect(d.zileInainte == null, d.zileDupa == null, reason: d.nume);
        final p = programDepot(
          ultima: inceput,
          interval: d.interval,
          inLuni: d.inLuni,
        );
        expect(p, hasLength(6), reason: d.nume);
        expect(p.first.data.isAfter(inceput), isTrue, reason: d.nume);
      }
      final byannli = depoturi.firstWhere((d) => d.produse == 'Byannli');
      expect((byannli.zileInainte, byannli.zileDupa), (14, 21));
      expect(
        programDepot(ultima: inceput, interval: 0, inLuni: false),
        isEmpty,
      );
      final text = textProgram(
        'Test',
        inceput,
        programDepot(
          ultima: inceput,
          interval: 3,
          inLuni: true,
          zileInainte: 14,
          zileDupa: 14,
          cate: 1,
        ),
      );
      expect(
        text,
        contains('mar. 12.01.2027 (între 29.12.2026 și 26.01.2027)'),
      );
    });
  });

  test('instrumentele apar in lista si au ecran propriu', () {
    final cu = calculatoare.where((c) => c.ecran != null).toList();
    expect(cu.map((c) => c.id), ['plan_doze', 'depot', 'monitorizare']);
    expect(
      calculatoare.map((c) => c.id).toSet(),
      hasLength(calculatoare.length),
    );
  });

  test(
    'monitorizarea se extrage din RCP-ul unui produs cu acel cod ATC',
    () async {
      SharedPreferences.setMockInitialValues({});
      final medicamente = MedicamenteProvider();
      await medicamente.incarca();
      final clozapina = await monitorizareDinRcp(medicamente, 'N05AH02');
      expect(clozapina, isNotNull);
      final (m, fraze) = clozapina!;
      expect(m.atc, 'N05AH02');
      expect(fraze, isNotEmpty);
      expect(
        fraze.every((f) => f.sectiune == '4.2' || f.sectiune == '4.4'),
        isTrue,
      );
      expect(
        fraze.any((f) => f.text.toLowerCase().contains('leucocit')),
        isTrue,
      );
      expect(await monitorizareDinRcp(medicamente, 'Z99ZZ99'), isNull);
      expect(
        substanteMonitorizate.map((s) => s.$2).toSet(),
        hasLength(substanteMonitorizate.length),
      );
    },
  );

  test('doza maxima se extrage din sectiunea 4.2', () {
    final tema = temeRcp.firstWhere((t) => t.id == 'doza_maxima');
    final f = extrage(tema, const {
      '4.2':
          'Doza inițială este de 50 mg pe zi. Doza zilnică maximă este de 200 mg. '
          'Se administrează dimineața. Doza nu trebuie să depășească 20 mg pe zi la vârstnici.',
      '4.4': 'Doza maximă nu a fost studiată.',
    });
    expect(f.map((x) => x.text), [
      'Doza zilnică maximă este de 200 mg.',
      'Doza nu trebuie să depășească 20 mg pe zi la vârstnici.',
    ]);
  });
}
