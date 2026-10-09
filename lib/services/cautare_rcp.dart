import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import 'data_store.dart';

/// Un text de RCP care contine cuvintele cautate.
class PotrivireRcp {
  /// Amprenta textului (acelasi text e comun mai multor concentratii) sau, la
  /// contraindicatii, adresa RCP-ului.
  final String cheie;
  final String sectiune;

  /// Fraza din jurul primului cuvant gasit.
  final String fragment;

  const PotrivireRcp(this.cheie, this.sectiune, this.fragment);
}

/// Starea unei cautari in curs.
class ProgresCautare {
  /// Intre 0 si 1.
  final double parcurs;
  final List<PotrivireRcp> potriviri;
  final bool gata;

  /// true daca s-a atins [maxPotriviri] si cautarea s-a oprit.
  final bool trunchiat;

  const ProgresCautare(
    this.parcurs,
    this.potriviri, {
    this.gata = false,
    this.trunchiat = false,
  });
}

const maxPotriviri = 300;

const _diacritice = {
  'ă': 'a',
  'â': 'a',
  'î': 'i',
  'ș': 's',
  'ş': 's',
  'ț': 't',
  'ţ': 't',
};

/// Litere mici, fara diacritice. Pastreaza lungimea textului, ca pozitiile
/// gasite sa fie valabile si in textul original.
String faraDiacritice(String text) {
  var t = text.toLowerCase();
  for (final e in _diacritice.entries) {
    t = t.replaceAll(e.key, e.value);
  }
  return t;
}

/// Cuvintele unei interogari, pregatite pentru cautare; cele sub 3 litere se ignora.
List<String> cuvinteCautate(String interogare) => [
  for (final c in faraDiacritice(interogare).split(RegExp(r'[^a-z0-9]+')))
    if (c.length >= 3) c,
];

/// Fraza din [text] in care se afla pozitia [index], cel mult 320 de caractere.
String fragmentLa(String text, int index) {
  var start = index;
  while (start > 0 &&
      !'.;\n'.contains(text[start - 1]) &&
      index - start < 200) {
    start--;
  }
  var end = index;
  while (end < text.length &&
      !'.;\n'.contains(text[end]) &&
      end - start < 320) {
    end++;
  }
  if (end < text.length && text[end] != '\n') end++;
  return text.substring(start, end).trim();
}

/// Daca [text] contine toate [cuvinte], intoarce fraza cu primul dintre ele.
String? potriveste(String text, List<String> cuvinte) {
  if (cuvinte.isEmpty) return null;
  final simplu = faraDiacritice(text);
  var prima = -1;
  for (final c in cuvinte) {
    final i = simplu.indexOf(c);
    if (i < 0) return null;
    if (prima < 0) prima = i;
  }
  // daca scrierea cu majuscule a schimbat lungimea, pozitia nu mai e sigura
  if (simplu.length != text.length) {
    return text.length > 320 ? '${text.substring(0, 320)}…' : text;
  }
  return fragmentLa(text, prima);
}

typedef _Sarcina = (Uint8List, List<String>, List<String>);

/// Ruleaza pe un fir separat: despacheteaza un pachet de sectiuni si cauta in el.
List<List<String>> _cautaInPachet(_Sarcina s) {
  final (bytes, cuvinte, sectiuni) = s;
  final pachet = jsonDecode(
    utf8.decode(GZipDecoder().decodeBytes(bytes)),
  ) as Map<String, dynamic>;
  final gasite = <List<String>>[];
  for (final e in pachet.entries) {
    final text = e.value as Map<String, dynamic>;
    for (final numar in sectiuni) {
      final continut = text[numar];
      if (continut is! String) continue;
      final fragment = potriveste(continut, cuvinte);
      if (fragment != null) {
        gasite.add([e.key, numar, fragment]);
        break; // o potrivire pe document e de ajuns
      }
    }
  }
  return gasite;
}

/// Cauta [interogare] in sectiunile RCP pastrate in aplicatie. Textele sunt
/// impartite in pachete; se parcurg pe rand, cu rezultate partiale, ca
/// telefonul sa nu incarce totul in memorie.
///
/// [contraindicatii] (adresa RCP -> text) sunt pastrate separat de pachete si
/// se cauta in ele cand "4.3" este printre [sectiuni].
Stream<ProgresCautare> cautaInRcp(
  String interogare, {
  required List<String> sectiuni,
  Map<String, String> contraindicatii = const {},
}) async* {
  final cuvinte = cuvinteCautate(interogare);
  if (cuvinte.isEmpty || sectiuni.isEmpty) {
    yield const ProgresCautare(1, [], gata: true);
    return;
  }
  final potriviri = <PotrivireRcp>[];
  bool plin() => potriviri.length >= maxPotriviri;

  if (sectiuni.contains('4.3')) {
    final vazute = <String>{};
    for (final e in contraindicatii.entries) {
      // concentratiile aceluiasi produs au de regula acelasi text
      if (!vazute.add(e.value)) continue;
      final fragment = potriveste(e.value, cuvinte);
      if (fragment != null) potriviri.add(PotrivireRcp(e.key, '4.3', fragment));
      if (plin()) break;
    }
  }

  final inPachete = [
    for (final s in sectiuni)
      if (s != '4.3') s,
  ];
  if (inPachete.isNotEmpty && !plin()) {
    final index = ((await DataStore.instance.jsonGz(
      'rcp/index.json.gz',
    )) as Map).cast<String, String>();
    final prefixe = {for (final a in index.values) a.substring(0, 2)}.toList()
      ..sort();
    for (final (i, prefix) in prefixe.indexed) {
      final bytes = await DataStore.instance.bytes('rcp/$prefix.json.gz');
      final gasite = await compute(_cautaInPachet, (bytes, cuvinte, inPachete));
      for (final g in gasite) {
        potriviri.add(PotrivireRcp(g[0], g[1], g[2]));
      }
      if (plin()) break;
      yield ProgresCautare((i + 1) / prefixe.length, List.of(potriviri));
    }
  }
  yield ProgresCautare(
    1,
    potriviri.take(maxPotriviri).toList(),
    gata: true,
    trunchiat: plin(),
  );
}
