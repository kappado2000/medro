import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/sinteza.dart';

/// Aduce editiile Sintezei de pe server si pastreaza o copie pe telefon, ca
/// editiile deja deschise sa poata fi citite si fara internet. Editiile sunt
/// generate saptamanal de tool/build_sinteza.py.
class SintezaStore {
  /// De aici se citesc index.json si fisierele editiilor. Se poate schimba la
  /// rulare cu --dart-define=SINTEZA_URL=..., pentru probe pe un server local.
  static const urlImplicit = String.fromEnvironment(
    'SINTEZA_URL',
    defaultValue: 'https://medro-asistent-2026.web.app/sinteza/date/',
  );

  /// Pagina web a Sintezei, cea trimisa altora; `#editie` sau
  /// `#editie/articol` deschide direct o editie sau un articol.
  static const paginaPublica = 'https://medro-asistent-2026.web.app/sinteza/';

  final String url;

  /// Clientul HTTP; in teste se inlocuieste cu unul simulat.
  final http.Client? client;

  /// Copia locala tinuta in memorie in loc de disc; folosita in teste.
  final Map<String, String>? memorie;

  SintezaStore({this.url = urlImplicit, this.client, this.memorie});

  static bool get _inTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  // in teste si in browser nu se foloseste discul (vezi DataStore.init)
  static bool get _faraDisc => kIsWeb || _inTest;

  Future<File?> _fisier(String nume) async {
    if (_faraDisc) return null;
    try {
      final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/sinteza',
      );
      await dir.create(recursive: true);
      return File('${dir.path}/$nume');
    } catch (_) {
      return null;
    }
  }

  Future<String?> _dinMemorie(String nume) async {
    if (memorie != null) return memorie![nume];
    try {
      final f = await _fisier(nume);
      if (f != null && await f.exists()) return await f.readAsString();
    } catch (_) {}
    return null;
  }

  Future<String?> _dePeServer(String nume) async {
    // testele care nu aduc un client simulat nu ies pe retea
    if (client == null && _inTest) return null;
    final c = client ?? http.Client();
    try {
      final r = await c
          .get(Uri.parse('$url$nume'))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return null;
      final text = utf8.decode(r.bodyBytes);
      jsonDecode(text); // un raspuns care nu e JSON nu ajunge in memorie
      if (memorie != null) {
        memorie![nume] = text;
      } else {
        try {
          await (await _fisier(nume))?.writeAsString(text);
        } catch (_) {}
      }
      return text;
    } catch (_) {
      return null;
    } finally {
      if (client == null) c.close();
    }
  }

  /// Lista editiilor, cea mai noua prima. Cu [proaspat] se intreaba intai
  /// serverul; altfel se foloseste copia de pe telefon, daca exista.
  /// Intoarce null daca nu exista nici raspuns, nici copie.
  Future<List<RezumatEditie>?> index({bool proaspat = true}) async {
    final text =
        (proaspat ? await _dePeServer('index.json') : null) ??
        await _dinMemorie('index.json') ??
        (proaspat ? null : await _dePeServer('index.json'));
    if (text == null) return null;
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      return [
        for (final e in j['editii'] as List)
          RezumatEditie.dinJson((e as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      return null;
    }
  }

  /// O editie. Copia de pe telefon se foloseste doar daca are amprenta
  /// [versiune] din lista editiilor; altfel editia a fost republicata si se
  /// descarca din nou. Fara internet se arata copia veche, daca exista.
  Future<EditieSinteza?> editie(String id, {String versiune = ''}) async {
    EditieSinteza? citeste(String? text) {
      if (text == null) return null;
      try {
        return EditieSinteza.dinJson(jsonDecode(text) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }

    final copie = citeste(await _dinMemorie('$id.json'));
    if (copie != null && (versiune.isEmpty || copie.versiune == versiune)) {
      return copie;
    }
    return citeste(await _dePeServer('$id.json')) ?? copie;
  }
}
