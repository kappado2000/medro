import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../help/ajutor.dart';
import '../help/glosar.dart';
import '../models/medicament.dart';
import '../services/claude_client.dart';
import '../services/costuri.dart';
import '../services/data_store.dart';
import '../utils/rcp_extrase.dart';
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

La fiecare conversație poți primi două feluri de material: documente atașate (rezumatul caracteristicilor produsului, RCP, pentru medicamentele alese de medic) și un bloc <date_aplicatie> cu informații din nomenclatorul ANMDM, lista de compensare CNAS și baza de interacțiuni DDInter. Blocul este context complet, generat automat pentru medicamentele atașate, nu o parte a întrebării: folosește din el doar ce ajută la întrebarea pusă și nu îl comenta dacă nu are legătură cu ea. Întrebarea medicului este textul care urmează după bloc. Un document cu titlul „RCP … (extras)” conține doar secțiunile 4.1–4.9, unele prescurtate: dacă răspunsul nu se găsește în extras, spune că trebuie verificat RCP-ul complet, nu presupune.

Materialul primit este sursa ta principală. Pentru doze, contraindicații, interacțiuni, ajustări la insuficiență renală sau hepatică și reacții adverse, sprijină-te pe RCP-ul atașat și citează pasajul relevant. Dacă informația cerută nu se află în material, spune asta explicit și precizează că ce urmează vine din cunoștințele tale generale, fiindcă medicul trebuie să poată deosebi ce e verificabil în RCP de ce nu este. Nu completa din memorie cifre de dozaj care lipsesc din material.

Baza DDInter oferă doar nivelul de severitate al unei interacțiuni, fără mecanism. Când explici o interacțiune, caută mecanismul și conduita în RCP; lipsa unei perechi din DDInter nu înseamnă că interacțiunea nu există.

Decizia clinică aparține medicului. Nu adăuga avertismente generice la fiecare răspuns; semnalează doar riscurile concrete, relevante pentru întrebare.

Răspunsul este afișat într-o aplicație de telefon care arată textul exact cum îl scrii, fără să interpreteze Markdown. Scrie deci text simplu: fără asteriscuri pentru îngroșare, fără titluri cu diez și fără tabele. Pentru enumerări folosește rânduri scurte care încep cu o liniuță.''';

/// Instructiunile trimise modelului: cele medicale, urmate de ghidul
/// aplicatiei, ca asistentul sa poata explica si cum se foloseste MedRO.
final String instructiuniComplete =
    '''$instructiuniAsistent

Medicul te poate întreba și cum se folosește aplicația MedRO, în care rulezi: unde se găsește o funcție, ce înseamnă un element de pe ecran, de unde vin datele, cât costă o întrebare. La astfel de întrebări răspunde scurt și concret, numai pe baza ghidului dintre etichetele <ghid_aplicatie>, care este textul paginilor de ajutor din aplicație. Numește secțiunea din bara de jos și butonul sau rândul care trebuie atins. Dacă ghidul nu acoperă ce ești întrebat, spune că nu știi și trimite la semnul întrebării din secțiunea respectivă; nu inventa funcții, butoane sau meniuri. Ghidul descrie aplicația, nu este o sursă medicală.

Când ești întrebat ce înseamnă o prescurtare, un cod sau un termen care apare în aplicație, folosește glosarul dintre etichetele <glosar>. Explică pe larg, nu doar desfăcând prescurtarea: ce este, cine îl emite sau îl stabilește, ce conține, la ce folosește în practica medicului și cum se folosește în aplicație (în ce secțiune apare și ce se atinge), cu un exemplu dacă ajută. Tratează doar aspectele care au sens pentru termenul întrebat. Un cod compus se explică parte cu parte. Dacă termenul nu este nici în glosar, nici în ghid, dar este un termen medical sau farmaceutic uzual, explică-l din cunoștințele tale și spune că explicația nu vine din aplicație.

<ghid_aplicatie>
${textGhidAplicatie()}
</ghid_aplicatie>

