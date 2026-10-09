import 'package:flutter/material.dart';

import 'calculator.dart';

const _categorie = 'Psihiatrie';

// PHQ-9 si GAD-7: textul oficial "Romanian for Romania". Autorii precizeaza ca
// nu este necesara permisiunea pentru reproducere, traducere sau distribuire.
const _frecventa2Saptamani = [
  'Deloc',
  'Câteva zile',
  'Peste jumătate din zile',
  'Aproape zilnic',
];
const _p0123 = [0, 1, 2, 3];

const _phq9 = <Camp>[
  CampAlegere(
    'q1',
    '1. Interesul sau plăcerea limitate de a face diverse lucruri',
    _frecventa2Saptamani,
    puncte: _p0123,
  ),
  CampAlegere(
    'q2',
    '2. Sentimentul de tristețe, deprimare sau deznădăjduire',
    _frecventa2Saptamani,
    puncte: _p0123,
  ),
  CampAlegere(
    'q3',
    '3. Dificultăți de adormire sau de continuitate a somnului ori somnul prea îndelungat',
    _frecventa2Saptamani,
    puncte: _p0123,
  ),
  CampAlegere(
    'q4',
    '4. Senzația de oboseală sau lipsă de energie',
    _frecventa2Saptamani,
    puncte: _p0123,
  ),
  CampAlegere(
    'q5',
    '5. Apetit redus sau alimentare excesivă',
    _frecventa2Saptamani,
    puncte: _p0123,
  ),
  CampAlegere(
    'q6',
    '6. Sentimente negative la adresa dvs. — sau că sunteți un (o) ratat(ă) sau că '
        'v-ați dezamăgit, pe dvs. sau familia dvs.',
    _frecventa2Saptamani,
    puncte: _p0123,
  ),
  CampAlegere(
    'q7',
    '7. Dificultăți de concentrare asupra unor lucruri precum cititul ziarului sau '
        'uitatul la televizor',
    _frecventa2Saptamani,
    puncte: _p0123,
  ),
  CampAlegere(
    'q8',
    '8. Mișcarea sau vorbitul atât de lente încât alte persoane ar fi putut remarca? '
        'Sau contrariul — o stare de neliniște sau agitație excesivă, care v-a făcut să '
        'vă mișcați mult mai mult decât de obicei',
    _frecventa2Saptamani,
    puncte: _p0123,
  ),
  CampAlegere(
    'q9',
    '9. Gânduri că v-ar fi mai bine mort sau gândul de a vă face vreun rău',
    _frecventa2Saptamani,
    puncte: _p0123,
  ),
];

const _gad7 = <Camp>[
  CampAlegere(
    'q1',
    '1. Sentimentul de nervozitate, anxietate sau tensiune',
    _frecventa2Saptamani,
    puncte: _p0123,
  ),
  CampAlegere(
    'q2',
    '2. Incapacitatea de a vă opri sau controla îngrijorarea',
    _frecventa2Saptamani,
    puncte: _p0123,
  ),
  CampAlegere(
    'q3',
    '3. Îngrijorarea excesivă pentru diverse lucruri',
    _frecventa2Saptamani,
    puncte: _p0123,
  ),
  CampAlegere(
    'q4',
    '4. Dificultăți de relaxare',
    _frecventa2Saptamani,
    puncte: _p0123,
  ),
  CampAlegere(
    'q5',
    '5. O neliniște excesivă, din cauza căreia v-a fost dificil să stați liniștit',
    _frecventa2Saptamani,
    puncte: _p0123,
  ),
  CampAlegere(
    'q6',
    '6. Apariția ușoară a enervării sau iritabilității',
    _frecventa2Saptamani,
    puncte: _p0123,
  ),
  CampAlegere(
    'q7',
    '7. Un sentiment de teamă ca și cum s-ar putea întâmpla ceva groaznic',
    _frecventa2Saptamani,
    puncte: _p0123,
  ),
];

const _frecventaAudit = [
  'Niciodată',
  'Mai rar decât lunar',
  'Lunar',
  'Săptămânal',
  'Zilnic sau aproape zilnic',
];
const _p01234 = [0, 1, 2, 3, 4];
const _daNuAudit = ['Nu', 'Da, dar nu în ultimul an', 'Da, în ultimul an'];
const _p024 = [0, 2, 4];

