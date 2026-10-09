import '../utils/text_utils.dart';

class Ambalaj {
  final String cim;
  final String descriere;
  final String volum;
  final String valabilitate;

  const Ambalaj(this.cim, this.descriere, this.volum, this.valabilitate);
}

/// Incadrarea unui ambalaj intr-o sublista CNAS de compensare.
class Compensare {
  final String lista;

  /// Pret maximal pe ambalaj (lei).
  final double pret;

  /// Contributia maxima a asiguratului pe ambalaj (lei).
  final double contributie;

  /// Contributia pentru pensionarii cu venituri mici; exista doar la sublista B.
  final double? contributiePensionari;

  /// Ambalajul asa cum apare in lista CNAS; completat doar cand potrivirea
  /// s-a facut dupa denumire, nu dupa codul ambalajului.
  final String? ambalajCnas;

  const Compensare(
    this.lista,
    this.pret,
    this.contributie,
    this.contributiePensionari, [
    this.ambalajCnas,
  ]);

  factory Compensare.fromJson(List<dynamic> j) {
    return Compensare(
      j[0] as String,
      (j[1] as num).toDouble(),
      (j[2] as num).toDouble(),
      (j[3] as num?)?.toDouble(),
      j.length > 4 ? j[4] as String : null,
    );
  }
}

/// Cheia de potrivire dupa denumire si substanta; aceeasi regula ca in
/// tool/build_compensare.py.
String cheieCompensareNume(String denumire, String dci) {
  final fara = denumire
      .toUpperCase()
      .replaceAll(RegExp(r'\([^)]*\)'), '')
      .replaceAll('®', '')
      .replaceAll(RegExp(r'[^A-Z0-9,./%]'), '');
  return '$fara|${dci.toUpperCase().trim()}';
}

/// Procentul de compensare al fiecarei subliste, conform legendei CNAS.
String procentCompensare(String lista) {
  switch (lista) {
    case 'A':
      return '90%';
    case 'B':
      return '50%';
    case 'D':
      return '20%';
    case 'C2':
      return '100% · programe naționale';
  }
  return '100%';
}

class Medicament {
  final String denumire;
  final String dci;
  final String forma;
  final String concentratie;
  final String detinator;
  final String producator;
  final String atc;
  final String actiune;
  final String prescriptie;
  final bool centralizat;
  final String rcpUrl;
  final String prospectUrl;
  final List<Ambalaj> ambalaje;

  final String denumireNorm;
  final String dciNorm;

  Medicament({
    required this.denumire,
    required this.dci,
    required this.forma,
    required this.concentratie,
    required this.detinator,
    required this.producator,
    required this.atc,
    required this.actiune,
    required this.prescriptie,
    required this.centralizat,
    required this.rcpUrl,
    required this.prospectUrl,
    required this.ambalaje,
  }) : denumireNorm = normalizeForSearch(denumire),
       dciNorm = normalizeForSearch(dci);

  /// Identificator stabil al produsului (pentru favorite). Primul cod CIM
  /// singur nu ajunge: in nomenclator cateva coduri apar la doua produse.
  String get id => '${ambalaje.first.cim}|$denumire';

  bool get faraReteta => prescriptie == 'OTC';

  /// Sublistele CNAS in care apare cel putin un ambalaj al produsului;
  /// completat de MedicamenteProvider dupa incarcarea listei de compensare.
  List<String> liste = const [];

  factory Medicament.fromJson(Map<String, dynamic> j) {
    return Medicament(
      denumire: j['n'] as String,
      dci: j['d'] as String,
      forma: j['f'] as String,
      concentratie: j['c'] as String,
      detinator: j['h'] as String,
      producator: j['m'] as String,
      atc: j['a'] as String,
      actiune: j['t'] as String,
      prescriptie: (j['p'] as String).replaceAll('-', ''),
      centralizat: j['e'] == 1,
      rcpUrl: j['r'] as String,
      prospectUrl: j['l'] as String,
      ambalaje: [
        for (final k in j['k'] as List)
          Ambalaj(
            k[0] as String,
            k[1] as String,
            k[2] as String,
            k[3] as String,
          ),
      ],
    );
  }
}

const _explicatiiPrescriptie = {
  'OTC': 'Se eliberează fără prescripție medicală',
  'P6L': 'Prescripție care nu se reține în farmacie; valabilă 6 luni, se poate reînnoi',
  'PRF': 'Prescripție care se reține în farmacie; nu se reînnoiește',
  'PR': 'Prescripție restrictivă, pentru utilizare în domenii specializate',
  // in nomenclator, "S" este notatia alternativa pentru prescriptia restrictiva
  'S': 'Prescripție restrictivă, pentru utilizare în domenii specializate',
  'PS': 'Prescripție specială (stupefiante și psihotrope)',
};

/// Explicatia codului de prescriptie din nomenclator, dupa legenda CNAS.
/// Codurile compuse ("S/PRF", "PS,PR") se explica parte cu parte; null daca
/// nicio parte nu e cunoscuta.
String? explicatiePrescriptie(String cod) {
  final parti = cod.split(RegExp(r'[/,]')).map((p) => p.trim()).toList();
  final explicatii = <String>{
    for (final p in parti)
      if (_explicatiiPrescriptie[p] != null) _explicatiiPrescriptie[p]!,
  };
  if (explicatii.isEmpty) return null;
  return explicatii.join('; sau: ');
}
