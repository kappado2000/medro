"""Genereaza editia saptamanala a Sintezei: noutati din psihiatrie si
psihoterapie (sectiunea principala), din restul cercetarii medicale, din
stiinte si din arta, culese de pe web si rezumate in romana de Claude.

Calea obisnuita, fara cost de API: o rutina programata din abonamentul Claude
scrie sambata ciorna editiei in sinteza/ciorne/ (instructiunile ei sunt in
tool/sinteza_rutina.md), iar fluxul .github/workflows/sinteza.yml ruleaza acest
script cu --din-fisier.

Pasii:
  1. cercetare  - Claude cauta pe web noutatile ultimelor 7 zile si scrie articolele
  2. structurare - textul este transcris intr-un JSON cu forma fixa
  3. verificare - fiecare sursa este deschisa; linkurile moarte se elimina, iar
                  imaginea articolului (og:image) se ia din pagina sursei
  4. publicare  - editia ajunge in hosting/sinteza/date/, de unde o citesc
                  aplicatia (lib/services/sinteza_store.dart) si pagina web
                  (hosting/sinteza/index.html)
Pasii 1 si 2 ruleaza aici doar fara --din-fisier, prin API (cu cost pe tokeni).

Rulare:
  python tool/build_sinteza.py --din-fisier c.json   pasii 3 si 4, pe o ciorna
  python tool/build_sinteza.py --din-fisier c.json --verifica-forma
                                                  doar forma ciornei, fara retea
  python tool/build_sinteza.py                    toti pasii (cere ANTHROPIC_API_KEY)
  python tool/build_sinteza.py --forteaza         reface editia saptamanii curente
  python tool/build_sinteza.py --data 2026-10-10  alta data decat cea de azi
"""
import argparse
import datetime as dt
import html
import json
import os
import re
import socket
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TINTA = ROOT / "hosting" / "sinteza" / "date"

MODEL = os.environ.get("SINTEZA_MODEL", "claude-opus-5-5")
# ordinea de afisare; psihiatria deschide editia
SECTIUNI = ("psihiatrie", "medicina", "stiinta", "arta")

# sub aceste praguri editia nu se publica si ramane cea de saptamana trecuta
MINIM_PE_SECTIUNE = {"psihiatrie": 3, "medicina": 2, "stiinta": 2, "arta": 2}
MINIM_TOTAL = 9

# pret orientativ, USD pe milion de tokeni (intrare, iesire), pentru raportul de cost
PRETURI = {
    "claude-opus-5-5": (4.0, 20.0),
    "claude-sonnet-5-5": (2.0, 10.0),
    "claude-haiku-4-5": (1.0, 5.0),
}
PRET_CAUTARE = 0.01  # USD pe cautare web

LUNI = [
    "ianuarie", "februarie", "martie", "aprilie", "mai", "iunie", "iulie",
    "august", "septembrie", "octombrie", "noiembrie", "decembrie",
]

