import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/text_utils.dart';

class IcdCapitol {
  final int index;
  final String numar;
  final String titlu;
  final String deLa;
  final String panaLa;

  const IcdCapitol(this.index, this.numar, this.titlu, this.deLa, this.panaLa);

  String get interval => '$deLa–$panaLa';
}

class IcdCod {
  final String cod;
  final String titlu;
  final int capitol;
  final String titluNorm;
  final String codCompact;

  IcdCod(this.cod, this.titlu, this.capitol)
    : titluNorm = normalizeForSearch(titlu),
      codCompact = cod.replaceAll('.', '').toLowerCase();

  /// Categoriile au 3 caractere (F32); subcategoriile au punct (F32.0).
  bool get esteCategorie => cod.length == 3;
}

class IcdProvider extends ChangeNotifier {
  static const _assetPath = 'assets/data/icd10.json.gz';
  static const maxRezultate = 200;

  /// Capitolul V (tulburari mentale), afisat primul.
  static const indexPsihiatrie = 4;

  List<IcdCod> _coduri = const [];
  List<IcdCapitol> capitole = const [];
  String sursa = '';
  bool incarcat = false;
  String? eroare;

  int get total => _coduri.length;

  Future<void> incarca() async {
    try {
      final bytes = (await rootBundle.load(_assetPath)).buffer.asUint8List();
      final json = utf8.decode(GZipDecoder().decodeBytes(bytes));
      final data = jsonDecode(json) as Map<String, dynamic>;
      sursa = data['sursa'] as String;
      final brute = data['capitole'] as List;
      final toate = [
        for (final (i, c) in brute.indexed)
          IcdCapitol(
            i,
            c[0] as String,
            c[1] as String,
            c[2] as String,
            c[3] as String,
          ),
      ];
      capitole = [
        toate[indexPsihiatrie],
        for (final c in toate)
          if (c.index != indexPsihiatrie) c,
      ];
      _coduri = [
        for (final c in data['coduri'] as List)
          IcdCod(c[0] as String, c[1] as String, c[2] as int),
      ];
    } catch (e) {
      eroare = e.toString();
    }
    incarcat = true;
    notifyListeners();
  }

  /// Categoriile de 3 caractere ale unui capitol.
  List<IcdCod> categorii(IcdCapitol capitol) {
    return [
      for (final c in _coduri)
        if (c.capitol == capitol.index && c.esteCategorie) c,
    ];
  }

  /// Codurile aflate direct sub un cod: F32 -> F32.0, F32.1; F60.3 -> F60.30.
  List<IcdCod> subcoduri(IcdCod parinte) {
    final prefix = parinte.esteCategorie ? '${parinte.cod}.' : parinte.cod;
    final lungime = parinte.esteCategorie ? 5 : parinte.cod.length + 1;
    return [
      for (final c in _coduri)
        if (c.cod.length == lungime && c.cod.startsWith(prefix)) c,
    ];
  }

  bool areSubcoduri(IcdCod cod) =>
      cod.cod.length < 6 && subcoduri(cod).isNotEmpty;

  /// Cauta dupa cod (cu sau fara punct) ori dupa cuvinte din denumire.
  /// Potrivirile pe cod apar primele.
  List<IcdCod> cauta(String interogare) {
    final cuvinte = normalizeForSearch(interogare)
        .split(' ')
        .where((c) => c.isNotEmpty)
        .toList();
    if (cuvinte.isEmpty) return const [];
    final compact = cuvinte.join().replaceAll('.', '');
    final dupaCod = <IcdCod>[];
    final dupaTitlu = <IcdCod>[];
    for (final c in _coduri) {
      if (c.codCompact.startsWith(compact)) {
        dupaCod.add(c);
      } else if (cuvinte.every(c.titluNorm.contains)) {
        dupaTitlu.add(c);
      }
    }
    // categoriile inaintea subcategoriilor cand cautarea e dupa denumire
    mergeSort(
      dupaTitlu,
      compare: (a, b) => a.cod.length.compareTo(b.cod.length),
    );
    return [...dupaCod, ...dupaTitlu].take(maxRezultate).toList();
  }
}