const _audit = <Camp>[
  CampAlegere('q1', '1. Cât de des consumați băuturi alcoolice?', [
    'Niciodată',
    'Lunar sau mai rar',
    'De 2–4 ori pe lună',
    'De 2–3 ori pe săptămână',
    'De 4 ori pe săptămână sau mai des',
  ], puncte: _p01234),
  CampAlegere(
    'q2',
    '2. Câte băuturi standard (care conțin alcool) consumați într-o zi obișnuită în care beți?',
    ['1–2', '3–4', '5–6', '7–9', '10 sau mai multe'],
    puncte: _p01234,
    detaliu:
        'O băutură standard = aproximativ 10 g de alcool pur (definiția OMS): cam '
        '250–330 ml de bere (4–5%), 100–125 ml de vin (12%) sau 30–40 ml de tărie (40%).',
  ),
  CampAlegere(
    'q3',
    '3. Cât de des consumați șase sau mai multe băuturi standard la o singură ocazie?',
    _frecventaAudit,
    puncte: _p01234,
  ),
  CampAlegere(
    'q4',
    '4. În ultimul an, cât de des ați constatat că nu vă mai puteați opri din băut odată '
        'ce ați început?',
    _frecventaAudit,
    puncte: _p01234,
  ),
  CampAlegere(
    'q5',
    '5. În ultimul an, cât de des nu ați reușit, din cauza băuturii, să faceți ceea ce se '
        'aștepta în mod normal de la dvs.?',
    _frecventaAudit,
    puncte: _p01234,
  ),
  CampAlegere(
    'q6',
    '6. În ultimul an, cât de des ați avut nevoie de un prim pahar dimineața ca să vă '
        'puteți pune pe picioare („să vă dregeți”) după ce ați băut mult?',
    _frecventaAudit,
    puncte: _p01234,
  ),
  CampAlegere(
    'q7',
    '7. În ultimul an, cât de des ați avut sentimente de vinovăție sau remușcări după ce ați băut?',
    _frecventaAudit,
    puncte: _p01234,
  ),
  CampAlegere(
    'q8',
    '8. În ultimul an, cât de des nu v-ați putut aminti ce s-a întâmplat cu o seară '
        'înainte, pentru că băuserăți?',
    _frecventaAudit,
    puncte: _p01234,
  ),
  CampAlegere(
    'q9',
    '9. Ați fost rănit(ă) dvs. sau a fost rănită o altă persoană ca urmare a consumului '
        'dvs. de alcool?',
    _daNuAudit,
    puncte: _p024,
  ),
  CampAlegere(
    'q10',
    '10. O rudă, un prieten, un medic sau alt cadru medical s-a arătat îngrijorat de consumul '
        'dvs. de alcool sau v-a sugerat să îl reduceți?',
    _daNuAudit,
    puncte: _p024,
  ),
];

// Ancorele sunt cele ale scalei originale: la itemii 1–5 sunt definite notele
// 0, 1, 4 si 7, iar la itemii 6–10 fiecare nivel.
const _ciwaHalucinatii =
    '4–6 = halucinații (moderat severe / severe / extrem de severe) · 7 = halucinații continue';

