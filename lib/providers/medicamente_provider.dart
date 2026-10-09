import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medicament.dart';
import '../services/data_store.dart';
import '../utils/text_utils.dart';

enum FiltruMedicamente { toate, faraReteta, cuReteta, compensate, favorite }

class MedicamenteProvider extends ChangeNotifier {
  static const _assetPath = 'medicamente.json.gz';
  static const _compensareAssetPath = 'compensare.json.gz';
  static const _contraindicatiiAssetPath = 'contraindicatii.json.gz';
  static const _favoriteKey = 'favorite';
  static const maxRezultate = 200;

  List<Medicament> _toate = const [];
  final Map<String, List<Medicament>> _dupaDci = {};
  Set<String> _favorite = {};
  Map<String, List<Compensare>> _compensare = const {};
  Map<String, List<String>> _listeDci = const {};
  Map<String, List<Compensare>> _compensareNume = const {};

  /// Sectiunea 4.3 din RCP, dupa adresa documentului.
  Map<String, String> _contraindicatii = const {};

  /// Data listei CNAS din care provin incadrarile si preturile.
  String dataCompensare = '';
  String actualizat = '';
  bool incarcat = false;
  String? eroare;

  int get total => _toate.length;

  /// Cate zile au trecut de la data nomenclatorului inclus in aplicatie
  /// ("08.10.26"); null daca data nu poate fi citita.
  int? zileVechime([DateTime? azi]) {
    final m = RegExp(r'^(\d{2})\.(\d{2})\.(\d{2})$').firstMatch(actualizat);
    if (m == null) return null;
    final data = DateTime(
      2000 + int.parse(m.group(3)!),
      int.parse(m.group(2)!),
      int.parse(m.group(1)!),
    );
    return (azi ?? DateTime.now()).difference(data).inDays;
  }

  /// Peste acest prag, antetul avertizeaza ca datele trebuie actualizate.
  static const pragVechimeZile = 90;
  int get totalSubstante => _dupaDci.length;

  Future<void> incarca() async {
    eroare = null;
    _dupaDci.clear();
    try {
      final data = await _citesteJsonGz(_assetPath);
      actualizat = data['updated'] as String;
      _toate = [
        for (final p in data['products'] as List)
          Medicament.fromJson(p as Map<String, dynamic>),
      ]..sort((a, b) => a.denumireNorm.compareTo(b.denumireNorm));
      for (final m in _toate) {
        if (m.dci.isNotEmpty) _dupaDci.putIfAbsent(m.dci, () => []).add(m);
      }
      final prefs = await SharedPreferences.getInstance();
      _favorite = (prefs.getStringList(_favoriteKey) ?? const []).toSet();
    } catch (e) {
      eroare = e.toString();
    }
    // registrul ramane utilizabil chiar daca lista de compensare lipseste
    try {
      await _incarcaCompensare();
    } catch (_) {
      dataCompensare = '';
    }
    // extragerea contraindicatiilor e partiala si optionala
    try {
      final data = await _citesteJsonGz(_contraindicatiiAssetPath);
      _contraindicatii = data.cast<String, String>();
    } catch (_) {
      _contraindicatii = const {};
    }
    incarcat = true;
    notifyListeners();
  }

  /// Contraindicatiile din RCP-ul produsului (sectiunea 4.3), daca au putut
  /// fi extrase; textul e cel din document.
  String? contraindicatii(Medicament m) => _contraindicatii[m.rcpUrl];

  Future<Map<String, dynamic>> _citesteJsonGz(String asset) async {
    return await DataStore.instance.jsonGz(asset) as Map<String, dynamic>;
  }

  Future<void> _incarcaCompensare() async {
    final data = await _citesteJsonGz(_compensareAssetPath);
    _compensare = {
      for (final e in (data['cim'] as Map<String, dynamic>).entries)
        e.key: [
          for (final c in e.value as List) Compensare.fromJson(c as List),
        ],
    };
    _listeDci = {
      for (final e in (data['dci'] as Map<String, dynamic>).entries)
        e.key: (e.value as List).cast<String>(),
    };
    _compensareNume = {
      for (final e
          in ((data['nume'] as Map<String, dynamic>?) ?? const {}).entries)
        e.key: [
          for (final c in e.value as List) Compensare.fromJson(c as List),
        ],
    };
    dataCompensare = data['data'] as String;
    for (final m in _toate) {
      final liste = <String>{
        for (final a in m.ambalaje)
          for (final c in _compensare[a.cim] ?? const <Compensare>[]) c.lista,
      };
      // codul ambalajului se schimba la reautorizare; atunci produsul se
      // regaseste in lista CNAS doar dupa denumire
      if (liste.isEmpty) {
        liste.addAll(compensareDupaNume(m).map((c) => c.lista));
      }
      if (liste.isNotEmpty) m.liste = liste.toList()..sort();
    }
  }

