/// Extrage din sectiunile unui RCP frazele relevante pentru o tema (functie
/// renala, monitorizare, enzime hepatice, interval QT). Nimic nu este
/// reformulat: se afiseaza frazele din document, cu sectiunea din care provin.
library;

import 'text_utils.dart';

class FrazaRcp {
  /// Numarul sectiunii din RCP ("4.2", "4.4"…).
  final String sectiune;
  final String text;
  const FrazaRcp(this.sectiune, this.text);
}

/// Denumirile sectiunilor, pentru afisare.
const titluriSectiuni = {
  '4.1': 'Indicații terapeutice',
  '4.2': 'Doze și mod de administrare',
  '4.4': 'Atenționări și precauții',
  '4.5': 'Interacțiuni',
  '4.6': 'Fertilitatea, sarcina și alăptarea',
  '4.7': 'Conducerea vehiculelor și folosirea utilajelor',
  '4.8': 'Reacții adverse',
  '4.9': 'Supradozaj',
};

class TemaRcp {
  final String id;
  final String titlu;
  final RegExp tipar;
  final List<String> sectiuni;
  const TemaRcp._(this.id, this.titlu, this.tipar, this.sectiuni);
}

final temeRcp = [
  TemaRcp._(
    'doza_maxima',
    'Doza maximă',
    RegExp(
      r'doz[aăe](i)? (zilnic[aăe] )?maxim|maxim(um)? (de )?\d|nu trebuie (s[aă] )?dep[aă][sș]|'
      r'nu (se|trebuie) (va )?dep[aă][sș]|p[aâ]n[aă] la (o doz[aă] (maxim[aă] )?de )?\d+([.,]\d+)? ?mg',
      caseSensitive: false,
    ),
    const ['4.2'],
  ),
  TemaRcp._(
    'renal',
    'Insuficiență renală',
    RegExp(
      r'insuficien[tţț][aăe] renal|afectare[a]? renal|func[tţț]i(a|ei) renal|clearance|dializ|hemodializ',
      caseSensitive: false,
    ),
    const ['4.2', '4.3', '4.4'],
  ),
  TemaRcp._(
    'hepatic',
    'Insuficiență hepatică',
    RegExp(
      r'insuficien[tţț][aăe] hepatic|afectare[a]? hepatic|func[tţț]i(a|ei) hepatic|ciroz|Child[- ]Pugh',
      caseSensitive: false,
    ),
    const ['4.2', '4.3', '4.4'],
  ),
  TemaRcp._(
    'varstnici',
    'Vârstnici',
    RegExp(
      r'v[aâ]rstnic|peste 65 de ani|pacien[tţț]i(i|lor)? [iî]n v[aâ]rst[aă]',
      caseSensitive: false,
    ),
    const ['4.2', '4.4'],
  ),
  TemaRcp._(
    'monitorizare',
    'Monitorizare',
    RegExp(
      r'monitoriz|trebuie (determinat|controlat|verificat|m[aă]surat|evaluat)|se recomand[aă] '
      r'(determinarea|controlul|m[aă]surarea|evaluarea|efectuarea)|hemoleucogram|hemogram'
      r'|electrocardiogram|\bECG\b|litemi|concentra[tţț]i(a|ile|ilor) plasmatic[ae]? (de|a|ale) ',
      caseSensitive: false,
    ),
    const ['4.2', '4.4'],
  ),
  TemaRcp._(
    'cyp',
    'Enzime hepatice (CYP)',
    RegExp(r'CYP\s?[0-9][A-Z0-9]*|citocrom', caseSensitive: false),
    const ['4.5', '4.4', '4.2'],
  ),
  TemaRcp._(
    'anticolinergic',
    'Efecte anticolinergice',
    RegExp(r'anticolinergic|antimuscarinic', caseSensitive: false),
    const ['4.3', '4.4', '4.5', '4.8'],
  ),
  TemaRcp._(
    'qt',
    'Interval QT',
    RegExp(r'\bQT[c]?\b|torsad', caseSensitive: false),
    const ['4.3', '4.4', '4.5', '4.8'],
  ),
];

/// Imparte un text in fraze, fara a rupe dupa abrevieri uzuale ("pct.", "ex.").
List<String> fraze(String text) {
  final out = <String>[];
  for (final rand in text.split('\n')) {
    var curent = StringBuffer();
    final bucati = rand.split(RegExp(r'(?<=[.;])\s+'));
    for (final b in bucati) {
      if (curent.isNotEmpty) curent.write(' ');
      curent.write(b);
      final t = curent.toString();
      // dupa o abreviere, fraza continua
      if (RegExp(
        r'\b(pct|vezi|ex|nr|aprox|respectiv|de ex)\.$',
        caseSensitive: false,
      ).hasMatch(t)) {
        continue;
      }
      out.add(t.trim());
      curent = StringBuffer();
    }
    if (curent.isNotEmpty) out.add(curent.toString().trim());
  }
  return [
    for (final f in out)
      if (f.length > 3) f,
  ];
}