SISTEM = """Ești redactorul unei sinteze săptămânale de știri despre psihiatrie și psihoterapie, cercetare medicală, științe și artă, scrisă în limba română. Cititorul principal este un medic psihiatru, care vrea să fie la curent cu cercetarea, inovațiile și noutățile din domeniul lui; ediția este citită și de familia și prietenii lui, oameni curioși și educați, dar nu specialiști.

Sarcina ta: caută pe web ce s-a întâmplat cu adevărat important sau surprinzător în intervalul de date primit și alege cele mai bune subiecte. Secțiunea de psihiatrie este cea principală: deschide ediția și primește cele mai multe articole, cinci (cel puțin patru, cel mult șase). Celelalte trei secțiuni au câte trei articole (cel puțin două, cel mult patru).
- psihiatrie: psihiatrie și psihoterapie. Cercetare: studii clinice cu medicamente, psihoterapii, neuromodulare (rTMS, ECT, stimulare cerebrală profundă) și intervenții digitale; meta-analize; studii despre mecanisme, genetică și epidemiologie. Inovare: molecule și clase noi, terapii asistate de psihedelice, instrumente de diagnostic și de monitorizare. Informații și noutăți: aprobări și avertizări ale EMA, FDA sau ANMDM, ghiduri noi sau revizuite, rezultate prezentate la congrese, schimbări de clasificare. Acoperă pe cât se poate atât partea biologică, cât și psihoterapia, și caută mai întâi în revistele domeniului (JAMA Psychiatry, The Lancet Psychiatry, American Journal of Psychiatry, World Psychiatry, Molecular Psychiatry, Psychotherapy and Psychosomatics, British Journal of Psychiatry) și în publicațiile profesionale (Psychiatric Times, Medscape Psychiatry). Aici poți scrie la nivelul unui medic: denumiri comune internaționale, doze, scale, mărimi de efect, intervale de încredere, design-ul studiului și limitele lui;
- medicina: restul cercetării medicale: studii clinice, terapii noi, descoperiri despre boli, sănătate publică, neuroștiințe;
- stiinta: fizică, astronomie, chimie, biologie, paleontologie, arheologie, mediu, matematică, tehnologie cu miză științifică;
- arta: arte vizuale, muzee și expoziții, patrimoniu, literatură, muzică, arhitectură, film, redescoperiri și restaurări.

Ce face un subiect bun: aduce ceva nou (un rezultat, o descoperire, o premieră, o decizie), are o sursă serioasă și poate fi explicat cuiva din afara domeniului. Caută varietate de țări și de discipline, nu doar știri din Statele Unite și nu de trei ori aceeași temă. Evită comunicatele comerciale, produsele, zvonurile și subiectele deja tratate în edițiile anterioare, pe care le primești în mesaj.

Exactitatea contează mai mult decât orice. Scrie numai ce ai găsit în paginile citite: nume, cifre, date, instituții. Dacă un detaliu nu apare în surse, lasă-l deoparte, nu îl completa din memorie. Deschide articolul-sursă înainte să scrii despre el ori de câte ori rezultatul căutării nu îți dă destule detalii. Preferă sursa primară sau o publicație de referință (revista științifică, instituția, muzeul, o redacție cunoscută) și dă adresa exactă a paginii pe care ai văzut-o în rezultate, nu una reconstituită. Subiectul trebuie să fie din intervalul cerut; un articol de sinteză publicat acum despre ceva vechi nu este o noutate.

La psihiatrie și la medicină, spune limpede în ce stadiu este rezultatul: pe celule, pe animale, studiu de fază 1, 2 sau 3, câți pacienți. Nu da sfaturi de tratament și nu prezenta un rezultat timpuriu drept un leac.

Cum scrii: în română firească, cu diacritice, la persoana a treia, fără entuziasm de reclamă și fără formule de umplutură. Explică termenii de specialitate la prima apariție. Titlul spune faptul, nu îl ascunde. Numele proprii rămân în forma originală.

Pentru fiecare subiect scrie, cu aceste etichete, pe rânduri separate:
SECTIUNE: psihiatrie, medicina, stiinta sau arta
TITLU: cel mult 90 de caractere
REZUMAT: una sau două fraze care spun esențialul
TEXT: trei până la cinci paragrafe, 180-320 de cuvinte în total
DE CE CONTEAZA: una sau două fraze despre miză sau despre ce urmează
LOC: orașul sau țara unde s-a petrecut, ori instituția
SURSA: numele publicației | adresa completă a paginii | data publicării (AAAA-LL-ZZ)
ALTE SURSE: zero până la două rânduri în forma „nume | adresă”, cu alte redacții care au scris despre același fapt
TRIMITERI: două până la patru rânduri în forma „ce găsește cititorul acolo | adresă”, pentru cine vrea să afle mai mult: studiul original, pagina instituției sau a expoziției, un articol de enciclopedie care explică noțiunea centrală, un material mai amplu de context. Numai pagini pe care le-ai văzut în rezultate.

Începe răspunsul cu:
TITLUL EDITIEI: un titlu scurt care leagă două-trei dintre subiectele săptămânii, începând cu psihiatria
INTRODUCERE: două sau trei fraze care prezintă ediția
"""

