import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medro/models/sinteza.dart';
import 'package:medro/providers/sinteza_provider.dart';
import 'package:medro/screens/home_shell.dart';
import 'package:medro/screens/sinteza_screen.dart';
import 'package:medro/services/notificari_sinteza.dart';
import 'package:medro/services/sinteza_store.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

Map<String, dynamic> _articol(String id, String sectiune, String titlu) => {
  'id': id,
  'sectiune': sectiune,
  'titlu': titlu,
  'rezumat': 'Rezumatul articolului $id.',
  'text': 'Primul paragraf.\n\nAl doilea paragraf.\n\n\nAl treilea.',
  'de_ce_conteaza': 'Miza articolului $id.',
  'loc': 'Stockholm, Suedia',
  'sursa': {
    'nume': 'Nature',
    'url': 'https://www.nature.com/articles/x',
    'data': '2026-10-05',
  },
  'alte_surse': [
    {'nume': 'CNN', 'url': 'https://www.cnn.com/y'},
  ],
  'trimiteri': [
    {
      'titlu': 'Optogenetica',
      'url': 'https://en.wikipedia.org/wiki/Optogenetics',
    },
  ],
  'imagine': null,
};

Map<String, dynamic> _editie(String id, String interval) => {
  'id': id,
  'data': '2026-10-10',
  'interval': interval,
  'titlu': 'Titlul ediției $id',
  'introducere': 'Introducerea ediției.',
  'articole': [
    _articol('a1', 'medicina', 'Articol de medicină'),
    _articol('a2', 'stiinta', 'Articol de științe'),
    _articol('a3', 'arta', 'Articol de artă'),
  ],
};

const _intervalNou = '3–10 octombrie 2026';
const _intervalVechi = '26 septembrie – 3 octombrie 2026';

final _index = {
  'editii': [
    {
      'id': '2026-W41',
      'data': '2026-10-10',
      'interval': _intervalNou,
      'titlu': 'Titlul ediției 2026-W41',
      'articole': 3,
    },
    {
      'id': '2026-W40',
      'data': '2026-10-03',
      'interval': _intervalVechi,
      'titlu': 'Titlul ediției 2026-W40',
      'articole': 3,
    },
  ],
};

SintezaStore _store({bool faraServer = false}) => SintezaStore(
  url: 'https://exemplu.test/sinteza/date/',
  client: MockClient((cerere) async {
    if (faraServer) return http.Response('', 503);
    final corp = switch (cerere.url.pathSegments.last) {
      'index.json' => _index,
      '2026-W41.json' => _editie('2026-W41', _intervalNou),
      '2026-W40.json' => _editie('2026-W40', _intervalVechi),
      _ => null,
    };
    if (corp == null) return http.Response('', 404);
    return http.Response.bytes(utf8.encode(jsonEncode(corp)), 200);
  }),
);

Widget _aplicatie(SintezaProvider provider) => ChangeNotifierProvider.value(
  value: provider,
  child: const MaterialApp(home: Scaffold(body: SintezaScreen())),
);

/// Tine minte alegerea, fara sa atinga notificarile telefonului.
class _NotificariDeProba extends NotificariSinteza {
  bool? stare;
  _NotificariDeProba([this.stare]);

  @override
  Future<bool?> alegere() async => stare;

  @override
  Future<bool> seteaza(bool pornita) async => stare = pornita;
}

