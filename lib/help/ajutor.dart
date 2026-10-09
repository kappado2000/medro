import 'package:flutter/material.dart';

/// Un capitol din pagina de ajutor a unei sectiuni.
class CapitolAjutor {
  final IconData icon;
  final String titlu;

  /// Paragraf introductiv, optional.
  final String? text;

  /// Puncte: fiecare are un termen ingrosat si explicatia lui.
  final List<(String, String)> puncte;

  /// Capitolele despre limite si avertizari sunt evidentiate cu rosu.
  final bool avertizare;

  const CapitolAjutor({
    required this.icon,
    required this.titlu,
    this.text,
    this.puncte = const [],
    this.avertizare = false,
  });
}

class Ajutor {
  final String titlu;
  final String rezumat;
  final List<CapitolAjutor> capitole;

  const Ajutor({
    required this.titlu,
    required this.rezumat,
    required this.capitole,
  });
}

const _paginaMedicamentului = CapitolAjutor(
  icon: Icons.description_outlined,
  titlu: 'Pagina unui medicament',
  text: 'Atinge un medicament din listă ca să îi deschizi pagina. De sus în jos găsești:',
  puncte: [
    (
      'Contraindicații',
      'caseta roșie de la început conține secțiunea 4.3 din RCP, exact cum apare în '
          'document. Textele lungi sunt prescurtate; apasă „Arată tot”. Caseta lipsește '
          'dacă secțiunea nu a putut fi extrasă din document.',
    ),
    (
      'RCP și Prospect',
      'deschid documentele oficiale în browser (necesită internet). Pentru medicamentele '
          'autorizate la nivel european există un singur document, de la EMA, care le '
          'conține pe amândouă.',
    ),
    (
      'Răspunsuri rapide din RCP',
      'frazele din document despre doza maximă, sarcină și alăptare, insuficiența renală și '
          'hepatică, vârstnici, monitorizare, enzimele hepatice (CYP), efectele anticolinergice și intervalul QT. '
          'Fiecare frază are în față numărul secțiunii din care provine. Sunt '
          'disponibile fără internet.',
    ),
    (
      'Secțiunile RCP',
      'textul secțiunilor 4.1–4.9: indicații, doze, atenționări, interacțiuni, '
          'reacții adverse, supradozaj. Secțiunile foarte lungi sunt prescurtate și '
          'trimit la document.',
    ),
    (
      'Întreabă asistentul',
      'atașează medicamentul în secțiunea Asistent, unde poți pune întrebări pe baza RCP-ului.',
    ),
    (
      'Verifică interacțiunile',
      'trimite substanța (sau substanțele, la combinații) în secțiunea Interacțiuni.',
    ),
    (
      'Eliberare',
      'tipul de prescripție: OTC (fără rețetă), P6L (rețetă valabilă 6 luni), PRF '
          '(rețetă care se reține în farmacie), PR (prescripție restrictivă), PS '
          '(prescripție specială).',
    ),
    (
      'Compensare CNAS',
      'pentru fiecare ambalaj compensat: sublista (A, B, C1, C2, C3, D), procentul de '
          'compensare, prețul maximal și contribuția maximă a pacientului. La sublista B '
          'apare și contribuția pentru pensionarii cu venituri mici.',
    ),
    (
      'Protocol terapeutic CNAS',
      'apare la medicamentele care au protocol de prescriere: codul, sublista sau '
          'programul și dacă medicul de familie poate continua tratamentul. Atinge '
          'protocolul ca să deschizi PDF-ul CNAS direct la pagina lui.',
    ),
    (
      'Clasificare și autorizare',
      'codul ATC, acțiunea terapeutică, deținătorul autorizației și producătorul.',
    ),
    (
      'Ambalaje',
      'toate formele de prezentare, cu codul CIM și valabilitatea. Textele pot fi '
          'selectate și copiate.',
    ),
    (
      'Aceeași substanță activă',
      'celelalte medicamente cu aceeași substanță, utile ca alternative.',
    ),
    (
      'Favorite',
      'inima din colțul din dreapta sus adaugă medicamentul la favorite.',
    ),
  ],
);