SISTEM_STRUCTURARE = """Primești textul unei ediții de știri scrise în română, cu etichete (TITLUL EDITIEI, INTRODUCERE, apoi pentru fiecare articol SECTIUNE, TITLU, REZUMAT, TEXT, DE CE CONTEAZA, LOC, SURSA, ALTE SURSE, TRIMITERI). Transcrie-l în structura JSON cerută, fără să schimbi, să scurtezi sau să completezi nimic: aceleași cuvinte, aceleași adrese. În câmpul text, paragrafele rămân despărțite printr-un rând gol. Dacă un articol nu are o sursă cu adresă, lasă-l deoparte. Data sursei se scrie AAAA-LL-ZZ sau șir gol dacă lipsește."""

_SURSA = {
    "type": "object",
    "properties": {"nume": {"type": "string"}, "url": {"type": "string"}},
    "required": ["nume", "url"],
    "additionalProperties": False,
}
SCHEMA = {
    "type": "object",
    "properties": {
        "titlu": {"type": "string"},
        "introducere": {"type": "string"},
        "articole": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "sectiune": {"type": "string", "enum": list(SECTIUNI)},
                    "titlu": {"type": "string"},
                    "rezumat": {"type": "string"},
                    "text": {"type": "string"},
                    "de_ce_conteaza": {"type": "string"},
                    "loc": {"type": "string"},
                    "sursa_nume": {"type": "string"},
                    "sursa_url": {"type": "string"},
                    "sursa_data": {"type": "string"},
                    "alte_surse": {"type": "array", "items": _SURSA},
                    "trimiteri": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "titlu": {"type": "string"},
                                "url": {"type": "string"},
                            },
                            "required": ["titlu", "url"],
                            "additionalProperties": False,
                        },
                    },
                },
                "required": [
                    "sectiune", "titlu", "rezumat", "text", "de_ce_conteaza",
                    "loc", "sursa_nume", "sursa_url", "sursa_data", "alte_surse",
                    "trimiteri",
                ],
                "additionalProperties": False,
            },
        },
    },
    "required": ["titlu", "introducere", "articole"],
    "additionalProperties": False,
}


# ----------------------------------------------------------------- forma ciornei

_CAMPURI_TEXT = (
    "titlu", "rezumat", "text", "de_ce_conteaza", "loc", "sursa_nume", "sursa_url",
)


def probleme_forma(ciorna) -> list[str]:
    """Ce lipseste sau este gresit intr-o ciorna; lista goala daca e in regula.
    Nu foloseste reteaua."""
    if not isinstance(ciorna, dict):
        return ["ciorna trebuie sa fie un obiect JSON"]
    probleme = []
    for camp in ("titlu", "introducere"):
        if not isinstance(ciorna.get(camp), str) or not ciorna[camp].strip():
            probleme.append(f"lipseste {camp}")
    if "data" in ciorna:
        try:
            dt.date.fromisoformat(ciorna["data"])
        except (TypeError, ValueError):
            probleme.append("data nu este de forma AAAA-LL-ZZ")
    articole = ciorna.get("articole")
    if not isinstance(articole, list):
        return probleme + ["lipseste lista articole"]
    for i, a in enumerate(articole, 1):
        unde = f"articolul {i}"
        if not isinstance(a, dict):
            probleme.append(f"{unde}: nu este un obiect")
            continue
        if a.get("sectiune") not in SECTIUNI:
            probleme.append(f"{unde}: sectiune necunoscuta ({a.get('sectiune')!r})")
        for camp in _CAMPURI_TEXT:
            if not isinstance(a.get(camp), str) or not a[camp].strip():
                probleme.append(f"{unde}: lipseste {camp}")
        if not str(a.get("sursa_url", "")).startswith("https://"):
            probleme.append(f"{unde}: sursa_url trebuie sa inceapa cu https://")
        if not isinstance(a.get("sursa_data"), str):
            probleme.append(f"{unde}: sursa_data trebuie sa fie text (poate fi gol)")
        for lista, cheie in (("alte_surse", "nume"), ("trimiteri", "titlu")):
            randuri = a.get(lista)
            if not isinstance(randuri, list) or any(
                not isinstance(r, dict)
                or not isinstance(r.get(cheie), str)
                or not isinstance(r.get("url"), str)
                for r in randuri
            ):
                probleme.append(
                    f"{unde}: {lista} trebuie sa fie o lista de {{{cheie}, url}}"
                )
    for sectiune, minim in MINIM_PE_SECTIUNE.items():
        n = sum(isinstance(a, dict) and a.get("sectiune") == sectiune for a in articole)
        if n < minim:
            probleme.append(f"{sectiune}: {n} articole, minimum {minim}")
    return probleme


