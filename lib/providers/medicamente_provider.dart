import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medicament.dart';
import '../services/data_store.dart';
import '../utils/rcp_extrase.dart';
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

  /// Codul ATC al fiecarei substante (DCI), luat de la primul ei produs.
  Map<String, String> get atcDupaDci => {
    for (final e in _dupaDci.entries)
      if (e.value.first.atc.isNotEmpty) e.key: e.value.first.atc,
  };

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
    // legatura dintre textele RCP si produse, pentru cautarea in continut
    _dupaRcp.clear();
    _dupaText.clear();
    for (final m in _toate) {
      if (m.rcpUrl.isNotEmpty) _dupaRcp.putIfAbsent(m.rcpUrl, () => []).add(m);
    }
    try {
      final index = await _citesteJsonGz('rcp/index.json.gz');
      for (final e in index.entries) {
        final produse = _dupaRcp[e.key];
        if (produse != null) {
          _dupaText.putIfAbsent(e.value as String, () => []).addAll(produse);
        }
      }
    } catch (_) {
      // fara index, cautarea in continut gaseste doar contraindicatiile
    }
    // protocoalele terapeutice sunt optionale
    try {
      final data = await _citesteJsonGz('protocoale.json.gz');
      dataProtocoale = data['data'] as String;
      _protocoale = [
        for (final p in data['protocoale'] as List)
          Protocol(
            p[0] as String,
            p[1] as String,
            p[2] as String,
            p[3] as String,
            p[4] as String,
            p[5] as int,
          ),
      ];
    } catch (_) {
      _protocoale = const [];
      dataProtocoale = '';
    }
    incarcat = true;
    notifyListeners();
  }

  final Map<String, List<Medicament>> _dupaRcp = {};
  final Map<String, List<Medicament>> _dupaText = {};

  /// Contraindicatiile tuturor produselor, dupa adresa RCP-ului.
  Map<String, String> get toateContraindicatiile => _contraindicatii;

  /// Produsele care au un anumit text de RCP: [cheie] este amprenta textului
  /// din pachetele de sectiuni sau, la contraindicatii, adresa RCP-ului.
  List<Medicament> produseCuTextul(String cheie) =>
      _dupaText[cheie] ?? _dupaRcp[cheie] ?? const [];

  List<Protocol> _protocoale = const [];

  /// Luna listei de protocoale CNAS, ex. "iulie 2026".
  String dataProtocoale = '';

  int get totalProtocoale => _protocoale.length;

  /// Protocoalele terapeutice CNAS care privesc medicamentul: cele cu codul
  /// lui ATC si cele in a caror denumire apare substanta (toate componentele,
  /// la o combinatie).
  List<Protocol> protocoale(Medicament m) {
    final componente = [
      for (final c in m.dci.split('+'))
        if (normalizeForSearch(c).isNotEmpty) normalizeForSearch(c),
    ];
    // "COMBINATII" si denumirile generice nu identifica o substanta
    final dupaNume =
        componente.isNotEmpty &&
        componente.every((c) => c.length > 5 && !c.startsWith('combinat'));
    return [
      for (final p in _protocoale)
        if ((m.atc.isNotEmpty && p.cod == m.atc) ||
            (dupaNume &&
                // o substanta singura nu intra sub protocoalele combinatiilor ei
                !(componente.length == 1 && p.cautare.startsWith('combinat')) &&
                componente.every(
                  (c) =>
                      RegExp('(^|[^a-z])${RegExp.escape(c)}(\$|[^a-z])')
                          .hasMatch(p.cautare),
                )))
          p,
    ];
  }

  /// Ce spune RCP-ul unui produs cu una dintre substantele [dci] despre
  /// substanta recunoscuta dupa [radacini] si despre clasa ei, data de codul
  /// [atcAlta]. Se foloseste primul produs ale carui sectiuni au fost extrase;
  /// null daca niciunul nu are.
  Future<TextRcp?> rcpDespre(
    List<String> dci,
    List<String> radacini, {
    String atcAlta = '',
  }) async {
    final incercate = <String>{};
    for (final d in dci) {
      for (final m in _dupaDci[d] ?? const <Medicament>[]) {
        if (m.rcpUrl.isEmpty || !incercate.add(m.rcpUrl)) continue;
        // cateva incercari sunt de ajuns: concentratiile au de regula acelasi RCP
        if (incercate.length > 8) return null;
        final sectiuni = await RcpStore.instance.sectiuni(m.rcpUrl);
        if (sectiuni.isEmpty) continue;
        // contraindicatiile sunt pastrate separat de celelalte sectiuni
        final toate = {...sectiuni, '4.3': ?contraindicatii(m)};
        return textDespre(
          m.denumire,
          toate,
          radacini,
          clasaInteractiuni(atcAlta),
        );
      }
    }
    return null;
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
