import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Recunoasterea vorbirii, in spatele unei interfete care se poate inlocui in teste.
abstract class MotorDictare {
  /// false daca telefonul nu are recunoastere vocala sau permisiunea a fost refuzata.
  Future<bool> pregateste({
    required void Function(String stare) laStare,
    required void Function(String eroare) laEroare,
  });

  Future<void> asculta(void Function(String text, bool final_) laText);
  Future<void> opreste();
}

/// Citirea cu voce tare.
abstract class MotorCitire {
  Future<void> pregateste({required VoidCallback laSfarsit});
  Future<void> citeste(String text);
  Future<void> opreste();
}

class DictareTelefon implements MotorDictare {
  final SpeechToText _stt = SpeechToText();

  @override
  Future<bool> pregateste({
    required void Function(String stare) laStare,
    required void Function(String eroare) laEroare,
  }) {
    return _stt.initialize(
      onStatus: laStare,
      onError: (SpeechRecognitionError e) => laEroare(e.errorMsg),
    );
  }

  @override
  Future<void> asculta(void Function(String text, bool final_) laText) async {
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) =>
          laText(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: 'ro_RO',
        partialResults: true,
        // dictarea se opreste singura dupa o pauza sau dupa un minut
        pauseFor: const Duration(seconds: 4),
        listenFor: const Duration(seconds: 60),
      ),
    );
  }

  @override
  Future<void> opreste() => _stt.stop();
}

class CitireTelefon implements MotorCitire {
  final FlutterTts _tts = FlutterTts();

  @override
  Future<void> pregateste({required VoidCallback laSfarsit}) async {
    _tts
      ..setCompletionHandler(laSfarsit)
      ..setCancelHandler(laSfarsit)
      ..setErrorHandler((_) => laSfarsit());
    await _tts.setLanguage('ro-RO');
  }

  @override
  Future<void> citeste(String text) async => _tts.speak(text);

  @override
  Future<void> opreste() async => _tts.stop();
}

/// Vocea asistentului: dictarea intrebarii si citirea raspunsurilor.
class Voce extends ChangeNotifier {
  final MotorDictare _dictare;
  final MotorCitire _citire;

  Voce({MotorDictare? dictare, MotorCitire? citire})
    : _dictare = dictare ?? DictareTelefon(),
      _citire = citire ?? CitireTelefon();

  bool _dictarePregatita = false;
  bool _citirePregatita = false;

  /// Microfonul este deschis.
  bool asculta = false;

  /// Raspunsul care se citeste acum (obiectul mesajului), sau null.
  Object? citit;

  /// Ultima problema de afisat utilizatorului; se goleste la o noua incercare.
  String? eroare;

  /// Porneste dictarea; [laText] primeste textul recunoscut pe masura ce se
  /// vorbeste. Intoarce false daca dictarea nu poate porni.
  Future<bool> pornesteDictarea(void Function(String text) laText) async {
    eroare = null;
    await opresteCitirea();
    try {
      if (!_dictarePregatita) {
        _dictarePregatita = await _dictare.pregateste(
          laStare: (stare) {
            // motorul anunta singur cand a incheiat ascultarea
            if (stare == 'done' || stare == 'notListening') {
              _seteazaAsculta(false);
            }
          },
          laEroare: (e) {
            eroare = _mesajEroare(e);
            _seteazaAsculta(false);
          },
        );
      }
      if (!_dictarePregatita) {
        eroare =
            'Dictarea nu este disponibilă: verifică permisiunea pentru microfon '
            'și recunoașterea vocală în setările telefonului.';
        notifyListeners();
        return false;
      }
      _seteazaAsculta(true);
      await _dictare.asculta((text, _) => laText(text));
      return true;
    } catch (_) {
      eroare = 'Dictarea nu a putut porni pe acest dispozitiv.';
      _seteazaAsculta(false);
      return false;
    }
  }

  Future<void> opresteDictarea() async {
    if (!asculta) return;
    try {
      await _dictare.opreste();
    } catch (_) {}
    _seteazaAsculta(false);
  }

  /// Citeste [text] cu voce tare; a doua atingere pe acelasi mesaj opreste.
  Future<void> comutaCitirea(Object mesaj, String text) async {
    if (citit == mesaj) {
      await opresteCitirea();
      return;
    }
    eroare = null;
    await opresteDictarea();
    try {
      if (!_citirePregatita) {
        await _citire.pregateste(
          laSfarsit: () {
            citit = null;
            notifyListeners();
          },
        );
        _citirePregatita = true;
      }
      await _citire.opreste();
      citit = mesaj;
      notifyListeners();
      await _citire.citeste(textPentruCitire(text));
    } catch (_) {
      citit = null;
      eroare = 'Citirea cu voce tare nu este disponibilă pe acest dispozitiv.';
      notifyListeners();
    }
  }

  Future<void> opresteCitirea() async {
    if (citit == null) return;
    citit = null;
    notifyListeners();
    try {
      await _citire.opreste();
    } catch (_) {}
  }

  void _seteazaAsculta(bool valoare) {
    if (asculta == valoare) return;
    asculta = valoare;
    notifyListeners();
  }

  static String _mesajEroare(String cod) {
    switch (cod) {
      case 'error_no_match':
      case 'error_speech_timeout':
        return 'Nu am înțeles nimic. Încearcă din nou, mai aproape de microfon.';
      case 'error_permission':
      case 'error_audio':
        return 'Microfonul nu este permis pentru MedRO. Activează-l în setările telefonului.';
      case 'error_network':
      case 'error_network_timeout':
      case 'error_server':
        return 'Dictarea are nevoie de internet pe acest telefon.';
      case 'error_language_not_supported':
      case 'error_language_unavailable':
        return 'Limba română nu este instalată pentru dictare pe acest telefon.';
    }
    return 'Dictarea s-a oprit ($cod).';
  }
}

/// Raspunsul pregatit pentru citire: liniutele de enumerare si semnele care nu
/// se pronunta devin pauze.
String textPentruCitire(String text) {
  return text
      .split('\n')
      .map(
        (rand) => rand
            .replaceFirst(RegExp(r'^\s*[-•]\s*'), '')
            .replaceAll(RegExp(r'[*_#<>]'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim(),
      )
      .where((rand) => rand.isNotEmpty)
      .map((rand) => RegExp(r'[.!?:;]$').hasMatch(rand) ? rand : '$rand.')
      .join(' ');
}
