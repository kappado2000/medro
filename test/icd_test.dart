import 'package:flutter_test/flutter_test.dart';
import 'package:medro/providers/icd_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late IcdProvider provider;

  setUpAll(() async {
    provider = IcdProvider();
    await provider.incarca();
  });

  test('clasificarea se incarca, cu psihiatria pe primul loc', () {
    expect(provider.eroare, isNull);
    expect(provider.total, greaterThan(12000));
    expect(provider.capitole, hasLength(22));
    expect(provider.capitole.first.numar, 'V');
    expect(provider.capitole.first.interval, 'F00–F99');
  });

  test('capitolul F contine categoriile asteptate', () {
    final categorii = provider.categorii(provider.capitole.first);
    final coduri = categorii.map((c) => c.cod).toList();
    expect(categorii.every((c) => c.esteCategorie), isTrue);
    expect(coduri, containsAll(['F00', 'F10', 'F20', 'F32', 'F41', 'F99']));
    expect(coduri.every((c) => c.startsWith('F')), isTrue);
  });

  test('subcodurile sunt doar cele directe', () {
    final f32 = provider.cauta('F32').first;
    expect(f32.cod, 'F32');
    final sub = provider.subcoduri(f32).map((c) => c.cod).toList();
    expect(sub, containsAll(['F32.0', 'F32.1', 'F32.2', 'F32.3']));
    expect(sub.every((c) => c.length == 5), isTrue);
    expect(provider.areSubcoduri(f32), isTrue);

    final f603 = provider.cauta('F60.3').first;
    final sub5 = provider.subcoduri(f603).map((c) => c.cod).toList();
    expect(sub5, contains('F60.31'));
    expect(sub5.every((c) => c.startsWith('F60.3') && c.length == 6), isTrue);
  });

  test('cautarea merge dupa cod, cu sau fara punct, si dupa denumire', () {
    expect(provider.cauta('f20.0').first.titlu, 'Schizofrenia paranoida');
    expect(provider.cauta('F200').first.cod, 'F20.0');
    expect(
      provider.cauta('i10').first.titlu,
      contains('Hipertensiunea esentiala'),
    );

    final dupaNume = provider.cauta('episod depresiv');
    expect(dupaNume.first.cod, 'F32');
    expect(dupaNume.map((c) => c.cod), contains('F32.0'));

    // diacriticele din interogare nu conteaza
    expect(provider.cauta('schizofrenia paranoidă'), isNotEmpty);
    expect(provider.cauta(''), isEmpty);
    expect(provider.cauta('zzzzqqq'), isEmpty);
  });

  test('F70-F79 au subcategoriile comune', () {
    final r = provider.cauta('F70.1');
    expect(r.first.cod, 'F70.1');
    expect(r.first.titlu, startsWith('Retardare mentala usoara'));
    final f70 = provider.cauta('F70').first;
    expect(provider.subcoduri(f70).map((c) => c.cod), [
      'F70.0',
      'F70.1',
      'F70.8',
      'F70.9',
    ]);
  });

  test('F10-F19 au subcategoriile comune', () {
    final r = provider.cauta('F10.2');
    expect(r.first.cod, 'F10.2');
    expect(r.first.titlu, contains('sindrom de dependenta'));
  });
}
