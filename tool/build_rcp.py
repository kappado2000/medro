"""Descarca RCP-urile din nomenclator si extrage sectiunile clinice (4.1-4.9).

Rezultate:
  - tool/cache/rcp/<md5>.pdf          documentele, pastrate ca extragerea sa
                                      poata fi refacuta fara o noua descarcare
  - tool/cache/sectiuni/<md5>.json    sectiunile extrase din fiecare document
  - assets/data/contraindicatii.json.gz   sectiunea 4.3, incarcata la pornire
  - assets/data/rcp/index.json.gz + <xx>.json.gz   restul sectiunilor, incarcate
                                      la cerere, cate un fisier mic

Textul este cel din RCP, nemodificat in afara curatarii spatiilor. Descarcarea
e lenta (mii de PDF-uri, servere care limiteaza ritmul); scriptul reia de unde
a ramas. Psihotropele (ATC N05, N06, N03) se proceseaza primele.

Se ruleaza dupa build_medicamente.py.
Rulare:  python tool/build_rcp.py [--limita N] [--doar-asset] [--reextrage] [--test URL]
"""
import gzip
import hashlib
import io
import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

import fitz

ROOT = Path(__file__).resolve().parent.parent
MEDICAMENTE = ROOT / "assets" / "data" / "medicamente.json.gz"
PDF = ROOT / "tool" / "cache" / "rcp"
SECTIUNI = ROOT / "tool" / "cache" / "sectiuni"
VECHI = ROOT / "tool" / "cache" / "contraindicatii.json"  # extragerea anterioara, doar 4.3
OUT_CI = ROOT / "assets" / "data" / "contraindicatii.json.gz"
OUT_RCP = ROOT / "assets" / "data" / "rcp"
UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "Chrome/126 Safari/537.36"
)
MAX_PAGINI = 70
# limita de caractere pe sectiune in aplicatie; restul ramane in RCP
LIMITA = {"4.3": 4000}
LIMITA_IMPLICITA = 6000

N = r"\s*\.\s*"  # punctul din numarul sectiunii, cu spatii optionale
T = "[tţț]"
S = "[sşș]"
A = "[aăã]"


def titlu(numar: str, text: str, pana_la_capat: bool = True) -> re.Pattern:
    """Titlu de sectiune la inceput de rand. Numarul poate lipsi din rand: in
    unele PDF-uri sta in alta coloana si ajunge pe alt rand."""
    cap, coada = numar.split(".")
    return re.compile(
        rf"(?m)^\s*(?:{cap}{N}{coada}\.?\s*)?(?:{text})" + (r"\s*$" if pana_la_capat else ""),
        re.I,
    )


# in ordinea din document; fiecare sectiune se intinde pana la urmatorul titlu gasit
TITLURI = [
    ("4.1", titlu("4.1", rf"Indica{T}ii terapeutice")),
    ("4.2", titlu("4.2", rf"Doze {S}i mod de administrare")),
    ("4.3", titlu("4.3", rf"Contraindica{T}ii")),
    ("4.4", titlu("4.4", rf"Aten{T}ion{A}ri {S}i precau{T}ii|Precau{T}ii {S}i aten{T}ion{A}ri"
                         rf"|Aten{T}ion{A}ri speciale|Precau{T}ii speciale", False)),
    ("4.5", titlu("4.5", rf"Interac{T}iuni cu alte medicamente", False)),
    ("4.6", titlu("4.6", rf"Fertilitatea?, sarcina|Sarcina {S}i al{A}ptarea|Sarcina, al{A}ptarea"
                         rf"|Fertilitate, sarcin{A}", False)),
    ("4.7", titlu("4.7", rf"Efecte asupra capacit{A}{T}ii de a conduce", False)),
    ("4.8", titlu("4.8", rf"Reac{T}ii adverse")),
    ("4.9", titlu("4.9", r"Supradozaj")),
    ("5", re.compile(rf"(?m)^\s*(?:5\.?\s*)?PROPRIET[AĂ][TŢȚ]I\s+FARMACOLOGICE|"
                     rf"^\s*(?:5{N}1\.?\s*)?Propriet{A}{T}i farmacodinamice\s*$")),
]
# restul unui titlu lung care a trecut pe randul urmator
REST_TITLU = re.compile(
    rf"^(?:speciale )?pentru utilizare$|^(?:{S}i )?alte forme de interac{T}iune$"
    rf"|^{S}i al{A}ptarea$|^vehicule {S}i de a folosi utilaje$|^de a folosi utilaje$",
    re.I,
)
PASTRATE = ("4.1", "4.2", "4.3", "4.4", "4.5", "4.6", "4.8", "4.9")


