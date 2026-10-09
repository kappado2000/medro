/// Calendarul administrarilor pentru antipsihoticele injectabile cu eliberare
/// prelungita. Intervalele sunt cele uzuale din RCP si pot fi modificate in
/// ecran; fereastra de administrare apare doar unde RCP-ul o precizeaza.
library;

import 'plan_doze.dart';

class Depot {
  final String nume;
  final String produse;

  /// Intervalul dintre administrari: in luni calendaristice sau in zile.
  final int interval;
  final bool inLuni;

  /// Cu cate zile mai devreme sau mai tarziu se poate face injectia, dupa RCP.
  final int? zileInainte;
  final int? zileDupa;

  final String nota;

  const Depot({
    required this.nume,
    required this.produse,
    required this.interval,
    this.inLuni = false,
    this.zileInainte,
    this.zileDupa,
    this.nota = '',
  });
}

const depoturi = [
  Depot(
    nume: 'Paliperidonă, lunar',
    produse: 'Xeplion și generice',
    interval: 1,
    inLuni: true,
    zileInainte: 7,
    zileDupa: 7,
    nota:
        'Inițiere: două injecții în deltoid, în ziua 1 și în ziua 8 (± 4 zile); '
        'întreținerea începe la o lună după a doua.',
  ),
  Depot(
    nume: 'Paliperidonă, la 3 luni',
    produse: 'Trevicta',
    interval: 3,
    inLuni: true,
    zileInainte: 14,
    zileDupa: 14,
    nota: 'Doar după stabilizare pe paliperidonă lunară, de preferat cel puțin 4 luni.',
  ),
  Depot(
    nume: 'Paliperidonă, la 6 luni',
    produse: 'Byannli',
    interval: 6,
    inLuni: true,
    zileInainte: 14,
    zileDupa: 21,
    nota: 'Doar după stabilizare pe paliperidonă lunară sau trimestrială.',
  ),
  Depot(
    nume: 'Aripiprazol, lunar',
    produse: 'Abilify Maintena 400 mg',
    interval: 1,
    inLuni: true,
    nota:
        'Nu mai devreme de 26 de zile de la injecția precedentă. La inițiere se '
        'continuă aripiprazolul oral, după schema din RCP.',
  ),
  Depot(
    nume: 'Aripiprazol, la 2 luni',
    produse: 'Abilify Maintena 960 mg',
    interval: 2,
    inLuni: true,
    nota: 'Verifică în RCP fereastra de administrare și schema de inițiere.',
  ),
  Depot(
    nume: 'Risperidonă, la 2 săptămâni',
    produse: 'Rispolept Consta',
    interval: 14,
    nota:
        'Eliberarea începe după aproximativ 3 săptămâni: la inițiere este '
        'necesară acoperire antipsihotică orală.',
  ),
  Depot(nume: 'Risperidonă, la 28 de zile', produse: 'Okedi', interval: 28),
  Depot(
    nume: 'Olanzapină pamoat',
    produse: 'Zypadhera',
    interval: 14,
    nota:
        'La 2 sau la 4 săptămâni, după doză: modifică intervalul dacă e cazul. '
        'După fiecare injecție pacientul rămâne sub observație cel puțin 3 ore '
        '(sindrom post-injectare).',
  ),
  Depot(
    nume: 'Haloperidol decanoat',
    produse: 'absent din nomenclatorul actual',
    interval: 28,
    nota: 'De regulă la 4 săptămâni.',
  ),
  Depot(
    nume: 'Flupentixol decanoat',
    produse: 'Fluanxol Depot',
    interval: 14,
    nota: 'La 2–4 săptămâni: modifică intervalul după schema pacientului.',
  ),
  Depot(
    nume: 'Zuclopentixol decanoat',
    produse: 'Clopixol Depot',
    interval: 14,
    nota: 'La 2–4 săptămâni: modifică intervalul după schema pacientului.',
  ),
];

class Administrare {
  final DateTime data;

  /// Limitele ferestrei de administrare, daca RCP-ul le precizeaza.
  final DateTime? deLa;
  final DateTime? panaLa;
  const Administrare(this.data, [this.deLa, this.panaLa]);
}

/// Data aflata la [luni] luni dupa [d]; daca luna nu are ziua respectiva
/// (31 ianuarie + 1 luna), se ia ultima zi a lunii.
DateTime adaugaLuni(DateTime d, int luni) {
  final prima = DateTime(d.year, d.month + luni, 1);
  final ultimaZi = DateTime(prima.year, prima.month + 1, 0).day;
  return DateTime(prima.year, prima.month, d.day > ultimaZi ? ultimaZi : d.day);
}

/// Urmatoarele [cate] administrari dupa cea din [ultima]. Datele se calculeaza
/// toate de la [ultima], ca o zi de sfarsit de luna sa nu alunece.
List<Administrare> programDepot({
  required DateTime ultima,
  required int interval,
  required bool inLuni,
  int? zileInainte,
  int? zileDupa,
  int cate = 6,
}) {
  if (interval <= 0) return const [];
  final baza = DateTime(ultima.year, ultima.month, ultima.day);
  return [
    for (var i = 1; i <= cate; i++)
      () {
        final data = inLuni
            ? adaugaLuni(baza, interval * i)
            : adaugaZile(baza, interval * i);
        return Administrare(
          data,
          zileInainte == null ? null : adaugaZile(data, -zileInainte),
          zileDupa == null ? null : adaugaZile(data, zileDupa),
        );
      }(),
  ];
}

/// Programul ca text, pentru copiere.
String textProgram(String nume, DateTime ultima, List<Administrare> program) {
  final b = StringBuffer(
    '$nume\nUltima administrare: ${formatData(ultima, cuZi: false)}\n',
  );
  for (final a in program) {
    b.write(formatData(a.data));
    if (a.deLa != null && a.panaLa != null) {
      b.write(
        ' (între ${formatData(a.deLa!, cuZi: false)} și '
        '${formatData(a.panaLa!, cuZi: false)})',
      );
    }
    b.writeln();
  }
  return b.toString().trimRight();
}
