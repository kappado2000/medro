import 'package:flutter_test/flutter_test.dart';
import 'package:medro/models/medicament.dart';
import 'package:medro/providers/medicamente_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MedicamenteProvider med;

  Medicament produs(String atc) =>
      med.cauta('', FiltruMedicamente.toate, atcPrefix: atc).first;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    med = MedicamenteProvider();
    await med.incarca();
  });

  test('lista de protocoale se incarca intreaga', () {
    expect(med.totalProtocoale, greaterThan(400));
    expect(med.dataProtocoale, isNotEmpty);
  });

  test('psihotropele isi gasesc protocolul dupa substanta', () {
    final clozapina = med.protocoale(produs('N05AH02'));
    expect(clozapina.map((p) => p.cod), ['N016F']);
    expect(clozapina.single.denumire, 'CLOZAPINUM');
    expect(clozapina.single.sublista, 'C1-G15');
    expect(clozapina.single.medicFamilie, 'NU');
    expect(
      clozapina.single.legatura,
      matches(RegExp(r'^https://cnas\.ro/.+\.pdf#page=\d+$')),
    );

    expect(
      med.protocoale(produs('N05AH03')).map((p) => p.cod),
      contains('N003F'),
    );
    expect(
      med.protocoale(produs('N06BA09')).map((p) => p.cod),
      contains('N0020F'),
    );
  });

  test('protocoalele cu cod ATC se potrivesc si dupa cod', () {
    final cariprazina = med.protocoale(produs('N05AX15'));
    expect(cariprazina.map((p) => p.cod), contains('N05AX15'));
  });

  test('medicamentele fara protocol nu primesc unul din greseala', () {
    expect(med.protocoale(produs('N02BE01')), isEmpty); // paracetamol
    expect(med.protocoale(produs('N05BA01')), isEmpty); // diazepam
    // metformina simpla nu primeste protocoalele combinatiilor cu metformina
    expect(med.protocoale(produs('A10BA02')), isEmpty);
    // nicio linie din lista nu a ramas cu antetul de pagina in ea
    for (final atc in ['N03AX16', 'N05AH04', 'N06AX16']) {
      for (final p in med.protocoale(produs(atc))) {
        expect(p.medicFamilie, isNot(contains('COD PROTOCOL')), reason: p.cod);
      }
    }
  });
}