const _ciwa = <Camp>[
  CampScala(
    'greata',
    'Greață și vărsături',
    7,
    detaliu:
        '0 = fără greață, fără vărsături · 1 = greață ușoară, fără vărsături · '
        '4 = greață intermitentă, cu eforturi de vărsătură · 7 = greață constantă, '
        'eforturi de vărsătură frecvente și vărsături',
  ),
  CampScala(
    'tremor',
    'Tremor',
    7,
    detaliu:
        'Cu brațele întinse și degetele răsfirate. 0 = absent · 1 = nu se vede, dar se '
        'simte vârf de deget la vârf de deget · 4 = moderat, cu brațele întinse · '
        '7 = sever, chiar și fără brațele întinse',
  ),
  CampScala(
    'transpiratii',
    'Transpirații paroxistice',
    7,
    detaliu:
        '0 = fără transpirație vizibilă · 1 = abia perceptibilă, palme umede · '
        '4 = broboane de sudoare evidente pe frunte · 7 = transpirații profuze',
  ),
  CampScala(
    'anxietate',
    'Anxietate',
    7,
    detaliu:
        '0 = fără anxietate, relaxat · 1 = ușor anxios · 4 = moderat anxios sau reținut '
        '(anxietatea se deduce) · 7 = echivalentă cu stările acute de panică din '
        'delirium sever sau din reacțiile schizofrenice acute',
  ),
  CampScala(
    'agitatie',
    'Agitație',
    7,
    detaliu:
        '0 = activitate normală · 1 = activitate ceva mai intensă decât normal · '
        '4 = moderat neastâmpărat și neliniștit · 7 = se plimbă de colo-colo în cea mai '
        'mare parte a interviului sau se zbate continuu',
  ),
  CampScala(
    'tactil',
    'Tulburări tactile',
    7,
    detaliu:
        '0 = absente · 1–3 = prurit, înțepături, arsuri sau amorțeli (foarte ușoare / '
        'ușoare / moderate) · $_ciwaHalucinatii',
  ),
  CampScala(
    'auditiv',
    'Tulburări auditive',
    7,
    detaliu:
        '0 = absente · 1–3 = sunete percepute ca stridente sau înspăimântătoare (foarte '
        'ușor / ușor / moderat) · $_ciwaHalucinatii',
  ),
  CampScala(
    'vizual',
    'Tulburări vizuale',
    7,
    detaliu:
        '0 = absente · 1–3 = sensibilitate la lumină (foarte ușoară / ușoară / moderată) · '
        '$_ciwaHalucinatii',
  ),
  CampScala(
    'cefalee',
    'Cefalee, senzație de presiune în cap',
    7,
    detaliu:
        '0 = absentă · 1 = foarte ușoară · 2 = ușoară · 3 = moderată · 4 = moderat severă · '
        '5 = severă · 6 = foarte severă · 7 = extrem de severă. Nu se cotează amețeala.',
  ),
  CampScala(
    'orientare',
    'Orientare și obnubilarea conștienței',
    4,
    detaliu:
        '0 = orientat, poate face adunări în serie · 1 = nu poate face adunări în serie '
        'sau este nesigur asupra datei · 2 = dezorientat asupra datei cu cel mult 2 zile · '
        '3 = dezorientat asupra datei cu peste 2 zile · 4 = dezorientat în spațiu și/sau '
        'la propria persoană',
  ),
];

const _cgi = <Camp>[
  CampAlegere(
    's',
    'CGI-S – severitatea bolii',
    [
      '1 · Normal, deloc bolnav',
      '2 · La limita bolii psihice',
      '3 · Ușor bolnav',
      '4 · Moderat bolnav',
      '5 · Marcat bolnav',
      '6 · Sever bolnav',
      '7 · Printre pacienții cei mai grav bolnavi',
    ],
    detaliu:
        'Având în vedere întreaga dvs. experiență clinică cu această categorie de '
        'pacienți, cât de bolnav psihic este pacientul în acest moment?',
  ),
  CampAlegere(
    'i',
    'CGI-I – ameliorarea globală față de starea de la inițierea tratamentului',
    [
      '1 · Foarte mult ameliorat',
      '2 · Mult ameliorat',
      '3 · Minim ameliorat',
      '4 · Nicio schimbare',
      '5 · Minim agravat',
      '6 · Mult agravat',
      '7 · Foarte mult agravat',
    ],
    detaliu: 'Se notează ameliorarea totală, indiferent dacă se datorează sau nu tratamentului.',
  ),
];

/// Doza (mg) echivalenta cu 10 mg diazepam, dupa tabelul Ashton.
/// Unde sursa da un interval am folosit mijlocul lui.
const echivalenteBenzodiazepine = <String, double>{
  'Alprazolam': 0.5,
  'Bromazepam': 5.5,
  'Clonazepam': 0.5,
  'Clorazepat': 15,
  'Clordiazepoxid': 25,
  'Diazepam': 10,
  'Lorazepam': 1,
  'Lormetazepam': 1.5,
  'Medazepam': 10,
  'Nitrazepam': 10,
  'Oxazepam': 20,
  'Zolpidem': 20,
  'Zopiclonă': 15,
};

/// Doza orala (mg) echivalenta cu 100 mg clorpromazina, dupa Woods 2003.
const echivalenteAntipsihotice = <String, double>{
  'Aripiprazol': 7.5,
  'Clorpromazină': 100,
  'Haloperidol': 2,
  'Olanzapină': 5,
  'Quetiapină': 75,
  'Risperidonă': 2,
  'Ziprasidonă': 60,
};

