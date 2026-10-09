import 'package:flutter_test/flutter_test.dart';
import 'package:medro/providers/medicamente_provider.dart';
import 'package:medro/utils/rcp_extrase.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('radacinile leaga scrierea latina, englezeasca si romaneasca', () {
    expect(radaciniSubstanta(['SERTRALINUM', 'Sertraline']), ['sertralin']);
    expect(radaciniSubstanta(['METHYLPHENIDATUM']), ['metilfenidat']);
    expect(radaciniSubstanta(['ACIDUM VALPROICUM + SARURI']), ['valproic']);
    expect(radaciniSubstanta(['CHLORPROMAZINUM']), ['clorpromazin']);
    // cuvintele prea scurte nu deosebesc o substanta
    expect(radaciniSubstanta(['LITII CARBONAS', 'ACIDUM']), ['carbon']);
    expect(radaciniSubstanta(const []), isEmpty);
  });

  test(
    'gaseste frazele despre cealalta substanta, in orice forma a numelui',
    () {
      const sectiuni = {
        '4.3': 'Asocierea cu metilfenidat este contraindicată.',
        '4.4': 'Se recomandă prudență la pacienții vârstnici.',
        '4.5':
            'Administrarea concomitentă cu tramadol crește riscul de sindrom serotoninergic. '
            'Concentrația sertralinei nu este modificată de cimetidină. '
            'Expunerea la tramadolul administrat oral crește. '
            'Nu s-au efectuat studii cu antitramadolice.',
      };
      final tramadol = frazeDespre(
        sectiuni,
        radaciniSubstanta(['TRAMADOLUM', 'Tramadol']),
      );
      expect(tramadol.map((f) => f.sectiune), ['4.5', '4.5']);
      expect(tramadol.first.text, contains('sindrom serotoninergic'));
      // secventa din interiorul altui cuvant nu se potriveste
      expect(tramadol.any((f) => f.text.contains('antitramadolice')), isFalse);

      final mph = frazeDespre(
        sectiuni,
        radaciniSubstanta(['METHYLPHENIDATUM']),
      );
      expect(mph.single.sectiune, '4.3');
      expect(
        frazeDespre(sectiuni, radaciniSubstanta(['QUETIAPINUM'])),
        isEmpty,
      );
      expect(frazeDespre(sectiuni, const []), isEmpty);
      expect(frazeDespre(sectiuni, ['tramadol'], maxim: 1), hasLength(1));
    },
  );

  test('clasa se alege dupa cel mai lung prefix ATC', () {
    expect(clasaInteractiuni('N06AB06')!.nume, 'ISRS');
    expect(clasaInteractiuni('N06AX16')!.nume, 'IRSN');
    expect(clasaInteractiuni('N05AH02')!.nume, 'antipsihotice');
    expect(clasaInteractiuni('N05AN01')!.nume, 'litiu'); // nu "antipsihotice"
    expect(clasaInteractiuni('N02AX02')!.nume, 'opioide');
    expect(clasaInteractiuni('A10BA02'), isNull);
    expect(clasaInteractiuni(''), isNull);
  });

  test(
    'frazele despre clasa apar separat, fara a repeta pe cele cu numele',
    () {
      const sectiuni = {
        '4.5':
            'Asocierea cu sertralină crește riscul de sângerare. '
            'Inhibitorii selectivi ai recaptării serotoninei (ISRS) pot scădea pragul convulsivant. '
            'Sertralina și alți ISRS trebuie evitați. '
            'Nu se asociază cu antibiotice.',
      };
      final t = textDespre(
        'TRAMADOL TEST',
        sectiuni,
        radaciniSubstanta(['SERTRALINUM']),
        clasaInteractiuni('N06AB06'),
      );
      expect(t.produs, 'TRAMADOL TEST');
      expect(t.peNume, hasLength(2));
      expect(t.clasa, 'ISRS');
      expect(t.peClasa.single.text, contains('pragul convulsivant'));
      final faraClasa = textDespre('X', sectiuni, ['sertralin'], null);
      expect(faraClasa.clasa, isNull);
      expect(faraClasa.peClasa, isEmpty);
    },
  );

  test(
    'RCP-urile reale: clozapina si carbamazepina se pomenesc reciproc',
    () async {
      SharedPreferences.setMockInitialValues({});
      final med = MedicamenteProvider();
      await med.incarca();
      final r = await med.rcpDespre(
        ['CLOZAPINUM'],
        radaciniSubstanta(['CARBAMAZEPINUM', 'Carbamazepine']),
        atcAlta: 'N03AF01',
      );
      expect(r, isNotNull);
      expect(r!.produs, startsWith('LEPONEX'));
      expect(r.peNume, isNotEmpty);
      expect(
        r.peNume.every((f) => f.text.toLowerCase().contains('carbamazepin')),
        isTrue,
      );
      expect(
        r.peNume.every((f) => sectiuniInteractiuni.contains(f.sectiune)),
        isTrue,
      );
      expect(r.clasa, 'antiepileptice');
      final invers = await med.rcpDespre([
        'CARBAMAZEPINUM',
      ], radaciniSubstanta(['CLOZAPINUM', 'Clozapine']));
      expect(invers!.peNume, isNotEmpty);

      // tramadolul nu numeste sertralina, dar vorbeste despre clasa ei
      final tramadol = await med.rcpDespre(
        ['TRAMADOLUM'],
        radaciniSubstanta(['SERTRALINUM', 'Sertraline']),
        atcAlta: 'N06AB06',
      );
      expect(tramadol, isNotNull);
      expect(tramadol!.peClasa, isNotEmpty);
      expect(await med.rcpDespre(['SUBSTANTA INEXISTENTA'], ['orice']), isNull);
    },
  );
}
