/// Prescurtarile, codurile si termenii care apar in aplicatie, explicate pe
/// larg. Asistentul primeste acest text impreuna cu paginile de ajutor, ca sa
/// poata lamuri orice eticheta de pe ecran. Se completeaza cand aplicatia
/// incepe sa afiseze un cod sau o prescurtare noua.
const glosarAplicatie = '''
INSTITUȚII ȘI SURSE DE DATE
- ANMDM: Agenția Națională a Medicamentului și a Dispozitivelor Medicale din România. Publică Nomenclatorul medicamentelor de uz uman, din care vine registrul din secțiunea Medicamente (denumiri, substanțe, forme, ambalaje, RCP și prospect).
- Nomenclator: lista oficială ANMDM a medicamentelor autorizate în România. Data lui apare sub titlul MedRO, de exemplu „ANMDM 08.10.26”.
- EMA: Agenția Europeană pentru Medicamente. Autorizează medicamentele prin procedură centralizată, valabilă în toată Uniunea Europeană. La aceste medicamente RCP-ul și prospectul sunt un singur document PDF lung, în română, de pe site-ul EMA.
- CNAS: Casa Națională de Asigurări de Sănătate. Publică lista medicamentelor compensate (cu prețuri) și protocoalele terapeutice.
- DDInter 2.0: bază de date academică de interacțiuni medicamentoase, în engleză, cu licență necomercială (CC BY-NC-SA). Din ea vine secțiunea Interacțiuni. Conține doar nivelul de severitate, fără mecanism și fără conduită.
- RoDRG: sistemul românesc de clasificare a cazurilor spitalizate. Lista lui tabelară (2011) este sursa codurilor din secțiunea ICD-10.

DOCUMENTELE UNUI MEDICAMENT
- RCP: Rezumatul caracteristicilor produsului, documentul oficial de referință pentru medic și farmacist.
  Cine îl emite: textul este redactat de deținătorul autorizației de punere pe piață și aprobat de autoritate odată cu autorizația: ANMDM pentru medicamentele autorizate național, Comisia Europeană, pe baza evaluării EMA, pentru cele autorizate centralizat. Orice modificare trece din nou prin aprobare, iar data ultimei revizuiri este scrisă la punctul 10.
  Ce conține, în aceeași ordine la orice medicament: 1 Denumirea comercială; 2 Compoziția calitativă și cantitativă; 3 Forma farmaceutică; 4 Date clinice (4.1 Indicații terapeutice; 4.2 Doze și mod de administrare; 4.3 Contraindicații; 4.4 Atenționări și precauții speciale pentru utilizare; 4.5 Interacțiuni; 4.6 Fertilitatea, sarcina și alăptarea; 4.7 Efecte asupra capacității de a conduce vehicule și de a folosi utilaje; 4.8 Reacții adverse; 4.9 Supradozaj); 5 Proprietăți farmacologice (5.1 farmacodinamice; 5.2 farmacocinetice; 5.3 date preclinice de siguranță); 6 Proprietăți farmaceutice (excipienți, incompatibilități, perioadă de valabilitate, păstrare, ambalaj); 7 Deținătorul autorizației; 8 Numărul autorizației; 9 Data primei autorizări; 10 Data revizuirii textului.
  La ce folosește în practică: este sursa oficială pentru indicațiile aprobate (4.1; o utilizare în afara lor este „off-label”), pentru doze, ajustări la vârstnici, în insuficiența renală sau hepatică și doza maximă (4.2), pentru situațiile în care medicamentul nu se dă (4.3), pentru ce trebuie urmărit și la cine e nevoie de prudență (4.4), pentru asocieri (4.5), sarcină și alăptare (4.6), frecvența reacțiilor adverse (4.8) și conduita în supradozaj (4.9). Timpul de înjumătățire și calea de metabolizare sunt la 5.2.
  Cum îl folosești în aplicație: în pagina medicamentului, caseta roșie arată contraindicațiile (4.3); „Răspunsuri rapide din RCP” adună frazele despre doza maximă, sarcină, rinichi, ficat, vârstnici, monitorizare, CYP, efecte anticolinergice și QT; „Secțiunile RCP” arată textul secțiunilor 4.1–4.9, fără internet; butonul „RCP” deschide documentul întreg, online; „Întreabă asistentul” trimite RCP-ul asistentului, care răspunde cu trimitere la pasaj. Textele din aplicație sunt extrase automat și uneori prescurtate, deci pentru o decizie se verifică documentul întreg.
- Prospect: documentul pentru pacient, aflat în cutia medicamentului, scris în limbaj obișnuit. Se bazează pe RCP și este aprobat de aceeași autoritate. Spune pacientului la ce folosește medicamentul, ce trebuie să știe înainte de a-l lua, cum se ia, ce reacții adverse pot apărea și cum se păstrează. Butonul „Prospect” din pagina medicamentului îl deschide online.
- pct.: „punctul”, adică o trimitere la altă secțiune din RCP („vezi pct. 4.4”).
- Eticheta mică albastră cu un număr (4.2, 4.4…) din fața unei fraze arată secțiunea din RCP din care a fost luată fraza.

IDENTIFICAREA MEDICAMENTULUI
- DCI: denumirea comună internațională, adică substanța activă. În nomenclator este în latină: Sertralinum, Clozapinum, Acidum valproicum.
- Denumire comercială: numele sub care se vinde produsul (Zoloft, Leponex).
- ATC: clasificarea Anatomică, Terapeutică, Chimică a OMS. Codul are 7 caractere pe 5 niveluri, de exemplu N06AB06: N = sistem nervos; N06 = psihoanaleptice; N06A = antidepresive; N06AB = inhibitori selectivi ai recaptării serotoninei; N06AB06 = sertralină. Primele 5 caractere (N06AB) sunt „subgrupa ATC” folosită la alternativele din Interacțiuni.
- Subgrupele folosite la filtrul „Clase psihotrope”: N05A antipsihotice; N05B anxiolitice; N05C hipnotice și sedative; N06A antidepresive; N06B psihostimulante și medicamente pentru ADHD; N06D medicamente antidemențiale; N03A antiepileptice (aici intră și stabilizatorii de dispoziție); N07B medicamente pentru adicții.
- CIM: codul de identificare a medicamentului, unic pentru fiecare ambalaj (de exemplu W68786001). Leagă nomenclatorul de lista CNAS.
- APP: autorizația de punere pe piață. „Deținător APP” este firma care deține autorizația; „Producător” este fabrica.
- Acțiune terapeutică: grupa farmacologică, așa cum o scrie nomenclatorul.

CODURILE DE PRESCRIPȚIE (eticheta colorată din dreapta unui medicament)
- OTC: se eliberează fără prescripție medicală.
- P6L sau P-6L: prescripție care nu se reține în farmacie; este valabilă 6 luni și se poate reînnoi.
- PRF sau P-RF: prescripție care se reține în farmacie și nu se reînnoiește; pentru fiecare eliberare este nevoie de o rețetă nouă.
- PR sau S: prescripție restrictivă, pentru medicamente rezervate utilizării în anumite domenii specializate (de regulă inițiate de medicul specialist sau folosite în spital).
- PS: prescripție specială, pe formulare cu regim special, pentru stupefiante și psihotrope.
- Coduri compuse, cu bară sau virgulă (S/P-RF, PR/PS): produsul se poate elibera în oricare dintre regimurile enumerate, după ambalaj sau indicație; fiecare parte se citește separat.

COMPENSAREA CNAS
- Sublista A: compensare 90% din prețul de referință.
- Sublista B: compensare 50% din prețul de referință; pentru pensionarii cu venituri mici, numai din pensii, compensarea este mai mare, iar aplicația arată separat contribuția lor.
- Sublista C1: compensare 100%, pentru grupe de boli notate cu G și un număr. Exemple din psihiatrie și neurologie: G11 epilepsie; G12 boala Parkinson; G15 boli psihice (schizofrenie, tulburări schizotipale și delirante, tulburări afective majore, tulburări psihotice acute și boli psihice copil, autism); G16 demențe.
- Sublista C2: compensare 100%, pentru medicamentele din programele naționale de sănătate, notate cu P și un număr (de exemplu P3 oncologie, P5 diabet zaharat, P11 sănătate mintală).
- Sublista C3: compensare 100% pentru copii până la 18 ani, tineri de la 18 la 26 de ani dacă sunt elevi, studenți sau ucenici fără venituri, gravide și lăuze.
- Sublista D: compensare 20% din prețul de referință.
- Un medicament poate fi pe mai multe subliste în același timp („A și C1-G15”).
- Preț maximal: prețul cu amănuntul maxim al ambalajului. Preț de referință: suma față de care se calculează compensarea. Contribuție maximă: cât plătește cel mult pacientul pentru acel ambalaj.
- „CNAS C1” scris în lista de medicamente înseamnă că produsul sau substanța lui se află pe acea sublistă.

PROTOCOALELE TERAPEUTICE CNAS
- Protocol terapeutic: document aprobat prin ordin al Ministerului Sănătății și al CNAS, care stabilește indicația, criteriile de includere și excludere, dozele, monitorizarea și cine poate prescrie un medicament compensat.
- Codul protocolului: fie un cod intern (N016F pentru clozapină, N003F pentru olanzapină), fie codul ATC al substanței (N05AX15 pentru cariprazină). Sufixele (-A, -BPOC, -ONCO) deosebesc protocoalele aceleiași substanțe pentru indicații diferite.
- „Continuare la medicul de familie”: DA = medicul de familie poate continua tratamentul inițiat de specialist, pe baza scrisorii medicale; NU = prescrie doar medicul specialist; orice alt text este condiția scrisă în lista CNAS (de exemplu „DA, pentru formele orale”).
- Semnele din denumiri: un asterisc sau două marchează în lista CNAS medicamentele care se prescriu cu aprobare sau pe baza protocolului; Ω marchează medicamentele cu contracte cost-volum.

INTERACȚIUNI
- Majoră: asociere de evitat sau care cere măsuri speciale; sumarul devine roșu.
- Moderată: asociere care poate cere ajustarea dozei sau monitorizare.
- Minoră: efect clinic limitat.
- Severitate neprecizată: DDInter înregistrează interacțiunea, dar fără nivel.
- Lipsa unei perechi din listă nu înseamnă că interacțiunea nu există.
- „fără date pentru: …” la un medicament combinat: componenta respectivă nu se găsește în DDInter și nu poate fi verificată.

RĂSPUNSURILE RAPIDE DIN RCP
- CYP (CYP3A4, CYP2D6, CYP2C19, CYP1A2…): izoenzimele citocromului P450, prin care ficatul metabolizează multe medicamente. Un inhibitor al unei izoenzime crește concentrația medicamentelor metabolizate de ea; un inductor o scade.
- QT, QTc: intervalul QT de pe electrocardiogramă și valoarea lui corectată după frecvența cardiacă. Prelungirea lui crește riscul de torsada vârfurilor, o aritmie ventriculară gravă.
- ECG: electrocardiogramă.
- Efecte anticolinergice: gură uscată, constipație, retenție urinară, vedere încețoșată, tahicardie, confuzie; mai frecvente și mai grave la vârstnici.
- Clearance: capacitatea de eliminare; la rinichi se exprimă prin clearance-ul creatininei, în ml/min.
- Child-Pugh: clasificarea severității cirozei hepatice (clasele A, B, C).

FORMELE FARMACEUTICE (prescurtările din nomenclator)
- compr. = comprimat; compr. film. = comprimat filmat; draj. = drajeu; caps. = capsulă; minicompr. = minicomprimat
- elib. prel. = cu eliberare prelungită; elib. modif. = cu eliberare modificată; gastrorez. = gastrorezistent
- mast. = masticabil; eff. = efervescent; disp. = dispersabil sau orodispersabil; subling. = sublingual
- sol. = soluție; susp. = suspensie; pic. = picături; gran. = granule; pulb. = pulbere; liof. = liofilizat; conc. = concentrat; solv. = solvent
- inj. = injectabil; perf. = perfuzabil; pt. = pentru (de exemplu „pulb. pt. sol. inj.” = pulbere pentru soluție injectabilă; „conc. pt. sol. perf.” = concentrat pentru soluție perfuzabilă)
- oft. = oftalmic; naz. = nazal; auric. = auricular; cut. = cutanat; vag. = vaginal; inhal. = de inhalat
- supoz. = supozitor; ung. = unguent; parent. = parenteral
- La ambalaje: blist. = blister; flac. = flacon; PVC, PVDC, PE, Al = materialele blisterului (policlorură de vinil, policlorură de viniliden, polietilenă, aluminiu); „x 28” = numărul de unități din cutie.

ICD-10
- ICD-10 sau CIM-10: Clasificarea Internațională a Maladiilor, revizia a 10-a. Aplicația folosește varianta CIM-10-AM din sistemul RoDRG.
- Capitol: grupă mare de boli, notată cu cifre romane (capitolul V = tulburări mentale și de comportament, codurile F00–F99).
- Categorie: cod de trei caractere (F32 = episod depresiv). Subcod: cod cu punct, mai precis (F32.1 = episod depresiv moderat).

SCALE ȘI CALCULATOARE
- PHQ-9: Patient Health Questionnaire, 9 întrebări despre depresie în ultimele 2 săptămâni; scor 0–27.
- GAD-7: Generalized Anxiety Disorder, 7 întrebări despre anxietate în ultimele 2 săptămâni; scor 0–21.
- AUDIT: Alcohol Use Disorders Identification Test, chestionarul OMS pentru consumul problematic de alcool; scor 0–40.
- CIWA-Ar: Clinical Institute Withdrawal Assessment for Alcohol, revised; evaluează severitatea sevrajului la alcool. Scor până la 8 = sevraj ușor; 9–19 = moderat; 20 sau peste = sever.
- CGI: Clinical Global Impression; CGI-S măsoară severitatea bolii, CGI-I ameliorarea față de început.
- Criteriile Hunter: criterii clinice pentru diagnosticul sindromului serotoninergic.
- AIMS: Abnormal Involuntary Movement Scale, pentru diskinezia tardivă.
- BPRS: Brief Psychiatric Rating Scale, 18 itemi de psihopatologie generală.
- Echivalențe benzodiazepine: doza echivalentă cu 10 mg diazepam, după tabelul Ashton. Echivalențe antipsihotice: doza orală echivalentă cu 100 mg clorpromazină, după Woods 2003. Sunt orientative.
- eGFR: rata estimată a filtrării glomerulare, în ml/min/1,73 m², calculată cu formula CKD-EPI 2021. Stadiile G1–G5 arată gradul bolii cronice de rinichi.
- Cockcroft-Gault: formula clasică pentru clearance-ul creatininei, folosită în RCP-uri la ajustarea dozelor.
- IMC: indicele de masă corporală, kg/m².
- CHA2DS2-VASc: riscul de accident vascular cerebral în fibrilația atrială. HAS-BLED: riscul de sângerare sub anticoagulant.
- QT corectat (Bazett): QT împărțit la rădăcina pătrată a intervalului RR.
- TAM: tensiunea arterială medie. CURB-65: severitatea pneumoniei comunitare. GCS: scala Glasgow a stării de conștiență, 3–15.

INSTRUMENTE DE PRESCRIERE
- Titrare: creșterea treptată a dozei până la doza țintă. Reducere treptată: scăderea dozei în pași, pentru a evita sevrajul sau recăderea.
- Fracțiune minimă: cea mai mică parte de comprimat care se poate administra (un sfert, o jumătate); planul rotunjește dozele la multipli ai ei.
- Depot sau LAI (long-acting injectable): antipsihotic injectabil cu eliberare prelungită, administrat la 2 săptămâni până la 6 luni.
- Fereastră de administrare: intervalul din jurul datei programate în care RCP-ul permite injecția (de exemplu ± 7 zile la paliperidona lunară).

CONT ȘI BLOCARE
- Cont: adresa de e-mail și parola cu care se deschide aplicația. Conturile nu se pot crea din aplicație; le creează administratorul în Firebase. Același cont merge pe orice telefon.
- Deblocare biometrică: după prima autentificare, aplicația cere la fiecare deschidere, și când revii după mai mult de un minut, amprenta sau Face ID; dacă telefonul nu le are, cere codul telefonului. Funcționează și fără internet. Datele biometrice rămân în telefon, aplicația primește doar răspunsul da sau nu.
- Folosește parola: alternativa la biometrie, cu parola contului; are nevoie de internet.
- Am uitat parola: trimite pe adresa contului un e-mail cu o legătură de resetare.
- Ieși din cont: șterge sesiunea de pe telefon; la următoarea deschidere se cer din nou e-mailul și parola. Se găsește în fereastra deschisă prin atingerea rândului de sub titlul MedRO și pe ecranul de blocare.
- Asistentul răspunde doar unui utilizator autentificat; registrul, interacțiunile, calculatoarele și ICD-10 merg fără internet după deblocare.

ASISTENT ȘI COSTURI
- Model: varianta de inteligență artificială care răspunde. Sonnet 5.5 este modelul obișnuit; Opus 5.5 este mai capabil și de două ori mai scump la intrare și la răspuns.
- Token: unitatea în care se măsoară textul, de 3–4 caractere. Se plătesc separat tokenii trimiși și cei primiți.
- Tokeni trimiși: întrebarea, instrucțiunile aplicației, datele despre medicamente și documentul RCP. Tokeni primiți: răspunsul.
- Document nou: RCP-ul trimis prima dată într-o conversație, plătit întreg. Document refolosit: același RCP la întrebările următoare, puse în câteva minute, plătit la o zecime.
- Extras: secțiunile 4.1–4.9 ale RCP-ului, trimise asistentului ca text în locul PDF-ului întreg, ca întrebarea să coste mai puțin. Nu cuprinde secțiunile 5 și 6 (farmacocinetică, excipienți); pentru ele se deschide RCP-ul din pagina medicamentului.
- Dictare: microfonul din câmpul de întrebare al asistentului transformă vorbirea în text, în română. Recunoașterea o face telefonul, prin serviciul Apple sau Google, care poate trimite sunetul pe serverele lor; de aceea nu se dictează date care pot identifica un pacient. Prima folosire cere permisiunea pentru microfon și pentru recunoașterea vocală.
- Ascultă: butonul de sub un răspuns al asistentului îl citește cu voce tare, cu vocea românească a telefonului; se citește doar la cerere, niciodată automat.
- USD: dolari americani; Anthropic facturează în dolari.
- Cheie API proprie: opțiune pentru cine vrea să plătească din alt cont Anthropic; în mod obișnuit nu este necesară, asistentul merge prin serverul aplicației.
''';