void main() {
  tearDown(() {
    tabCurent.value = 0;
    NotificariSinteza.instance = NotificariSinteza();
  });

  test('textul trimis altora are titlul si adresa de pe pagina web', () {
    final e = EditieSinteza.dinJson(_editie('2026-W41', _intervalNou));
    expect(
      textDeTrimis(e),
      'Sinteza săptămânii, 3–10 octombrie 2026\n'
      'Titlul ediției 2026-W41\n'
      'https://medro-asistent-2026.web.app/sinteza/#2026-W41',
    );
    final articol = textDeTrimis(e, e.articole[2]);
    expect(articol, startsWith('Articol de artă\n'));
    expect(
      articol,
      endsWith('https://medro-asistent-2026.web.app/sinteza/#2026-W41/a3'),
    );
  });

  test('notificarea cade in prima sambata la ora 9, si peste ora de iarna', () {
    tzdata.initializeTimeZones();
    final ro = tz.getLocation('Europe/Bucharest');
    tz.TZDateTime la(int luna, int zi, int ora) =>
        tz.TZDateTime(ro, 2026, luna, zi, ora);
    // sambata, 10 octombrie 2026
    expect(NotificariSinteza.urmatoareaAparitie(la(10, 10, 8)), la(10, 10, 9));
    expect(NotificariSinteza.urmatoareaAparitie(la(10, 10, 9)), la(10, 17, 9));
    expect(NotificariSinteza.urmatoareaAparitie(la(10, 12, 15)), la(10, 17, 9));
    // 25 octombrie 2026: trecerea la ora de iarna, intre sambata 24 si sambata 31
    final peste = NotificariSinteza.urmatoareaAparitie(la(10, 24, 10));
    expect(peste, la(10, 31, 9));
    expect(peste.hour, 9);
  });

  testWidgets('invitatia la notificare apare o data si dispare dupa alegere', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final notificari = _NotificariDeProba();
    NotificariSinteza.instance = notificari;

    tabCurent.value = tabSinteza;
    await tester.pumpWidget(_aplicatie(SintezaProvider(_store())));
    await tester.pumpAndSettle();
    expect(find.textContaining('Vrei o notificare'), findsOneWidget);

    await tester.tap(find.text('Da, anunță-mă'));
    await tester.pumpAndSettle();
    expect(notificari.stare, isTrue);
    expect(find.textContaining('Vrei o notificare'), findsNothing);
    expect(find.textContaining('Vei primi o notificare'), findsOneWidget);
  });

  testWidgets('notificarea se opreste din meniul cu trei puncte', (
    tester,
  ) async {
    final notificari = _NotificariDeProba(true);
    NotificariSinteza.instance = notificari;

    tabCurent.value = tabSinteza;
    await tester.pumpWidget(_aplicatie(SintezaProvider(_store())));
    await tester.pumpAndSettle();
    expect(find.textContaining('Vrei o notificare'), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notificare sâmbăta'));
    await tester.pumpAndSettle();
    expect(notificari.stare, isFalse);
  });

  test('articolul se citeste din JSON, cu paragrafe si trimiteri', () {
    final e = EditieSinteza.dinJson(_editie('2026-W41', _intervalNou));
    expect(e.articole, hasLength(3));
    final a = e.articole.first;
    expect(a.sectiune, SectiuneSinteza.medicina);
    expect(a.paragrafe, [
      'Primul paragraf.',
      'Al doilea paragraf.',
      'Al treilea.',
    ]);
    expect(a.sursa.site, 'nature.com');
    expect(a.alteSurse.single.titlu, 'CNN');
    expect(a.trimiteri.single.site, 'en.wikipedia.org');
    expect(a.imagine, isEmpty);
    expect(a.minuteLectura, 1);
    expect(e.dinSectiunea(SectiuneSinteza.arta).single.id, 'a3');
  });

  test('o sectiune necunoscuta aplicatiei ajunge la Alte noutăți', () {
    final j = _editie('2026-W41', _intervalNou);
    (j['articole'] as List).add(_articol('a4', 'gastronomie', 'Articol nou'));
    final e = EditieSinteza.dinJson(j);
    expect(e.articole.last.sectiune, SectiuneSinteza.altele);
    expect(e.dinSectiunea(SectiuneSinteza.stiinta), hasLength(1));
  });

  test('o editie republicata inlocuieste copia de pe telefon', () async {
    var versiune = 'v1';
    var titlu = 'Titlul vechi';
    var cereri = 0;
    final store = SintezaStore(
      url: 'https://exemplu.test/',
      memorie: {},
      client: MockClient((cerere) async {
        final editie = _editie('2026-W41', _intervalNou)
          ..['titlu'] = titlu
          ..['versiune'] = versiune;
        if (cerere.url.pathSegments.last == 'index.json') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'editii': [
                  {
                    'id': '2026-W41',
                    'data': '2026-10-10',
                    'interval': _intervalNou,
                    'titlu': titlu,
                    'articole': 3,
                    'versiune': versiune,
                  },
                ],
              }),
            ),
            200,
          );
        }
        cereri++;
        return http.Response.bytes(utf8.encode(jsonEncode(editie)), 200);
      }),
    );
    final p = SintezaProvider(store);
    await p.incarcaLaPrimaDeschidere();
    expect(p.editie!.titlu, 'Titlul vechi');

    // aceeasi amprenta: editia vine din copia locala, fara o cerere noua
    await p.reincarca();
    expect(cereri, 1);

    // editia este republicata cu alt continut
    versiune = 'v2';
    titlu = 'Titlul nou';
    await p.reincarca();
    expect(cereri, 2);
    expect(p.editie!.titlu, 'Titlul nou');
  });

  test('data se scrie pe litere', () {
    expect(dataPeLitere('2026-10-05'), '5 octombrie 2026');
    expect(dataPeLitere(''), '');
  });

  test('providerul incarca cea mai noua editie si deschide arhiva', () async {
    final p = SintezaProvider(_store());
    await p.incarcaLaPrimaDeschidere();
    expect(p.eroare, isNull);
    expect(p.editii, hasLength(2));
    expect(p.editie!.id, '2026-W41');
    await p.alege('2026-W40');
    expect(p.editie!.id, '2026-W40');
    expect(p.seIncarca, isFalse);
  });

  test('fara server si fara copie locala apare un mesaj', () async {
    final p = SintezaProvider(_store(faraServer: true));
    await p.incarcaLaPrimaDeschidere();
    expect(p.editie, isNull);
    expect(p.eroare, contains('internet'));
  });

  testWidgets('editia se descarca abia la deschiderea sectiunii', (
    tester,
  ) async {
    final p = SintezaProvider(_store());
    await tester.pumpWidget(_aplicatie(p));
    await tester.pump();
    expect(p.editie, isNull);

    tabCurent.value = tabSinteza;
    await tester.pumpAndSettle();
    expect(p.editie, isNotNull);
    expect(find.text('Titlul ediției 2026-W41'), findsOneWidget);
    expect(find.textContaining(_intervalNou), findsOneWidget);
  });

  testWidgets('filtrul arata o sectiune, iar cardul deschide articolul', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    tabCurent.value = tabSinteza;
    await tester.pumpWidget(_aplicatie(SintezaProvider(_store())));
    await tester.pumpAndSettle();
    expect(find.text('Articol de medicină'), findsOneWidget);

    await tester.ensureVisible(find.text('Artă'));
    await tester.tap(find.text('Artă'));
    await tester.pumpAndSettle();
    expect(find.text('Articol de medicină'), findsNothing);
    expect(find.text('Articol de artă'), findsOneWidget);

    await tester.tap(find.text('Articol de artă'));
    await tester.pumpAndSettle();
    expect(find.text('Al doilea paragraf.'), findsOneWidget);
    expect(find.text('Miza articolului a3.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Optogenetica'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('AFLĂ MAI MULT'), findsOneWidget);
    expect(find.text('ACEEAȘI ȘTIRE, ÎN ALTE REDACȚII'), findsOneWidget);
  });

  testWidgets('meniul din antet deschide lista editiilor', (tester) async {
    tabCurent.value = tabSinteza;
    final p = SintezaProvider(_store());
    await tester.pumpWidget(_aplicatie(p));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ediții anterioare'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_intervalVechi));
    await tester.pumpAndSettle();
    expect(p.editie!.id, '2026-W40');
    expect(find.text('Titlul ediției 2026-W40'), findsOneWidget);
  });
}
