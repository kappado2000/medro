import 'package:flutter_test/flutter_test.dart';
import 'package:medro/services/data_store.dart';
import 'package:medro/utils/rcp_extrase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sectiuni = {
    '4.2':
        'Doza inițială este de 50 mg pe zi. La pacienții cu insuficiență renală nu este '
        'necesară ajustarea dozei (vezi pct. 5.2). La pacienții cu insuficiență hepatică '
        'trebuie administrate doze mai mici.\nVârstnici: se recomandă prudență.',
    '4.4':
        'Se recomandă monitorizarea atentă a pacienților. Prelungirea intervalului QT a '
        'fost raportată. La pacienții cu insuficiență renală nu este necesară ajustarea '
        'dozei (vezi pct. 5.2).',
    '4.5':
        'Sertralina este un inhibitor slab al CYP2D6. Inhibitorii puternici ai CYP3A4 '
        'cresc expunerea. Metabolizarea implică și CYP 2C19.',
  };

  TemaRcp tema(String id) => temeRcp.firstWhere((t) => t.id == id);

  test('frazele nu se rup dupa abrevieri', () {
    final f = fraze('Vezi mai jos (vezi pct. 5.2). A doua frază; a treia.');
    expect(f, ['Vezi mai jos (vezi pct. 5.2).', 'A doua frază;', 'a treia.']);
  });

  test(
    'extrage frazele temei, cu sectiunea de provenienta, fara repetitii',
    () {
      final renal = extrage(tema('renal'), sectiuni);
      expect(renal, hasLength(1));
      expect(renal.single.sectiune, '4.2');
      expect(renal.single.text, contains('insuficiență renală'));

      final hepatic = extrage(tema('hepatic'), sectiuni);
      expect(hepatic.single.text, contains('doze mai mici'));

      expect(
        extrage(tema('varstnici'), sectiuni).single.text,
        startsWith('Vârstnici'),
      );
      expect(extrage(tema('monitorizare'), sectiuni).single.sectiune, '4.4');
      expect(extrage(tema('qt'), sectiuni).single.text, contains('QT'));
      expect(extrage(tema('cyp'), sectiuni), hasLength(3));
      expect(
        extrage(tema('qt'), const {'4.1': 'Indicat în depresie.'}),
        isEmpty,
      );
    },
  );

  test('limita de fraze este respectata', () {
    final multe = {
      '4.4': List.generate(
        30,
        (i) => 'Se recomandă monitorizarea $i.',
      ).join(' '),
    };
    expect(extrage(tema('monitorizare'), multe, maxim: 5), hasLength(5));
  });

  test('izoenzimele sunt recunoscute, cu sau fara spatiu', () {
    expect(izoenzime(sectiuni), ['CYP2C19', 'CYP2D6', 'CYP3A4']);
    expect(izoenzime(const {'4.5': 'Fără interacțiuni cunoscute.'}), isEmpty);
  });

  test('sectiunile unui RCP se incarca la cerere din pachete', () async {
    final index = (await DataStore.instance.jsonGz('rcp/index.json.gz')) as Map;
    expect(index, isNotEmpty);
    final url = index.keys.first as String;
    final s = await RcpStore.instance.sectiuni(url);
    expect(s, isNotEmpty);
    expect(s.keys.every((k) => RegExp(r'^4\.\d$').hasMatch(k)), isTrue);
    expect(
      s.containsKey('4.3'),
      isFalse,
    ); // contraindicatiile se incarca separat
    expect(
      await RcpStore.instance.sectiuni('https://exemplu.test/inexistent.pdf'),
      isEmpty,
    );
    expect(await RcpStore.instance.sectiuni(''), isEmpty);
    expect(DataStore.instance.versiune, isNotEmpty);
  });
}
