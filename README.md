# MedRO

Aplicație Flutter de referință medicală pentru uz propriu, orientată spre psihiatrie:
registru de medicamente (nomenclator ANMDM), compensare CNAS, interacțiuni (DDInter 2.0),
calculatoare și scale clinice, ICD-10 și un asistent AI care răspunde pe baza RCP-ului.

## Date

Datele sunt incluse în `assets/data/` și se regenerează cu scripturile din `tool/`:

| Script | Sursă | Rezultat |
|---|---|---|
| `tool/build_medicamente.py` | Nomenclatorul ANMDM | `medicamente.json.gz` |
| `tool/resolve_ema.py` | Lista de medicamente EMA | `tool/ema_links.json` (apoi se rerulează scriptul de mai sus) |
| `tool/build_compensare.py --refresh` | Lista interactivă CNAS | `compensare.json.gz` |
| `tool/build_icd10.py` | Lista tabelară RoDRG (CIM-10-AM) | `icd10.json.gz` |
| `tool/build_interactiuni.py` | DDInter 2.0 (CC BY-NC-SA, doar necomercial) | `interactiuni.json.gz` |
| `tool/build_contraindicatii.py` | Secțiunea 4.3 din RCP-urile ANMDM și EMA | `contraindicatii.json.gz` |

Scripturile cer Python cu `openpyxl` și `pymupdf`; descărcările se păstrează în `tool/cache/`.

## Asistentul

Aplicația trimite întrebările către funcția Firebase din `functions/`, care păstrează cheia
Anthropic ca secret. Fișierul `lib/config/asistent_server.dart` (adresa și codul de acces) nu
este în git; se creează după `lib/config/asistent_server.example.dart`.

```
firebase functions:secrets:set ANTHROPIC_API_KEY
firebase functions:secrets:set MEDRO_ACCESS_TOKEN
firebase deploy --only functions:medroAsistent
```

## Rulare

```
flutter test
flutter run -d web-server --web-port 5599
```

## Surse de date și drepturi

Aplicația este un instrument de referință pentru uz propriu, nu un dispozitiv medical. Datele
sunt preluate automat și pot conține erori sau pot fi depășite; sursa oficială rămâne documentul
original (RCP, lista CNAS, clasificarea ICD-10).

Datele din `assets/data/` aparțin surselor lor și nu sunt acoperite de vreo licență a acestui
proiect:

- **Nomenclatorul medicamentelor și RCP-urile:** ANMDM (nomenclator.anm.ro) și EMA (ema.europa.eu).
- **Compensare și prețuri:** CNAS (cnas.ro).
- **Interacțiuni:** DDInter 2.0 (ddinter2.scbdd.com), Xiong G. et al., *Nucleic Acids Research*,
  licență [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/). Fișierul
  `interactiuni.json.gz` este o prelucrare a acestor date și se distribuie sub aceeași licență,
  exclusiv necomercial.
- **ICD-10:** Lista tabelară a bolilor RoDRG (CIM-10-AM în română).
- **PHQ-9 și GAD-7:** dezvoltate de R. L. Spitzer, J. B. W. Williams, K. Kroenke și colegii, cu un
  grant educațional Pfizer Inc.; reproducerea nu necesită permisiune.

Codul nu are încă o licență declarată.