const _limiteMedicamente = CapitolAjutor(
  icon: Icons.info_outline,
  titlu: 'Ce trebuie să știi',
  avertizare: true,
  puncte: [
    (
      'Datele se actualizează singure',
      'aplicația caută date noi o dată pe zi, la pornire, dacă are internet. '
          'Atinge rândul de sub titlul MedRO ca să vezi data fiecărei surse și să '
          'verifici manual. Registrul funcționează și fără internet, cu ultimele date '
          'descărcate; documentele RCP și prospect se deschid online.',
    ),
    (
      'Textele din RCP sunt extrase automat',
      'extragerea poate rata sau tăia o secțiune. Dacă secțiunile nu apar, '
          'documentul nu a putut fi citit; folosește butonul RCP.',
    ),
    (
      'Compensarea poate fi depășită',
      'lista CNAS are data afișată în secțiunea de compensare. Nu toate ambalajele se '
          'regăsesc în ea; uneori apare doar sublista în care figurează substanța, fără preț.',
    ),
    (
      'Contraindicațiile sunt extrase automat',
      'verifică-le în RCP înainte de o decizie. Lipsa casetei nu înseamnă că '
          'medicamentul nu are contraindicații.',
    ),
  ],
);

const ajutorMedicamente = Ajutor(
  titlu: 'Medicamente',
  rezumat:
      'Registrul medicamentelor autorizate în România, din Nomenclatorul ANMDM: '
      'cauți un medicament și afli rapid contraindicațiile, tipul de prescripție, '
      'compensarea, documentele oficiale și alternativele cu aceeași substanță.',
  capitole: [
    CapitolAjutor(
      icon: Icons.search,
      titlu: 'Cum cauți',
      puncte: [
        (
          'După denumirea comercială',
          'de exemplu „zoloft”. Rezultatele care încep cu textul scris apar primele.',
        ),
        (
          'După substanța activă',
          'în forma din nomenclator („sertralinum”) sau în română („sertralina”, „clozapina”).',
        ),
        (
          'După codul ATC',
          'de exemplu „N06AB06” sau doar începutul lui, „N06AB”.',
        ),
        (
          'Cu mai multe cuvinte',
          '„sertralina 50” găsește doar produsele care conțin ambele. Diacriticele și '
              'majusculele nu contează.',
        ),
      ],
    ),
    CapitolAjutor(
      icon: Icons.filter_list,
      titlu: 'Filtre',
      text: 'Rândul de sub căutare restrânge lista și se combină cu textul căutat.',
      puncte: [
        (
          'Clase psihotrope',
          'alegi o clasă (antipsihotice, anxiolitice, hipnotice, antidepresive, '
              'psihostimulante, antidemențiale, antiepileptice și stabilizatori, medicamente '
              'pentru adicții) și vezi toate medicamentele ei. „Toate clasele” anulează alegerea.',
        ),
        (
          'Fără rețetă / Cu rețetă',
          'separă medicamentele OTC de cele cu prescripție.',
        ),
        (
          'Compensate',
          'doar medicamentele care au cel puțin un ambalaj în lista CNAS.',
        ),
        ('Favorite', 'medicamentele marcate de tine cu inimă.'),
      ],
    ),
    CapitolAjutor(
      icon: Icons.view_list_outlined,
      titlu: 'Cum citești lista',
      puncte: [
        (
          'Eticheta din dreapta',
          'tipul de prescripție: albastră pentru OTC, roșie pentru medicamentele cu rețetă.',
        ),
        (
          '„CNAS A”, „CNAS C2”…',
          'sublistele de compensare în care apare medicamentul, lângă forma farmaceutică.',
        ),
        ('Inima roșie', 'medicamentul este la favorite.'),
      ],
    ),
    _paginaMedicamentului,
    _limiteMedicamente,
  ],
);

const ajutorPaginaMedicament = Ajutor(
  titlu: 'Pagina medicamentului',
  rezumat:
      'Tot ce conține aplicația despre un medicament, plus legăturile către '
      'documentele oficiale, asistent și verificatorul de interacțiuni.',
  capitole: [_paginaMedicamentului, _limiteMedicamente],
);