def cheie(url: str) -> str:
    return hashlib.md5(url.encode("utf-8")).hexdigest()


def descarca(url: str, destinatie: Path) -> str:
    """Intoarce "ok", "lipsa" (404) sau ridica dupa mai multe incercari esuate."""
    if destinatie.exists() and destinatie.stat().st_size > 1000:
        return "ok"
    temporar = destinatie.with_suffix(".part")
    for asteptare in (30, 120, 300, 900, 1800, 1800, 3600, None):
        r = subprocess.run(
            ["curl", "-s", "-L", "-o", str(temporar), "--max-time", "240", "-A", UA,
             "-w", "%{http_code}", url],
            capture_output=True,
            text=True,
        )
        cod = r.stdout.strip()
        if cod == "200":
            shutil.move(temporar, destinatie)
            return "ok"
        if cod in ("404", "410"):
            temporar.unlink(missing_ok=True)
            return "lipsa"
        if asteptare is None:
            raise RuntimeError(f"serverul nu raspunde (HTTP {cod or '000'}) pentru {url}")
        print(f"  HTTP {cod or '000'}; astept {asteptare}s", flush=True)
        time.sleep(asteptare)
    return "lipsa"


def curata(text: str) -> str:
    randuri = [re.sub(r"[ \t]+", " ", r).strip() for r in text.split("\n")]
    # numerele de pagina si numerele de sectiune ramase singure pe rand
    randuri = [r for r in randuri if r and not re.fullmatch(r"\d{1,3}|\d\s*\.\s*\d\.?", r)]
    while randuri and REST_TITLU.match(randuri[0]):
        randuri.pop(0)
    out: list[str] = []
    for r in randuri:
        # un rand nou incepe la liniuta/bulina sau dupa un rand incheiat cu punct
        nou = not out or re.match(r"^[-•–·●]\s*", r) or out[-1].endswith((".", ":", ";"))
        if nou:
            out.append(re.sub(r"^[•–·●]\s*", "- ", r))
        else:
            out[-1] += " " + r
    return "\n".join(out).strip()


def extrage(cale_pdf: Path) -> dict[str, str]:
    """Sectiunile 4.1-4.9 din primul RCP al documentului; lipsesc cele negasite."""
    try:
        doc = fitz.open(cale_pdf)
    except Exception:
        return {}
    text = ""
    for i, pagina in enumerate(doc):
        text += pagina.get_text() + "\n"
        if i >= 3 and TITLURI[-1][1].search(text):
            break
        if i >= MAX_PAGINI:
            break
    # pozitiile titlurilor, in ordinea din document
    gasite: list[tuple[str, int, int]] = []
    pozitie = 0
    for numar, tipar in TITLURI:
        m = tipar.search(text, pozitie)
        if m:
            gasite.append((numar, m.start(), m.end()))
            pozitie = m.end()
    sectiuni = {}
    for (numar, _, sfarsit_titlu), urmator in zip(gasite, gasite[1:]):
        if numar in PASTRATE:
            continut = curata(text[sfarsit_titlu : urmator[1]])
            if continut:
                sectiuni[numar] = continut
    return sectiuni


def taie(text: str, limita: int) -> str:
    if len(text) <= limita:
        return text
    # taiere la sfarsit de propozitie, cu semn ca textul continua in RCP
    scurt = text[:limita]
    capat = max(scurt.rfind(". "), scurt.rfind(".\n"), scurt.rfind(";\n"))
    return (scurt[: capat + 1] if capat > limita * 0.6 else scurt).rstrip() + "\n[…] continuă în RCP"


