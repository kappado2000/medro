import 'package:flutter/foundation.dart';

import '../models/sinteza.dart';
import '../services/sinteza_store.dart';

class SintezaProvider extends ChangeNotifier {
  final SintezaStore _store;
  SintezaProvider([SintezaStore? store]) : _store = store ?? SintezaStore();

  /// Editiile publicate, cea mai noua prima.
  List<RezumatEditie> editii = const [];

  /// Editia afisata acum.
  EditieSinteza? editie;
  bool seIncarca = false;
  String? eroare;
  bool _pornit = false;

  /// Incarca lista si cea mai noua editie, o singura data; apelata cand
  /// sectiunea este deschisa prima oara, ca aplicatia sa nu foloseasca
  /// internetul pentru o pagina pe care nimeni nu o citeste.
  Future<void> incarcaLaPrimaDeschidere() async {
    if (_pornit) return;
    _pornit = true;
    await reincarca();
  }

  /// Intreaba serverul daca exista o editie noua si o afiseaza pe cea mai
  /// recenta.
  Future<void> reincarca() async {
    seIncarca = true;
    eroare = null;
    notifyListeners();
    final lista = await _store.index();
    if (lista == null || lista.isEmpty) {
      seIncarca = false;
      eroare = lista == null
          ? 'Sinteza nu a putut fi descărcată. Verifică legătura la internet.'
          : 'Nu a fost publicată încă nicio ediție.';
      notifyListeners();
      return;
    }
    editii = lista;
    await _deschide(lista.first.id);
  }

  /// Afiseaza o editie din arhiva.
  Future<void> alege(String id) async {
    if (editie?.id == id) return;
    seIncarca = true;
    eroare = null;
    notifyListeners();
    await _deschide(id);
  }

  Future<void> _deschide(String id) async {
    final versiune = editii
        .where((r) => r.id == id)
        .map((r) => r.versiune)
        .firstOrNull;
    final e = await _store.editie(id, versiune: versiune ?? '');
    seIncarca = false;
    if (e == null) {
      eroare =
          'Ediția nu a putut fi descărcată. Verifică legătura la internet.';
    } else {
      editie = e;
    }
    notifyListeners();
  }
}