const ajutorInteractiuni = Ajutor(
  titlu: 'Interacțiuni',
  rezumat:
      'Verifici dintr-o privire dacă două sau mai multe medicamente interacționează '
      'și cât de grav, sau vezi toate interacțiunile majore ale unei substanțe.',
  capitole: [
    CapitolAjutor(
      icon: Icons.add_circle_outline,
      titlu: 'Cum adaugi medicamente',
      puncte: [
        (
          'Scrie în câmpul de sus',
          'numele substanței („clozapina”, „clozapinum”) sau denumirea comercială („leponex”).',
        ),
        (
          'Alege din sugestii',
          'sub „Substanțe” apar substanțele active, iar sub „Medicamente” produsele '
              'comerciale. La un medicament combinat se adaugă toate substanțele lui.',
        ),
        (
          'Din pagina unui medicament',
          'butonul „Verifică interacțiunile acestui medicament” îl adaugă direct aici.',
        ),
        (
          'Scoate sau golește',
          'X-ul de pe o etichetă scoate substanța; „Golește” le șterge pe toate.',
        ),
      ],
    ),
    CapitolAjutor(
      icon: Icons.compare_arrows,
      titlu: 'Cum citești rezultatul',
      puncte: [
        (
          'Două sau mai multe substanțe',
          'sunt verificate toate perechile posibile. Sumarul de sus spune câte '
              'interacțiuni există și devine roșu dacă una este majoră.',
        ),
        ('Ordinea', 'perechile apar de la cea mai gravă la cea mai ușoară.'),
        (
          'Alternative din aceeași clasă',
          'la o interacțiune majoră, atinge rândul acesta ca să vezi substanțe din '
              'aceeași subgrupă ATC care nu au interacțiune majoră cu restul listei. '
              'Cele pe fond albastru nu au nicio interacțiune înregistrată; la celelalte '
              'scrie nivelul rămas. Atinge una ca să o pui în locul celei vechi. Sunt '
              'sugestii de verificat, nu echivalențe terapeutice.',
        ),
        (
          'Culorile',
          'roșu – majoră; albastru – moderată; gri – minoră sau cu severitate neprecizată.',
        ),
        (
          'O singură substanță',
          'vezi lista tuturor substanțelor cu care are interacțiuni majore. Atinge una '
              'ca să o adaugi la verificare.',
        ),
      ],
    ),
    CapitolAjutor(
      icon: Icons.info_outline,
      titlu: 'Ce trebuie să știi',
      avertizare: true,
      puncte: [
        (
          'Doar nivelul de severitate',
          'datele provin din baza DDInter 2.0 și nu conțin mecanismul sau conduita. '
              'Pentru acestea, atașează medicamentele în Asistent sau citește secțiunea 4.5 din RCP.',
        ),
        (
          'Lipsa din listă nu înseamnă siguranță',
          'o pereche care nu apare poate interacționa totuși; baza nu este completă.',
        ),
        (
          'Unele substanțe lipsesc',
          'de exemplu bromazepam, sulpirid, tianeptină, flupentixol, zuclopentixol și '
              'tiaprid nu sunt acoperite. Dacă o substanță nu apare la căutare, nu poate fi verificată.',
        ),
        (
          'Încadrarea este prudentă',
          'baza marchează multe asocieri drept majore; nivelul arată că asocierea cere '
              'atenție, nu că este interzisă.',
        ),
      ],
    ),
  ],
);

