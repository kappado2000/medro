import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medro/services/voce.dart';

class DictareFalsa implements MotorDictare {
  bool disponibila;
  bool porneste = true;
  late void Function(String) laStare;
  late void Function(String) laEroare;
  void Function(String, bool)? laText;
  int opriri = 0;
  DictareFalsa({this.disponibila = true});

  @override
  Future<bool> pregateste({
    required void Function(String stare) laStare,
    required void Function(String eroare) laEroare,
  }) async {
    this.laStare = laStare;
    this.laEroare = laEroare;
    return disponibila;
  }

  @override
  Future<void> asculta(void Function(String text, bool final_) laText) async {
    if (!porneste) throw Exception('fara motor');
    this.laText = laText;
  }

  @override
  Future<void> opreste() async => opriri++;
}

class CitireFalsa implements MotorCitire {
  late VoidCallback laSfarsit;
  final citite = <String>[];
  int opriri = 0;
  bool strica = false;

  @override
  Future<void> pregateste({required VoidCallback laSfarsit}) async {
    this.laSfarsit = laSfarsit;
  }

  @override
  Future<void> citeste(String text) async {
    if (strica) throw Exception('fara voce');
    citite.add(text);
  }

  @override
  Future<void> opreste() async => opriri++;
}

void main() {
  test(
    'dictarea umple campul pe masura ce se vorbeste si se opreste singura',
    () async {
      final d = DictareFalsa();
      final v = Voce(dictare: d, citire: CitireFalsa());
      final primite = <String>[];
      expect(await v.pornesteDictarea(primite.add), isTrue);
      expect(v.asculta, isTrue);
      d.laText!('care este doza', false);
      d.laText!('care este doza maximă', true);
      expect(primite, ['care este doza', 'care este doza maximă']);
      d.laStare('done');
      expect(v.asculta, isFalse);

      await v.pornesteDictarea(primite.add);
      await v.opresteDictarea();
      expect(v.asculta, isFalse);
      expect(d.opriri, 1);
    },
  );

  test(
    'dictarea indisponibila sau esuata da un mesaj, nu o exceptie',
    () async {
      final faraMotor = Voce(
        dictare: DictareFalsa(disponibila: false),
        citire: CitireFalsa(),
      );
      expect(await faraMotor.pornesteDictarea((_) {}), isFalse);
      expect(faraMotor.asculta, isFalse);
      expect(faraMotor.eroare, contains('microfon'));

      final d = DictareFalsa()..porneste = false;
      final v = Voce(dictare: d, citire: CitireFalsa());
      expect(await v.pornesteDictarea((_) {}), isFalse);
      expect(v.eroare, contains('nu a putut porni'));

      final e = DictareFalsa();
      final w = Voce(dictare: e, citire: CitireFalsa());
      await w.pornesteDictarea((_) {});
      e.laEroare('error_network');
      expect(w.asculta, isFalse);
      expect(w.eroare, contains('internet'));
      e.laEroare('error_no_match');
      expect(w.eroare, contains('Nu am înțeles'));
    },
  );

  test(
    'citirea porneste la cerere, se opreste la a doua atingere si la sfarsit',
    () async {
      final c = CitireFalsa();
      final v = Voce(dictare: DictareFalsa(), citire: c);
      final a = Object();
      final b = Object();
      await v.comutaCitirea(a, 'Primul răspuns.');
      expect(v.citit, a);
      expect(c.citite, ['Primul răspuns.']);
      // alt mesaj il intrerupe pe primul
      await v.comutaCitirea(b, 'Al doilea.');
      expect(v.citit, b);
      // a doua atingere pe acelasi mesaj opreste
      await v.comutaCitirea(b, 'Al doilea.');
      expect(v.citit, isNull);
      expect(c.citite, hasLength(2));
      // motorul anunta sfarsitul citirii
      await v.comutaCitirea(a, 'Primul răspuns.');
      c.laSfarsit();
      expect(v.citit, isNull);

      c.strica = true;
      await v.comutaCitirea(a, 'x');
      expect(v.citit, isNull);
      expect(v.eroare, contains('nu este disponibilă'));
    },
  );

  test('dictarea si citirea nu merg in acelasi timp', () async {
    final d = DictareFalsa();
    final c = CitireFalsa();
    final v = Voce(dictare: d, citire: c);
    final mesaj = Object();
    await v.comutaCitirea(mesaj, 'Text');
    await v.pornesteDictarea((_) {});
    expect(v.citit, isNull);
    expect(v.asculta, isTrue);
    await v.comutaCitirea(mesaj, 'Text');
    expect(v.asculta, isFalse);
    expect(v.citit, mesaj);
  });

  test('textul pentru citire nu contine liniute si semne nepronuntate', () {
    expect(
      textPentruCitire(
        'Conform secțiunii 4.2:\n\n- doza inițială 50 mg\n- maxim 200 mg pe zi.\n\nVerifică RCP-ul',
      ),
      'Conform secțiunii 4.2: doza inițială 50 mg. maxim 200 mg pe zi. Verifică RCP-ul.',
    );
    expect(textPentruCitire('**Atenție** <test>'), 'Atenție test.');
    expect(textPentruCitire('  \n '), '');
  });
}