List<Camp> _campuriEchivalenta(Map<String, double> tabel) {
  final substante = tabel.keys.toList();
  return [
    CampAlegere('din', 'Din', substante),
    const CampNumar('doza', 'Doză zilnică', 'mg'),
    CampAlegere('in', 'În', substante),
  ];
}

Rezultat? _echivalenta(Map<String, double> tabel, Map<String, Object> v) {
  final doza = v['doza'];
  if (doza is! double || doza <= 0 || v['din'] is! int || v['in'] is! int) {
    return null;
  }
  final din = tabel.entries.elementAt(v['din'] as int);
  final spre = tabel.entries.elementAt(v['in'] as int);
  final rezultat = doza * spre.value / din.value;
  return Rezultat(
    formatNumar(rezultat, rezultat < 10 ? 2 : 1),
    'mg ${spre.key.toLowerCase()}',
    '${formatNumar(doza, doza < 10 ? 2 : 1)} mg ${din.key.toLowerCase()} corespund aproximativ '
        'acestei doze. Echivalențele sunt orientative și nu țin cont de timpul de '
        'înjumătățire, vârstă, funcția hepatică sau toleranță.',
    Nivel.atentie,
  );
}

bool _toateCompletate(List<Camp> campuri, Map<String, Object> v) {
  return campuri.every((c) => v[c.id] is int);
}

const _hunter = <Camp>[
  CampBifa(
    'agent',
    'Expunere la un agent serotoninergic',
    0,
    detaliu:
        'Tratament, asociere de medicamente sau supradoză; condiție obligatorie '
        'pentru aplicarea criteriilor',
  ),
  CampBifa('clonus_spontan', 'Clonus spontan', 0),
  CampBifa('clonus_inductibil', 'Clonus provocat (inductibil)', 0),
  CampBifa(
    'clonus_ocular',
    'Clonus ocular',
    0,
    detaliu: 'Mișcări oculare orizontale lente, continue',
  ),
  CampBifa('agitatie', 'Agitație', 0),
  CampBifa('diaforeza', 'Diaforeză', 0),
  CampBifa('tremor', 'Tremor', 0),
  CampBifa('hiperreflexie', 'Hiperreflexie', 0),
  CampBifa('hipertonie', 'Hipertonie musculară', 0),
  CampBifa('febra', 'Temperatură peste 38 °C', 0),
];

const _aimsAncore =
    '0 = absente · 1 = minime (pot fi la limita extremă a normalului) · 2 = ușoare · '
    '3 = moderate · 4 = severe';

/// Primii 7 itemi sunt zonele corporale care intra in scorul total.
const _aimsZone = 7;
const _aimsGlobal =
    '0 = absentă, normal · 1 = minimă · 2 = ușoară · 3 = moderată · 4 = severă';
const _aims = <Camp>[
  CampScala(
    'a1',
    '1. Mușchii mimicii',
    4,
    detaliu:
        'Frunte, sprâncene, regiune periorbitală, obraji; inclusiv încruntare, clipit, '
        'zâmbet, grimase.\n$_aimsAncore',
  ),
  CampScala(
    'a2',
    '2. Buze și regiune periorală',
    4,
    detaliu: 'Țuguiere, bosumflare, plescăit.\n$_aimsAncore',
  ),
  CampScala(
    'a3',
    '3. Mandibulă',
    4,
    detaliu:
        'Mușcare, încleștare, masticație, deschiderea gurii, mișcări laterale.\n$_aimsAncore',
  ),
  CampScala(
    'a4',
    '4. Limbă',
    4,
    detaliu:
        'Se notează doar creșterea mișcărilor, în interiorul și în afara cavității '
        'bucale, NU incapacitatea de a menține o poziție.\n$_aimsAncore',
  ),
  CampScala(
    'a5',
    '5. Membre superioare',
    4,
    detaliu:
        'Brațe, articulațiile pumnului, mâini, degete. Se includ mișcările coreice și '
        'atetozice; NU se include tremorul.\n$_aimsAncore',
  ),
  CampScala(
    'a6',
    '6. Membre inferioare',
    4,
    detaliu:
        'Gambe, genunchi, glezne, degete: mișcări laterale ale genunchilor, bătut din '
        'picior, lăsarea călcâiului, frământarea picioarelor, inversiunea și eversiunea '
        'piciorului.\n$_aimsAncore',
  ),
  CampScala(
    'a7',
    '7. Trunchi: gât, umeri, șolduri',
    4,
    detaliu:
        'Legănare, răsucire, zvârcolire, mișcări de rotație ale bazinului.\n$_aimsAncore',
  ),
  CampScala(
    'a8',
    '8. Severitatea mișcărilor anormale (apreciere globală)',
    4,
    detaliu: 'Nu intră în scorul total. $_aimsGlobal',
  ),
  CampScala(
    'a9',
    '9. Incapacitatea (afectarea funcțională) datorată mișcărilor anormale',
    4,
    detaliu: 'Nu intră în scorul total. $_aimsGlobal',
  ),
  CampScala(
    'a10',
    '10. Conștientizarea mișcărilor anormale de către pacient',
    4,
    detaliu:
        'Se notează doar relatarea pacientului. 0 = nu le conștientizează · 1 = le '
        'conștientizează, fără disconfort · 2 = disconfort ușor · 3 = disconfort moderat · '
        '4 = disconfort sever',
  ),
  CampBifa('a11', '11. Probleme actuale cu dinții și/sau proteza dentară', 0),
  CampBifa('a12', '12. Pacientul poartă de obicei proteză dentară', 0),
];

