import 'package:flutter/foundation.dart';

import '../services/data_store.dart';
import '../utils/text_utils.dart';

/// Nivelul de severitate din DDInter, de la cel mai grav.
enum Severitate { majora, moderata, minora, neprecizata }

class Substanta {
  final int index;

  /// Denumirea din DDInter (engleza).
  final String denumireEn;

  /// Denumirile DCI din nomenclator carora le corespunde.
  final List<String> dci;

  final String cautare;

  Substanta(this.index, this.denumireEn, this.dci)
    : cautare = normalizeForSearch('${dci.join(' ')} $denumireEn');

  String get nume => titleCase(dci.first);
}

class Interactiune {
  final Substanta a;
  final Substanta b;
  final Severitate severitate;
  const Interactiune(this.a, this.b, this.severitate);
}

class InteractiuniProvider extends ChangeNotifier {
  static const _fisier = 'interactiuni.json.gz';
  static const maxSugestii = 30;

  List<Substanta> _substante = const [];
  Map<String, List<int>> _dupaDci = const {};
  Map<String, List<String>> _incomplet = const {};

  /// Pentru fiecare substanta, vecinii cu index mai mare, pe niveluri.
  Map<int, List<List<int>>> _perechi = const {};

  String sursa = '';
  bool incarcat = false;
  String? eroare;

  int get totalSubstante => _substante.length;

  /// Substantele alese pentru verificare in ecranul de interactiuni.
  final List<Substanta> selectie = [];

  void adaugaInSelectie(Iterable<Substanta> substante) {
    for (final s in substante) {
      if (!selectie.any((x) => x.index == s.index)) selectie.add(s);
    }
    notifyListeners();
  }

  void scoateDinSelectie(Substanta s) {
    selectie.removeWhere((x) => x.index == s.index);
    notifyListeners();
  }

  void inlocuiesteInSelectie(Substanta veche, Substanta noua) {
    final i = selectie.indexWhere((x) => x.index == veche.index);
    if (i < 0 || selectie.any((x) => x.index == noua.index)) return;
    selectie[i] = noua;
    notifyListeners();
  }

  void golesteSelectia() {
    selectie.clear();
    notifyListeners();
  }

  Future<void> incarca() async {
    try {
      final data =
          await DataStore.instance.jsonGz(_fisier) as Map<String, dynamic>;
      sursa = data['sursa'] as String;
      _substante = [
        for (final (i, s) in (data['substante'] as List).indexed)
          Substanta(i, s[0] as String, (s[1] as List).cast<String>()),
      ];
      _dupaDci = {
        for (final e in (data['dci'] as Map<String, dynamic>).entries)
          e.key: (e.value as List).cast<int>(),
      };
      _incomplet = {
        for (final e
            in ((data['incomplet'] as Map<String, dynamic>?) ?? const {})
                .entries)
          e.key: (e.value as List).cast<String>(),
      };
      _perechi = {
        for (final e in (data['perechi'] as Map<String, dynamic>).entries)
          int.parse(e.key): [
            for (final nivel in e.value as List) (nivel as List).cast<int>(),
          ],
      };
    } catch (e) {
      eroare = e.toString();
    }
    incarcat = true;
    notifyListeners();
  }

  /// Substantele unui produs, dupa DCI-ul din nomenclator (mai multe la combinatii).
  List<Substanta> substanteProdus(String dci) {
    return [for (final i in _dupaDci[dci] ?? const <int>[]) _substante[i]];
  }

  /// Componentele unei combinatii care nu exista in baza de interactiuni si
  /// deci nu pot fi verificate.
  List<String> componenteNeacoperite(String dci) => _incomplet[dci] ?? const [];

  /// Cauta dupa denumirea DCI sau dupa cea englezeasca.
  List<Substanta> cauta(String interogare) {
    final q = normalizeForSearch(interogare);
    if (q.isEmpty) return const [];
    final inceput = <Substanta>[];
    final restul = <Substanta>[];
    for (final s in _substante) {
      if (s.cautare.startsWith(q) || s.cautare.contains(' $q')) {
        inceput.add(s);
      } else if (s.cautare.contains(q)) {
        restul.add(s);
      }
    }
    if (inceput.isEmpty && restul.isEmpty) {
      // denumirea romaneasca a substantei: "clozapina" pentru CLOZAPINUM
      final radacina = radacinaSubstanta(q);
      if (radacina != null) return cauta(radacina);
    }
    return [...inceput, ...restul].take(maxSugestii).toList();
  }

