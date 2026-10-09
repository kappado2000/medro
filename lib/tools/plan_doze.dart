/// Calculul unui plan de reducere sau de crestere treptata a dozei. Este un
/// calcul aritmetic: ritmul si dozele le stabileste medicul.
library;

/// Cum se schimba doza la fiecare pas.
enum TipPas {
  /// Procent din doza curenta (pasii devin tot mai mici la reducere).
  procent,

  /// Aceeasi cantitate in mg la fiecare pas.
  fix,
}

class PasDoza {
  /// Prima zi in care se ia doza.
  final DateTime data;
  final double doza;
  const PasDoza(this.data, this.doza);
}

/// Sub aceasta fractiune din doza de pornire, o reducere procentuala spre zero
/// se incheie cu oprirea (altfel nu ar ajunge niciodata la zero).
const pragOprire = 0.1;

const maxPasi = 60;

/// Data aflata la [zile] zile dupa [d], fara ora.
DateTime adaugaZile(DateTime d, int zile) =>
    DateTime(d.year, d.month, d.day + zile);

double _rotunjeste(double doza, double multiplu) {
  if (multiplu <= 0) return double.parse(doza.toStringAsFixed(3));
  return double.parse(
    ((doza / multiplu).round() * multiplu).toStringAsFixed(3),
  );
}

/// Pasii de la doza [start] la doza [tinta]. Primul pas incepe la [inceput],
/// urmatorii la cate [intervalZile] zile. [pas] este procentul sau cantitatea
/// in mg, dupa [tip]. Cu [rotunjire] > 0 dozele sunt multipli ai acelei valori
/// (cea mai mica fractiune care se poate administra).
///
/// Intoarce o lista goala daca datele nu permit un plan.
List<PasDoza> planDoze({
  required double start,
  required double tinta,
  required TipPas tip,
  required double pas,
  required int intervalZile,
  required DateTime inceput,
  double rotunjire = 0,
}) {
  if (start < 0 || tinta < 0 || pas <= 0 || intervalZile <= 0) return const [];
  if (start == tinta) return const [];
  if (tip == TipPas.procent && pas >= 100) return const [];
  final scade = tinta < start;
  // o crestere procentuala de la zero nu porneste niciodata
  if (!scade && tip == TipPas.procent && start == 0) return const [];

  final pasi = <PasDoza>[];
  var doza = start;
  var data = DateTime(inceput.year, inceput.month, inceput.day);
  while (pasi.length < maxPasi) {
    var noua = switch (tip) {
      TipPas.procent => scade ? doza * (1 - pas / 100) : doza * (1 + pas / 100),
      TipPas.fix => scade ? doza - pas : doza + pas,
    };
    noua = _rotunjeste(noua, rotunjire);
    // rotunjirea nu are voie sa opreasca planul pe loc
    if (scade && noua >= doza) noua = _rotunjeste(doza - rotunjire, rotunjire);
    if (!scade && noua <= doza) noua = _rotunjeste(doza + rotunjire, rotunjire);

    final gata = scade
        ? noua <= tinta || (tinta == 0 && noua < start * pragOprire)
        : noua >= tinta;
    if (gata) {
      // ultima doza dinaintea opririi ramane in plan, daca e diferita
      if (scade && tinta == 0 && noua > 0 && noua < doza) {
        pasi.add(PasDoza(data, noua));
        data = adaugaZile(data, intervalZile);
      }
      pasi.add(PasDoza(data, tinta));
      return pasi;
    }
    pasi.add(PasDoza(data, noua));
    doza = noua;
    data = adaugaZile(data, intervalZile);
  }
  return pasi;
}

const _zile = ['lun.', 'mar.', 'mie.', 'joi', 'vin.', 'sâm.', 'dum.'];

/// "vin. 09.10.2026"
String formatData(DateTime d, {bool cuZi = true}) {
  String doua(int n) => n.toString().padLeft(2, '0');
  final data = '${doua(d.day)}.${doua(d.month)}.${d.year}';
  return cuZi ? '${_zile[d.weekday - 1]} $data' : data;
}

/// "7,5" sau "10", fara zecimale inutile.
String formatDoza(double v) {
  var s = v.toStringAsFixed(3);
  s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return s.replaceAll('.', ',');
}

/// Planul ca text, pentru copiere in fisa pacientului.
String textPlan(List<PasDoza> pasi, double start, String unitate) {
  final b = StringBuffer('Doza actuală: ${formatDoza(start)} $unitate\n');
  for (final p in pasi) {
    b.writeln(
      p.doza == 0
          ? 'din ${formatData(p.data, cuZi: false)}: oprire'
          : 'din ${formatData(p.data, cuZi: false)}: ${formatDoza(p.doza)} $unitate',
    );
  }
  return b.toString().trimRight();
}
