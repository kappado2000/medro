import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

/// Eroare de autentificare, cu mesaj pentru utilizator.
class AuthException implements Exception {
  final String mesaj;

  /// true cand contul nu mai e valabil si sesiunea trebuie inchisa.
  final bool sesiuneInvalida;

  const AuthException(this.mesaj, {this.sesiuneInvalida = false});

  @override
  String toString() => mesaj;
}

/// Un utilizator autentificat.
class Sesiune {
  final String email;

  /// Dovada de identitate trimisa serverului asistentului; expira dupa o ora.
  final String idToken;

  /// Cu el se obtine un idToken nou fara parola; se pastreaza pe telefon.
  final String refreshToken;
  final DateTime expira;

  const Sesiune(this.email, this.idToken, this.refreshToken, this.expira);
}

/// Conturile sunt in Firebase Authentication. Aplicatia vorbeste direct cu
/// serviciul prin HTTP (Identity Toolkit), fara SDK-ul nativ Firebase, ca sa
/// nu depinda de fisiere de configurare pe fiecare platforma.
class AuthService {
  static const _conturi = 'https://identitytoolkit.googleapis.com/v1/accounts';
  static const _tokenuri = 'https://securetoken.googleapis.com/v1/token';
  static const _timeout = Duration(seconds: 25);

  final http.Client _http;

  /// Cheia web a proiectului Firebase: un identificator public, nu un secret.
  final String apiKey;

  AuthService(this.apiKey, [http.Client? client])
    : _http = client ?? http.Client();

  bool get configurat => apiKey.isNotEmpty;

  Future<Map<String, dynamic>> _post(Uri url, Object corp) async {
    final http.Response r;
    try {
      r = await _http
          .post(
            url,
            headers: const {'content-type': 'application/json'},
            body: jsonEncode(corp),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AuthException('Serverul nu răspunde. Încearcă din nou.');
    } on http.ClientException {
      throw const AuthException('Nu există conexiune la internet.');
    } catch (_) {
      throw const AuthException('Nu există conexiune la internet.');
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw const AuthException('Răspuns neașteptat de la server.');
    }
    if (r.statusCode != 200) {
      final cod = ((json['error'] as Map?)?['message'] as String? ?? '')
          .split(' ')
          .first;
      throw AuthException(
        _mesaj(cod),
        sesiuneInvalida: const {
          'TOKEN_EXPIRED',
          'USER_DISABLED',
          'USER_NOT_FOUND',
          'INVALID_REFRESH_TOKEN',
          'INVALID_GRANT_TYPE',
        }.contains(cod),
      );
    }
    return json;
  }

  static String _mesaj(String cod) {
    switch (cod) {
      case 'EMAIL_NOT_FOUND':
      case 'INVALID_PASSWORD':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'E-mail sau parolă greșită.';
      case 'INVALID_EMAIL':
        return 'Adresa de e-mail nu este validă.';
      case 'MISSING_PASSWORD':
        return 'Scrie parola.';
      case 'USER_DISABLED':
        return 'Contul a fost dezactivat.';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'Prea multe încercări. Așteaptă câteva minute.';
      case 'TOKEN_EXPIRED':
      case 'USER_NOT_FOUND':
      case 'INVALID_REFRESH_TOKEN':
        return 'Sesiunea a expirat. Autentifică-te din nou.';
    }
    return 'Autentificarea nu a reușit${cod.isEmpty ? '' : ' ($cod)'}.';
  }

  Future<Sesiune> autentifica(String email, String parola) async {
    final j = await _post(
      Uri.parse('$_conturi:signInWithPassword?key=$apiKey'),
      {'email': email.trim(), 'password': parola, 'returnSecureToken': true},
    );
    return Sesiune(
      j['email'] as String? ?? email.trim(),
      j['idToken'] as String,
      j['refreshToken'] as String,
      DateTime.now().add(
        Duration(seconds: int.tryParse('${j['expiresIn']}') ?? 3600),
      ),
    );
  }

  /// Un idToken nou pentru o sesiune pastrata pe telefon.
  Future<Sesiune> reimprospateaza(String email, String refreshToken) async {
    final j = await _post(Uri.parse('$_tokenuri?key=$apiKey'), {
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
    });
    return Sesiune(
      email,
      j['id_token'] as String,
      j['refresh_token'] as String? ?? refreshToken,
      DateTime.now().add(
        Duration(seconds: int.tryParse('${j['expires_in']}') ?? 3600),
      ),
    );
  }

  /// Trimite e-mailul de resetare a parolei.
  Future<void> trimiteResetare(String email) async {
    await _post(Uri.parse('$_conturi:sendOobCode?key=$apiKey'), {
      'requestType': 'PASSWORD_RESET',
      'email': email.trim(),
    });
  }
}

/// Unde se pastreaza sesiunea intre porniri.
abstract class DepozitSesiune {
  Future<(String email, String refreshToken)?> citeste();
  Future<void> scrie(String email, String refreshToken);
  Future<void> sterge();
}

/// Keychain pe iOS, Keystore pe Android.
class DepozitSigur implements DepozitSesiune {
  static const _email = 'cont_email';
  static const _token = 'cont_refresh_token';
  final FlutterSecureStorage _stocare;

  const DepozitSigur([this._stocare = const FlutterSecureStorage()]);

  @override
  Future<(String, String)?> citeste() async {
    try {
      // un depozit blocat nu are voie sa tina aplicatia pe ecranul de pornire
      const limita = Duration(seconds: 8);
      final email = await _stocare.read(key: _email).timeout(limita);
      final token = await _stocare.read(key: _token).timeout(limita);
      if (email == null || token == null || token.isEmpty) return null;
      return (email, token);
    } catch (_) {
      // un depozit care nu se poate citi inseamna autentificare din nou
      return null;
    }
  }

  @override
  Future<void> scrie(String email, String refreshToken) async {
    await _stocare.write(key: _email, value: email);
    await _stocare.write(key: _token, value: refreshToken);
  }

  @override
  Future<void> sterge() async {
    try {
      await _stocare.delete(key: _email);
      await _stocare.delete(key: _token);
    } catch (_) {}
  }
}

/// Confirmarea identitatii pe telefon: amprenta, Face ID sau codul telefonului.
abstract class Biometrie {
  /// false pe dispozitivele fara nicio metoda de blocare (si in browser).
  Future<bool> disponibila();

  /// true daca utilizatorul a confirmat.
  Future<bool> confirma();
}

class BiometrieTelefon implements Biometrie {
  final LocalAuthentication _auth;
  BiometrieTelefon([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  @override
  Future<bool> disponibila() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> confirma() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Confirmă că ești tu pentru a deschide MedRO',
        // fara amprenta sau Face ID se accepta codul telefonului
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