<glosar>
${glosarAplicatie.trim()}
</glosar>''';

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

  /// Jurnalul intrebarilor si al costului lor, pastrat pe telefon.
  final JurnalCosturi costuri = JurnalCosturi();

  Future<void> golesteCosturi() async {
    await costuri.goleste();
    notifyListeners();
  }

  /// Asistentul merge fie prin serverul propriu, fie cu o cheie introdusa aici.
  bool get disponibil => _client.areServer || areCheie;
  bool get conversatieInceputa => _istoric.isNotEmpty;

  Future<void> incarca() async {
    final prefs = await SharedPreferences.getInstance();
    cheie = prefs.getString(_cheieKey) ?? '';
    final salvat = prefs.getString(_modelKey);
    if (ClaudeClient.modele.containsKey(salvat)) model = salvat!;
    await costuri.incarca();
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

  /// Sectiunile extrase dintr-un RCP, ca text pentru model. Contraindicatiile
  /// (4.3) sunt pastrate separat in aplicatie si se adauga aici la locul lor.
  @visibleForTesting
  static String textExtras(
    Map<String, String> sectiuni,
    String? contraindicatii,
  ) {
    final toate = {...sectiuni, '4.3': ?contraindicatii};
    final b = StringBuffer(
      'Extras din rezumatul caracteristicilor produsului, secțiunile 4.1–4.9. '
      'Secțiunile lungi sunt prescurtate.\n',
    );
    for (final numar in toate.keys.toList()..sort()) {
      final titlu = numar == '4.3'
          ? 'Contraindicații'
          : (titluriSectiuni[numar] ?? '');
      b.writeln('\n$numar $titlu\n${toate[numar]}');
    }
    return b.toString().trim();
  }

  /// RCP-urile EMA sunt documente de sute de pagini (toate concentratiile si
  /// prospectul), de zeci de ori mai scumpe decat sectiunile lor clinice. Unde
  /// aplicatia are sectiunile extrase, se trimit acelea in locul PDF-ului.
  Future<Map<String, Map<String, String>>> _extraseEma() async {
    final rezultat = <String, Map<String, String>>{};
    for (final m in atasate) {
      if (!m.centralizat || m.rcpUrl.isEmpty) continue;
      final sectiuni = await RcpStore.instance.sectiuni(m.rcpUrl);
      if (sectiuni.isNotEmpty) rezultat[m.rcpUrl] = sectiuni;
    }
    return rezultat;
  }

  /// Continutul primului mesaj: RCP-urile ca documente, datele din aplicatie,
  /// apoi intrebarea. Mesajele urmatoare contin doar intrebarea.
  @visibleForTesting
  List<Map<String, dynamic>> continutMesaj(
    String intrebare,
    MedicamenteProvider med,
    InteractiuniProvider inter, {
    required bool cuDocumente,
    Map<String, Map<String, String>> extrase = const {},
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
            if (extrase[m.rcpUrl] case final sectiuni? when sectiuni.isNotEmpty)
              {
                'type': 'document',
                'source': {
                  'type': 'text',
                  'media_type': 'text/plain',
                  'data': textExtras(sectiuni, med.contraindicatii(m)),
                },
                'title': 'RCP ${m.denumire} (extras)',
                'citations': {'enabled': true},
              }
            // PDF-ul intreg de la EMA nu se trimite niciodata: costa de zece
            // ori mai mult decat un RCP obisnuit
            else if (!m.centralizat)
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
      final extrase = cuDocumente && !conversatieInceputa
          ? await _extraseEma()
          : const <String, Map<String, String>>{};
      var continut = continutMesaj(
        text,
        med,
        inter,
        cuDocumente: cuDocumente,
        extrase: extrase,
      );
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
      // doar raspunsurile primite se factureaza, deci doar ele intra in jurnal
      final consum = raspuns.consum;
      if (consum != null) {
        await costuri.adauga(
          consum,
          documente: continut.where((b) => b['type'] == 'document').length,
        );
      }
      final faraRcp = [
        for (final m in atasate)
          if (cuDocumente &&
              !conversatieInceputa &&
              m.centralizat &&
              m.rcpUrl.isNotEmpty &&
              !extrase.containsKey(m.rcpUrl))
            m.denumire,
      ];
      if (faraRcp.isNotEmpty) {
        mesaje.add(
          MesajAsistent(
            utilizator: false,
            avertizare: true,
            text:
                'RCP-ul pentru ${faraRcp.join(', ')} nu a fost trimis: documentul EMA '
                'întreg ar fi costat în jur de 0,50 USD, iar aplicația nu are extrasul '
                'lui. Răspunsul se bazează pe datele din aplicație; deschide RCP-ul din '
                'pagina medicamentului.',
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
      system: instructiuniComplete,
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