# ---------------------------------------------------------------- date si editii

def id_editie(zi: dt.date) -> str:
    an, saptamana, _ = zi.isocalendar()
    return f"{an}-W{saptamana:02d}"


def interval_text(de_la: dt.date, pana_la: dt.date) -> str:
    if de_la.month == pana_la.month:
        return f"{de_la.day}–{pana_la.day} {LUNI[pana_la.month - 1]} {pana_la.year}"
    return (
        f"{de_la.day} {LUNI[de_la.month - 1]} – "
        f"{pana_la.day} {LUNI[pana_la.month - 1]} {pana_la.year}"
    )


def citeste_index() -> dict:
    f = TINTA / "index.json"
    if f.exists():
        return json.loads(f.read_text(encoding="utf-8"))
    return {"editii": []}


def subiecte_anterioare(cate_editii: int = 6) -> list[str]:
    """Titlurile si sursele din ultimele editii, ca sa nu se repete."""
    randuri = []
    for e in citeste_index()["editii"][:cate_editii]:
        f = TINTA / f"{e['id']}.json"
        if not f.exists():
            continue
        for a in json.loads(f.read_text(encoding="utf-8"))["articole"]:
            randuri.append(f"- {a['titlu']} ({a['sursa']['url']})")
    return randuri


# ------------------------------------------------------------------ apelul Claude

class Consum:
    """Tokenii si cautarile adunate din toate apelurile, pentru raportul de cost."""

    def __init__(self) -> None:
        self.intrare = 0
        self.scrise_cache = 0
        self.citite_cache = 0
        self.iesire = 0
        self.cautari = 0

    def aduna(self, usage) -> None:
        self.intrare += usage.input_tokens or 0
        self.scrise_cache += getattr(usage, "cache_creation_input_tokens", 0) or 0
        self.citite_cache += getattr(usage, "cache_read_input_tokens", 0) or 0
        self.iesire += usage.output_tokens or 0
        unelte = getattr(usage, "server_tool_use", None)
        if unelte is not None:
            self.cautari += getattr(unelte, "web_search_requests", 0) or 0

    def cost(self) -> float:
        intrare, iesire = PRETURI.get(MODEL, PRETURI["claude-opus-5-5"])
        # scrierea in cache costa 1,25x, iar citirea din cache 0,1x pretul de intrare
        return (
            (self.intrare + 1.25 * self.scrise_cache + 0.1 * self.citite_cache)
            / 1e6 * intrare
            + self.iesire / 1e6 * iesire
            + self.cautari * PRET_CAUTARE
        )

    def raport(self) -> str:
        return (
            f"Model {MODEL}: {self.intrare:,} tokeni intrare (+{self.scrise_cache:,} "
            f"scrisi in cache, {self.citite_cache:,} cititi din cache), {self.iesire:,} "
            f"tokeni iesire, {self.cautari} cautari web, cost estimat {self.cost():.2f} USD"
        )


def _mesaj(client, consum: Consum, **cerere):
    """Un apel in flux, cu trecerea automata pe alt model daca cererea este
    refuzata de filtrele de siguranta (fallbacks). Daca serverul nu accepta
    optiunea in combinatia data, apelul se reia fara ea."""
    import anthropic

    variante = [
        {
            "extra_headers": {"anthropic-beta": "server-side-fallback-2026-07-01"},
            "extra_body": {"fallbacks": "default"},
        },
        {},
    ]
    for i, in_plus in enumerate(variante):
        try:
            with client.messages.stream(**cerere, **in_plus) as flux:
                raspuns = flux.get_final_message()
            consum.aduna(raspuns.usage)
            return raspuns
        except anthropic.BadRequestError as e:
            if i == len(variante) - 1 or "fallback" not in str(e).lower():
                raise
            print("  optiunea fallbacks a fost respinsa; reiau fara ea")
    raise AssertionError("neatins")