/// Frazele din sectiunile temei care contin tiparul ei, fara repetitii.
List<FrazaRcp> extrage(
  TemaRcp tema,
  Map<String, String> sectiuni, {
  int maxim = 12,
}) {
  final vazute = <String>{};
  final out = <FrazaRcp>[];
  for (final numar in tema.sectiuni) {
    final text = sectiuni[numar];
    if (text == null) continue;
    for (final f in fraze(text)) {
      if (!tema.tipar.hasMatch(f)) continue;
      if (!vazute.add(f.toLowerCase())) continue;
      out.add(FrazaRcp(numar, f));
      if (out.length >= maxim) return out;
    }
  }
  return out;
}

/// Izoenzimele CYP mentionate in sectiunile RCP-ului (ex. "CYP2D6", "CYP3A4").
List<String> izoenzime(Map<String, String> sectiuni) {
  final gasite = <String>{};
  for (final text in sectiuni.values) {
    for (final m in RegExp(
      r'CYP\s?([0-9][A-Z][0-9]{1,2})',
      caseSensitive: false,
    ).allMatches(text)) {
      gasite.add('CYP${m.group(1)!.toUpperCase()}');
    }
  }
  return gasite.toList()..sort();
}

/// Aduce la aceeasi forma scrierea latina din nomenclator si pe cea romaneasca
/// din RCP: "METHYLPHENIDATUM" si "metilfenidat" devin amandoua "metilfenidat".
String _aceeasiScriere(String text) =>
    normalizeForSearch(text)
        .replaceAll('ph', 'f')
        .replaceAll('th', 't')
        .replaceAll('ch', 'c')
        .replaceAll('y', 'i');

const _cuvinteGenerice = {
  'acidum',
  'saruri',
  'combinatii',
  'hidroclorid',
  'hidrocloridum',
  'natrii',
  'kalii',
  'calcii',
};

/// Radacinile dupa care o substanta poate fi recunoscuta in textul unui RCP,
/// pornind de la denumirile ei (DCI in latina, denumirea englezeasca):
/// "SERTRALINUM" si "Sertraline" dau "sertralin", care se regaseste in
/// "sertralină", "sertralinei".
List<String> radaciniSubstanta(Iterable<String> denumiri) {
  final radacini = <String>{};
  for (final denumire in denumiri) {
    for (final cuvant in _aceeasiScriere(denumire).split(RegExp(r'[^a-z]+'))) {
      if (_cuvinteGenerice.contains(cuvant)) continue;
      // terminatiile latine si englezesti cad; ramane tulpina comuna
      final r = cuvant.replaceFirst(RegExp(r'(ium|um|as|is|e|a)$'), '');
      if (r.length >= 6) radacini.add(r);
    }
  }
  return radacini.toList();
}

/// Sectiunile in care un RCP vorbeste despre asocierea cu alte medicamente.
const sectiuniInteractiuni = ['4.5', '4.3', '4.4'];

/// Frazele din RCP in care apare una dintre [radacini], adica substanta
/// cealalta dintr-o pereche. Nimic nu este reformulat.
List<FrazaRcp> frazeDespre(
  Map<String, String> sectiuni,
  List<String> radacini, {
  int maxim = 8,
}) {
  if (radacini.isEmpty) return const [];
  final tipar = RegExp(
    '(^|[^a-z])(${radacini.map(_aceeasiScriere).map(RegExp.escape).join('|')})',
  );
  final vazute = <String>{};
  final out = <FrazaRcp>[];
  for (final numar in sectiuniInteractiuni) {
    final text = sectiuni[numar];
    if (text == null) continue;
    for (final f in fraze(text)) {
      if (!tipar.hasMatch(_aceeasiScriere(f))) continue;
      if (!vazute.add(f.toLowerCase())) continue;
      out.add(FrazaRcp(numar, f));
      if (out.length >= maxim) return out;
    }
  }
  return out;
}

/// O clasa de medicamente, asa cum o numesc RCP-urile cand descriu o asociere
/// fara sa enumere substantele ("nu se asociaza cu IMAO").
class ClasaInteractiuni {
  /// Prefixele codurilor ATC ale substantelor din clasa.
  final List<String> atc;
  final String nume;

