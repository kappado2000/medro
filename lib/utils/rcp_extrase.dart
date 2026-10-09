/// Extrage din sectiunile unui RCP frazele relevante pentru o tema (functie
/// renala, monitorizare, enzime hepatice, interval QT). Nimic nu este
/// reformulat: se afiseaza frazele din document, cu sectiunea din care provin.
library;

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