const ajutorCalculatoare = Ajutor(
  titlu: 'Calculatoare',
  rezumat:
      'Scale, scoruri și formule clinice care se calculează pe măsură ce completezi, '
      'cu interpretarea rezultatului și sursa fiecăruia.',
  capitole: [
    CapitolAjutor(
      icon: Icons.psychology_outlined,
      titlu: 'Ce găsești',
      puncte: [
        (
          'Instrumente de prescriere',
          'plan de reducere sau titrare a dozei, calendarul injecțiilor depot și '
              'monitorizarea cerută de RCP. Fiecare are propria pagină de ajutor.',
        ),
        (
          'Psihiatrie',
          'PHQ-9 (depresie), GAD-7 (anxietate), AUDIT (consum de alcool), CIWA-Ar '
              '(sevraj la alcool), CGI (impresie clinică globală), criteriile Hunter (sindrom '
              'serotoninergic), AIMS (diskinezie tardivă), BPRS și conversii de doze între '
              'benzodiazepine și între antipsihotice.',
        ),
        (
          'Nefrologie',
          'eGFR (CKD-EPI 2021) și clearance-ul de creatinină Cockcroft-Gault, util la '
              'ajustarea dozelor.',
        ),
        (
          'Cardiologie',
          'CHA2DS2-VASc, HAS-BLED, QT corectat (Bazett), tensiune arterială medie.',
        ),
        (
          'Altele',
          'IMC, suprafață corporală, greutate ideală, CURB-65, scala Glasgow, calciu corectat.',
        ),
      ],
    ),
    CapitolAjutor(
      icon: Icons.touch_app_outlined,
      titlu: 'Cum le folosești',
      puncte: [
        (
          'Găsește calculatorul',
          'derulează lista, grupată pe specialități, sau scrie în câmpul de căutare.',
        ),
        (
          'Completează',
          'valorile numerice se scriu în căsuțe (virgula și punctul sunt acceptate), '
              'opțiunile se aleg prin atingere, criteriile se bifează.',
        ),
        (
          'Citește rezultatul',
          'caseta de sus rămâne vizibilă în timp ce derulezi și se actualizează la '
              'fiecare modificare. Devine roșie când rezultatul indică risc crescut.',
        ),
        (
          'Chestionarele',
          'PHQ-9, GAD-7, AUDIT, CIWA-Ar și BPRS afișează scorul abia după ce ai răspuns '
              'la toți itemii. Lângă fiecare variantă apare punctajul ei.',
        ),
        (
          'Conversia de doze',
          'alegi substanța de la care pleci, scrii doza zilnică și alegi substanța țintă.',
        ),
        (
          'Resetează',
          'săgeata circulară din dreapta sus golește toate câmpurile.',
        ),
      ],
    ),
    CapitolAjutor(
      icon: Icons.info_outline,
      titlu: 'Ce trebuie să știi',
      avertizare: true,
      puncte: [
        (
          'Instrumente orientative',
          'nu înlocuiesc judecata clinică. Sub fiecare calculator este indicată sursa formulei.',
        ),
        (
          'PHQ-9',
          'orice răspuns diferit de „Deloc” la itemul 9 afișează avertizarea de risc '
              'suicidar, indiferent de scorul total.',
        ),
        (
          'Traduceri',
          'PHQ-9 și GAD-7 folosesc textul oficial în română. AUDIT, CIWA-Ar, CGI, AIMS și '
              'BPRS sunt traduse după originalele în engleză și revizuite, dar nu au o '
              'versiune românească validată; la CIWA-Ar și AIMS sunt afișate descrierile '
              'originale ale fiecărei note.',
        ),
        (
          'Echivalențe de doze',
          'sunt aproximative și diferă între surse; nu țin cont de timpul de '
              'înjumătățire, vârstă sau funcția hepatică.',
        ),
      ],
    ),
  ],
);

