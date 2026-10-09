const _diacritics = {
  'ă': 'a',
  'â': 'a',
  'î': 'i',
  'ș': 's',
  'ş': 's',
  'ț': 't',
  'ţ': 't',
  'é': 'e',
  'è': 'e',
  'ö': 'o',
  'ü': 'u',
  'á': 'a',
  'í': 'i',
  'ó': 'o',
};

/// Litere mici, fara diacritice si fara simboluri de marca, pentru cautare.
String normalizeForSearch(String input) {
  final b = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    if (ch == '®' || ch == '™') continue;
    b.write(_diacritics[ch] ?? ch);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// "ALLOPURINOLUM" -> "Allopurinolum"; pastreaza siglele scurte.
String titleCase(String input) {
  return input
      .toLowerCase()
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

/// Radacina unei denumiri de substanta scrise in romana, ca sa se potriveasca
/// cu forma latina din nomenclator: "clozapina" -> "clozapin" (CLOZAPINUM).
/// Intoarce null pentru cuvinte prea scurte sau care nu se termina in vocala.
String? radacinaSubstanta(String cuvant) {
  if (cuvant.length < 6) return null;
  if (!cuvant.endsWith('a') && !cuvant.endsWith('e')) return null;
  return cuvant.substring(0, cuvant.length - 1);
}