  /// Incadrarile CNAS ale unui ambalaj, dupa codul CIM.
  List<Compensare> compensareAmbalaj(String cim) =>
      _compensare[cim] ?? const [];

  /// Incadrarile gasite dupa denumire, cand niciun cod de ambalaj al
  /// produsului nu apare in lista CNAS.
  List<Compensare> compensareDupaNume(Medicament m) {
    if (m.ambalaje.any((a) => _compensare.containsKey(a.cim))) return const [];
    return _compensareNume[cheieCompensareNume(m.denumire, m.dci)] ?? const [];
  }

  /// Sublistele in care figureaza substanta activa, indiferent de ambalaj.
  List<String> listeSubstanta(String dci) => _listeDci[dci] ?? const [];

  bool esteFavorit(Medicament m) =>
      _favorite.contains(m.id) || _favorite.contains(m.ambalaje.first.cim);

  Future<void> comutaFavorit(Medicament m) async {
    final era = esteFavorit(m);
    _favorite
      ..remove(m.id)
      ..remove(m.ambalaje.first.cim);
    if (!era) _favorite.add(m.id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteKey, _favorite.toList());
  }

  /// Alte produse cu aceeasi substanta activa.
  List<Medicament> echivalente(Medicament m) {
    return [
      for (final x in _dupaDci[m.dci] ?? const <Medicament>[])
        if (!identical(x, m)) x,
    ];
  }

  /// Cauta dupa denumire, substanta activa sau cod ATC. Fiecare cuvant din
  /// interogare trebuie sa se regaseasca; potrivirile la inceput de denumire
  /// apar primele.
  List<Medicament> cauta(
    String interogare,
    FiltruMedicamente filtru, {
    String atcPrefix = '',
  }) {
    final cuvinte = normalizeForSearch(interogare)
        .split(' ')
        .where((c) => c.isNotEmpty)
        .toList();
    final rezultate = <(int, Medicament)>[];
    for (final m in _toate) {
      if (!_trecFiltru(m, filtru)) continue;
      if (!m.atc.startsWith(atcPrefix)) continue;
      if (cuvinte.isEmpty) {
        rezultate.add((0, m));
        continue;
      }
      final scor = _scor(m, cuvinte);
      if (scor != null) rezultate.add((scor, m));
    }
    if (cuvinte.isNotEmpty) {
      // sortarea e stabila fata de ordinea alfabetica initiala
      mergeSort(rezultate, compare: (a, b) => a.$1.compareTo(b.$1));
    }
    final limita = atcPrefix.isEmpty ? maxRezultate : rezultate.length;
    return [for (final r in rezultate.take(limita)) r.$2];
  }

  bool _trecFiltru(Medicament m, FiltruMedicamente filtru) {
    switch (filtru) {
      case FiltruMedicamente.toate:
        return true;
      case FiltruMedicamente.faraReteta:
        return m.faraReteta;
      case FiltruMedicamente.cuReteta:
        return !m.faraReteta;
      case FiltruMedicamente.compensate:
        return m.liste.isNotEmpty;
      case FiltruMedicamente.favorite:
        return esteFavorit(m);
    }
  }

  int? _scor(Medicament m, List<String> cuvinte) {
    final atc = m.atc.toLowerCase();
    var scor = 0;
    for (final c in cuvinte) {
      if (m.denumireNorm.startsWith(c)) {
        scor += 0;
      } else if (m.dciNorm.startsWith(c)) {
        scor += 1;
      } else if (m.denumireNorm.contains(' $c')) {
        scor += 2;
      } else if (m.denumireNorm.contains(c) || m.dciNorm.contains(c)) {
        scor += 3;
      } else if (atc.startsWith(c)) {
        scor += 4;
      } else {
        // denumirea romaneasca a substantei: "clozapina" pentru CLOZAPINUM
        final radacina = radacinaSubstanta(c);
        if (radacina == null || !m.dciNorm.contains(radacina)) return null;
        scor += 3;
      }
    }
    return scor;
  }
}
