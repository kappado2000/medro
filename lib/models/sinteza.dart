/// Sectiunile unei editii, in ordinea in care sunt afisate.
enum SectiuneSinteza {
  /// Sectiunea principala: deschide editia si are cele mai multe articole.
  psihiatrie('psihiatrie', 'Psihiatrie și psihoterapie', 'Psihiatrie'),

  /// Comunicari oficiale de siguranta; poate lipsi dintr-o editie.
  siguranta('siguranta', 'Siguranța medicamentelor', 'Siguranță'),
  medicina('medicina', 'Medicină'),
  stiinta('stiinta', 'Științe'),
  arta('arta', 'Artă'),
  arhitectura('arhitectura', 'Arhitectură'),

  /// Sectiuni adaugate pe server dupa ce aplicatia a fost instalata.
  altele('altele', 'Alte noutăți', 'Altele');

  final String cod;
  final String eticheta;

  /// Numele scurt, pentru filtre.
  final String scurt;
  const SectiuneSinteza(this.cod, this.eticheta, [String? scurt])
    : scurt = scurt ?? eticheta;

  static SectiuneSinteza dinCod(String cod) => values.firstWhere(
    (s) => s.cod == cod,
    orElse: () => SectiuneSinteza.altele,
  );
}

/// O trimitere catre o pagina web: sursa, alta redactie sau lectura in plus.
class Trimitere {
  final String titlu;
  final String url;
  const Trimitere(this.titlu, this.url);

  /// Numele site-ului, fara "www.", afisat sub titlul trimiterii.
  String get site {
    final gazda = Uri.tryParse(url)?.host ?? '';
    return gazda.startsWith('www.') ? gazda.substring(4) : gazda;
  }
}

class ArticolSinteza {
  final String id;
  final SectiuneSinteza sectiune;
  final String titlu;
  final String rezumat;

  /// Paragrafele articolului.
  final List<String> paragrafe;
  final String deCeConteaza;
  final String loc;

  /// Sursa principala si data la care a publicat stirea (poate lipsi).
  final Trimitere sursa;
  final String dataSursa;
  final List<Trimitere> alteSurse;

  /// Pagini pentru cine vrea sa afle mai mult.
  final List<Trimitere> trimiteri;
  final String imagine;
  final String creditImagine;

  const ArticolSinteza({
    required this.id,
    required this.sectiune,
    required this.titlu,
    required this.rezumat,
    required this.paragrafe,
    required this.deCeConteaza,
    required this.loc,
    required this.sursa,
    required this.dataSursa,
    required this.alteSurse,
    required this.trimiteri,
    required this.imagine,
    required this.creditImagine,
  });

  factory ArticolSinteza.dinJson(Map<String, dynamic> j) {
    final sursa = (j['sursa'] as Map).cast<String, dynamic>();
    final imagine = (j['imagine'] as Map?)?.cast<String, dynamic>();
    List<Trimitere> lista(String cheie, String camp) => [
      for (final t in (j[cheie] as List?) ?? const [])
        Trimitere((t as Map)[camp] as String, t['url'] as String),
    ];
    return ArticolSinteza(
      id: j['id'] as String,
      sectiune: SectiuneSinteza.dinCod(j['sectiune'] as String),
      titlu: j['titlu'] as String,
      rezumat: j['rezumat'] as String,
      paragrafe: [
        for (final p in (j['text'] as String).split(RegExp(r'\n\s*\n')))
          if (p.trim().isNotEmpty) p.trim(),
      ],
      deCeConteaza: (j['de_ce_conteaza'] as String?) ?? '',
      loc: (j['loc'] as String?) ?? '',
      sursa: Trimitere(sursa['nume'] as String, sursa['url'] as String),
      dataSursa: (sursa['data'] as String?) ?? '',
      alteSurse: lista('alte_surse', 'nume'),
      trimiteri: lista('trimiteri', 'titlu'),
      imagine: (imagine?['url'] as String?) ?? '',
      creditImagine: (imagine?['credit'] as String?) ?? '',
    );
  }

  /// Timpul de citire, la aproximativ 200 de cuvinte pe minut.
  int get minuteLectura {
    final cuvinte = paragrafe.fold<int>(
      0,
      (n, p) => n + p.split(RegExp(r'\s+')).length,
    );
    return (cuvinte / 200).ceil().clamp(1, 60);
  }
}

class EditieSinteza {
  final String id;

  /// Ziua in care a fost generata (AAAA-LL-ZZ).
  final String data;

  /// Intervalul acoperit, scris pe litere: "3–10 octombrie 2026".
  final String interval;
  final String titlu;
  final String introducere;
  final List<ArticolSinteza> articole;

  const EditieSinteza({
    required this.id,
    required this.data,
    required this.interval,
    required this.titlu,
    required this.introducere,
    required this.articole,
  });

  factory EditieSinteza.dinJson(Map<String, dynamic> j) => EditieSinteza(
    id: j['id'] as String,
    data: j['data'] as String,
    interval: j['interval'] as String,
    titlu: j['titlu'] as String,
    introducere: (j['introducere'] as String?) ?? '',
    articole: [
      for (final a in j['articole'] as List)
        ArticolSinteza.dinJson((a as Map).cast<String, dynamic>()),
    ],
  );

  List<ArticolSinteza> dinSectiunea(SectiuneSinteza s) => [
    for (final a in articole)
      if (a.sectiune == s) a,
  ];
}

/// Un rand din lista editiilor (arhiva).
class RezumatEditie {
  final String id;
  final String data;
  final String interval;
  final String titlu;
  final int articole;

  const RezumatEditie(
    this.id,
    this.data,
    this.interval,
    this.titlu,
    this.articole,
  );

  factory RezumatEditie.dinJson(Map<String, dynamic> j) => RezumatEditie(
    j['id'] as String,
    j['data'] as String,
    j['interval'] as String,
    j['titlu'] as String,
    (j['articole'] as num).toInt(),
  );
}
