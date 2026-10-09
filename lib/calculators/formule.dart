import 'dart:math' as math;

/// Formule clinice pure, fara interfata, ca sa poata fi testate direct.

/// Indice de masa corporala (kg/m²).
double imc(double kg, double cm) => kg / math.pow(cm / 100, 2);

/// Suprafata corporala, formula Mosteller (m²).
double suprafataCorporala(double kg, double cm) => math.sqrt(kg * cm / 3600);

/// eGFR CKD-EPI 2021 pe baza creatininei, fara coeficient de rasa
/// (ml/min/1,73 m²). Creatinina in mg/dl.
double egfrCkdEpi2021({
  required double creatinina,
  required double varsta,
  required bool femeie,
}) {
  final k = femeie ? 0.7 : 0.9;
  final alfa = femeie ? -0.241 : -0.302;
  final r = creatinina / k;
  return 142 *
      math.pow(math.min(r, 1), alfa) *
      math.pow(math.max(r, 1), -1.200) *
      math.pow(0.9938, varsta) *
      (femeie ? 1.012 : 1);
}

/// Clearance de creatinina Cockcroft-Gault (ml/min). Creatinina in mg/dl.
double cockcroftGault({
  required double creatinina,
  required double varsta,
  required double kg,
  required bool femeie,
}) {
  return (140 - varsta) * kg / (72 * creatinina) * (femeie ? 0.85 : 1);
}

/// Calciu corectat dupa albumina (mg/dl); albumina in g/dl.
double calciuCorectat(double calciu, double albumina) =>
    calciu + 0.8 * (4 - albumina);

/// QT corectat Bazett (ms); QT in ms, frecventa in batai/min.
double qtcBazett(double qt, double frecventa) => qt / math.sqrt(60 / frecventa);

/// Greutate ideala Devine (kg).
double greutateIdeala(double cm, {required bool femeie}) {
  final inchi = cm / 2.54;
  return (femeie ? 45.5 : 50) + 2.3 * (inchi - 60);
}

/// Tensiune arteriala medie (mmHg).
double tensiuneMedie(double sistolica, double diastolica) =>
    (sistolica + 2 * diastolica) / 3;

/// Conversie creatinina din µmol/l in mg/dl.
double creatininaMgDl(double umol) => umol / 88.4;
