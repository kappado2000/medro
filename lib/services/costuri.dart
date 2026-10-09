import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Tokenii facturati pentru un raspuns, asa cum ii raporteaza Messages API.
class Consum {
  /// Modelul care a raspuns.
  final String model;

  /// Tokeni de intrare platiti la pret intreg.
  final int intrare;

  /// Tokeni de intrare scrisi in cache (documentul, la prima intrebare).
  final int scriereCache;

  /// Tokeni de intrare cititi din cache (documentul, la intrebarile urmatoare).
  final int citireCache;

  /// Tokeni de iesire: raspunsul si gandirea modelului.
  final int iesire;

  const Consum({
    required this.model,
    this.intrare = 0,
    this.scriereCache = 0,
    this.citireCache = 0,
    this.iesire = 0,
  });

  /// Din campul `usage` al raspunsului; null daca lipseste.
  static Consum? dinRaspuns(Map<String, dynamic> json, String modelCerut) {
    final u = json['usage'];
    if (u is! Map) return null;
    int n(String cheie) => (u[cheie] as num?)?.toInt() ?? 0;
    return Consum(
      model: json['model'] as String? ?? modelCerut,
      intrare: n('input_tokens'),
      scriereCache: n('cache_creation_input_tokens'),
      citireCache: n('cache_read_input_tokens'),
      iesire: n('output_tokens'),
    );
  }

  int get totalIntrare => intrare + scriereCache + citireCache;
}

/// Preturile unui model, in USD pe un milion de tokeni.
class Tarif {
  final String nume;
  final double intrare;
  final double iesire;
  final double citireCache;

  const Tarif(this.nume, this.intrare, this.iesire, this.citireCache);

  /// Scrierea in cache (pastrare 5 minute) costa cu un sfert peste intrare.
  double get scriereCache => intrare * 1.25;
}

/// Tarifele publicate de Anthropic pentru modelele oferite de aplicatie.
/// Se actualizeaza aici daca Anthropic le schimba.
const tarife = {
  'claude-sonnet-5-5': Tarif('Sonnet 5.5', 2, 10, 0.20),
  'claude-opus-5-5': Tarif('Opus 5.5', 4, 20, 0.20),
};

Tarif tarifPentru(String model) {
  for (final e in tarife.entries) {
    if (model.startsWith(e.key)) return e.value;
  }
  return tarife['claude-sonnet-5-5']!;
}

/// Costul estimat al unui raspuns, in USD.
double costUsd(Consum c) {
  final t = tarifPentru(c.model);
  return (c.intrare * t.intrare +
          c.scriereCache * t.scriereCache +
          c.citireCache * t.citireCache +
          c.iesire * t.iesire) /
      1e6;
}

/// O intrebare pusa asistentului, cu ce a costat.
class Interogare {
  final DateTime data;
  final Consum consum;
  final double cost;

  /// Cate documente RCP au fost trimise cu intrebarea.
  final int documente;

  const Interogare(this.data, this.consum, this.cost, this.documente);

  Map<String, dynamic> toJson() => {
    't': data.toIso8601String(),
    'm': consum.model,
    'i': consum.intrare,
    'w': consum.scriereCache,
    'r': consum.citireCache,
    'o': consum.iesire,
    'c': cost,
    'd': documente,
  };

  static Interogare fromJson(Map<String, dynamic> j) => Interogare(
    DateTime.parse(j['t'] as String),
    Consum(
      model: j['m'] as String,
      intrare: j['i'] as int,
      scriereCache: j['w'] as int,
      citireCache: j['r'] as int,
      iesire: j['o'] as int,
    ),
    (j['c'] as num).toDouble(),
    (j['d'] as int?) ?? 0,
  );
}

/// Totalul unei perioade.
class Sumar {
  final int interogari;
  final double cost;
  const Sumar(this.interogari, this.cost);
}

/// Jurnalul intrebarilor puse asistentului de pe acest telefon. Costul se
/// calculeaza la momentul raspunsului, cu tarifele de atunci, si se pastreaza.
class JurnalCosturi {
  static const _cheie = 'jurnal_costuri_asistent';

  /// Peste aceasta limita se sterg cele mai vechi inregistrari.
  static const maxInregistrari = 5000;

  final List<Interogare> _toate = [];

  /// De la cea mai noua la cea mai veche.
  List<Interogare> get toate => _toate.reversed.toList();

  bool get gol => _toate.isEmpty;

  Future<void> incarca() async {
    final prefs = await SharedPreferences.getInstance();
    _toate.clear();
    for (final rand in prefs.getStringList(_cheie) ?? const <String>[]) {
      try {
        _toate.add(
          Interogare.fromJson(jsonDecode(rand) as Map<String, dynamic>),
        );
      } catch (_) {
        // o inregistrare stricata nu blocheaza jurnalul
      }
    }
  }

  Future<void> _salveaza() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_cheie, [
      for (final i in _toate) jsonEncode(i.toJson()),
    ]);
  }

  Future<Interogare> adauga(
    Consum consum, {
    int documente = 0,
    DateTime? acum,
  }) async {
    final i = Interogare(
      acum ?? DateTime.now(),
      consum,
      costUsd(consum),
      documente,
    );
    _toate.add(i);
    if (_toate.length > maxInregistrari) {
      _toate.removeRange(0, _toate.length - maxInregistrari);
    }
    await _salveaza();
    return i;
  }

  Future<void> goleste() async {
    _toate.clear();
    await _salveaza();
  }

  Sumar _sumar(bool Function(Interogare) conditie) {
    var n = 0;
    var cost = 0.0;
    for (final i in _toate) {
      if (!conditie(i)) continue;
      n++;
      cost += i.cost;
    }
    return Sumar(n, cost);
  }

  Sumar get total => _sumar((_) => true);

  Sumar zi(DateTime d) => _sumar(
    (i) =>
        i.data.year == d.year && i.data.month == d.month && i.data.day == d.day,
  );

  Sumar luna(DateTime d) =>
      _sumar((i) => i.data.year == d.year && i.data.month == d.month);

  /// Totalurile pe luni, de la cea mai recenta: (prima zi a lunii, sumar).
  List<(DateTime, Sumar)> get peLuni {
    final luni = <DateTime>{
      for (final i in _toate) DateTime(i.data.year, i.data.month),
    }.toList()..sort((a, b) => b.compareTo(a));
    return [for (final l in luni) (l, luna(l))];
  }
}

/// "0,16 USD"; sumele sub un cent pastreaza trei zecimale.
String formatUsd(double v) {
  final zecimale = v > 0 && v < 0.01 ? 3 : 2;
  return '${v.toStringAsFixed(zecimale).replaceAll('.', ',')} USD';
}

/// "61.240"
String formatTokeni(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

const _luni = [
  'ianuarie',
  'februarie',
  'martie',
  'aprilie',
  'mai',
  'iunie',
  'iulie',
  'august',
  'septembrie',
  'octombrie',
  'noiembrie',
  'decembrie',
];

/// "octombrie 2026"
String numeLuna(DateTime d) => '${_luni[d.month - 1]} ${d.year}';