  /// Cum apare clasa in text, fara diacritice.
  final List<String> termeni;
  const ClasaInteractiuni(this.atc, this.nume, this.termeni);
}

/// Clasele dupa care se cauta in RCP, pe langa numele substantei. Lista
/// acopera psihotropele si clasele cu care se asociaza des.
const claseInteractiuni = [
  ClasaInteractiuni(
    ['N06AB'],
    'ISRS',
    [
      'isrs',
      'inhibitori selectivi ai recaptarii serotoninei',
      'inhibitorii selectivi ai recaptarii serotoninei',
      'serotoninergic',
    ],
  ),
  ClasaInteractiuni(
    ['N06AX16', 'N06AX21', 'N06AX23'],
    'IRSN',
    [
      'irsn',
      'inhibitori ai recaptarii serotoninei si noradrenalinei',
      'serotoninergic',
    ],
  ),
  ClasaInteractiuni(
    ['N06AA'],
    'antidepresive triciclice',
    ['antidepresive triciclice', 'antidepresivele triciclice', 'triciclic'],
  ),
  ClasaInteractiuni(
    ['N06AF', 'N06AG', 'N04BD'],
    'IMAO',
    [
      'imao',
      'inhibitori de monoaminooxidaza',
      'inhibitori ai monoaminooxidazei',
      'inhibitorii monoaminooxidazei',
      'inhibitori de mao',
      'inhibitori ai mao',
    ],
  ),
  ClasaInteractiuni(['N05A'], 'antipsihotice', ['antipsihotic', 'neuroleptic']),
  ClasaInteractiuni(
    ['N05BA', 'N05CD', 'N03AE'],
    'benzodiazepine',
    ['benzodiazepin'],
  ),
  ClasaInteractiuni(['N02A', 'N07BC'], 'opioide', ['opioid', 'opiacee']),
  ClasaInteractiuni(
    ['N03A'],
    'antiepileptice',
    ['antiepileptic', 'anticonvulsivant'],
  ),
  ClasaInteractiuni(
    ['N06BA'],
    'psihostimulante',
    ['psihostimulant', 'simpatomimetic', 'stimulante ale snc'],
  ),
  ClasaInteractiuni(['N05AN'], 'litiu', ['litiu', 'saruri de litiu']),
  ClasaInteractiuni(
    ['M01A', 'N02BA'],
    'AINS',
    [
      'ains',
      'antiinflamatoare nesteroidiene',
      'antiinflamatoarele nesteroidiene',
    ],
  ),
  ClasaInteractiuni(
    ['B01A'],
    'anticoagulante și antiagregante',
    ['anticoagulant', 'antiagregant'],
  ),
  ClasaInteractiuni(['C03'], 'diuretice', ['diuretic']),
  ClasaInteractiuni(
    ['C09A', 'C09B'],
    'inhibitori ai ECA',
    [
      'inhibitori ai enzimei de conversie',
      'inhibitorii enzimei de conversie',
      'ieca',
    ],
  ),
];

/// Clasa din care face parte o substanta, dupa codul ei ATC. Se alege
/// prefixul cel mai lung care se potriveste.
ClasaInteractiuni? clasaInteractiuni(String atc) {
  ClasaInteractiuni? gasita;
  var lungime = 0;
  for (final c in claseInteractiuni) {
    for (final p in c.atc) {
      if (atc.startsWith(p) && p.length > lungime) {
        gasita = c;
        lungime = p.length;
      }
    }
  }
  return gasita;
}

/// Ce spune RCP-ul unui produs despre o alta substanta.
class TextRcp {
  final String produs;

  /// Frazele in care substanta apare pe nume.
  final List<FrazaRcp> peNume;

  /// Clasa substantei si frazele in care apare doar clasa.
  final String? clasa;
  final List<FrazaRcp> peClasa;

  const TextRcp(this.produs, this.peNume, this.clasa, this.peClasa);
}

/// Cauta in [sectiuni] substanta dupa [radacini] si, separat, clasa ei.
TextRcp textDespre(
  String produs,
  Map<String, String> sectiuni,
  List<String> radacini,
  ClasaInteractiuni? clasa,
) {
  final peNume = frazeDespre(sectiuni, radacini);
  final dejaAfisate = {for (final f in peNume) f.text};
  final peClasa = clasa == null
      ? const <FrazaRcp>[]
      : [
          for (final f in frazeDespre(sectiuni, clasa.termeni, maxim: 12))
            if (!dejaAfisate.contains(f.text)) f,
        ].take(6).toList();
  return TextRcp(produs, peNume, clasa?.nume, peClasa);
}
