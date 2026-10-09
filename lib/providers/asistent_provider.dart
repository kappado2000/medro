import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medicament.dart';
import '../services/claude_client.dart';
import '../utils/text_utils.dart';
import 'interactiuni_provider.dart';
import 'medicamente_provider.dart';

class MesajAsistent {
  final bool utilizator;
  final String text;
  final List<Citare> citari;
  final bool avertizare;

  const MesajAsistent({
    required this.utilizator,
    required this.text,
    this.citari = const [],
    this.avertizare = false,
  });
}

const instructiuniAsistent = '''
Ești asistentul unei aplicații de referință medicală folosite de un medic psihiatru din România. Răspunzi în limba română, clar și la obiect, pentru un cititor cu pregătire medicală.

La fiecare conversație poți primi două feluri de material: documente atașate (rezumatul caracteristicilor produsului, RCP, pentru medicamentele alese de medic) și un bloc <date_aplicatie> cu informații din nomenclatorul ANMDM, lista de compensare CNAS și baza de interacțiuni DDInter. Blocul este context complet, generat automat pentru medicamentele atașate, nu o parte a întrebării: folosește din el doar ce ajută la întrebarea pusă și nu îl comenta dacă nu are legătură cu ea. Întrebarea medicului este textul care urmează după bloc.

Materialul primit este sursa ta principală. Pentru doze, contraindicații, interacțiuni, ajustări la insuficiență renală sau hepatică și reacții adverse, sprijină-te pe RCP-ul atașat și citează pasajul relevant. Dacă informația cerută nu se află în material, spune asta explicit și precizează că ce urmează vine din cunoștințele tale generale, fiindcă medicul trebuie să poată deosebi ce e verificabil în RCP de ce nu este. Nu completa din memorie cifre de dozaj care lipsesc din material.

Baza DDInter oferă doar nivelul de severitate al unei interacțiuni, fără mecanism. Când explici o interacțiune, caută mecanismul și conduita în RCP; lipsa unei perechi din DDInter nu înseamnă că interacțiunea nu există.

Decizia clinică aparține medicului. Nu adăuga avertismente generice la fiecare răspuns; semnalează doar riscurile concrete, relevante pentru întrebare.

Răspunsul este afișat într-o aplicație de telefon care arată textul exact cum îl scrii, fără să interpreteze Markdown. Scrie deci text simplu: fără asteriscuri pentru îngroșare, fără titluri cu diez și fără tabele. Pentru enumerări folosește rânduri scurte care încep cu o liniuță.''';

class AsistentProvider extends ChangeNotifier {
  static const _cheieKey = 'cheie_api_anthropic';
  static const _modelKey = 'model_asistent';
  static const maxAtasate = 3;

  final ClaudeClient _client;
  AsistentProvider([ClaudeClient? client]) : _client = client ?? ClaudeClient();

  String cheie = '';
  bool incarcat = false;
  bool asteapta = false;
  bool includeRcp = true;
  String model = ClaudeClient.modelImplicit;

  final List<Medicament> atasate = [];
  final List<MesajAsistent> mesaje = [];

  /// Istoricul trimis la API; se adauga doar la sfarsit, niciodata nu se editeaza.
  final List<Map<String, dynamic>> _istoric = [];

  bool get areCheie => cheie.isNotEmpty;

  /// Asistentul merge fie prin serverul propriu, fie cu o cheie introdusa aici.
  bool get disponibil => _client.areServer || areCheie;
  bool get conversatieInceputa => _istoric.isNotEmpty;

  Future<void> incarca() async {
    final prefs = await SharedPreferences.getInstance();
    cheie = prefs.getString(_cheieKey) ?? '';
    final salvat = prefs.getString(_modelKey);
    if (ClaudeClient.modele.containsKey(salvat)) model = salvat!;
    incarcat = true;
    notifyListeners();
  }

