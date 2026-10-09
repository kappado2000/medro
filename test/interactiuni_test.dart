import 'package:flutter_test/flutter_test.dart';
import 'package:medro/providers/interactiuni_provider.dart';
import 'package:medro/screens/interactiuni_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InteractiuniProvider provider;

  Substanta gaseste(String nume) {
    return provider.cauta(nume).firstWhere((s) => s.denumireEn == nume);
  }

  setUpAll(() async {
    provider = InteractiuniProvider();
    await provider.incarca();
  });

  test('baza se incarca', () {
    expect(provider.eroare, isNull);
    expect(provider.totalSubstante, greaterThan(700));
    expect(provider.sursa, contains('CC BY-NC-SA'));
  });

  test('cautarea merge dupa DCI si dupa denumirea englezeasca', () {
    expect(provider.cauta('sertralinum').first.denumireEn, 'Sertraline');
    expect(provider.cauta('Sertraline').first.dci, ['SERTRALINUM']);
    expect(provider.cauta('paracetamol').first.denumireEn, 'Acetaminophen');
    expect(provider.cauta('lithium').first.denumireEn, 'Lithium carbonate');
    expect(provider.cauta('clozapina').first.denumireEn, 'Clozapine');
    expect(provider.cauta('olanzapina').first.denumireEn, 'Olanzapine');
    expect(provider.cauta(''), isEmpty);
    expect(provider.cauta('zzzzqqq'), isEmpty);
  });

  test('severitatea e simetrica si absenta intre o substanta si ea insasi', () {
    final sertralina = gaseste('Sertraline');
    final tramadol = gaseste('Tramadol');
    expect(provider.severitate(sertralina, tramadol), Severitate.majora);
    expect(provider.severitate(tramadol, sertralina), Severitate.majora);
    expect(provider.severitate(sertralina, sertralina), isNull);
  });

  test('perechi psihiatrice de control', () {
    expect(
      provider.severitate(gaseste('Clozapine'), gaseste('Carbamazepine')),
      Severitate.majora,
    );
    expect(
      provider.severitate(gaseste('Lithium carbonate'), gaseste('Ibuprofen')),
      Severitate.majora,
    );
    expect(
      provider.severitate(gaseste('Clozapine'), gaseste('Fluvoxamine')),
      Severitate.moderata,
    );
  });

  test('verificarea unei liste intoarce perechile sortate dupa gravitate', () {
    final lista = [
      gaseste('Clozapine'),
      gaseste('Fluvoxamine'),
      gaseste('Carbamazepine'),
    ];
    final rezultate = provider.verifica(lista);
    expect(rezultate, isNotEmpty);
    expect(rezultate.length, lessThanOrEqualTo(3));
    expect(rezultate.first.severitate, Severitate.majora);
    final niveluri = rezultate.map((r) => r.severitate.index).toList();
    expect(niveluri, [...niveluri]..sort());
    expect(provider.verifica([lista.first]), isEmpty);
  });

  test('partenerele majore includ ambele directii ale perechii', () {
    final sertralina = gaseste('Sertraline');
    final tramadol = gaseste('Tramadol');
    expect(
      provider.partenere(sertralina, Severitate.majora),
      contains(tramadol),
    );
    expect(
      provider.partenere(tramadol, Severitate.majora),
      contains(sertralina),
    );
  });

  test('selectia nu dubleaza substantele si anunta ascultatorii', () {
    var notificari = 0;
    provider.addListener(() => notificari++);
    final sertralina = gaseste('Sertraline');
    final tramadol = gaseste('Tramadol');
    provider.adaugaInSelectie([sertralina]);
    provider.adaugaInSelectie([sertralina, tramadol]);
    expect(provider.selectie, [sertralina, tramadol]);
    provider.scoateDinSelectie(sertralina);
    expect(provider.selectie, [tramadol]);
    provider.golesteSelectia();
    expect(provider.selectie, isEmpty);
    expect(notificari, 4);
  });

  test('sumarul se acorda la singular si plural', () {
    expect(
      textSumar(0, 1, 0),
      'Nicio interacțiune înregistrată pentru perechea verificată.',
    );
    expect(
      textSumar(0, 3, 0),
      'Nicio interacțiune înregistrată pentru cele 3 perechi verificate.',
    );
    expect(
      textSumar(1, 1, 1),
      'O interacțiune la perechea verificată, majoră.',
    );
    expect(textSumar(1, 3, 0), 'O interacțiune din 3 perechi.');
    expect(
      textSumar(3, 3, 1),
      '3 interacțiuni din 3 perechi, dintre care una majoră.',
    );
    expect(
      textSumar(3, 3, 2),
      '3 interacțiuni din 3 perechi, dintre care 2 majore.',
    );
    expect(textSumar(2, 3, 2), '2 interacțiuni din 3 perechi, toate majore.');
  });

  test('combinatiile acoperite partial isi declara componentele lipsa', () {
    expect(provider.componenteNeacoperite('SERTRALINUM'), isEmpty);
    expect(provider.componenteNeacoperite('DCI INEXISTENT'), isEmpty);
  });

  test('produsele combinate dau toate substantele', () {
    expect(
      provider.substanteProdus('SERTRALINUM').single.denumireEn,
      'Sertraline',
    );
    expect(provider.substanteProdus('DCI INEXISTENT'), isEmpty);
  });

  test(
    'alternativele sunt din aceeasi subgrupa si fara interactiune majora',
    () {
      const atc = {
        'SERTRALINUM': 'N06AB06',
        'CITALOPRAMUM': 'N06AB04',
        'ESCITALOPRAMUM': 'N06AB10',
        'FLUOXETINUM': 'N06AB03',
        'PAROXETINUM': 'N06AB05',
        'MIRTAZAPINUM': 'N06AX11',
        'TRAMADOLUM': 'N02AX02',
      };
      final sertralina = gaseste('Sertraline');
      final tramadol = gaseste('Tramadol');
      expect(provider.clasaAtc(sertralina, atc), 'N06AB');
      expect(provider.clasaAtc(sertralina, const {}), isNull);

      final alt = provider.alternative(sertralina, [tramadol], atc);
      for (final (s, sev) in alt) {
        expect(provider.clasaAtc(s, atc), 'N06AB');
        expect(s.index, isNot(sertralina.index));
        expect(sev, isNot(Severitate.majora));
        expect(provider.severitate(s, tramadol), sev);
      }
      // fara alte substante in lista, toata subgrupa este disponibila
      final toate = provider.alternative(sertralina, const [], atc);
      expect(toate.map((e) => e.$1.denumireEn), contains('Citalopram'));
      expect(toate.every((e) => e.$2 == null), isTrue);
      expect(toate.length, greaterThanOrEqualTo(alt.length));
      expect(provider.alternative(sertralina, [tramadol], const {}), isEmpty);
    },
  );

  test('inlocuirea in selectie pastreaza pozitia', () {
    final p = InteractiuniProvider();
    final a = gaseste('Sertraline');
    final b = gaseste('Tramadol');
    final c = gaseste('Citalopram');
    p.adaugaInSelectie([a, b]);
    p.inlocuiesteInSelectie(a, c);
    expect(p.selectie.map((s) => s.denumireEn), ['Citalopram', 'Tramadol']);
    p.inlocuiesteInSelectie(c, b); // deja in lista: nu se dubleaza
    expect(p.selectie.map((s) => s.denumireEn), ['Citalopram', 'Tramadol']);
  });
}
