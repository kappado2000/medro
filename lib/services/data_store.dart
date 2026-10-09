import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Rezultatul unei verificari de actualizare a datelor.
class StareActualizare {
  /// Versiunea datelor folosite dupa verificare.
  final String versiune;

  /// Cate fisiere au fost descarcate; 0 daca datele erau la zi.
  final int descarcate;

  /// Mesaj de eroare, daca verificarea nu a reusit.
  final String? eroare;

  const StareActualizare(this.versiune, this.descarcate, [this.eroare]);

  bool get actualizat => descarcate > 0;
}

/// Citeste fisierele de date ale aplicatiei. Fiecare fisier vine fie din
/// pachetul aplicatiei (assets/data/), fie dintr-o versiune mai noua,
/// descarcata de [actualizeaza] in folderul aplicatiei. Asa datele se pot
/// improspata fara o versiune noua a aplicatiei.
class DataStore {
  DataStore._();
  static final instance = DataStore._();

  static const _assets = 'assets/data/';

  /// De aici se descarca datele noi (manifest.json si fisierele din el).
  static const urlActualizari = 'https://medro-asistent-2026.web.app/date/';

  Directory? _dir;
  Map<String, dynamic> _manifest = const {};
  Map<String, dynamic> _manifestPachet = const {};
  bool _initializat = false;

  /// Versiunea datelor folosite acum (data generarii lor).
  String get versiune => (_manifest['versiune'] as String?) ?? '';

  /// Data fiecarei surse, asa cum a fost inregistrata la generare.
  Map<String, String> get surse =>
      ((_manifest['surse'] as Map?) ?? const {}).cast<String, String>();

  Future<void> init() async {
    if (_initializat) return;
    _initializat = true;
    try {
      _manifestPachet = jsonDecode(
        await rootBundle.loadString('${_assets}manifest.json'),
      ) as Map<String, dynamic>;
    } catch (_) {
      _manifestPachet = const {};
    }
    _manifest = _manifestPachet;
    // in teste se folosesc doar datele din pachet: accesul real la disc nu se
    // termina niciodata in ceasul simulat al testelor de interfata
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/date',
      );
      final local = File('${dir.path}/manifest.json');
      if (await local.exists()) {
        final m =
            jsonDecode(await local.readAsString()) as Map<String, dynamic>;
        final v = (m['versiune'] as String?) ?? '';
        final pachet = (_manifestPachet['versiune'] as String?) ?? '';
        if (v.compareTo(pachet) > 0) {
          _dir = dir;
          _manifest = m;
        } else {
          // aplicatia instalata aduce date mai noi decat cele descarcate candva
          await dir.delete(recursive: true);
        }
      }
    } catch (_) {
      // fara stocare locala (teste, platforme fara suport) raman datele din pachet
      _dir = null;
      _manifest = _manifestPachet;
    }
  }

  /// Continutul unui fisier de date, dupa calea relativa (ex. "rcp/ab.json.gz").
  Future<Uint8List> bytes(String nume) async {
    await init();
    final dir = _dir;
    if (dir != null) {
      final f = File('${dir.path}/$nume');
      if (await f.exists()) return f.readAsBytes();
    }
    return (await rootBundle.load('$_assets$nume')).buffer.asUint8List();
  }

  /// Un fisier .json.gz decodat.
  Future<dynamic> jsonGz(String nume) async {
    final b = await bytes(nume);
    return jsonDecode(utf8.decode(GZipDecoder().decodeBytes(b)));
  }

  /// Verifica daca exista date mai noi si le descarca. Fisierele sunt
  /// verificate cu suma de control inainte de a le inlocui pe cele vechi;
  /// daca ceva esueaza, raman datele curente.
  Future<StareActualizare> actualizeaza({http.Client? client}) async {
    await init();
    if (kIsWeb) {
      return StareActualizare(
        versiune,
        0,
        'Actualizarea nu este disponibilă în browser.',
      );
    }
    final c = client ?? http.Client();
    try {
      final r = await c
          .get(Uri.parse('${urlActualizari}manifest.json'))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) {
        return StareActualizare(
          versiune,
          0,
          'Serverul de actualizări nu răspunde (${r.statusCode}).',
        );
      }
      final nou = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final versiuneNoua = (nou['versiune'] as String?) ?? '';
      if (versiuneNoua.compareTo(versiune) <= 0) {
        return StareActualizare(versiune, 0);
      }

      final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/date',
      );
      final temporar = Directory('${dir.path}.nou');
      if (await temporar.exists()) await temporar.delete(recursive: true);
      await temporar.create(recursive: true);

      final fisiereNoi = (nou['fisiere'] as Map).cast<String, dynamic>();
      final fisiereVechi = ((_manifest['fisiere'] as Map?) ?? const {})
          .cast<String, dynamic>();
      var descarcate = 0;
      for (final e in fisiereNoi.entries) {
        final suma = (e.value as Map)['sha256'] as String;
        final tinta = File('${temporar.path}/${e.key}');
        await tinta.parent.create(recursive: true);
        if ((fisiereVechi[e.key] as Map?)?['sha256'] == suma) {
          // neschimbat: se copiaza versiunea folosita acum
          await tinta.writeAsBytes(await bytes(e.key));
          continue;
        }
        final f = await c
            .get(Uri.parse('$urlActualizari${e.key}'))
            .timeout(const Duration(minutes: 2));
        if (f.statusCode != 200 ||
            sha256.convert(f.bodyBytes).toString() != suma) {
          await temporar.delete(recursive: true);
          return StareActualizare(
            versiune,
            0,
            'Fișierul ${e.key} nu a putut fi descărcat corect.',
          );
        }
        await tinta.writeAsBytes(f.bodyBytes);
        descarcate++;
      }
      await File('${temporar.path}/manifest.json')
          .writeAsString(jsonEncode(nou));
      if (await dir.exists()) await dir.delete(recursive: true);
      await temporar.rename(dir.path);
      _dir = dir;
      _manifest = nou;
      return StareActualizare(versiuneNoua, descarcate);
    } catch (e) {
      return StareActualizare(
        versiune,
        0,
        'Actualizarea nu a reușit: fără conexiune sau server indisponibil.',
      );
    } finally {
      if (client == null) c.close();
    }
  }
}

/// Sectiunile din RCP, incarcate la cerere din fisiere mici.
class RcpStore {
  RcpStore._();
  static final instance = RcpStore._();

  Map<String, String>? _index;
  final Map<String, Map<String, dynamic>> _pachete = {};

  /// Se apeleaza dupa o actualizare a datelor.
  void goleste() {
    _index = null;
    _pachete.clear();
  }

  /// Sectiunile RCP-ului de la adresa data ("4.1" -> text); gol daca nu au
  /// fost extrase.
  Future<Map<String, String>> sectiuni(String rcpUrl) async {
    if (rcpUrl.isEmpty) return const {};
    try {
      _index ??= ((await DataStore.instance.jsonGz('rcp/index.json.gz')) as Map)
          .cast<String, String>();
      final amprenta = _index![rcpUrl];
      if (amprenta == null) return const {};
      final prefix = amprenta.substring(0, 2);
      final pachet = _pachete[prefix] ??= ((await DataStore.instance.jsonGz(
        'rcp/$prefix.json.gz',
      )) as Map).cast<String, dynamic>();
      return ((pachet[amprenta] as Map?) ?? const {}).cast<String, String>();
    } catch (_) {
      return const {};
    }
  }
}
