import 'package:flutter/material.dart';

import 'calculator.dart';
import 'formule.dart';
import 'psihiatrie.dart';

const _sex = CampAlegere('sex', 'Sex', ['Bărbat', 'Femeie']);
const _varsta = CampNumar('varsta', 'Vârstă', 'ani');
const _greutate = CampNumar('kg', 'Greutate', 'kg');
const _inaltime = CampNumar('cm', 'Înălțime', 'cm');
const _unitateCreatinina = CampAlegere('unitate', 'Unitate creatinină', [
  'mg/dl',
  'µmol/l',
], implicit: 0);
const _creatinina = CampNumar('cr', 'Creatinină serică', '');

double? _n(Map<String, Object> v, String id) {
  final x = v[id];
  return x is double && x > 0 ? x : null;
}

/// Creatinina in mg/dl, indiferent de unitatea aleasa.
double? _creatininaMgDl(Map<String, Object> v) {
  final cr = _n(v, 'cr');
  if (cr == null || v['unitate'] is! int) return null;
  return v['unitate'] == 1 ? creatininaMgDl(cr) : cr;
}

Rezultat _stadiuRenal(double valoare, String unitate) {
  final (text, nivel) = switch (valoare) {
    >= 90 => ('G1 – funcție normală sau crescută', Nivel.normal),
    >= 60 => ('G2 – scădere ușoară', Nivel.normal),
    >= 45 => ('G3a – scădere ușoară până la moderată', Nivel.atentie),
    >= 30 => ('G3b – scădere moderată până la severă', Nivel.atentie),
    >= 15 => ('G4 – scădere severă', Nivel.ridicat),
    _ => ('G5 – insuficiență renală', Nivel.ridicat),
  };
  return Rezultat(formatNumar(valoare, 0), unitate, text, nivel);
}