  Future<void> seteazaCheie(String valoare) async {
    cheie = valoare.trim();
    final prefs = await SharedPreferences.getInstance();
    if (cheie.isEmpty) {
      await prefs.remove(_cheieKey);
    } else {
      await prefs.setString(_cheieKey, cheie);
    }
    notifyListeners();
  }

  /// Atasarile se fixeaza la prima intrebare; schimbarea lor porneste o conversatie noua.
  void ataseaza(Medicament m) {
    if (atasate.any((x) => x.id == m.id)) return;
    if (conversatieInceputa) conversatieNoua(pastreazaAtasate: true);
    if (atasate.length >= maxAtasate) atasate.removeAt(0);
    atasate.add(m);
    notifyListeners();
  }

  void detaseaza(Medicament m) {
    if (conversatieInceputa) conversatieNoua(pastreazaAtasate: true);
    atasate.removeWhere((x) => x.id == m.id);
    notifyListeners();
  }

  /// Blocurile de gandire sunt legate de modelul care le-a produs, deci
  /// schimbarea modelului porneste o conversatie noua.
  Future<void> seteazaModel(String valoare) async {
    if (valoare == model || !ClaudeClient.modele.containsKey(valoare)) return;
    if (conversatieInceputa) conversatieNoua(pastreazaAtasate: true);
    model = valoare;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, valoare);
  }

  void seteazaIncludeRcp(bool valoare) {
    if (conversatieInceputa) conversatieNoua(pastreazaAtasate: true);
    includeRcp = valoare;
    notifyListeners();
  }

  void conversatieNoua({bool pastreazaAtasate = false}) {
    _istoric.clear();
    mesaje.clear();
    if (!pastreazaAtasate) atasate.clear();
    notifyListeners();
  }

  /// Datele din aplicatie despre medicamentele atasate, ca text pentru model.
  @visibleForTesting
  String dateAplicatie(MedicamenteProvider med, InteractiuniProvider inter) {
    if (atasate.isEmpty) return '';
    final b = StringBuffer('Date din aplicație\n');
    for (final m in atasate) {
      b.writeln('\n${m.denumire}');
      b.writeln('- Substanță activă (DCI): ${titleCase(m.dci)}');
      b.writeln(
        '- Formă și concentrație: ${m.forma.toLowerCase()}, ${m.concentratie}',
      );
      b.writeln('- Cod ATC: ${m.atc} (${titleCase(m.actiune)})');
      b.writeln('- Prescripție: ${m.prescriptie}');
      final liste = m.liste.isNotEmpty ? m.liste : med.listeSubstanta(m.dci);
      if (med.dataCompensare.isNotEmpty) {
        b.writeln(
          liste.isEmpty
              ? '- Compensare CNAS (lista din ${med.dataCompensare}): nu figurează'
              : '- Compensare CNAS (lista din ${med.dataCompensare}): '
                    'sublista ${liste.join(', ')}',
        );
      }
    }
    final substante = <Substanta>[];
    for (final m in atasate) {
      for (final s in inter.substanteProdus(m.dci)) {
        if (!substante.any((x) => x.index == s.index)) substante.add(s);
      }
    }
    if (substante.length > 1) {
      b.writeln('\nInteracțiuni între substanțele atașate, după DDInter 2.0:');
      final gasite = inter.verifica(substante);
      if (gasite.isEmpty) b.writeln('- nicio pereche înregistrată');
      for (final i in gasite) {
        b.writeln(
          '- ${i.a.nume} + ${i.b.nume}: severitate ${_severitate(i.severitate)}',
        );
      }
    }
    return b.toString().trim();
  }

  static String _severitate(Severitate s) {
    switch (s) {
      case Severitate.majora:
        return 'majoră';
      case Severitate.moderata:
        return 'moderată';
      case Severitate.minora:
        return 'minoră';
      case Severitate.neprecizata:
        return 'neprecizată';
    }
  }

  /// Continutul primului mesaj: RCP-urile ca documente, datele din aplicatie,
  /// apoi intrebarea. Mesajele urmatoare contin doar intrebarea.
  @visibleForTesting
  List<Map<String, dynamic>> continutMesaj(
    String intrebare,
    MedicamenteProvider med,
    InteractiuniProvider inter, {
    required bool cuDocumente,
  }) {
    if (conversatieInceputa) {
      return [
        {'type': 'text', 'text': intrebare},
      ];
    }
    final date = dateAplicatie(med, inter);
    final documente = <Map<String, dynamic>>[
      if (cuDocumente)
        for (final m in atasate)
          if (m.rcpUrl.isNotEmpty)
            {
              'type': 'document',
              'source': {'type': 'url', 'url': m.rcpUrl},
              'title': 'RCP ${m.denumire}',
              'citations': {'enabled': true},
            },
    ];
    // Punct de cache fix dupa ultimul document: raspunsurile cu citari au
    // zeci de blocuri, iar cache-ul automat nu mai regaseste prefixul peste
    // ele, deci fara asta fiecare intrebare ar plati din nou tot RCP-ul.
    if (documente.isNotEmpty) {
      documente.last['cache_control'] = {'type': 'ephemeral'};
    }
    return [
      ...documente,
      if (date.isNotEmpty)
        {'type': 'text', 'text': '<date_aplicatie>\n$date\n</date_aplicatie>'},
      {'type': 'text', 'text': intrebare},
    ];
  }

  Future<void> trimite(
    String intrebare,
    MedicamenteProvider med,
    InteractiuniProvider inter,
  ) async {
    final text = intrebare.trim();
    if (text.isEmpty || asteapta || !disponibil) return;
    mesaje.add(MesajAsistent(utilizator: true, text: text));
    asteapta = true;
    notifyListeners();

    final cuDocumente = includeRcp && atasate.any((m) => m.rcpUrl.isNotEmpty);
    try {
      RaspunsClaude raspuns;
      var continut = continutMesaj(text, med, inter, cuDocumente: cuDocumente);
      try {
        raspuns = await _cere(continut);
      } on ClaudeException catch (e) {
        // RCP-ul nu a putut fi preluat de server (PDF inaccesibil sau prea mare):
        // intrebarea se retrimite doar cu datele din aplicatie
        final laPrimulMesaj = !conversatieInceputa && cuDocumente;
        if (!laPrimulMesaj || (e.cod != 400 && e.cod != 413)) rethrow;
        continut = continutMesaj(text, med, inter, cuDocumente: false);
        raspuns = await _cere(continut);
        mesaje.add(
          const MesajAsistent(
            utilizator: false,
            avertizare: true,
            text: 'RCP-ul nu a putut fi atașat; răspunsul se bazează doar pe datele din aplicație.',
          ),
        );
      }
      _istoric
        ..add({'role': 'user', 'content': continut})
        ..add({'role': 'assistant', 'content': raspuns.continutBrut});
      mesaje.add(_mesajDin(raspuns));
    } on ClaudeException catch (e) {
      mesaje.add(
        MesajAsistent(utilizator: false, text: e.mesaj, avertizare: true),
      );
    } finally {
      asteapta = false;
      notifyListeners();
    }
  }

  Future<RaspunsClaude> _cere(List<Map<String, dynamic>> continut) {
    return _client.trimite(
      cheie: cheie,
      model: model,
      system: instructiuniAsistent,
      mesaje: [
        ..._istoric,
        {'role': 'user', 'content': continut},
      ],
    );
  }

  static MesajAsistent _mesajDin(RaspunsClaude r) {
    if (r.refuzat) {
      return const MesajAsistent(
        utilizator: false,
        avertizare: true,
        text:
            'Asistentul nu a putut răspunde la această întrebare. Reformulează sau '
            'pornește o conversație nouă.',
      );
    }
    final text = r.trunchiat
        ? '${r.text}\n\n(Răspuns întrerupt la limita de lungime.)'
        : r.text;
    return MesajAsistent(
      utilizator: false,
      text: text.isEmpty ? '(Răspuns gol.)' : text,
      citari: r.citari,
    );
  }
}
