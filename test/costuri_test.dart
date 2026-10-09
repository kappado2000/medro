import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medro/providers/asistent_provider.dart';
import 'package:medro/providers/interactiuni_provider.dart';
import 'package:medro/providers/medicamente_provider.dart';
import 'package:medro/services/claude_client.dart';
import 'package:medro/services/costuri.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('costul se calculeaza din cele patru feluri de tokeni', () {
    // prima intrebare cu un RCP de 61.000 de tokeni pe Sonnet 5.5
    const prima = Consum(
      model: 'claude-sonnet-5-5',
      intrare: 400,
      scriereCache: 61000,
      iesire: 600,
    );
    // 400*2 + 61000*2,5 + 600*10 = 159.300 milionimi de dolar
    expect(costUsd(prima), closeTo(0.1593, 1e-9));
    // a doua intrebare: documentul vine din cache
    const aDoua = Consum(
      model: 'claude-sonnet-5-5',
      intrare: 450,
      citireCache: 61000,
      iesire: 500,
    );
    expect(costUsd(aDoua), closeTo(0.0181, 1e-9));
    // Opus are intrarea si iesirea duble
    const opus = Consum(model: 'claude-opus-5-5', intrare: 1000, iesire: 1000);
    expect(costUsd(opus), closeTo(0.024, 1e-9));
    expect(prima.totalIntrare, 61400);
    // un model necunoscut se socoteste la tariful implicit, nu la zero
    expect(costUsd(const Consum(model: 'altceva', intrare: 1000000)), 2);
  });

  test('consumul se citeste din raspunsul API', () {
    final c = Consum.dinRaspuns({
      'model': 'claude-opus-5-5',
      'usage': {
        'input_tokens': 4,
        'cache_creation_input_tokens': 14416,
        'cache_read_input_tokens': 0,
        'output_tokens': 58,
        'cache_creation': {'ephemeral_5m_input_tokens': 14416},
      },
    }, 'claude-sonnet-5-5')!;
    expect(c.model, 'claude-opus-5-5');
    expect(
      (c.intrare, c.scriereCache, c.citireCache, c.iesire),
      (4, 14416, 0, 58),
    );
    expect(Consum.dinRaspuns(const {'content': []}, 'x'), isNull);
    final r = ClaudeClient.interpreteaza({
      'content': [
        {'type': 'text', 'text': 'Salut'},
      ],
      'usage': {'input_tokens': 10, 'output_tokens': 5},
    }, 'claude-opus-5-5');
    expect(r.consum!.model, 'claude-opus-5-5');
    expect(r.consum!.iesire, 5);
  });

  test('jurnalul aduna pe zi, luna si total si se pastreaza', () async {
    final j = JurnalCosturi();
    await j.incarca();
    expect(j.gol, isTrue);
    const c = Consum(model: 'claude-sonnet-5-5', intrare: 500000);
    await j.adauga(c, acum: DateTime(2026, 9, 30, 23, 50));
    await j.adauga(c, documente: 2, acum: DateTime(2026, 10, 9, 8));
    await j.adauga(c, acum: DateTime(2026, 10, 9, 18));
    await j.adauga(c, acum: DateTime(2026, 10, 1));

    expect(j.total.interogari, 4);
    expect(j.total.cost, closeTo(4, 1e-9));
    expect(j.zi(DateTime(2026, 10, 9)).interogari, 2);
    expect(j.zi(DateTime(2026, 10, 10)).interogari, 0);
    expect(j.luna(DateTime(2026, 10, 20)).cost, closeTo(3, 1e-9));
    expect(
      [for (final (l, s) in j.peLuni) (l.month, s.interogari)],
      [(10, 3), (9, 1)],
    );
    expect(j.toate.first.data, DateTime(2026, 10, 1));

    final altul = JurnalCosturi();
    await altul.incarca();
    expect(altul.total.interogari, 4);
    expect(altul.toate[2].documente, 2);
    await altul.goleste();
    final gol = JurnalCosturi();
    await gol.incarca();
    expect(gol.gol, isTrue);
  });

  test('formatarea sumelor si a tokenilor', () {
    expect(formatUsd(0.1593), '0,16 USD');
    expect(formatUsd(0.004), '0,004 USD');
    expect(formatUsd(0), '0,00 USD');
    expect(formatUsd(12.5), '12,50 USD');
    expect(formatTokeni(61240), '61.240');
    expect(formatTokeni(999), '999');
    expect(formatTokeni(1234567), '1.234.567');
    expect(numeLuna(DateTime(2026, 10, 9)), 'octombrie 2026');
  });

  test(
    'asistentul inregistreaza fiecare raspuns primit, nu si erorile',
    () async {
      final med = MedicamenteProvider();
      await med.incarca();
      final inter = InteractiuniProvider();
      await inter.incarca();
      var apel = 0;
      http.Response raspuns(Object corp, [int cod = 200]) =>
          http.Response.bytes(
            utf8.encode(jsonEncode(corp)),
            cod,
            headers: {'content-type': 'application/json'},
          );
      final p = AsistentProvider(
        ClaudeClient(
          MockClient((r) async {
            apel++;
            if (apel == 2) {
              return raspuns({
                'type': 'error',
                'error': {'type': 'overloaded_error', 'message': 'x'},
              }, 529);
            }
            return raspuns({
              'model': 'claude-sonnet-5-5',
              'stop_reason': 'end_turn',
              'content': [
                {'type': 'text', 'text': 'Raspuns'},
              ],
              'usage': {
                'input_tokens': 300,
                'cache_creation_input_tokens': 20000,
                'output_tokens': 200,
              },
            });
          }),
        ),
      );
      p.cheie = 'sk-test';
      final sertralina = med
          .cauta('sertralina arena', FiltruMedicamente.toate)
          .firstWhere((m) => m.rcpUrl.isNotEmpty);
      p.ataseaza(sertralina);

      await p.trimite('Prima', med, inter);
      await p.trimite('A doua', med, inter); // eroare 529
      await p.trimite('A treia', med, inter);

      expect(p.costuri.total.interogari, 2);
      // 300*2 + 20000*2,5 + 200*10 = 52.600 milionimi, de doua ori
      expect(p.costuri.total.cost, closeTo(0.1052, 1e-9));
      expect(p.costuri.toate.last.documente, 1); // prima intrebare a dus RCP-ul
      expect(p.costuri.toate.first.documente, 0);
      await p.golesteCosturi();
      expect(p.costuri.gol, isTrue);
    },
  );
}