const _bprsItemi = [
  'Preocupări somatice',
  'Anxietate',
  'Retragere emoțională',
  'Dezorganizare conceptuală',
  'Sentimente de vinovăție',
  'Tensiune',
  'Manierisme și posturi bizare',
  'Grandoare',
  'Dispoziție depresivă',
  'Ostilitate',
  'Suspiciozitate',
  'Comportament halucinator',
  'Lentoare motorie',
  'Lipsă de cooperare',
  'Conținut neobișnuit al gândirii',
  'Aplatizare afectivă',
  'Excitație',
  'Dezorientare',
];

final _bprs = <Camp>[
  for (final (i, item) in _bprsItemi.indexed)
    CampScala('b${i + 1}', '${i + 1}. $item', 7, minim: 1),
];

bool _hunterPozitiv(Map<String, Object> v) {
  bool are(String id) => v[id] == true;
  final agitatieSauDiaforeza = are('agitatie') || are('diaforeza');
  return are('clonus_spontan') ||
      (are('clonus_inductibil') && agitatieSauDiaforeza) ||
      (are('clonus_ocular') && agitatieSauDiaforeza) ||
      (are('tremor') && are('hiperreflexie')) ||
      (are('hipertonie') &&
          are('febra') &&
          (are('clonus_ocular') || are('clonus_inductibil')));
}

