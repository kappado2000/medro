import 'package:flutter_test/flutter_test.dart';
import 'package:medro/calculators/calculator.dart';
import 'package:medro/calculators/formule.dart';
import 'package:medro/calculators/lista_calculatoare.dart';
import 'package:medro/calculators/psihiatrie.dart';

Rezultat? calc(String id, Map<String, Object> valori) {
  return calculatoare.firstWhere((c) => c.id == id).calculeaza(valori);
}

void main() {
  group('formule', () {
    test('IMC si suprafata corporala', () {
      expect(imc(70, 175), closeTo(22.86, 0.01));
      expect(suprafataCorporala(70, 175), closeTo(1.845, 0.001));
    });

    test('eGFR CKD-EPI 2021', () {
      expect(
        egfrCkdEpi2021(creatinina: 1.0, varsta: 50, femeie: false),
        closeTo(91.7, 0.5),
      );
      expect(
        egfrCkdEpi2021(creatinina: 0.6, varsta: 60, femeie: true),
        closeTo(102.7, 0.5),
      );
    });

    test('Cockcroft-Gault', () {
      expect(
        cockcroftGault(creatinina: 1.0, varsta: 60, kg: 72, femeie: false),
        closeTo(80, 0.001),
      );
      expect(
        cockcroftGault(creatinina: 1.0, varsta: 60, kg: 72, femeie: true),
        closeTo(68, 0.001),
      );
    });

    test('calciu corectat, QTc, greutate ideala, TAM', () {
      expect(calciuCorectat(8.0, 2.0), closeTo(9.6, 0.001));
      expect(qtcBazett(400, 60), closeTo(400, 0.001));
      expect(qtcBazett(400, 75), closeTo(447.2, 0.1));
      expect(greutateIdeala(180, femeie: false), closeTo(75.0, 0.1));
      expect(greutateIdeala(165, femeie: true), closeTo(56.9, 0.1));
      expect(tensiuneMedie(120, 80), closeTo(93.33, 0.01));
      expect(creatininaMgDl(88.4), closeTo(1.0, 0.001));
    });
  });

  group('calculatoare', () {
    test('id-urile sunt unice si fiecare are campuri', () {
      expect(calculatoare.map((c) => c.id).toSet().length, calculatoare.length);
      for (final c in calculatoare) {
        expect(c.campuri, isNotEmpty, reason: c.id);
        expect(
          c.campuri.map((x) => x.id).toSet().length,
          c.campuri.length,
          reason: c.id,
        );
      }
    });

    test('nu dau rezultat cat timp lipsesc date numerice', () {
      for (final id in [
        'egfr',
        'cg',
        'imc',
        'sc',
        'gi',
        'qtc',
        'tam',
        'calciu',
        'gcs',
      ]) {
        expect(calc(id, {}), isNull, reason: id);
      }
    });

    test('eGFR accepta ambele unitati si stadializeaza', () {
      final mg = calc('egfr', {
        'sex': 0,
        'varsta': 50.0,
        'unitate': 0,
        'cr': 1.0,
      })!;
      final umol = calc('egfr', {
        'sex': 0,
        'varsta': 50.0,
        'unitate': 1,
        'cr': 88.4,
      })!;
      expect(mg.valoare, '92');
      expect(umol.valoare, mg.valoare);
      expect(mg.interpretare, startsWith('G1'));
      final sever = calc('egfr', {
        'sex': 0,
        'varsta': 70.0,
        'unitate': 0,
        'cr': 3.0,
      })!;
      expect(sever.interpretare, startsWith('G4'));
      expect(sever.nivel, Nivel.ridicat);
    });

    test('IMC clasifica', () {
      expect(
        calc('imc', {'kg': 70.0, 'cm': 175.0})!.interpretare,
        'Greutate normală',
      );
      expect(
        calc('imc', {'kg': 100.0, 'cm': 175.0})!.interpretare,
        'Obezitate gradul I',
      );
    });

    test('CHA2DS2-VASc', () {
      expect(calc('cha2ds2vasc', {}), isNull);
      final minimB = calc('cha2ds2vasc', {'varsta': 0, 'sex': 0})!;
      expect(minimB.valoare, '0');
      expect(minimB.nivel, Nivel.normal);
      // femeie fara alti factori: 1 punct, dar tot risc scazut
      final minimF = calc('cha2ds2vasc', {'varsta': 0, 'sex': 1})!;
      expect(minimF.valoare, '1');
      expect(minimF.nivel, Nivel.normal);
      final maxim = calc('cha2ds2vasc', {
        'varsta': 2,
        'sex': 1,
        'ic': true,
        'hta': true,
        'dz': true,
        'avc': true,
        'vasc': true,
      })!;
      expect(maxim.valoare, '9');
      expect(maxim.nivel, Nivel.ridicat);
    });

    test('HAS-BLED, CURB-65 si GCS', () {
      expect(calc('hasbled', {})!.valoare, '0');
      final hb = calc('hasbled', {'hta': true, 'avc': true, 'varsta': true})!;
      expect(hb.valoare, '3');
      expect(hb.nivel, Nivel.ridicat);

      expect(calc('curb65', {'c': true, 'v': true})!.nivel, Nivel.atentie);
      expect(
        calc('curb65', {'c': true, 'u': true, 'r': true})!.nivel,
        Nivel.ridicat,
      );

      expect(calc('gcs', {'ochi': 0, 'verbal': 0, 'motor': 0})!.valoare, '15');
      final coma = calc('gcs', {'ochi': 3, 'verbal': 4, 'motor': 5})!;
      expect(coma.valoare, '3');
      expect(coma.nivel, Nivel.ridicat);
    });

    test('QTc foloseste praguri diferite pe sexe', () {
      final b = calc('qtc', {'sex': 0, 'qt': 455.0, 'fc': 60.0})!;
      final f = calc('qtc', {'sex': 1, 'qt': 455.0, 'fc': 60.0})!;
      expect(b.nivel, Nivel.atentie);
      expect(f.nivel, Nivel.normal);
    });
  });

  group('psihiatrie', () {
    Map<String, Object> raspunsuri(int n, int valoare) {
      return {for (var i = 1; i <= n; i++) 'q$i': valoare};
    }

    test('categoria Psihiatrie apare prima', () {
      expect(calculatoare.first.categorie, 'Psihiatrie');
    });

    test('PHQ-9 cere toti itemii si clasifica', () {
      expect(calc('phq9', raspunsuri(8, 1)), isNull);
      expect(calc('phq9', raspunsuri(9, 0))!.valoare, '0');
      final sever = calc('phq9', raspunsuri(9, 3))!;
      expect(sever.valoare, '27');
      expect(sever.nivel, Nivel.ridicat);
      final usoara = calc('phq9', {...raspunsuri(9, 1), 'q1': 2, 'q9': 0})!;
      expect(usoara.valoare, '9');
      expect(usoara.interpretare, startsWith('Depresie ușoară'));
      expect(usoara.nivel, Nivel.normal);
    });

    test('PHQ-9 semnaleaza itemul 9 indiferent de scor', () {
      final r = calc('phq9', {...raspunsuri(9, 0), 'q9': 1})!;
      expect(r.valoare, '1');
      expect(r.nivel, Nivel.ridicat);
      expect(r.interpretare, contains('riscul suicidar'));
    });

    test('GAD-7', () {
      expect(calc('gad7', raspunsuri(7, 3))!.valoare, '21');
      final r = calc('gad7', {...raspunsuri(7, 1), 'q1': 3, 'q2': 3})!;
      expect(r.valoare, '11');
      expect(r.interpretare, startsWith('Anxietate moderată'));
    });

    test('AUDIT puncteaza itemii 9 si 10 cu 0, 2, 4', () {
      expect(calc('audit', raspunsuri(10, 0))!.valoare, '0');
      final r = calc('audit', {...raspunsuri(10, 0), 'q9': 2, 'q10': 1})!;
      expect(r.valoare, '6');
      final maxim = calc('audit', {...raspunsuri(8, 4), 'q9': 2, 'q10': 2})!;
      expect(maxim.valoare, '40');
      expect(maxim.interpretare, startsWith('Zona IV'));
    });

    test('CIWA-Ar aduna notele si are maximum 67', () {
      const iduri = [
        'greata',
        'tremor',
        'transpiratii',
        'anxietate',
        'agitatie',
        'tactil',
        'auditiv',
        'vizual',
        'cefalee',
      ];
      expect(calc('ciwa', {for (final id in iduri) id: 0}), isNull);
      final maxim = calc('ciwa', {
        for (final id in iduri) id: 7,
        'orientare': 4,
      })!;
      expect(maxim.valoare, '67');
      expect(maxim.nivel, Nivel.ridicat);
      final usor = calc('ciwa', {
        for (final id in iduri) id: 0,
        'orientare': 0,
        'tremor': 5,
      })!;
      expect(usor.valoare, '5');
      expect(usor.nivel, Nivel.normal);
    });

    test('CGI afiseaza severitatea si ameliorarea', () {
      expect(calc('cgi', {}), isNull);
      final doarS = calc('cgi', {'s': 3})!;
      expect(doarS.valoare, '4');
      expect(doarS.interpretare, 'Moderat bolnav');
      final ambele = calc('cgi', {'s': 5, 'i': 1})!;
      expect(ambele.valoare, '6 / 2');
      expect(ambele.interpretare, 'Sever bolnav. Mult ameliorat.');
      expect(ambele.nivel, Nivel.ridicat);
    });

    test('echivalente de doze', () {
      final bzd = echivalenteBenzodiazepine.keys.toList();
      final r = calc('echiv_bzd', {
        'din': bzd.indexOf('Alprazolam'),
        'doza': 1.0,
        'in': bzd.indexOf('Diazepam'),
      })!;
      expect(r.valoare, '20,0');
      expect(r.unitate, 'mg diazepam');

      final ap = echivalenteAntipsihotice.keys.toList();
      final o = calc('echiv_ap', {
        'din': ap.indexOf('Olanzapină'),
        'doza': 10.0,
        'in': ap.indexOf('Risperidonă'),
      })!;
      expect(o.valoare, '4,00');
      expect(calc('echiv_ap', {'din': 0, 'in': 1}), isNull);
    });
  });
  group('psihiatrie – instrumente suplimentare', () {
    test('criteriile Hunter', () {
      expect(calc('hunter', {})!.valoare, '—');
      expect(calc('hunter', {'clonus_spontan': true})!.valoare, '—');
      expect(calc('hunter', {'agent': true})!.valoare, 'Negativ');
      expect(
        calc('hunter', {'agent': true, 'clonus_spontan': true})!.valoare,
        'Pozitiv',
      );
      expect(
        calc('hunter', {'agent': true, 'clonus_inductibil': true})!.valoare,
        'Negativ',
      );
      expect(
        calc('hunter', {
          'agent': true,
          'clonus_inductibil': true,
          'diaforeza': true,
        })!.valoare,
        'Pozitiv',
      );
      expect(
        calc('hunter', {
          'agent': true,
          'clonus_ocular': true,
          'agitatie': true,
        })!.valoare,
        'Pozitiv',
      );
      expect(
        calc('hunter', {'agent': true, 'tremor': true})!.valoare,
        'Negativ',
      );
      expect(
        calc('hunter', {
          'agent': true,
          'tremor': true,
          'hiperreflexie': true,
        })!.valoare,
        'Pozitiv',
      );
      expect(
        calc('hunter', {
          'agent': true,
          'hipertonie': true,
          'febra': true,
        })!.valoare,
        'Negativ',
      );
      final r = calc('hunter', {
        'agent': true,
        'hipertonie': true,
        'febra': true,
        'clonus_ocular': true,
      })!;
      expect(r.valoare, 'Pozitiv');
      expect(r.nivel, Nivel.ridicat);
    });

    test('AIMS aduna doar cele 7 zone si aplica pragul de screening', () {
      Map<String, Object> zone(int nota) => {
        for (var i = 1; i <= 7; i++) 'a$i': nota,
      };
      expect(calc('aims', {'a1': 2}), isNull);
      final negativ = calc('aims', {
        ...zone(0),
        'a1': 2,
        'a8': 4,
        'a9': 4,
        'a10': 4,
      })!;
      expect(negativ.valoare, '2');
      expect(negativ.nivel, Nivel.normal);
      expect(
        calc('aims', {...zone(0), 'a1': 2, 'a4': 2})!.nivel,
        Nivel.ridicat,
      );
      expect(calc('aims', {...zone(0), 'a5': 3})!.nivel, Nivel.ridicat);
      expect(calc('aims', zone(4))!.valoare, '28');
    });

    test('BPRS are intervalul 18-126', () {
      Map<String, Object> itemi(int nota) => {
        for (var i = 1; i <= 18; i++) 'b$i': nota,
      };
      expect(calc('bprs', {'b1': 3}), isNull);
      final minim = calc('bprs', itemi(1))!;
      expect(minim.valoare, '18');
      expect(minim.nivel, Nivel.normal);
      final maxim = calc('bprs', itemi(7))!;
      expect(maxim.valoare, '126');
      expect(maxim.nivel, Nivel.ridicat);
      expect(calc('bprs', {...itemi(2), 'b1': 7})!.valoare, '41');
    });
  });
}
