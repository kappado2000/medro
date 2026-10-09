import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/asistent_server.dart';

/// Trimitere la un pasaj din documentul atasat (RCP), intoarsa de API.
class Citare {
  final String document;
  final String text;
  final int? pagina;
  const Citare(this.document, this.text, this.pagina);
}

class RaspunsClaude {
  /// Blocurile de continut exact cum au venit; se retrimit neschimbate in
  /// conversatie, inclusiv cele de gandire.
  final List<dynamic> continutBrut;
  final String text;
  final List<Citare> citari;
  final String? motivOprire;

  const RaspunsClaude(
    this.continutBrut,
    this.text,
    this.citari,
    this.motivOprire,
  );

  bool get refuzat => motivOprire == 'refusal';
  bool get trunchiat => motivOprire == 'max_tokens';
}

class ClaudeException implements Exception {
  final String mesaj;
  final int? cod;
  const ClaudeException(this.mesaj, [this.cod]);

  @override
  String toString() => mesaj;
}

/// Client minimal pentru Messages API. Dart nu are SDK oficial Anthropic,
/// asa ca cererea se face direct prin HTTP.
class ClaudeClient {
  /// Modelele oferite in aplicatie: id -> denumire afisata.
  static const modele = {
    'claude-sonnet-5-5': 'Claude Sonnet 5.5',
    'claude-opus-5-5': 'Claude Opus 5.5',
  };
  static const modelImplicit = 'claude-sonnet-5-5';
  static const _url = 'https://api.anthropic.com/v1/messages';
  static const _timeout = Duration(minutes: 5);

  final http.Client _http;
  final String serverUrl;
  final String serverToken;

  ClaudeClient([
    http.Client? client,
    this.serverUrl = asistentServerUrl,
    this.serverToken = asistentServerToken,
  ]) : _http = client ?? http.Client();

  /// Serverul propriu (functia Firebase) tine cheia Anthropic; cu el
  /// aplicatia nu are nevoie de nicio cheie.
  bool get areServer => serverUrl.isNotEmpty && serverToken.isNotEmpty;

  Map<String, String> get anteteServer => {
    'content-type': 'application/json',
    'x-medro-token': serverToken,
  };

  Map<String, String> antete(String cheie) => {
    'content-type': 'application/json',
    'x-api-key': cheie,
    'anthropic-version': '2023-06-01',
    // daca filtrele de siguranta refuza cererea, serverul o reia pe alt model
    'anthropic-beta': 'server-side-fallback-2026-07-01',
    // necesar pentru apeluri direct din browser (previzualizarea web)
    if (kIsWeb) 'anthropic-dangerous-direct-browser-access': 'true',
  };

  Map<String, dynamic> corp({
    required String model,
    required String system,
    required List<Map<String, dynamic>> mesaje,
  }) => {
    'model': model,
    'max_tokens': 16000,
    'fallbacks': 'default',
    // prefixul (instructiuni + RCP atasat) se refoloseste la intrebarile urmatoare
    'cache_control': {'type': 'ephemeral'},
    'output_config': {'effort': 'medium'},
    'system': system,
    'messages': mesaje,
  };

  Future<RaspunsClaude> trimite({
    String model = modelImplicit,

    /// Cheie Anthropic proprie; goala inseamna ca cererea merge prin server.
    String cheie = '',
    required String system,
    required List<Map<String, dynamic>> mesaje,
  }) async {
    final prinServer = cheie.isEmpty;
    if (prinServer && !areServer) {
      throw const ClaudeException('Asistentul nu este configurat.');
    }
    final http.Response raspuns;
    try {
      raspuns = await _http
          .post(
            Uri.parse(prinServer ? serverUrl : _url),
            headers: prinServer ? anteteServer : antete(cheie),
            // serverul fixeaza singur restul parametrilor cererii
            body: jsonEncode(
              prinServer
                  ? {'model': model, 'system': system, 'messages': mesaje}
                  : corp(model: model, system: system, mesaje: mesaje),
            ),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const ClaudeException(
        'Răspunsul a durat prea mult. Încearcă din nou.',
      );
    } on http.ClientException catch (e) {
      // in browser, o functie nepublicata arata ca o cerere esuata, nu ca 404
      throw ClaudeException(
        prinServer
            ? 'Serverul asistentului nu răspunde: nu este publicat încă sau '
                  'nu există conexiune la internet.'
            : 'Nu există conexiune la serviciul AI (${e.message}).',
      );
    }

    if (prinServer && raspuns.statusCode == 404) {
      throw const ClaudeException(
        'Serverul asistentului nu este publicat încă.',
        404,
      );
    }
    if (prinServer && raspuns.statusCode == 403) {
      throw const ClaudeException(
        'Serverul asistentului a respins codul de acces al aplicației.',
        403,
      );
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(raspuns.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw ClaudeException(
        'Răspuns neașteptat de la server.',
        raspuns.statusCode,
      );
    }
    if (raspuns.statusCode != 200) {
      throw ClaudeException(
        _mesajEroare(raspuns.statusCode, json),
        raspuns.statusCode,
      );
    }
    return interpreteaza(json);
  }

  static String _mesajEroare(int cod, Map<String, dynamic> json) {
    final detaliu =
        (json['error'] as Map<String, dynamic>?)?['message'] as String? ?? '';
    switch (cod) {
      case 401:
        return 'Cheia API nu este validă.';
      case 403:
        return 'Cheia API nu are acces la acest model.';
      case 413:
        return 'Cererea este prea mare (documentul atașat depășește limita).';
      case 429:
        return 'Limita de cereri a fost atinsă. Încearcă peste câteva momente.';
      case 529:
        return 'Serviciul AI este supraîncărcat. Încearcă din nou.';
    }
    if (cod >= 500) return 'Eroare temporară a serviciului AI ($cod).';
    return detaliu.isEmpty
        ? 'Cerere respinsă ($cod).'
        : 'Cerere respinsă: $detaliu';
  }

  @visibleForTesting
  static RaspunsClaude interpreteaza(Map<String, dynamic> json) {
    final continut = (json['content'] as List?) ?? const [];
    final text = StringBuffer();
    final citari = <Citare>[];
    for (final bloc in continut) {
      if (bloc is! Map || bloc['type'] != 'text') continue;
      text.write(bloc['text'] as String? ?? '');
      for (final c in (bloc['citations'] as List?) ?? const []) {
        citari.add(
          Citare(
            c['document_title'] as String? ?? 'Document',
            (c['cited_text'] as String? ?? '').trim(),
            c['start_page_number'] as int?,
          ),
        );
      }
    }
    return RaspunsClaude(
      continut,
      text.toString().trim(),
      citari,
      json['stop_reason'] as String?,
    );
  }
}