final List<Calculator> calculatoare = [
  ...calculatoarePsihiatrie,
  Calculator(
    id: 'egfr',
    titlu: 'eGFR (CKD-EPI 2021)',
    descriere: 'Rata de filtrare glomerulară estimată din creatinină',
    categorie: 'Nefrologie',
    icon: Icons.water_drop_outlined,
    campuri: const [_sex, _varsta, _unitateCreatinina, _creatinina],
    sursa: 'Inker LA et al., N Engl J Med 2021; stadializare KDIGO.',
    calculeaza: (v) {
      final cr = _creatininaMgDl(v);
      final varsta = _n(v, 'varsta');
      if (cr == null || varsta == null || v['sex'] is! int) return null;
      final r = egfrCkdEpi2021(
        creatinina: cr,
        varsta: varsta,
        femeie: v['sex'] == 1,
      );
      return _stadiuRenal(r, 'ml/min/1,73 m²');
    },
  ),
  Calculator(
    id: 'cg',
    titlu: 'Clearance creatinină (Cockcroft-Gault)',
    descriere: 'Folosit pentru ajustarea dozelor la funcția renală',
    categorie: 'Nefrologie',
    icon: Icons.opacity,
    campuri: const [_sex, _varsta, _greutate, _unitateCreatinina, _creatinina],
    sursa: 'Cockcroft DW, Gault MH, Nephron 1976.',
    calculeaza: (v) {
      final cr = _creatininaMgDl(v);
      final varsta = _n(v, 'varsta');
      final kg = _n(v, 'kg');
      if (cr == null || varsta == null || kg == null || v['sex'] is! int) {
        return null;
      }
      final r = cockcroftGault(
        creatinina: cr,
        varsta: varsta,
        kg: kg,
        femeie: v['sex'] == 1,
      );
      final nivel = r < 30
          ? Nivel.ridicat
          : (r < 60 ? Nivel.atentie : Nivel.normal);
      return Rezultat(
        formatNumar(r, 0),
        'ml/min',
        'Valoare neajustată la suprafața corporală. Verifică în RCP pragurile de ajustare a dozei.',
        nivel,
      );
    },
  ),
  Calculator(
    id: 'imc',
    titlu: 'Indice de masă corporală',
    descriere: 'IMC și clasificarea OMS',
    categorie: 'General',
    icon: Icons.monitor_weight_outlined,
    campuri: const [_greutate, _inaltime],
    sursa: 'Clasificarea OMS pentru adulți.',
    calculeaza: (v) {
      final kg = _n(v, 'kg');
      final cm = _n(v, 'cm');
      if (kg == null || cm == null) return null;
      final r = imc(kg, cm);
      final (text, nivel) = switch (r) {
        < 18.5 => ('Subponderal', Nivel.atentie),
        < 25 => ('Greutate normală', Nivel.normal),
        < 30 => ('Supraponderal', Nivel.atentie),
        < 35 => ('Obezitate gradul I', Nivel.ridicat),
        < 40 => ('Obezitate gradul II', Nivel.ridicat),
        _ => ('Obezitate gradul III', Nivel.ridicat),
      };
      return Rezultat(formatNumar(r), 'kg/m²', text, nivel);
    },
  ),
  Calculator(
    id: 'sc',
    titlu: 'Suprafață corporală (Mosteller)',
    descriere: 'Pentru doze exprimate pe m²',
    categorie: 'General',
    icon: Icons.accessibility_new,
    campuri: const [_greutate, _inaltime],
    sursa: 'Mosteller RD, N Engl J Med 1987.',
    calculeaza: (v) {
      final kg = _n(v, 'kg');
      final cm = _n(v, 'cm');
      if (kg == null || cm == null) return null;
      return Rezultat(
        formatNumar(suprafataCorporala(kg, cm), 2),
        'm²',
        'Formula Mosteller.',
      );
    },
  ),
  Calculator(
    id: 'gi',
    titlu: 'Greutate ideală (Devine)',
    descriere: 'Greutatea ideală în funcție de înălțime și sex',
    categorie: 'General',
    icon: Icons.straighten,
    campuri: const [_sex, _inaltime],
    sursa: 'Devine BJ, Drug Intell Clin Pharm 1974.',
    calculeaza: (v) {
      final cm = _n(v, 'cm');
      if (cm == null || v['sex'] is! int) return null;
      if (cm < 152.4) {
        return const Rezultat(
          '—',
          '',
          'Formula Devine se aplică la înălțimi de peste 152,4 cm (60 inchi).',
          Nivel.atentie,
        );
      }
      final r = greutateIdeala(cm, femeie: v['sex'] == 1);
      return Rezultat(formatNumar(r), 'kg', 'Formula Devine.');
    },
  ),
  Calculator(
    id: 'cha2ds2vasc',
    titlu: 'CHA2DS2-VASc',
    descriere: 'Riscul de AVC în fibrilația atrială',
    categorie: 'Cardiologie',
    icon: Icons.favorite_border,
    campuri: const [
      CampAlegere(
        'varsta',
        'Vârstă',
        ['Sub 65 de ani', '65–74 de ani', '75 de ani sau peste'],
        puncte: [0, 1, 2],
      ),
      CampAlegere('sex', 'Sex', ['Bărbat', 'Femeie'], puncte: [0, 1]),
      CampBifa(
        'ic',
        'Insuficiență cardiacă',
        1,
        detaliu: 'Semne/simptome de IC sau FEVS redusă',
      ),
      CampBifa('hta', 'Hipertensiune arterială', 1),
      CampBifa('dz', 'Diabet zaharat', 1),
      CampBifa('avc', 'AVC, AIT sau tromboembolism în antecedente', 2),
      CampBifa(
        'vasc',
        'Boală vasculară',
        1,
        detaliu:
            'Infarct miocardic, boală arterială periferică sau placă aortică',
      ),
    ],
    sursa: 'Lip GYH et al., Chest 2010; recomandări ESC 2020 pentru fibrilația atrială.',
    calculeaza: (v) {
      if (v['varsta'] is! int || v['sex'] is! int) return null;
      final femeie = v['sex'] == 1;
      final campuri = calculatoare
          .firstWhere((c) => c.id == 'cha2ds2vasc')
          .campuri;
      final scor = sumaPuncte(campuri, v);
      // pragurile ESC 2020 sunt cu un punct mai sus la femei
      final faraSex = scor - (femeie ? 1 : 0);
      final (text, nivel) = switch (faraSex) {
        0 => (
          'Risc scăzut – anticoagularea nu este recomandată.',
          Nivel.normal,
        ),
        1 => (
          'Risc intermediar – anticoagularea orală trebuie luată în considerare.',
          Nivel.atentie,
        ),
        _ => (
          'Risc crescut – anticoagularea orală este recomandată.',
          Nivel.ridicat,
        ),
      };
      return Rezultat('$scor', 'din 9', text, nivel);
    },
  ),
  Calculator(
    id: 'hasbled',
    titlu: 'HAS-BLED',
    descriere: 'Riscul de sângerare sub anticoagulant',
    categorie: 'Cardiologie',
    icon: Icons.bloodtype_outlined,
    campuri: const [
      CampBifa(
        'hta',
        'Hipertensiune necontrolată',
        1,
        detaliu: 'TA sistolică peste 160 mmHg',
      ),
      CampBifa(
        'renal',
        'Funcție renală anormală',
        1,
        detaliu: 'Dializă, transplant sau creatinină peste 2,26 mg/dl',
      ),
      CampBifa(
        'hepatic',
        'Funcție hepatică anormală',
        1,
        detaliu: 'Ciroză, bilirubină peste 2× sau transaminaze peste 3× limita superioară',
      ),
      CampBifa('avc', 'AVC în antecedente', 1),
      CampBifa('sangerare', 'Sângerare majoră sau predispoziție', 1),
      CampBifa(
        'inr',
        'INR labil',
        1,
        detaliu: 'Timp în interval terapeutic sub 60%',
      ),
      CampBifa('varsta', 'Vârstă peste 65 de ani', 1),
      CampBifa(
        'medicamente',
        'Medicamente care cresc riscul',
        1,
        detaliu: 'Antiagregante plachetare sau AINS',
      ),
      CampBifa(
        'alcool',
        'Consum de alcool',
        1,
        detaliu: '8 sau mai multe unități pe săptămână',
      ),
    ],
    sursa: 'Pisters R et al., Chest 2010.',
    calculeaza: (v) {
      final campuri = calculatoare.firstWhere((c) => c.id == 'hasbled').campuri;
      final scor = sumaPuncte(campuri, v);
      return scor >= 3
          ? Rezultat(
              '$scor',
              'din 9',
              'Risc crescut de sângerare – corectează factorii modificabili și '
                  'urmărește pacientul mai des. Scorul nu contraindică singur anticoagularea.',
              Nivel.ridicat,
            )
          : Rezultat(
              '$scor',
              'din 9',
              'Risc scăzut până la moderat de sângerare.',
            );
    },
  ),
  Calculator(
    id: 'qtc',
    titlu: 'QT corectat (Bazett)',
    descriere: 'QTc din intervalul QT și frecvența cardiacă',
    categorie: 'Cardiologie',
    icon: Icons.monitor_heart_outlined,
    campuri: const [
      _sex,
      CampNumar('qt', 'Interval QT', 'ms'),
      CampNumar('fc', 'Frecvență cardiacă', 'bătăi/min'),
    ],
    sursa: 'Bazett HC, Heart 1920. Formula supracorectează la frecvențe mari.',
    calculeaza: (v) {
      final qt = _n(v, 'qt');
      final fc = _n(v, 'fc');
      if (qt == null || fc == null || v['sex'] is! int) return null;
      final r = qtcBazett(qt, fc);
      final prag = v['sex'] == 1 ? 460 : 450;
      final (text, nivel) = r > 500
          ? (
              'QTc mult prelungit – risc crescut de torsada vârfurilor.',
              Nivel.ridicat,
            )
          : r > prag
          ? ('QTc prelungit (peste $prag ms).', Nivel.atentie)
          : ('QTc în limite normale (până la $prag ms).', Nivel.normal);
      return Rezultat(formatNumar(r, 0), 'ms', text, nivel);
    },
  ),
  Calculator(
    id: 'tam',
    titlu: 'Tensiune arterială medie',
    descriere: 'TAM din valorile sistolică și diastolică',
    categorie: 'Cardiologie',
    icon: Icons.speed,
    campuri: const [
      CampNumar('tas', 'TA sistolică', 'mmHg'),
      CampNumar('tad', 'TA diastolică', 'mmHg'),
    ],
    sursa: 'TAM = (TAS + 2 × TAD) / 3.',
    calculeaza: (v) {
      final tas = _n(v, 'tas');
      final tad = _n(v, 'tad');
      if (tas == null || tad == null) return null;
      final r = tensiuneMedie(tas, tad);
      return r < 65
          ? Rezultat(
              formatNumar(r, 0),
              'mmHg',
              'Sub 65 mmHg – perfuzie de organ posibil insuficientă.',
              Nivel.ridicat,
            )
          : Rezultat(
              formatNumar(r, 0),
              'mmHg',
              'Ținta uzuală de perfuzie este de cel puțin 65 mmHg.',
            );
    },
  ),
  Calculator(
    id: 'curb65',
    titlu: 'CURB-65',
    descriere: 'Severitatea pneumoniei comunitare',
    categorie: 'Pneumologie',
    icon: Icons.air,
    campuri: const [
      CampBifa('c', 'Confuzie nou apărută', 1),
      CampBifa(
        'u',
        'Uree peste 7 mmol/l',
        1,
        detaliu: 'Echivalent cu uree serică peste 42 mg/dl',
      ),
      CampBifa('r', 'Frecvență respiratorie de 30/min sau peste', 1),
      CampBifa(
        'b',
        'Hipotensiune',
        1,
        detaliu: 'TAS sub 90 mmHg sau TAD de 60 mmHg sau sub',
      ),
      CampBifa('v', 'Vârstă de 65 de ani sau peste', 1),
    ],
    sursa: 'Lim WS et al., Thorax 2003.',
    calculeaza: (v) {
      final campuri = calculatoare.firstWhere((c) => c.id == 'curb65').campuri;
      final scor = sumaPuncte(campuri, v);
      final (text, nivel) = switch (scor) {
        <= 1 => (
          'Risc scăzut – tratamentul ambulatoriu poate fi adecvat.',
          Nivel.normal,
        ),
        2 => ('Risc moderat – ia în considerare internarea.', Nivel.atentie),
        _ => (
          'Pneumonie severă – internare, evaluează necesitatea terapiei intensive.',
          Nivel.ridicat,
        ),
      };
      return Rezultat('$scor', 'din 5', text, nivel);
    },
  ),
  Calculator(
    id: 'gcs',
    titlu: 'Scala Glasgow (GCS)',
    descriere: 'Evaluarea stării de conștiență',
    categorie: 'Neurologie',
    icon: Icons.psychology_outlined,
    campuri: const [
      CampAlegere(
        'ochi',
        'Deschiderea ochilor',
        ['Spontană', 'La stimul verbal', 'La durere', 'Absentă'],
        puncte: [4, 3, 2, 1],
      ),
      CampAlegere(
        'verbal',
        'Răspuns verbal',
        [
          'Orientat',
          'Confuz',
          'Cuvinte nepotrivite',
          'Sunete neinteligibile',
          'Absent',
        ],
        puncte: [5, 4, 3, 2, 1],
      ),
      CampAlegere(
        'motor',
        'Răspuns motor',
        [
          'Execută comenzi',
          'Localizează durerea',
          'Retrage la durere',
          'Flexie anormală',
          'Extensie anormală',
          'Absent',
        ],
        puncte: [6, 5, 4, 3, 2, 1],
      ),
    ],
    sursa: 'Teasdale G, Jennett B, Lancet 1974.',
    calculeaza: (v) {
      if (v['ochi'] is! int || v['verbal'] is! int || v['motor'] is! int) {
        return null;
      }
      final campuri = calculatoare.firstWhere((c) => c.id == 'gcs').campuri;
      final scor = sumaPuncte(campuri, v);
      final (text, nivel) = switch (scor) {
        >= 13 => ('Afectare ușoară (13–15).', Nivel.normal),
        >= 9 => ('Afectare moderată (9–12).', Nivel.atentie),
        _ => (
          'Afectare severă (8 sau sub) – evaluează protecția căilor aeriene.',
          Nivel.ridicat,
        ),
      };
      return Rezultat('$scor', 'din 15', text, nivel);
    },
  ),
  Calculator(
    id: 'calciu',
    titlu: 'Calciu corectat',
    descriere: 'Calcemia corectată în funcție de albumină',
    categorie: 'Laborator',
    icon: Icons.science_outlined,
    campuri: const [
      CampNumar('ca', 'Calciu seric total', 'mg/dl'),
      CampNumar('alb', 'Albumină', 'g/dl'),
    ],
    sursa: 'Payne RB et al., BMJ 1973. Interval de referință uzual: 8,5–10,5 mg/dl.',
    calculeaza: (v) {
      final ca = _n(v, 'ca');
      final alb = _n(v, 'alb');
      if (ca == null || alb == null) return null;
      final r = calciuCorectat(ca, alb);
      final (text, nivel) = r < 8.5
          ? (
              'Sub intervalul de referință uzual (8,5–10,5 mg/dl).',
              Nivel.atentie,
            )
          : r > 10.5
          ? (
              'Peste intervalul de referință uzual (8,5–10,5 mg/dl).',
              Nivel.atentie,
            )
          : (
              'În intervalul de referință uzual (8,5–10,5 mg/dl).',
              Nivel.normal,
            );
      return Rezultat(formatNumar(r), 'mg/dl', text, nivel);
    },
  ),
];
