"""Construieste assets/data/compensare.json.gz din lista interactiva a CNAS
(https://www.cnas.ro/lista-medicamente/), unde tabelul intreg este inclus in pagina.

Rulare:  python tool/build_compensare.py [--refresh]
"""
import gzip
import html
import io
import json
import re
import sys
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tool" / "cache" / "cnas_lista.html"
OUT = ROOT / "assets" / "data" / "compensare.json.gz"
URL = "https://www.cnas.ro/lista-medicamente/"
UA = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "Chrome/126 Safari/537.36"
}
# coloanele tabelului CNAS
DENUMIRE, DCI, LISTA, CIM = 0, 1, 2, 3
AMBALAJ = 8
CANTITATE, PRET_AMBALAJ, PRET_UT = 11, 12, 13
CONTRIB_100, CONTRIB_LISTA, CONTRIB_PENSIONARI = 14, 15, 16


def numar(text: str) -> float:
    return float(text.replace(".", "").replace(",", ".")) if text else 0.0


def cheie_nume(denumire: str, dci: str) -> str:
    """Cheie de potrivire dupa denumire comerciala si substanta, pentru
    ambalajele al caror cod din lista CNAS nu mai exista in nomenclator
    (codul se schimba la reautorizare). Aceeasi regula e in aplicatie."""
    n = re.sub(r"\([^)]*\)", "", denumire.upper()).replace("®", "")
    return re.sub(r"[^A-Z0-9,./%]", "", n) + "|" + dci.upper().strip()


def cells(row: str) -> list[str]:
    return [
        html.unescape(re.sub(r"<[^>]+>", "", c)).strip()
        for c in re.findall(r"<t[hd][^>]*>(.*?)</t[hd]>", row, flags=re.S)
    ]


def main() -> None:
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    if "--refresh" in sys.argv or not CACHE.exists():
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        # -k: certificatul site-ului CNAS a fost gasit expirat; pagina e publica
        # si nu trimitem nimic, deci verificarea lui nu protejeaza nimic aici
        subprocess.run(
            ["curl", "-s", "-k", "-L", "--max-time", "300", "-A", UA["User-Agent"],
             "-o", str(CACHE), URL],
            check=True,
        )
    page = CACHE.read_text(encoding="utf-8")

    table = re.search(r'<table[^>]*id="tablepress-4"[^>]*>(.*?)</table>', page, flags=re.S)
    if not table:
        titlu = re.search(r"<title>(.*?)</title>", page, flags=re.S)
        raise SystemExit(
            "Tabelul CNAS nu a fost gasit: pagina primita are "
            f"{len(page) // 1024} KB si titlul {titlu.group(1).strip()[:80] if titlu else '(fara)'!r}. "
            "Fie structura paginii s-a schimbat, fie site-ul nu trimite tabelul "
            "catre acest calculator (se intampla din afara Romaniei)."
        )
    rows = [cells(r) for r in re.findall(r"<tr[^>]*>(.*?)</tr>", table.group(1), flags=re.S)]
    header, rows = rows[0], rows[1:]
    if len(header) != 17 or "Cod medicament" not in header[CIM]:
        raise SystemExit(f"Antet neasteptat in tabelul CNAS: {header}")

    text = html.unescape(re.sub(r"<[^>]+>", " ", page[: table.start()]))
    data = re.search(r"Data actualiz[ăa]rii listei:\s*(\d{2}\.\d{2}\.\d{4})", text)

    # un ambalaj apare o data pentru fiecare sublista (si repetat pentru programe)
    by_cim: dict[str, dict[str, list]] = {}
    by_dci: dict[str, set[str]] = {}
    by_nume: dict[str, dict[tuple, list]] = {}
    for r in rows:
        lista = r[LISTA]
        by_dci.setdefault(r[DCI].upper(), set()).add(lista)
        # la sublistele C se aplica contributia pentru compensare 100%
        contributie = r[CONTRIB_100] if lista.startswith("C") else r[CONTRIB_LISTA]
        cantitate = numar(r[CANTITATE])
        intrare = [
            lista,
            round(numar(r[PRET_AMBALAJ]), 2),
            round(numar(contributie) * cantitate, 2),
            # doar sublista B are contributie separata pentru pensionarii cu venituri mici
            round(numar(r[CONTRIB_PENSIONARI]) * cantitate, 2) if r[CONTRIB_PENSIONARI] else None,
        ]
        by_cim.setdefault(r[CIM], {})[lista] = intrare
        by_nume.setdefault(cheie_nume(r[DENUMIRE], r[DCI]), {})[(r[AMBALAJ], lista)] = (
            intrare + [r[AMBALAJ]]
        )

    out = {
        "data": data.group(1) if data else "",
        "cim": {c: [v[k] for k in sorted(v)] for c, v in sorted(by_cim.items())},
        "dci": {d: sorted(v) for d, v in sorted(by_dci.items())},
        # denumire|substanta -> [lista, pret, contributie, pensionari, ambalaj CNAS]
        "nume": {n: [v[k] for k in sorted(v)] for n, v in sorted(by_nume.items())},
    }
    raw = json.dumps(out, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    OUT.write_bytes(gzip.compress(raw, 9))
    print(f"Lista CNAS din {out['data'] or '?'}: {len(rows)} randuri, {len(by_cim)} ambalaje, "
          f"{len(by_dci)} substante")
    print(f"JSON: {len(raw) / 1e6:.2f} MB  gzip: {OUT.stat().st_size / 1e6:.2f} MB  -> {OUT}")


if __name__ == "__main__":
    main()