final List<Calculator> calculatoarePsihiatrie = [
  Calculator(
    id: 'phq9',
    titlu: 'PHQ-9',
    descriere: 'Chestionar pentru depresie, ultimele 2 săptămâni',
    categorie: _categorie,
    icon: Icons.sentiment_dissatisfied_outlined,
    campuri: _phq9,
    sursa:
        'Kroenke K, Spitzer RL, Williams JBW, J Gen Intern Med 2001. Text oficial în '
        'română (Pfizer); reproducerea nu necesită permisiune.',
    calculeaza: (v) {
      if (!_toateCompletate(_phq9, v)) return null;
      final scor = sumaPuncte(_phq9, v);
      var (text, nivel) = switch (scor) {
        <= 4 => ('Depresie minimă sau absentă (0–4).', Nivel.normal),
        <= 9 => ('Depresie ușoară (5–9).', Nivel.normal),
        <= 14 => ('Depresie moderată (10–14).', Nivel.atentie),
        <= 19 => ('Depresie moderat-severă (15–19).', Nivel.ridicat),
        _ => ('Depresie severă (20–27).', Nivel.ridicat),
      };
      if (v['q9'] != 0) {
        text = '$text\nItemul 9 este pozitiv – evaluează riscul suicidar.';
        nivel = Nivel.ridicat;
      }
      return Rezultat('$scor', 'din 27', text, nivel);
    },
  ),
  Calculator(
    id: 'gad7',
    titlu: 'GAD-7',
    descriere: 'Chestionar pentru anxietate, ultimele 2 săptămâni',
    categorie: _categorie,
    icon: Icons.waves,
    campuri: _gad7,
    sursa:
        'Spitzer RL et al., Arch Intern Med 2006. Text oficial în română (Pfizer); '
        'reproducerea nu necesită permisiune.',
    calculeaza: (v) {
      if (!_toateCompletate(_gad7, v)) return null;
      final scor = sumaPuncte(_gad7, v);
      final (text, nivel) = switch (scor) {
        <= 4 => ('Anxietate minimă (0–4).', Nivel.normal),
        <= 9 => ('Anxietate ușoară (5–9).', Nivel.normal),
        <= 14 => ('Anxietate moderată (10–14).', Nivel.atentie),
        _ => ('Anxietate severă (15–21).', Nivel.ridicat),
      };
      return Rezultat('$scor', 'din 21', text, nivel);
    },
  ),
  Calculator(
    id: 'audit',
    titlu: 'AUDIT',
    descriere: 'Screening pentru consumul problematic de alcool',
    categorie: _categorie,
    icon: Icons.local_bar_outlined,
    campuri: _audit,
    sursa: 'Babor TF et al., OMS 2001. Itemii: traducere revizuită după original, fără validare psihometrică în română.',
    calculeaza: (v) {
      if (!_toateCompletate(_audit, v)) return null;
      final scor = sumaPuncte(_audit, v);
      final (text, nivel) = switch (scor) {
        <= 7 => ('Zona I – consum cu risc scăzut (0–7).', Nivel.normal),
        <= 15 => (
          'Zona II – consum cu risc (8–15): sfat simplu.',
          Nivel.atentie,
        ),
        <= 19 => (
          'Zona III – consum nociv (16–19): consiliere scurtă și monitorizare.',
          Nivel.ridicat,
        ),
        _ => (
          'Zona IV – posibilă dependență (20–40): evaluare diagnostică și tratament.',
          Nivel.ridicat,
        ),
      };
      return Rezultat('$scor', 'din 40', text, nivel);
    },
  ),
  Calculator(
    id: 'ciwa',
    titlu: 'CIWA-Ar',
    descriere: 'Severitatea sevrajului la alcool',
    categorie: _categorie,
    icon: Icons.monitor_heart_outlined,
    campuri: _ciwa,
    sursa:
        'Sullivan JT et al., Br J Addict 1989. Praguri uzuale: până la 8, 9–19, 20 sau '
        'peste; unele protocoale folosesc 10 și 18. Itemii: traducere revizuită după original, fără validare psihometrică în română.',
    calculeaza: (v) {
      if (!_toateCompletate(_ciwa, v)) return null;
      final scor = sumaPuncte(_ciwa, v);
      final (text, nivel) = switch (scor) {
        <= 8 => (
          'Sevraj absent sau minim (până la 8) – de regulă fără medicație.',
          Nivel.normal,
        ),
        <= 19 => ('Sevraj ușor până la moderat (9–19).', Nivel.atentie),
        _ => (
          'Sevraj sever (20 sau peste) – risc de convulsii și delirium tremens.',
          Nivel.ridicat,
        ),
      };
      return Rezultat('$scor', 'din 67', text, nivel);
    },
  ),
  Calculator(
    id: 'cgi',
    titlu: 'CGI',
    descriere: 'Impresia clinică globală: severitate și ameliorare',
    categorie: _categorie,
    icon: Icons.assessment_outlined,
    campuri: _cgi,
    sursa: 'Guy W, ECDEU Assessment Manual for Psychopharmacology, 1976.',
    calculeaza: (v) {
      final s = v['s'];
      final i = v['i'];
      if (s is! int) return null;
      final severitate = (_cgi[0] as CampAlegere).optiuni[s].substring(4);
      final nivel = s >= 5
          ? Nivel.ridicat
          : (s >= 3 ? Nivel.atentie : Nivel.normal);
      if (i is! int) {
        return Rezultat('${s + 1}', 'CGI-S', severitate, nivel);
      }
      final ameliorare = (_cgi[1] as CampAlegere).optiuni[i].substring(4);
      return Rezultat(
        '${s + 1} / ${i + 1}',
        'S / I',
        '$severitate. $ameliorare.',
        nivel,
      );
    },
  ),
  Calculator(
    id: 'echiv_bzd',
    titlu: 'Echivalențe benzodiazepine',
    descriere: 'Conversie între benzodiazepine, raportat la diazepam',
    categorie: _categorie,
    icon: Icons.swap_horiz,
    campuri: _campuriEchivalenta(echivalenteBenzodiazepine),
    sursa:
        'Ashton CH, Benzodiazepine Equivalence Table. Unde sursa dă un interval '
        '(bromazepam, lormetazepam) s-a folosit mijlocul lui.',
    calculeaza: (v) => _echivalenta(echivalenteBenzodiazepine, v),
  ),
  Calculator(
    id: 'echiv_ap',
    titlu: 'Echivalențe antipsihotice',
    descriere: 'Conversie între antipsihotice orale, raportat la clorpromazină',
    categorie: _categorie,
    icon: Icons.compare_arrows,
    campuri: _campuriEchivalenta(echivalenteAntipsihotice),
    sursa:
        'Woods SW, J Clin Psychiatry 2003 (doze orale echivalente cu 100 mg '
        'clorpromazină). Alte surse dau valori diferite.',
    calculeaza: (v) => _echivalenta(echivalenteAntipsihotice, v),
  ),
  Calculator(
    id: 'hunter',
    titlu: 'Criteriile Hunter',
    descriere: 'Diagnosticul sindromului serotoninergic',
    categorie: _categorie,
    icon: Icons.bolt_outlined,
    campuri: _hunter,
    sursa: 'Dunkley EJC et al., QJM 2003 (Hunter Serotonin Toxicity Criteria).',
    calculeaza: (v) {
      if (v['agent'] != true) {
        return const Rezultat(
          '—',
          '',
          'Criteriile se aplică doar dacă pacientul a primit un agent serotoninergic.',
        );
      }
      return _hunterPozitiv(v)
          ? const Rezultat(
              'Pozitiv',
              '',
              'Criteriile Hunter sunt îndeplinite – sindrom serotoninergic probabil. '
                  'Oprește agenții serotoninergici și evaluează severitatea.',
              Nivel.ridicat,
            )
          : const Rezultat(
              'Negativ',
              '',
              'Combinația de semne bifate nu îndeplinește criteriile Hunter.',
            );
    },
  ),
  Calculator(
    id: 'aims',
    titlu: 'AIMS',
    descriere: 'Mișcări involuntare anormale – diskinezie tardivă',
    categorie: _categorie,
    icon: Icons.accessibility_new,
    campuri: _aims,
    sursa:
        'Guy W, ECDEU Assessment Manual, 1976; pragul de screening după Schooler și '
        'Kane, 1982. Itemii: traducere revizuită după original, fără validare psihometrică în română.',
    calculeaza: (v) {
      final zone = _aims.take(_aimsZone).toList();
      if (!_toateCompletate(zone, v)) return null;
      final note = [for (final c in zone) v[c.id] as int];
      final total = note.reduce((a, b) => a + b);
      final pozitiv =
          note.any((n) => n >= 3) || note.where((n) => n >= 2).length >= 2;
      return pozitiv
          ? Rezultat(
              '$total',
              'din 28',
              'Screening pozitiv: cel puțin o zonă cu notă 3 sau peste, ori cel puțin '
                  'două zone cu notă 2 sau peste.',
              Nivel.ridicat,
            )
          : Rezultat(
              '$total',
              'din 28',
              'Screening negativ după pragul Schooler-Kane.',
            );
    },
  ),
  Calculator(
    id: 'bprs',
    titlu: 'BPRS (18 itemi)',
    descriere:
        'Scala scurtă de evaluare psihiatrică. 1 = absent · 2 = foarte ușor · 3 = ușor · '
        '4 = moderat · 5 = moderat-sever · 6 = sever · 7 = extrem de sever',
    categorie: _categorie,
    icon: Icons.fact_check_outlined,
    campuri: _bprs,
    sursa:
        'Overall JE, Gorham DR, Psychol Rep 1962. Repere de severitate după Leucht '
        'et al., Br J Psychiatry 2005. Denumirile itemilor: traducere revizuită după original, fără validare psihometrică în română.',
    calculeaza: (v) {
      if (!_toateCompletate(_bprs, v)) return null;
      final scor = sumaPuncte(_bprs, v);
      final (text, nivel) = switch (scor) {
        < 31 => ('Sub reperul pentru „ușor bolnav” (31).', Nivel.normal),
        < 41 => ('În zona „ușor bolnav” (31–40).', Nivel.normal),
        < 53 => ('În zona „moderat bolnav” (41–52).', Nivel.atentie),
        _ => ('În zona „marcat bolnav” sau peste (53+).', Nivel.ridicat),
      };
      return Rezultat('$scor', 'din 126', text, nivel);
    },
  ),
];