const ajutorIcd = Ajutor(
  titlu: 'ICD-10',
  rezumat:
      'Clasificarea bolilor în română: găsești rapid codul unui diagnostic sau '
      'diagnosticul unui cod și îl copiezi dintr-o atingere.',
  capitole: [
    CapitolAjutor(
      icon: Icons.account_tree_outlined,
      titlu: 'Navigare pe capitole',
      puncte: [
        (
          'Capitolele',
          'cele 22 de capitole apar în listă, cu tulburările mentale și de comportament '
              '(capitolul V, F00–F99) primul, marcat cu roșu.',
        ),
        (
          'Trei niveluri',
          'din capitol ajungi la categorii (F32), de acolo la subcategorii (F32.1) și, '
              'unde există, la al cincilea caracter (F60.31). Săgeata din dreapta arată că '
              'un cod are subdiviziuni.',
        ),
      ],
    ),
    CapitolAjutor(
      icon: Icons.search,
      titlu: 'Căutare',
      puncte: [
        (
          'După cod',
          'cu sau fără punct: „F32.1” și „F321” dau același rezultat. Un început de cod, '
              '„F3”, arată toate codurile care încep așa.',
        ),
        (
          'După diagnostic',
          'scrie unul sau mai multe cuvinte, de exemplu „episod depresiv”. Diacriticele '
              'nu contează. Categoriile apar înaintea subcategoriilor.',
        ),
      ],
    ),
    CapitolAjutor(
      icon: Icons.copy,
      titlu: 'Copierea codului',
      text:
          'Butonul de copiere din dreptul fiecărui rând pune codul în clipboard, gata de '
          'lipit în alt program.',
    ),
    CapitolAjutor(
      icon: Icons.info_outline,
      titlu: 'Ce trebuie să știi',
      avertizare: true,
      puncte: [
        (
          'Sursa',
          'Lista tabelară a bolilor RoDRG (CIM-10-AM în română), ediția din 2011.',
        ),
        (
          'Fără diacritice',
          'titlurile apar așa cum sunt scrise în documentul oficial.',
        ),
        (
          'Subcategorii compuse',
          'la F10–F19 și F70–F79 documentul nu enumeră fiecare cod, așa că titlurile '
              'sunt alcătuite din categorie și al patrulea caracter standard.',
        ),
        (
          'Doar cod și titlu',
          'notele „Include” și „Exclude” și descrierile din clasificare nu sunt afișate.',
        ),
      ],
    ),
  ],
);

const ajutorAsistent = Ajutor(
  titlu: 'Asistent',
  rezumat:
      'Pui întrebări în română și primești răspunsuri formulate pe baza RCP-ului '
      'medicamentelor atașate, cu trimitere la pagina din document.',
  capitole: [
    CapitolAjutor(
      icon: Icons.auto_awesome,
      titlu: 'Ce poate face',
      puncte: [
        (
          'Răspunde din RCP',
          'doze, ajustări în insuficiența renală sau hepatică, contraindicații, '
              'interacțiuni cu mecanism și conduită, monitorizare, reacții adverse.',
        ),
        (
          'Compară mai multe medicamente',
          'poți atașa până la trei; primește RCP-ul fiecăruia și nivelul interacțiunilor '
              'dintre ele.',
        ),
        (
          'Folosește datele aplicației',
          'știe tipul de prescripție, codul ATC și sublista de compensare a '
              'medicamentelor atașate.',
        ),
        (
          'Întrebări generale',
          'fără niciun medicament atașat răspunde din cunoștințele lui generale și '
              'precizează acest lucru.',
        ),
      ],
    ),
    CapitolAjutor(
      icon: Icons.touch_app_outlined,
      titlu: 'Cum îl folosești',
      puncte: [
        (
          'Atașează medicamentul',
          'cu „Atașează medicament” sau, mai simplu, cu butonul „Întreabă asistentul” '
              'din pagina unui medicament.',
        ),
        (
          'Scrie întrebarea',
          'în câmpul de jos, apoi apasă săgeata. Răspunsul durează de obicei 5–20 de secunde.',
        ),
        (
          'Verifică sursele',
          'sub răspuns, „Surse din RCP” arată pagina și fragmentul din document pe care '
              'se bazează fiecare afirmație.',
        ),
        (
          'Continuă conversația',
          'poți pune întrebări suplimentare; asistentul ține minte ce s-a discutat.',
        ),
        (
          'Conversație nouă',
          'primul buton din antet șterge discuția și medicamentele atașate.',
        ),
      ],
    ),
    CapitolAjutor(
      icon: Icons.chat_bubble_outline,
      titlu: 'Exemple de întrebări',
      puncte: [
        ('Dozaj', '„Cum se ajustează doza în insuficiența hepatică?”'),
        (
          'Asociere',
          '„Care este mecanismul interacțiunii dintre cele două și ce conduită recomandă RCP-ul?”',
        ),
        (
          'Monitorizare',
          '„Ce analize trebuie urmărite la inițierea tratamentului?”',
        ),
        ('Rezumat', '„Rezumă contraindicațiile și atenționările speciale.”'),
      ],
    ),
    CapitolAjutor(
      icon: Icons.tune,
      titlu: 'Setări',
      puncte: [
        (
          'Trimite și RCP-ul',
          'comutatorul de sub medicamentele atașate. Oprit, asistentul răspunde mai '
              'ieftin, dar fără documente și fără citări.',
        ),
        (
          'Modelul',
          'butonul cu glisoare alege între Claude Sonnet 5.5 (implicit) și Claude Opus '
              '5.5, mai scump, pentru întrebări grele.',
        ),
        (
          'Cheia',
          'butonul cu cheia permite, opțional, folosirea unei chei Anthropic proprii în '
              'locul serverului aplicației.',
        ),
      ],
    ),
    CapitolAjutor(
      icon: Icons.info_outline,
      titlu: 'Ce trebuie să știi',
      avertizare: true,
      puncte: [
        (
          'Necesită internet',
          'este singura secțiune care nu funcționează offline.',
        ),
        (
          'Fiecare întrebare costă',
          'prima întrebare cu un RCP atașat este cea mai scumpă; următoarele din aceeași '
              'conversație costă mult mai puțin. La medicamentele autorizate de EMA, al căror '
              'RCP are sute de pagini, se trimit doar secțiunile clinice 4.1–4.9 extrase în '
              'aplicație, ca să nu plătești tot documentul.',
        ),
        (
          'Poate greși',
          'răspunsurile sunt generate de un model AI. Verifică pasajele citate înainte '
              'de o decizie clinică.',
        ),
        (
          'Fără date de pacient',
          'întrebările sunt trimise unui serviciu extern; nu introduce informații care '
              'pot identifica un pacient.',
        ),
        (
          'Schimbările repornesc discuția',
          'dacă atașezi sau scoți un medicament, schimbi modelul ori comutatorul de '
              'RCP, conversația începe de la zero.',
        ),
      ],
    ),
  ],
);