def _text(raspuns) -> str:
    return "\n".join(b.text for b in raspuns.content if b.type == "text").strip()


def _adrese_vazute(raspuns) -> set[str]:
    """Adresele aparute in rezultatele cautarilor si ale paginilor citite."""
    adrese = set()
    for b in raspuns.content:
        if b.type.endswith("_tool_result"):
            brut = json.dumps(b.to_dict(), ensure_ascii=False)
            adrese.update(
                normalizeaza(u) for u in re.findall(r'https?://[^\s"\\<>]+', brut)
            )
    return adrese


def cerceteaza(client, consum: Consum, de_la: dt.date, pana_la: dt.date):
    """Pasul 1: cautarea pe web si scrierea articolelor. Intoarce textul editiei
    si adresele pe care modelul le-a vazut cu adevarat."""
    anterioare = subiecte_anterioare()
    cerere_text = (
        f"Astăzi este {pana_la.isoformat()}. Pregătește ediția pentru intervalul "
        f"{de_la.isoformat()} – {pana_la.isoformat()} ({interval_text(de_la, pana_la)})."
    )
    if anterioare:
        cerere_text += (
            "\n\nSubiecte deja tratate în edițiile anterioare (nu le relua, decât "
            "dacă a apărut ceva cu adevărat nou):\n" + "\n".join(anterioare)
        )
    mesaje = [{"role": "user", "content": cerere_text}]
    adrese: set[str] = set()
    for _ in range(8):
        raspuns = _mesaj(
            client,
            consum,
            model=MODEL,
            max_tokens=64000,
            system=SISTEM,
            # la reluarea unei ture intrerupte, ce s-a citit deja se plateste la 0,1x
            cache_control={"type": "ephemeral"},
            thinking={"type": "adaptive"},
            output_config={"effort": "high"},
            tools=[
                {"type": "web_search_20260209", "name": "web_search", "max_uses": 40},
                {
                    "type": "web_fetch_20260209",
                    "name": "web_fetch",
                    "max_uses": 16,
                    "max_content_tokens": 8000,
                },
            ],
            messages=mesaje,
        )
        adrese |= _adrese_vazute(raspuns)
        if raspuns.stop_reason == "pause_turn":
            # serverul a intrerupt o tura lunga; se reia de unde a ramas
            mesaje.append({"role": "assistant", "content": raspuns.content})
            continue
        if raspuns.stop_reason == "refusal":
            raise RuntimeError(f"Cererea a fost refuzata: {raspuns.stop_details}")
        if raspuns.stop_reason == "max_tokens":
            raise RuntimeError("Raspunsul a fost taiat la limita de tokeni.")
        return _text(raspuns), adrese
    raise RuntimeError("Cercetarea nu s-a incheiat dupa 8 reluari.")


def structureaza(client, consum: Consum, text: str) -> dict:
    """Pasul 2: transcrierea textului in JSON cu forma fixa."""
    raspuns = _mesaj(
        client,
        consum,
        model=MODEL,
        max_tokens=32000,
        system=SISTEM_STRUCTURARE,
        output_config={
            "effort": "low",
            "format": {"type": "json_schema", "schema": SCHEMA},
        },
        messages=[{"role": "user", "content": text}],
    )
    if raspuns.stop_reason != "end_turn":
        raise RuntimeError(f"Structurarea s-a oprit cu {raspuns.stop_reason}.")
    return json.loads(_text(raspuns))


# ------------------------------------------------------- verificarea surselor

ANTET = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/126.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,image/*;q=0.9,*/*;q=0.8",
    "Accept-Language": "en,ro;q=0.8",
}

