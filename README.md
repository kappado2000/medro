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
