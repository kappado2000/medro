import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medro/providers/auth_provider.dart';
import 'package:medro/screens/acces_screen.dart';
import 'package:medro/services/auth_service.dart';
import 'package:medro/services/claude_client.dart';
import 'package:provider/provider.dart';

class DepozitMemorie implements DepozitSesiune {
  (String, String)? valoare;
  DepozitMemorie([this.valoare]);

  @override
  Future<(String, String)?> citeste() async => valoare;
  @override
  Future<void> scrie(String email, String refreshToken) async =>
      valoare = (email, refreshToken);
  @override
  Future<void> sterge() async => valoare = null;
}

class BiometrieFalsa implements Biometrie {
  bool exista;
  bool raspuns;
  int cereri = 0;
  BiometrieFalsa({this.exista = true, this.raspuns = true});

  @override
  Future<bool> disponibila() async => exista;
  @override
  Future<bool> confirma() async {
    cereri++;
    return raspuns;
  }
}

http.Response json(Object corp, [int cod = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(corp)),
  cod,
  headers: {'content-type': 'application/json'},
);

http.Response eroare(String mesaj) => json({
  'error': {'code': 400, 'message': mesaj},
}, 400);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Serviciu care accepta parola "corecta" si numara reimprospatarile.
  (AuthService, List<http.Request>) serviciu({String? refuzaRefresh}) {
    final cereri = <http.Request>[];
    var n = 0;
    final s = AuthService(
      'cheie-web',
      MockClient((r) async {
        cereri.add(r);
        final corp = jsonDecode(r.body) as Map<String, dynamic>;
        if (r.url.path.endsWith(':signInWithPassword')) {
          if (corp['password'] != 'corecta') {
            return eroare('INVALID_LOGIN_CREDENTIALS');
          }
          return json({
            'email': 'doctor@exemplu.ro',
            'idToken': 'id-0',
            'refreshToken': 'refresh-0',
            'expiresIn': '3600',
          });
        }
        if (r.url.host == 'securetoken.googleapis.com') {
          if (refuzaRefresh != null) return eroare(refuzaRefresh);
          n++;
          return json({
            'id_token': 'id-$n',
            'refresh_token': 'refresh-$n',
            'expires_in': '3600',
          });
        }
        if (r.url.path.endsWith(':sendOobCode')) {
          return corp['email'] == 'necunoscut@exemplu.ro'
              ? eroare('EMAIL_NOT_FOUND')
              : json({'email': corp['email']});
        }
        return json({}, 404);
      }),
    );
    return (s, cereri);
  }

  group('AuthService', () {
    test(
      'autentificarea trimite cheia proiectului si citeste sesiunea',
      () async {
        final (s, cereri) = serviciu();
        final sesiune = await s.autentifica(' doctor@exemplu.ro ', 'corecta');
        expect(sesiune.email, 'doctor@exemplu.ro');
        expect(sesiune.idToken, 'id-0');
        expect(sesiune.refreshToken, 'refresh-0');
        expect(
          sesiune.expira.isAfter(
            DateTime.now().add(const Duration(minutes: 50)),
          ),
          isTrue,
        );
        expect(cereri.single.url.queryParameters['key'], 'cheie-web');
        expect(jsonDecode(cereri.single.body), {
          'email': 'doctor@exemplu.ro',
          'password': 'corecta',
          'returnSecureToken': true,
        });
      },
    );

    test('erorile au mesaje in romana', () async {
      final (s, _) = serviciu();
      await expectLater(
        s.autentifica('doctor@exemplu.ro', 'gresita'),
        throwsA(
          isA<AuthException>()
              .having((e) => e.mesaj, 'mesaj', 'E-mail sau parolă greșită.')
              .having((e) => e.sesiuneInvalida, 'sesiuneInvalida', isFalse),
        ),
      );
      final (expirat, _) = serviciu(refuzaRefresh: 'TOKEN_EXPIRED');
      await expectLater(
        expirat.reimprospateaza('a@b.ro', 'vechi'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.sesiuneInvalida,
            'sesiuneInvalida',
            isTrue,
          ),
        ),
      );
      final faraRetea = AuthService(
        'k',
        MockClient((_) async => throw http.ClientException('fara retea')),
      );
      await expectLater(
        faraRetea.autentifica('a@b.ro', 'x'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.mesaj,
            'mesaj',
            contains('internet'),
          ),
        ),
      );
      expect(AuthService('').configurat, isFalse);
    });
  });

  group('AuthProvider', () {
    test(
      'fara cheia proiectului aplicatia nu are cont si e deschisa',
      () async {
        final p = AuthProvider(
          serviciu: AuthService(''),
          depozit: DepozitMemorie(),
          biometrie: BiometrieFalsa(),
        );
        await p.incarca();
        expect(p.activ, isFalse);
        expect(p.stare, StareAcces.deblocat);
        expect(await p.tokenId(), isNull);
      },
    );

    test(
      'prima pornire cere parola; autentificarea pastreaza sesiunea',
      () async {
        final (s, _) = serviciu();
        final depozit = DepozitMemorie();
        final p = AuthProvider(
          serviciu: s,
          depozit: depozit,
          biometrie: BiometrieFalsa(),
        );
        await p.incarca();
        expect(p.stare, StareAcces.neautentificat);

        expect(await p.autentifica('', ''), 'Scrie e-mailul și parola.');
        expect(
          await p.autentifica('doctor@exemplu.ro', 'gresita'),
          'E-mail sau parolă greșită.',
        );
        expect(p.stare, StareAcces.neautentificat);
        expect(depozit.valoare, isNull);

        expect(await p.autentifica('doctor@exemplu.ro', 'corecta'), isNull);
        expect(p.stare, StareAcces.deblocat);
        expect(p.email, 'doctor@exemplu.ro');
        expect(depozit.valoare, ('doctor@exemplu.ro', 'refresh-0'));
        expect(await p.tokenId(), 'id-0');
      },
    );

    test('la pornirile urmatoare se cere biometria, fara retea', () async {
      final (s, cereri) = serviciu();
      final bio = BiometrieFalsa();
      final p = AuthProvider(
        serviciu: s,
        depozit: DepozitMemorie(('doctor@exemplu.ro', 'refresh-0')),
        biometrie: bio,
      );
      await p.incarca();
      expect(bio.cereri, 1);
      expect(p.stare, StareAcces.deblocat);
      expect(cereri, isEmpty);
      // dovada pentru server se obtine abia cand e nevoie de ea
      expect(await p.tokenId(), 'id-1');
      expect(await p.tokenId(), 'id-1');
      expect(cereri, hasLength(1));
    });

    test('biometria refuzata sau absenta lasa aplicatia blocata', () async {
      final (s, _) = serviciu();
      final bio = BiometrieFalsa(raspuns: false);
      final p = AuthProvider(
        serviciu: s,
        depozit: DepozitMemorie(('doctor@exemplu.ro', 'refresh-0')),
        biometrie: bio,
      );
      await p.incarca();
      expect(p.stare, StareAcces.blocat);
      expect(await p.tokenId(), isNull);
      bio.raspuns = true;
      expect(await p.deblocheaza(), isTrue);
      expect(p.stare, StareAcces.deblocat);

      final faraBio = AuthProvider(
        serviciu: s,
        depozit: DepozitMemorie(('doctor@exemplu.ro', 'refresh-0')),
        biometrie: BiometrieFalsa(exista: false),
      );
      await faraBio.incarca();
      expect(faraBio.stare, StareAcces.blocat);
      // ramane parola contului
      expect(await faraBio.autentifica('doctor@exemplu.ro', 'corecta'), isNull);
      expect(faraBio.stare, StareAcces.deblocat);
    });

    test('se blocheaza din nou dupa mai mult de un minut in fundal', () async {
      final (s, _) = serviciu();
      final bio = BiometrieFalsa();
      var acum = DateTime(2026, 10, 9, 10);
      final p = AuthProvider(
        serviciu: s,
        depozit: DepozitMemorie(('doctor@exemplu.ro', 'refresh-0')),
        biometrie: bio,
        acum: () => acum,
      );
      await p.incarca();
      expect(bio.cereri, 1);

      p.laPlecare();
      acum = acum.add(const Duration(seconds: 30));
      p.laRevenire();
      expect(p.stare, StareAcces.deblocat);
      expect(bio.cereri, 1);

      bio.raspuns = false;
      p.laPlecare();
      acum = acum.add(const Duration(minutes: 2));
      p.laRevenire();
      await Future<void>.delayed(Duration.zero);
      expect(p.stare, StareAcces.blocat);
      expect(bio.cereri, 2);
    });

    test(
      'dovada expirata se reinnoieste; un cont dezactivat inchide sesiunea',
      () async {
        final (s, cereri) = serviciu();
        var acum = DateTime.now();
        final depozit = DepozitMemorie(('doctor@exemplu.ro', 'refresh-0'));
        final p = AuthProvider(
          serviciu: s,
          depozit: depozit,
          biometrie: BiometrieFalsa(),
          acum: () => acum,
        );
        await p.incarca();
        expect(await p.tokenId(), 'id-1');
        acum = acum.add(const Duration(minutes: 59));
        expect(await p.tokenId(), 'id-2');
        expect(depozit.valoare, ('doctor@exemplu.ro', 'refresh-2'));
        expect(cereri, hasLength(2));

        final (dezactivat, _) = serviciu(refuzaRefresh: 'USER_DISABLED');
        final d2 = DepozitMemorie(('doctor@exemplu.ro', 'refresh-0'));
        final q = AuthProvider(
          serviciu: dezactivat,
          depozit: d2,
          biometrie: BiometrieFalsa(),
        );
        await q.incarca();
        expect(await q.tokenId(), isNull);
        expect(q.stare, StareAcces.neautentificat);
        expect(d2.valoare, isNull);
      },
    );

    test(
      'iesirea sterge sesiunea; resetarea nu dezvaluie daca exista contul',
      () async {
        final (s, _) = serviciu();
        final depozit = DepozitMemorie(('doctor@exemplu.ro', 'refresh-0'));
        final p = AuthProvider(
          serviciu: s,
          depozit: depozit,
          biometrie: BiometrieFalsa(),
        );
        await p.incarca();
        await p.iesi();
        expect(p.stare, StareAcces.neautentificat);
        expect(depozit.valoare, isNull);
        expect(p.email, isEmpty);

        final cunoscut = await p.reseteazaParola('doctor@exemplu.ro');
        final necunoscut = await p.reseteazaParola('necunoscut@exemplu.ro');
        expect(cunoscut, necunoscut);
        expect(cunoscut, contains('legătura de resetare'));
        expect(await p.reseteazaParola('  '), 'Scrie întâi adresa de e-mail.');
      },
    );
  });

  group('asistentul', () {
    test('trimite dovada contului catre server si refuza fara ea', () async {
      late http.Request cerere;
      ClaudeClient client(Future<String?> Function()? token) => ClaudeClient(
        MockClient((r) async {
          cerere = r;
          return json({
            'content': [
              {'type': 'text', 'text': 'ok'},
            ],
          });
        }),
        'https://server.exemplu/medroAsistent',
        'cod',
        token,
      );
      const mesaje = [
        {'role': 'user', 'content': 'Buna'},
      ];
      await client(() async => 'id-7').trimite(system: 's', mesaje: mesaje);
      expect(cerere.headers['authorization'], 'Bearer id-7');
      expect(cerere.headers['x-medro-token'], 'cod');

      await client(null).trimite(system: 's', mesaje: mesaje);
      expect(cerere.headers.containsKey('authorization'), isFalse);

      await expectLater(
        client(() async => null).trimite(system: 's', mesaje: mesaje),
        throwsA(
          isA<ClaudeException>().having(
            (e) => e.mesaj,
            'mesaj',
            contains('contul'),
          ),
        ),
      );
    });
  });

  group('ecranul de acces', () {
    Future<AuthProvider> porneste(
      WidgetTester tester, {
      DepozitMemorie? depozit,
      BiometrieFalsa? biometrie,
    }) async {
      final (s, _) = serviciu();
      final p = AuthProvider(
        serviciu: s,
        depozit: depozit ?? DepozitMemorie(),
        biometrie: biometrie ?? BiometrieFalsa(),
      );
      await p.incarca();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: MaterialApp(
            locale: const Locale('ro'),
            supportedLocales: const [Locale('ro')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => PoartaAcces(child: child!),
            home: const Scaffold(body: Text('CONTINUT')),
          ),
        ),
      );
      await tester.pump();
      return p;
    }

    testWidgets('fara cont se vede formularul, nu continutul', (tester) async {
      final p = await porneste(tester);
      expect(find.text('CONTINUT'), findsNothing);
      expect(find.text('Intră în cont'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'doctor@exemplu.ro');
      await tester.enterText(find.byType(TextField).last, 'gresita');
      await tester.tap(find.text('Intră în cont'));
      await tester.pumpAndSettle();
      expect(find.text('E-mail sau parolă greșită.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'corecta');
      await tester.tap(find.text('Intră în cont'));
      await tester.pumpAndSettle();
      expect(p.stare, StareAcces.deblocat);
      expect(find.text('CONTINUT'), findsOneWidget);
      expect(find.text('Intră în cont'), findsNothing);
    });

    testWidgets('blocat: buton de deblocare, parola ca alternativa', (
      tester,
    ) async {
      final bio = BiometrieFalsa(raspuns: false);
      final p = await porneste(
        tester,
        depozit: DepozitMemorie(('doctor@exemplu.ro', 'refresh-0')),
        biometrie: bio,
      );
      expect(p.stare, StareAcces.blocat);
      expect(find.text('doctor@exemplu.ro'), findsOneWidget);
      expect(find.text('Deblochează'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('Folosește parola'));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(2));

      bio.raspuns = true;
      await p.deblocheaza();
      await tester.pumpAndSettle();
      expect(find.text('CONTINUT'), findsOneWidget);
      expect(find.text('Deblochează'), findsNothing);
    });

    testWidgets('ecranul se schimba odata cu starea', (tester) async {
      final (s, _) = serviciu();
      final p = AuthProvider(
        serviciu: s,
        depozit: DepozitMemorie(),
        biometrie: BiometrieFalsa(),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: p,
          child: MaterialApp(
            builder: (context, child) => PoartaAcces(child: child!),
            home: const Scaffold(body: Text('CONTINUT')),
          ),
        ),
      );
      // inca se citeste sesiunea: nici continut, nici formular
      expect(find.text('CONTINUT'), findsNothing);
      expect(find.text('Intră în cont'), findsNothing);
      await p.incarca();
      await tester.pump();
      expect(find.text('Intră în cont'), findsOneWidget);
      await p.autentifica('doctor@exemplu.ro', 'corecta');
      await tester.pump();
      expect(find.text('CONTINUT'), findsOneWidget);
      await p.iesi();
      await tester.pump();
      expect(find.text('Intră în cont'), findsOneWidget);
      expect(find.text('CONTINUT'), findsNothing);
    });

    testWidgets('formularul incape pe un ecran ingust cu text mare', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await porneste(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