_META = re.compile(r"<meta\b[^>]*>", re.I)
_ATRIBUT = re.compile(r"""([\w:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')""")
_CHEI_IMAGINE = ("og:image:secure_url", "og:image", "twitter:image", "twitter:image:src")


def normalizeaza(url: str) -> str:
    p = urllib.parse.urlsplit(url.strip())
    return f"{p.netloc.lower().removeprefix('www.')}{p.path.rstrip('/')}"


# starile intoarse de deschide() pe langa codurile HTTP
INEXISTENT = -1  # domeniul nu exista
NEVERIFICAT = 0  # serverul nu a raspuns (blocaj, expirare); nu spune nimic despre pagina
MOARTE = (INEXISTENT, 404, 410)


def _context_ssl() -> ssl.SSLContext:
    # certificatele din certifi (vine odata cu anthropic) sunt mai la zi decat
    # cele ale sistemului pe unele masini cu Windows
    try:
        import certifi

        return ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        return ssl.create_default_context()


_SSL = _context_ssl()


def deschide(url: str, octeti: int = 400_000):
    """(stare, continut, tip). Starea este codul HTTP, INEXISTENT sau NEVERIFICAT."""
    # adresele cu diacritice (Wikipedia in romana) trebuie codate
    url = urllib.parse.quote(url, safe=":/?#[]@!$&'()*+,;=%~")
    try:
        cerere = urllib.request.Request(url, headers=ANTET)
        with urllib.request.urlopen(cerere, timeout=25, context=_SSL) as r:
            return r.status, r.read(octeti), r.headers.get("Content-Type", "")
    except urllib.error.HTTPError as e:
        return e.code, b"", ""
    except urllib.error.URLError as e:
        if isinstance(e.reason, socket.gaierror):
            return INEXISTENT, b"", ""
        return NEVERIFICAT, b"", ""
    except Exception:
        return NEVERIFICAT, b"", ""


def imagine_din_pagina(continut: bytes, url_pagina: str) -> str:
    text = continut.decode("utf-8", errors="replace")
    gasite = {}
    for meta in _META.findall(text):
        atribute = {
            m.group(1).lower(): (m.group(2) or m.group(3) or "")
            for m in _ATRIBUT.finditer(meta)
        }
        cheie = (atribute.get("property") or atribute.get("name") or "").lower()
        if cheie in _CHEI_IMAGINE and atribute.get("content"):
            gasite.setdefault(cheie, atribute["content"])
    for cheie in _CHEI_IMAGINE:
        if cheie in gasite:
            adresa = urllib.parse.urljoin(url_pagina, html.unescape(gasite[cheie]))
            if adresa.startswith("https://"):
                return adresa
    return ""


# peste aceasta marime o imagine nu se foloseste: ar consuma datele cititorului
MAX_IMAGINE = 3_000_000


def micsoreaza(url: str) -> str:
    """Unele redactii pun in pagina originalul de mii de pixeli; serverele de
    imagini cunoscute primesc latimea dorita in adresa."""
    p = urllib.parse.urlsplit(url)
    if p.netloc == "cdn.sanity.io" and not p.query:
        return url + "?w=1200&fit=max&auto=format"
    return url


def imagine_valida(url: str) -> bool:
    url = urllib.parse.quote(url, safe=":/?#[]@!$&'()*+,;=%~")
    try:
        cerere = urllib.request.Request(url, headers=ANTET)
        with urllib.request.urlopen(cerere, timeout=25, context=_SSL) as r:
            tip = r.headers.get("Content-Type", "").lower()
            marime = int(r.headers.get("Content-Length") or 0)
            return r.status == 200 and tip.startswith("image/") and marime <= MAX_IMAGINE
    except Exception:
        return False