/// Butonul cu semnul intrebarii din antetul unei sectiuni.
class ButonAjutor extends StatelessWidget {
  final Ajutor ajutor;
  const ButonAjutor(this.ajutor, {super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Cum se folosește',
      icon: const Icon(Icons.help_outline, color: Colors.white),
      onPressed: () =>
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => AjutorScreen(ajutor))),
    );
  }
}

class AjutorScreen extends StatelessWidget {
  final Ajutor ajutor;
  const AjutorScreen(this.ajutor, {super.key});

  static const _albastru = Color(0xFF1558D6);
  static const _rosu = Color(0xFFE02B3C);
  static const _cerneala = Color(0xFF14213D);
  static const _estompat = Color(0xFF3F4B63);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Despre ${ajutor.titlu}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_albastru, Color(0xFF0B2F7A)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              ajutor.rezumat,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          for (final c in ajutor.capitole) ...[
            const SizedBox(height: 14),
            _capitol(c),
          ],
        ],
      ),
    );
  }

  Widget _capitol(CapitolAjutor c) {
    final culoare = c.avertizare ? _rosu : _albastru;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.avertizare ? const Color(0xFFFDE9EB) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: c.avertizare ? _rosu : const Color(0xFFE1E7F2),
          width: c.avertizare ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(c.icon, color: culoare, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  c.titlu,
                  style: TextStyle(
                    color: culoare,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (c.text != null) ...[
            const SizedBox(height: 10),
            Text(
              c.text!,
              style: const TextStyle(
                color: _cerneala,
                fontSize: 14.5,
                height: 1.45,
              ),
            ),
          ],
          for (final (termen, explicatie) in c.puncte)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: culoare,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: termen,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _cerneala,
                            ),
                          ),
                          TextSpan(
                            text: ' – $explicatie',
                            style: const TextStyle(color: _estompat),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 14.5, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

const ajutorInstrumente = Ajutor(
  titlu: 'Instrumente de prescriere',
  rezumat:
      'Trei unelte pentru practica de zi cu zi: calendarul unei reduceri sau '
      'titrări de doză, datele următoarelor injecții depot și ce cere RCP-ul să '
      'monitorizezi la psihotropele cu risc.',
  capitole: [
    CapitolAjutor(
      icon: Icons.trending_down,
      titlu: 'Plan de reducere sau titrare',
      puncte: [
        (
          'Dozele',
          'scrie doza actuală pe zi și doza țintă. Ținta 0 înseamnă oprire; o țintă '
              'mai mare decât doza actuală produce un plan de creștere.',
        ),
        (
          '% din doza curentă',
          'fiecare pas scade doza cu același procent din doza de la acel moment, '
              'deci pașii devin tot mai mici spre final.',
        ),
        ('mg la fiecare pas', 'fiecare pas schimbă doza cu aceeași cantitate.'),
        (
          'Fracțiune minimă',
          'cea mai mică fracțiune de comprimat disponibilă; dacă o completezi (de exemplu 0,25 mg), dozele sunt rotunjite la multipli '
              'ai ei, ca planul să poată fi urmat cu comprimatele existente.',
        ),
        (
          'Rezultatul',
          'data de la care se ia fiecare doză, data la care se atinge ținta și '
              'durata totală. „Copiază” pune planul ca text, pentru fișa pacientului.',
        ),
      ],
    ),
    CapitolAjutor(
      icon: Icons.vaccines_outlined,
      titlu: 'Injecții depot',
      puncte: [
        (
          'Alege preparatul',
          'intervalul uzual se completează singur și poate fi modificat, în zile '
              'sau în luni, după schema pacientului.',
        ),
        (
          'Ultima administrare',
          'atinge data ca să o schimbi; aplicația calculează următoarele șase '
              'administrări și peste câte zile este fiecare.',
        ),
        (
          'Fereastra',
          'la preparatele la care RCP-ul o precizează (paliperidonă lunară, la 3 și '
              'la 6 luni), vezi între ce date se poate face injecția. Dispare dacă '
              'modifici intervalul standard.',
        ),
        (
          'Nota preparatului',
          'reamintește ce e specific: schema de inițiere, acoperirea orală, '
              'observația de 3 ore după olanzapină pamoat.',
        ),
      ],
    ),
    CapitolAjutor(
      icon: Icons.monitor_heart_outlined,
      titlu: 'Monitorizare din RCP',
      puncte: [
        (
          'Lista',
          'psihotropele la care se cer analize sau controale: clozapină, valproat, '
              'carbamazepină, antipsihotice atipice, metilfenidat și altele.',
        ),
        (
          'Ce vezi',
          'frazele despre monitorizare din secțiunile 4.2 și 4.4 ale RCP-ului unui '
              'produs cu acea substanță, fiecare cu numărul secțiunii. De acolo poți '
              'deschide pagina medicamentului.',
        ),
        (
          'Alte medicamente',
          'aceleași fraze apar în pagina oricărui medicament, la „Răspunsuri rapide '
              'din RCP”.',
        ),
      ],
    ),
    CapitolAjutor(
      icon: Icons.warning_amber_rounded,
      titlu: 'Limite',
      avertizare: true,
      puncte: [
        (
          'Planul de doze este un calcul',
          'nu ține cont de medicament, de timpul de înjumătățire sau de pacient. '
              'Ritmul îl stabilești tu.',
        ),
        (
          'Datele depot sunt orientative',
          'la inițiere, doze omise sau schimbarea preparatului se aplică schemele '
              'din RCP, care nu sunt calculate aici.',
        ),
        (
          'Monitorizarea este extrasă automat',
          'lista de fraze poate fi incompletă și nu înlocuiește ghidurile sau '
              'protocoalele în vigoare. Litiul nu apare dacă nu are produse în '
              'nomenclator.',
        ),
      ],
    ),
  ],
);