  Severitate? severitate(Substanta a, Substanta b) {
    if (a.index == b.index) return null;
    final (i, j) = a.index < b.index ? (a.index, b.index) : (b.index, a.index);
    final niveluri = _perechi[i];
    if (niveluri == null) return null;
    for (final (n, vecini) in niveluri.indexed) {
      if (vecini.contains(j)) return Severitate.values[n];
    }
    return null;
  }

  /// Interactiunile dintre toate perechile din lista, cele mai grave primele.
  List<Interactiune> verifica(List<Substanta> selectie) {
    final rezultate = <Interactiune>[];
    for (var i = 0; i < selectie.length; i++) {
      for (var j = i + 1; j < selectie.length; j++) {
        final s = severitate(selectie[i], selectie[j]);
        if (s != null) rezultate.add(Interactiune(selectie[i], selectie[j], s));
      }
    }
    mergeSort(
      rezultate,
      compare: (a, b) => a.severitate.index.compareTo(b.severitate.index),
    );
    return rezultate;
  }

  /// Subgrupa ATC (primele 5 caractere, ex. N06AB) a unei substante.
  String? clasaAtc(Substanta s, Map<String, String> atcDupaDci) {
    for (final d in s.dci) {
      final atc = atcDupaDci[d];
      if (atc != null && atc.length >= 5) return atc.substring(0, 5);
    }
    return null;
  }

  /// Substante din aceeasi subgrupa ATC cu [s] care nu au nicio interactiune
  /// majora cu [ceilalti]. Fiecare vine cu cea mai grava interactiune ramasa
  /// (null = niciuna inregistrata); cele fara interactiuni sunt primele.
  List<(Substanta, Severitate?)> alternative(
    Substanta s,
    List<Substanta> ceilalti,
    Map<String, String> atcDupaDci,
  ) {
    final clasa = clasaAtc(s, atcDupaDci);
    if (clasa == null) return const [];
    final exclusi = {s.index, for (final c in ceilalti) c.index};
    final rezultat = <(Substanta, Severitate?)>[];
    for (final e in atcDupaDci.entries) {
      if (!e.value.startsWith(clasa)) continue;
      final componente = _dupaDci[e.key] ?? const <int>[];
      // combinatiile nu sunt alternative la o substanta singura
      if (componente.length != 1 || !exclusi.add(componente.single)) continue;
      final candidat = _substante[componente.single];
      Severitate? ceaMaiGrava;
      for (final c in ceilalti) {
        final sev = severitate(candidat, c);
        if (sev != null &&
            (ceaMaiGrava == null || sev.index < ceaMaiGrava.index)) {
          ceaMaiGrava = sev;
        }
      }
      if (ceaMaiGrava != Severitate.majora) {
        rezultat.add((candidat, ceaMaiGrava));
      }
    }
    int rang(Severitate? x) => switch (x) {
      null => 0,
      Severitate.minora => 1,
      Severitate.neprecizata => 2,
      Severitate.moderata => 3,
      Severitate.majora => 4,
    };
    rezultat.sort((a, b) {
      final r = rang(a.$2).compareTo(rang(b.$2));
      return r != 0 ? r : a.$1.nume.compareTo(b.$1.nume);
    });
    return rezultat;
  }

  /// Toate substantele cu care o substanta are interactiune de nivelul dat.
  List<Substanta> partenere(Substanta s, Severitate nivel) {
    final rezultat = <Substanta>[
      for (final j in _perechi[s.index]?[nivel.index] ?? const <int>[])
        _substante[j],
    ];
    for (final e in _perechi.entries) {
      if (e.key < s.index && e.value[nivel.index].contains(s.index)) {
        rezultat.add(_substante[e.key]);
      }
    }
    rezultat.sort((a, b) => a.nume.compareTo(b.nume));
    return rezultat;
  }
}