def scrie_asset(urluri: list[str]) -> None:
    vechi = json.loads(VECHI.read_text(encoding="utf-8")) if VECHI.exists() else {}
    contraindicatii: dict[str, str] = {}
    continuturi: dict[str, dict] = {}
    index: dict[str, str] = {}
    for url in urluri:
        f = SECTIUNI / f"{cheie(url)}.json"
        if f.exists():
            s = json.loads(f.read_text(encoding="utf-8"))
            if s.get("4.3"):
                contraindicatii[url] = taie(s["4.3"], LIMITA["4.3"])
            rest = {k: taie(v, LIMITA_IMPLICITA) for k, v in s.items() if k != "4.3"}
            if rest:
                # multe concentratii au acelasi text; continutul identic se pastreaza o data
                amprenta = hashlib.md5(json.dumps(rest, sort_keys=True).encode()).hexdigest()
                continuturi[amprenta] = rest
                index[url] = amprenta
        elif vechi.get(url):
            contraindicatii[url] = vechi[url]

    OUT_CI.write_bytes(gzip.compress(
        json.dumps(contraindicatii, ensure_ascii=False, separators=(",", ":")).encode("utf-8"), 9))

    if OUT_RCP.exists():
        shutil.rmtree(OUT_RCP)
    OUT_RCP.mkdir(parents=True)
    pachete: dict[str, dict] = {}
    for amprenta, sectiuni in continuturi.items():
        pachete.setdefault(amprenta[:2], {})[amprenta] = sectiuni
    total = 0
    for prefix, continut in pachete.items():
        date = gzip.compress(json.dumps(continut, ensure_ascii=False, separators=(",", ":")).encode("utf-8"), 9)
        (OUT_RCP / f"{prefix}.json.gz").write_bytes(date)
        total += len(date)
    date = gzip.compress(json.dumps(index, separators=(",", ":")).encode("utf-8"), 9)
    (OUT_RCP / "index.json.gz").write_bytes(date)
    print(f"Asset: contraindicatii pentru {len(contraindicatii)} RCP-uri; sectiuni pentru "
          f"{len(index)} RCP-uri ({len(continuturi)} texte distincte, {len(pachete)} pachete, "
          f"{(total + len(date)) / 1e6:.1f} MB)", flush=True)


def main() -> None:
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    PDF.mkdir(parents=True, exist_ok=True)
    SECTIUNI.mkdir(parents=True, exist_ok=True)

    if "--test" in sys.argv:
        url = sys.argv[sys.argv.index("--test") + 1]
        f = PDF / f"{cheie(url)}.pdf"
        print(descarca(url, f))
        for numar, continut in extrage(f).items():
            print(f"\n== {numar} ({len(continut)} caractere)\n{continut[:420]}")
        return

    produse = json.loads(gzip.open(MEDICAMENTE).read())["products"]
    psihotrop = lambda p: p["a"][:3] in ("N05", "N06", "N03")
    ordine = sorted(produse, key=lambda p: (not psihotrop(p), p["e"], p["n"]))
    urluri = list(dict.fromkeys(p["r"] for p in ordine if p["r"]))

    if "--doar-asset" in sys.argv:
        scrie_asset(urluri)
        return

    reextrage = "--reextrage" in sys.argv
    de_facut = [u for u in urluri if reextrage or not (SECTIUNI / f"{cheie(u)}.json").exists()]
    if "--limita" in sys.argv:
        de_facut = de_facut[: int(sys.argv[sys.argv.index("--limita") + 1])]
    print(f"{len(urluri)} RCP-uri unice, {len(de_facut)} de procesat", flush=True)

    cu_sectiuni = 0
    for i, url in enumerate(de_facut, 1):
        pdf = PDF / f"{cheie(url)}.pdf"
        era_local = pdf.exists()
        stare = descarca(url, pdf)
        sectiuni = extrage(pdf) if stare == "ok" else {}
        cu_sectiuni += bool(sectiuni)
        (SECTIUNI / f"{cheie(url)}.json").write_text(
            json.dumps(sectiuni, ensure_ascii=False), encoding="utf-8")
        if i % 20 == 0 or i == len(de_facut):
            print(f"  {i}/{len(de_facut)}  cu sectiuni: {cu_sectiuni}", flush=True)
        if i % 300 == 0:
            scrie_asset(urluri)
        if not era_local:
            time.sleep(1.5 if "ema.europa.eu" not in url else 4)
    scrie_asset(urluri)


if __name__ == "__main__":
    main()
