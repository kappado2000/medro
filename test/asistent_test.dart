import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medro/help/ajutor.dart';
import 'package:medro/models/medicament.dart';
import 'package:medro/providers/asistent_provider.dart';
import 'package:medro/providers/interactiuni_provider.dart';
import 'package:medro/providers/medicamente_provider.dart';
import 'package:medro/services/claude_client.dart';
import 'package:medro/services/data_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response jsonRaspuns(Object corp, [int cod = 200]) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(corp)),
    cod,
    headers: {'content-type': 'application/json'},
  );
}

Map<String, dynamic> raspunsText(String text, {String stop = 'end_turn'}) => {
  'stop_reason': stop,
  'content': [
    {'type': 'thinking', 'thinking': '', 'signature': 'sig'},
    {'type': 'text', 'text': text},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MedicamenteProvider med;
  late InteractiuniProvider inter;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    med = MedicamenteProvider();
    await med.incarca();
    inter = InteractiuniProvider();
    await inter.incarca();
  });

  group('ClaudeClient', () {
    test('trimite antetele si corpul asteptate', () async {
      late http.Request cerere;
      final client = ClaudeClient(
        MockClient((r) async {
          cerere = r;
          return jsonRaspuns(raspunsText('Salut'));
        }),
      );
      final r = await client.trimite(
        cheie: 'sk-test',
        system: 'instructiuni',
        mesaje: [
          {'role': 'user', 'content': 'Buna'},
        ],
      );
      expect(r.text, 'Salut');
      expect(cerere.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(cerere.headers['x-api-key'], 'sk-test');
      expect(cerere.headers['anthropic-version'], '2023-06-01');
      expect(
        cerere.headers['anthropic-beta'],
        'server-side-fallback-2026-07-01',
      );
      final corp = jsonDecode(cerere.body) as Map<String, dynamic>;
      expect(corp['model'], 'claude-sonnet-5-5');
      expect(corp['fallbacks'], 'default');
      expect(corp['system'], [
        {
          'type': 'text',
          'text': 'instructiuni',
          'cache_control': {'type': 'ephemeral'},
        },
      ]);
      expect(corp['output_config'], {'effort': 'medium'});
      expect(corp['cache_control'], {'type': 'ephemeral'});
      expect(corp.containsKey('thinking'), isFalse);
      expect(corp.containsKey('temperature'), isFalse);
    });

    test(
      'fara cheie proprie, cererea merge prin server cu codul de acces',
      () async {
        late http.Request cerere;
        final client = ClaudeClient(
          MockClient((r) async {
            cerere = r;
            return jsonRaspuns(raspunsText('Prin server'));
          }),
          'https://exemplu.test/medroAsistent',
          'cod-acces',
        );
        expect(client.areServer, isTrue);
        final r = await client.trimite(
          model: 'claude-opus-5-5',
          system: 'instructiuni',
          mesaje: [
            {'role': 'user', 'content': 'Buna'},
          ],
        );
        expect(r.text, 'Prin server');
        expect(cerere.url.toString(), 'https://exemplu.test/medroAsistent');
        expect(cerere.headers['x-medro-token'], 'cod-acces');
        expect(cerere.headers.containsKey('x-api-key'), isFalse);
        expect(jsonDecode(cerere.body), {
          'model': 'claude-opus-5-5',
          'system': 'instructiuni',
          'messages': [
            {'role': 'user', 'content': 'Buna'},
          ],
        });
      },
    );

    test('erorile serverului propriu au mesaje distincte', () async {
      Future<String> mesaj(int cod) async {
        final client = ClaudeClient(
          MockClient((_) async => http.Response('<html>eroare</html>', cod)),
          'https://exemplu.test/medroAsistent',
          'cod-acces',
        );
        try {
          await client.trimite(system: 's', mesaje: const []);
        } on ClaudeException catch (e) {
          return e.mesaj;
        }
        fail('nu a aruncat');
      }

      expect(await mesaj(404), contains('nu este publicat'));
      expect(await mesaj(403), contains('a respins codul de acces'));
    });

    test('fara server si fara cheie nu se trimite nimic', () async {
      var apeluri = 0;
      final client = ClaudeClient(
        MockClient((_) async {
          apeluri++;
          return jsonRaspuns(raspunsText('x'));
        }),
        '',
        '',
      );
      expect(client.areServer, isFalse);
      await expectLater(
        client.trimite(system: 's', mesaje: const []),
        throwsA(isA<ClaudeException>()),
      );
      expect(apeluri, 0);
    });

    test('extrage textul si citarile, ignorand blocurile de gandire', () {
      final r = ClaudeClient.interpreteaza({
        'stop_reason': 'end_turn',
        'content': [
          {'type': 'thinking', 'thinking': '', 'signature': 's'},
          {'type': 'text', 'text': 'Doza se reduce '},
          {
            'type': 'text',
            'text': 'la jumătate.',
            'citations': [
              {
                'type': 'page_location',
                'cited_text': ' doza trebuie redusă ',
                'document_title': 'RCP X',
                'start_page_number': 3,
                'end_page_number': 4,
              },
            ],
          },
        ],
      });
      expect(r.text, 'Doza se reduce la jumătate.');
      expect(r.citari.single.document, 'RCP X');
      expect(r.citari.single.pagina, 3);
      expect(r.citari.single.text, 'doza trebuie redusă');
      expect(r.continutBrut, hasLength(3));
      expect(r.refuzat, isFalse);
    });

    test('recunoaste refuzul si trunchierea', () {
      expect(
        ClaudeClient.interpreteaza({'stop_reason': 'refusal', 'content': []})
            .refuzat,
        isTrue,
      );
      expect(
        ClaudeClient.interpreteaza(raspunsText('x', stop: 'max_tokens'))
            .trunchiat,
        isTrue,
      );
    });

    test('traduce erorile HTTP in mesaje pentru utilizator', () async {
      Future<ClaudeException> eroare(int cod) async {
        final client = ClaudeClient(
          MockClient(
            (_) async => jsonRaspuns({
              'type': 'error',
              'error': {'type': 'x', 'message': 'detaliu'},
            }, cod),
          ),
        );
        try {
          await client.trimite(cheie: 'k', system: 's', mesaje: const []);
        } on ClaudeException catch (e) {
          return e;
        }
        fail('nu a aruncat');
      }

      expect((await eroare(401)).mesaj, contains('nu este validă'));
      expect((await eroare(429)).mesaj, contains('Limita de cereri'));
      expect((await eroare(529)).mesaj, contains('supraîncărcat'));
      final e400 = await eroare(400);
      expect(e400.cod, 400);
      expect(e400.mesaj, contains('detaliu'));
    });
  });

  group('AsistentProvider', () {
    AsistentProvider cuRaspunsuri(
      List<http.Response Function(http.Request)> pasi,
      List<http.Request> cereri,
    ) {
      var i = 0;
      final p = AsistentProvider(
        ClaudeClient(
          MockClient((r) async {
            cereri.add(r);
            return pasi[i++](r);
          }),
        ),
      );
      p.cheie = 'sk-test';
      return p;
    }

    List<dynamic> mesajeDin(http.Request r) =>
        (jsonDecode(r.body) as Map<String, dynamic>)['messages'] as List;

    test(
      'primul mesaj contine RCP-ul, datele din aplicatie si intrebarea',
      () async {
        final cereri = <http.Request>[];
        final p = cuRaspunsuri([
          (_) => jsonRaspuns(raspunsText('Raspuns 1')),
        ], cereri);
        final sertralina = med
            .cauta('sertralina arena', FiltruMedicamente.toate)
            .firstWhere((m) => m.rcpUrl.isNotEmpty);
        final tramadol = med
            .cauta('tramadol', FiltruMedicamente.toate)
            .firstWhere((m) => m.dci == 'TRAMADOLUM' && m.rcpUrl.isNotEmpty);
        p.ataseaza(sertralina);
        p.ataseaza(tramadol);

        await p.trimite('Ce interacțiune există?', med, inter);

        final continut =
            (mesajeDin(cereri.single).single as Map)['content'] as List;
        final documente = continut
            .where((b) => b['type'] == 'document')
            .toList();
        expect(documente, hasLength(2));
        // RCP-urile cu sectiuni extrase merg ca text, nu ca PDF
        expect(documente.first['source']['type'], 'text');
        expect(documente.first['title'], 'RCP ${sertralina.denumire} (extras)');
        expect(
          documente.first['source']['data'],
          contains('4.2 Doze și mod de administrare'),
        );
        expect(documente.first['citations'], {'enabled': true});
        // punctul de cache sta doar pe ultimul document
        expect(documente.first.containsKey('cache_control'), isFalse);
        expect(documente.last['cache_control'], {'type': 'ephemeral'});
        final date =
            continut.firstWhere(
                  (b) =>
                      b['type'] == 'text' &&
                      (b['text'] as String).startsWith('<date_aplicatie>'),
                )['text']
                as String;
        expect(date, contains('Sertralinum'));
        expect(date, endsWith('</date_aplicatie>'));
        expect(date, contains('Sertralinum + Tramadolum: severitate majoră'));
        expect(continut.last, {
          'type': 'text',
          'text': 'Ce interacțiune există?',
        });
        expect(p.mesaje.map((m) => m.text), [
          'Ce interacțiune există?',
          'Raspuns 1',
        ]);
        expect(p.asteapta, isFalse);
      },
    );

    test('RCP-ul EMA se trimite ca extras de text, nu ca PDF', () async {
      final cereri = <http.Request>[];
      final p = cuRaspunsuri([
        (_) => jsonRaspuns(raspunsText('Raspuns')),
      ], cereri);
      final index =
          (await DataStore.instance.jsonGz('rcp/index.json.gz')) as Map;
      final ema = med
          .cauta('', FiltruMedicamente.toate, atcPrefix: 'N05A')
          .firstWhere((m) => m.centralizat && index.containsKey(m.rcpUrl));
      p.ataseaza(ema);

      await p.trimite('Care este doza maximă?', med, inter);

      final continut =
          (mesajeDin(cereri.single).single as Map)['content'] as List;
      final document = continut.singleWhere((b) => b['type'] == 'document');
      expect(document['title'], 'RCP ${ema.denumire} (extras)');
      expect(document['citations'], {'enabled': true});
      expect(document['cache_control'], {'type': 'ephemeral'});
      final sursa = document['source'] as Map;
      expect(sursa['type'], 'text');
      expect(sursa['media_type'], 'text/plain');
      final text = sursa['data'] as String;
      expect(text, contains('4.2 Doze și mod de administrare'));
      expect(text.length, lessThan(80000));
      if (med.contraindicatii(ema) != null) {
        expect(text, contains('4.3 Contraindicații'));
      }
      // sectiunile apar in ordinea din RCP
      expect(
        AsistentProvider.textExtras(const {'4.4': 'b', '4.1': 'a'}, 'c'),
        endsWith(
          '4.1 Indicații terapeutice\na\n\n4.3 Contraindicații\nc\n\n'
          '4.4 Atenționări și precauții\nb',
        ),
      );
    });

    test('PDF-ul EMA intreg nu se trimite cand extrasul lipseste', () async {
      final cereri = <http.Request>[];
      final p = cuRaspunsuri([
        (_) => jsonRaspuns(raspunsText('Raspuns')),
      ], cereri);
      final ema = med
          .cauta('', FiltruMedicamente.toate)
          .firstWhere((m) => m.centralizat && m.rcpUrl.isNotEmpty);
      p.ataseaza(ema);
      final continut = p.continutMesaj(
        'Intrebare',
        med,
        inter,
        cuDocumente: true,
      );
      expect(continut.where((b) => b['type'] == 'document'), isEmpty);
      expect(continut.last, {'type': 'text', 'text': 'Intrebare'});
    });

    test('instructiunile contin ghidul aplicatiei, din paginile de ajutor', () async {
      final cereri = <http.Request>[];
      final p = cuRaspunsuri([
        (_) => jsonRaspuns(raspunsText('Raspuns')),
      ], cereri);
      await p.trimite('Unde văd costurile?', med, inter);
      final system =
          ((jsonDecode(cereri.single.body) as Map<String, dynamic>)['system']
                      as List)
                  .single['text']
              as String;
      expect(system, startsWith(instructiuniAsistent));
      expect(system, contains('<ghid_aplicatie>'));
      expect(system, contains('</ghid_aplicatie>'));
      expect(system, endsWith('</glosar>'));
      // fiecare cod de prescriptie si fiecare sublista din date are explicatie
      for (final cod in {
        for (final m in med.cauta('', FiltruMedicamente.toate, atcPrefix: 'N'))
          ...m.prescriptie.split(RegExp(r'[/,]')),
      }) {
        if (cod.trim().isEmpty || cod.trim() == 'R') continue;
        expect(system, contains(cod.trim()), reason: cod);
        expect(explicatiePrescriptie(cod.trim()), isNotNull, reason: cod);
      }
      for (final sublista in ['A', 'B', 'C1', 'C2', 'C3', 'D']) {
        expect(system, contains('Sublista $sublista:'));
      }
      for (final a in toateAjutoarele) {
        expect(system, contains('## ${a.titlu}'), reason: a.titlu);
        expect(
          system,
          contains(a.capitole.last.puncte.last.$2),
          reason: a.titlu,
        );
      }
      expect(system, contains('- Costuri: iconița cu bancnote'));
      // ghidul ramane mic fata de un RCP
      expect(textGhidAplicatie().length, lessThan(60000));
    });

    test('a doua intrebare retrimite istoricul neschimbat, cu blocurile de gandire', () async {
      final cereri = <http.Request>[];
      final p = cuRaspunsuri([
        (_) => jsonRaspuns(raspunsText('Unu')),
        (_) => jsonRaspuns(raspunsText('Doi')),
      ], cereri);
      await p.trimite('Prima', med, inter);
      await p.trimite('A doua', med, inter);

      final prima = mesajeDin(cereri[0]);
      final aDoua = mesajeDin(cereri[1]);
      expect(aDoua, hasLength(3));
      expect(aDoua[0], prima[0]);
      expect(aDoua[1]['role'], 'assistant');
      expect((aDoua[1]['content'] as List).first['type'], 'thinking');
      expect(aDoua[2]['content'], [
        {'type': 'text', 'text': 'A doua'},
      ]);
    });

    test(
      'daca RCP-ul nu poate fi atasat, reia intrebarea fara document',
      () async {
        final cereri = <http.Request>[];
        final p = cuRaspunsuri([
          (_) => jsonRaspuns({
            'type': 'error',
            'error': {
              'type': 'invalid_request_error',
              'message': 'could not fetch',
            },
          }, 400),
          (_) => jsonRaspuns(raspunsText('Fara RCP')),
        ], cereri);
        p.ataseaza(
          med
              .cauta('sertralina', FiltruMedicamente.toate)
              .firstWhere((m) => m.rcpUrl.isNotEmpty),
        );
        await p.trimite('Întrebare', med, inter);

        expect(cereri, hasLength(2));
        final reluat = (mesajeDin(cereri[1]).single as Map)['content'] as List;
        expect(reluat.any((b) => b['type'] == 'document'), isFalse);
        expect(
          p.mesaje.where((m) => m.avertizare).single.text,
          contains('nu a putut fi atașat'),
        );
        expect(p.mesaje.last.text, 'Fara RCP');
      },
    );

    test('eroarea de cheie apare ca mesaj si nu intra in istoric', () async {
      final cereri = <http.Request>[];
      final p = cuRaspunsuri([
        (_) => jsonRaspuns({
          'type': 'error',
          'error': {
            'type': 'authentication_error',
            'message': 'invalid x-api-key',
          },
        }, 401),
        (_) => jsonRaspuns(raspunsText('Ok')),
      ], cereri);
      await p.trimite('Test', med, inter);
      expect(p.mesaje.last.avertizare, isTrue);
      expect(p.conversatieInceputa, isFalse);
      await p.trimite('Din nou', med, inter);
      expect(mesajeDin(cereri[1]), hasLength(1));
    });

    test('schimbarea atasarilor porneste o conversatie noua', () async {
      final cereri = <http.Request>[];
      final p = cuRaspunsuri([(_) => jsonRaspuns(raspunsText('Unu'))], cereri);
      await p.trimite('Prima', med, inter);
      expect(p.conversatieInceputa, isTrue);
      p.ataseaza(med.cauta('paracetamol', FiltruMedicamente.toate).first);
      expect(p.conversatieInceputa, isFalse);
      expect(p.mesaje, isEmpty);
      expect(p.atasate, hasLength(1));
    });

    test(
      'modelul ales se trimite, se salveaza si reporneste conversatia',
      () async {
        SharedPreferences.setMockInitialValues({});
        final cereri = <http.Request>[];
        final p = cuRaspunsuri([
          (_) => jsonRaspuns(raspunsText('Unu')),
          (_) => jsonRaspuns(raspunsText('Doi')),
        ], cereri);
        expect(p.model, 'claude-sonnet-5-5');
        await p.trimite('Prima', med, inter);
        await p.seteazaModel('claude-opus-5-5');
        expect(p.conversatieInceputa, isFalse);
        await p.trimite('A doua', med, inter);

        String modelDin(http.Request r) =>
            (jsonDecode(r.body) as Map<String, dynamic>)['model'] as String;
        expect(modelDin(cereri[0]), 'claude-sonnet-5-5');
        expect(modelDin(cereri[1]), 'claude-opus-5-5');
        expect(mesajeDin(cereri[1]), hasLength(1));

        await p.seteazaModel('model-inexistent');
        expect(p.model, 'claude-opus-5-5');
        final q = AsistentProvider();
        await q.incarca();
        expect(q.model, 'claude-opus-5-5');
      },
    );

    test('cheia se salveaza si se sterge', () async {
      SharedPreferences.setMockInitialValues({});
      final p = AsistentProvider();
      await p.incarca();
      expect(p.areCheie, isFalse);
      await p.seteazaCheie('  sk-ant-abc  ');
      final q = AsistentProvider();
      await q.incarca();
      expect(q.cheie, 'sk-ant-abc');
      await q.seteazaCheie('');
      final r = AsistentProvider();
      await r.incarca();
      expect(r.areCheie, isFalse);
    });
  });
}
