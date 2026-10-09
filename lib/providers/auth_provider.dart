import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config/asistent_server.dart';
import '../services/auth_service.dart';

enum StareAcces {
  /// Se citeste sesiunea pastrata pe telefon.
  seIncarca,

  /// Nu exista cont pe acest telefon: se cer e-mailul si parola.
  neautentificat,

  /// Exista cont, dar aplicatia asteapta amprenta, Face ID sau parola.
  blocat,

  deblocat,
}

/// In testele de interfata aplicatia porneste fara cont, ca si cand cheia
/// proiectului nu ar fi configurata.
String _cheieImplicita() {
  if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) return '';
  return firebaseApiKey;
}

/// Contul utilizatorului si blocarea aplicatiei.
class AuthProvider extends ChangeNotifier {
  /// Dupa atat timp in fundal, aplicatia se blocheaza din nou.
  static const pauzaPanaLaBlocare = Duration(minutes: 1);

  final AuthService _serviciu;
  final DepozitSesiune _depozit;
  final Biometrie _biometrie;
  final DateTime Function() _acum;

  AuthProvider({
    AuthService? serviciu,
    DepozitSesiune? depozit,
    Biometrie? biometrie,
    DateTime Function()? acum,
  }) : _serviciu = serviciu ?? AuthService(_cheieImplicita()),
       _depozit = depozit ?? const DepozitSigur(),
       _biometrie = biometrie ?? BiometrieTelefon(),
       _acum = acum ?? DateTime.now;

  StareAcces stare = StareAcces.seIncarca;
  String email = '';
  bool lucreaza = false;

  String? _refreshToken;
  Sesiune? _sesiune;
  DateTime? _plecat;
  bool _confirmareInCurs = false;

  /// Fara cheia proiectului Firebase aplicatia nu are conturi si nu se blocheaza.
  bool get activ => _serviciu.configurat;

  bool get deblocat => stare == StareAcces.deblocat;

  Future<void> incarca() async {
    if (!activ) {
      stare = StareAcces.deblocat;
      notifyListeners();
      return;
    }
    final pastrat = await _depozit.citeste();
    if (pastrat == null) {
      stare = StareAcces.neautentificat;
      notifyListeners();
      return;
    }
    email = pastrat.$1;
    _refreshToken = pastrat.$2;
    stare = StareAcces.blocat;
    notifyListeners();
    await deblocheaza();
  }

  /// false pe un telefon fara amprenta, Face ID sau cod de blocare: acolo
  /// ecranul de blocare arata direct parola contului.
  Future<bool> poateDebloca() => _biometrie.disponibila();

  /// Cere amprenta, Face ID sau codul telefonului. Merge si fara internet.
  Future<bool> deblocheaza() async {
    if (stare != StareAcces.blocat || _confirmareInCurs) return false;
    _confirmareInCurs = true;
    try {
      // un telefon fara nicio metoda de blocare nu are cu ce confirma:
      // ramane parola contului
      if (!await _biometrie.disponibila()) return false;
      final ok = await _biometrie.confirma();
      if (ok && stare == StareAcces.blocat) {
        stare = StareAcces.deblocat;
        notifyListeners();
      }
      return ok;
    } finally {
      _confirmareInCurs = false;
    }
  }

  /// Autentificare cu e-mail si parola: la prima folosire si ca alternativa la
  /// biometrie. Intoarce mesajul de eroare sau null la reusita.
  Future<String?> autentifica(String adresa, String parola) async {
    if (adresa.trim().isEmpty || parola.isEmpty) {
      return 'Scrie e-mailul și parola.';
    }
    lucreaza = true;
    notifyListeners();
    try {
      final s = await _serviciu.autentifica(adresa, parola);
      _sesiune = s;
      _refreshToken = s.refreshToken;
      email = s.email;
      await _depozit.scrie(s.email, s.refreshToken);
      stare = StareAcces.deblocat;
      return null;
    } on AuthException catch (e) {
      return e.mesaj;
    } finally {
      lucreaza = false;
      notifyListeners();
    }
  }

  /// Mesajul de afisat dupa cererea de resetare a parolei.
  Future<String> reseteazaParola(String adresa) async {
    if (adresa.trim().isEmpty) return 'Scrie întâi adresa de e-mail.';
    try {
      await _serviciu.trimiteResetare(adresa);
    } on AuthException catch (e) {
      // nu se dezvaluie daca adresa are sau nu cont
      if (e.mesaj.contains('internet') || e.mesaj.contains('Serverul')) {
        return e.mesaj;
      }
    }
    return 'Dacă adresa are cont, vei primi un e-mail cu legătura de resetare.';
  }

  Future<void> iesi() async {
    await _depozit.sterge();
    _sesiune = null;
    _refreshToken = null;
    email = '';
    stare = activ ? StareAcces.neautentificat : StareAcces.deblocat;
    notifyListeners();
  }

  /// Dovada de identitate pentru serverul asistentului; null daca nu exista
  /// cont sau nu poate fi reinnoita.
  Future<String?> tokenId() async {
    if (!activ || !deblocat) return null;
    final s = _sesiune;
    if (s != null &&
        s.expira.isAfter(_acum().add(const Duration(minutes: 2)))) {
      return s.idToken;
    }
    final refresh = _refreshToken;
    if (refresh == null) return null;
    try {
      final noua = await _serviciu.reimprospateaza(email, refresh);
      _sesiune = noua;
      if (noua.refreshToken != refresh) {
        _refreshToken = noua.refreshToken;
        await _depozit.scrie(email, noua.refreshToken);
      }
      return noua.idToken;
    } on AuthException catch (e) {
      // cont sters, dezactivat sau cu parola schimbata: se cere din nou parola
      if (e.sesiuneInvalida) await iesi();
      return null;
    }
  }

  /// Aplicatia a trecut in fundal.
  void laPlecare() => _plecat ??= _acum();

  /// Aplicatia a revenit in fata; dupa o pauza lunga se blocheaza.
  void laRevenire() {
    final plecat = _plecat;
    _plecat = null;
    if (!activ || stare != StareAcces.deblocat || plecat == null) return;
    if (_acum().difference(plecat) < pauzaPanaLaBlocare) return;
    stare = StareAcces.blocat;
    notifyListeners();
    deblocheaza();
  }
}