def verifica_articol(
    a: dict, vazute: set[str], revizuit: bool
) -> tuple[dict | None, str]:
    """Articolul in forma finala, sau None si motivul pentru care a fost scos.

    O sursa care nu poate fi deschisa (multe redactii blocheaza cererile
    automate) este acceptata doar daca adresa a aparut in rezultatele cautarii
    sau daca ciorna a fost revizuita de un om ([revizuit])."""
    url = a["sursa_url"].strip()
    if not url.startswith("https://") and not url.startswith("http://"):
        return None, "sursa fara adresa"
    for camp in ("titlu", "rezumat", "text"):
        if not a[camp].strip():
            return None, f"lipseste {camp}"
    stare, continut, _ = deschide(url)
    if stare in MOARTE:
        return None, f"sursa nu exista ({stare})"
    # o adresa pe care modelul nu a vazut-o in rezultate trebuie sa se deschida
    # cu adevarat; altfel poate fi una reconstituita din memorie
    if stare != 200 and not revizuit and normalizeaza(url) not in vazute:
        return None, f"sursa nu a aparut in cautari si nu poate fi verificata ({stare})"

    alte = [
        {"nume": s["nume"].strip(), "url": s["url"].strip()}
        for s in a.get("alte_surse", [])
        if s["url"].strip().startswith("http") and s["url"].strip() != url
    ][:2]

    # trimiterile pentru aprofundare: raman doar cele care nu sunt linkuri moarte
    trimiteri = []
    for t in a.get("trimiteri", []):
        adresa = t["url"].strip()
        if not adresa.startswith("https://") or adresa == url or not t["titlu"].strip():
            continue
        if deschide(adresa, octeti=1024)[0] in MOARTE:
            continue
        trimiteri.append({"titlu": t["titlu"].strip(), "url": adresa})
    trimiteri = trimiteri[:4]

    imagine = None
    pagini = [(a["sursa_nume"].strip(), url, continut if stare == 200 else None)]
    pagini += [(s["nume"], s["url"], None) for s in alte]
    for nume, adresa, pagina in pagini:
        if pagina is None:
            st, pagina, _ = deschide(adresa)
            if st != 200:
                continue
        poza = micsoreaza(imagine_din_pagina(pagina, adresa))
        if poza and imagine_valida(poza):
            imagine = {"url": poza, "credit": nume}
            break

    return {
        "sectiune": a["sectiune"],
        "titlu": a["titlu"].strip(),
        "rezumat": a["rezumat"].strip(),
        "text": a["text"].strip(),
        "de_ce_conteaza": a["de_ce_conteaza"].strip(),
        "loc": a["loc"].strip(),
        "sursa": {
            "nume": a["sursa_nume"].strip(),
            "url": url,
            "data": a["sursa_data"].strip(),
        },
        "alte_surse": alte,
        "trimiteri": trimiteri,
        "imagine": imagine,
    }, ""


def finalizeaza(
    ciorna: dict, zi: dt.date, vazute: set[str], revizuit: bool = False
) -> dict:
    """Pasul 3: verifica sursele, ataseaza imaginile si construieste editia."""
    de_la = zi - dt.timedelta(days=7)
    articole = []
    for a in ciorna["articole"]:
        if a["sectiune"] not in SECTIUNI:
            print(f"  scos: {a['titlu'][:60]} (sectiune necunoscuta)")
            continue
        articol, motiv = verifica_articol(a, vazute, revizuit)
        if articol is None:
            print(f"  scos: {a['titlu'][:60]} ({motiv})")
            continue
        print(
            f"  ok [{articol['sectiune']}] {articol['titlu'][:60]}"
            f"{'' if articol['imagine'] else ' (fara imagine)'}"
        )
        articole.append(articol)

    # sectiunile raman grupate, in ordinea fixa
    articole.sort(key=lambda a: SECTIUNI.index(a["sectiune"]))
    for i, a in enumerate(articole, 1):
        a["id"] = f"a{i}"

    pe_sectiune = {s: sum(a["sectiune"] == s for a in articole) for s in SECTIUNI}
    probleme = [
        f"{s}: doar {n} articole" for s, n in pe_sectiune.items()
        if n < MINIM_PE_SECTIUNE[s]
    ]
    if len(articole) < MINIM_TOTAL:
        probleme.append(f"doar {len(articole)} articole in total")
    if probleme:
        raise RuntimeError("Editia NU se publica: " + "; ".join(probleme))

    return {
        "id": id_editie(zi),
        "data": zi.isoformat(),
        "de_la": de_la.isoformat(),
        "pana_la": zi.isoformat(),
        "interval": interval_text(de_la, zi),
        "titlu": ciorna["titlu"].strip(),
        "introducere": ciorna["introducere"].strip(),
        "articole": articole,
    }


