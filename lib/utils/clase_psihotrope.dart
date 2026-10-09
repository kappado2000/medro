/// Clase de psihotrope pentru filtrarea rapida a registrului, dupa prefixul
/// codului ATC.
class ClasaAtc {
  final String nume;
  final String prefix;
  const ClasaAtc(this.nume, this.prefix);
}

const clasePsihotrope = [
  ClasaAtc('Antipsihotice', 'N05A'),
  ClasaAtc('Anxiolitice', 'N05B'),
  ClasaAtc('Hipnotice și sedative', 'N05C'),
  ClasaAtc('Antidepresive', 'N06A'),
  ClasaAtc('Psihostimulante și ADHD', 'N06B'),
  ClasaAtc('Antidemențiale', 'N06D'),
  ClasaAtc('Antiepileptice și stabilizatori', 'N03A'),
  ClasaAtc('Medicamente pentru adicții', 'N07B'),
];