def publica(editie: dict) -> None:
    """Pasul 4: scrie editia si o trece prima in index."""
    TINTA.mkdir(parents=True, exist_ok=True)
    (TINTA / f"{editie['id']}.json").write_text(
        json.dumps(editie, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    index = citeste_index()
    prima_imagine = next(
        (a["imagine"]["url"] for a in editie["articole"] if a["imagine"]), ""
    )
    rand = {
        "id": editie["id"],
        "data": editie["data"],
        "interval": editie["interval"],
        "titlu": editie["titlu"],
        "articole": len(editie["articole"]),
        "imagine": prima_imagine,
    }
    editii = [e for e in index["editii"] if e["id"] != editie["id"]] + [rand]
    editii.sort(key=lambda e: e["data"], reverse=True)
    (TINTA / "index.json").write_text(
        json.dumps(
            {"actualizat": editie["data"], "editii": editii},
            ensure_ascii=False,
            indent=1,
        ),
        encoding="utf-8",
    )


def main() -> None:
    # consola Windows nu stie diacritice in codarea ei implicita
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--din-fisier", help="ciorna JSON deja scrisa; sare peste Claude")
    p.add_argument(
        "--verifica-forma",
        action="store_true",
        help="cu --din-fisier: verifica doar forma ciornei, fara retea si fara publicare",
    )
    p.add_argument("--forteaza", action="store_true", help="reface editia existenta")
    p.add_argument("--data", help="data editiei, AAAA-LL-ZZ (implicit: azi)")
    arg = p.parse_args()

    ciorna = None
    if arg.din_fisier:
        ciorna = json.loads(Path(arg.din_fisier).read_text(encoding="utf-8"))
        probleme = probleme_forma(ciorna)
        if probleme:
            print("Ciorna nu are forma ceruta:")
            for problema in probleme:
                print("  -", problema)
            sys.exit(1)
        if arg.verifica_forma:
            print(f"Forma ciornei este in regula: {len(ciorna['articole'])} articole.")
            return
    elif arg.verifica_forma:
        p.error("--verifica-forma se foloseste impreuna cu --din-fisier")

    # data editiei: din linia de comanda, din ciorna sau ziua de azi
    data = arg.data or (ciorna or {}).get("data")
    zi = dt.date.fromisoformat(data) if data else dt.date.today()
    editie_id = id_editie(zi)
    if (TINTA / f"{editie_id}.json").exists() and not arg.forteaza:
        print(f"Editia {editie_id} exista deja; foloseste --forteaza ca sa o refaci.")
        return

    vazute: set[str] = set()
    consum = None
    if ciorna is None:
        import anthropic

        client = anthropic.Anthropic()
        consum = Consum()
        print(f"Cercetare pentru editia {editie_id}…")
        text, vazute = cerceteaza(client, consum, zi - dt.timedelta(days=7), zi)
        print(f"  {len(text)} caractere, {len(vazute)} adrese vazute")
        ciorna = structureaza(client, consum, text)
        print("  " + consum.raport())

    print("Verificarea surselor:")
    try:
        editie = finalizeaza(ciorna, zi, vazute, revizuit=bool(arg.din_fisier))
    except RuntimeError as e:
        print(e)
        sys.exit(1)
    publica(editie)
    print(f"Editia {editie_id} publicata: {len(editie['articole'])} articole.")

    rezumat = os.environ.get("GITHUB_STEP_SUMMARY")
    if rezumat:
        with open(rezumat, "a", encoding="utf-8") as f:
            f.write(f"### Sinteza {editie_id}\n\n{editie['titlu']}\n\n")
            f.write(f"{len(editie['articole'])} articole. ")
            if consum:
                f.write(consum.raport())
            f.write("\n")


if __name__ == "__main__":
    main()
