"""Gaseste PDF-ul EMA in romana (RCP + prospect) pentru medicamentele
autorizate centralizat si scrie rezultatul in tool/ema_links.json.

Potrivirea se face local, pe lista oficiala de medicamente a EMA (denumire +
cod ATC), apoi fiecare PDF este verificat cu o cerere HEAD. Verificarile se
pastreaza in tool/cache/ema_verified.json, deci scriptul poate fi reluat.

Se ruleaza dupa build_medicamente.py; apoi build_medicamente.py trebuie rulat
din nou ca sa includa linkurile.

Rulare:  python tool/resolve_ema.py [--no-verify]
"""
import difflib
import gzip
import io
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "assets" / "data" / "medicamente.json.gz"
CACHE = ROOT / "tool" / "cache"
TABLE = CACHE / "ema_medicines.json"
VERIFIED = CACHE / "ema_verified.json"
OUT = ROOT / "tool" / "ema_links.json"
TABLE_URL = (
    "https://www.ema.europa.eu/en/documents/report/"
    "medicines-output-medicines_json-report_en.json"
)
UA = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "Chrome/126 Safari/537.36"
}
PDF = "https://www.ema.europa.eu/ro/documents/product-information/{}-epar-product-information_ro.pdf"
# starile in care EMA mai publica informatiile despre produs, in ordinea preferintei
STATUS_RANK = {"Authorised": 0, "Suspended": 1, "Withdrawn": 2, "Lapsed": 2, "Expired": 2}


def base_name(denumire: str) -> str:
    """Denumirea fara concentratie: "KEYTRUDA 25 mg/ml" -> "KEYTRUDA"."""
    return re.split(r"[\d®]", denumire)[0].strip()


def tokens(name: str) -> list[str]:
    return re.sub(r"[^a-z0-9]+", " ", name.lower()).split()


def ema_name(row: dict) -> str:
    """Denumirea curenta, fara paranteze: "Abasaglar (previously Abasria)" -> "Abasaglar"."""
    return re.sub(r"\([^)]*\)", "", row["name_of_medicine"]).strip()


def pdf_urls(row: dict) -> list[str]:
    """PDF-ul poarta fie denumirea curenta, fie identificatorul paginii EMA."""
    slugs = ["-".join(tokens(ema_name(row))), row["medicine_url"].rstrip("/").rsplit("/", 1)[-1]]
    return [PDF.format(x) for x in dict.fromkeys(slugs)]


def load_table() -> list[dict]:
    if not TABLE.exists():
        req = urllib.request.Request(TABLE_URL, headers=UA)
        with urllib.request.urlopen(req, timeout=120) as r:
            TABLE.write_bytes(r.read())
    rows = json.loads(TABLE.read_text(encoding="utf-8"))["data"]
    rows = [
        r
        for r in rows
        if r["category"] == "Human" and r["medicine_status"] in STATUS_RANK and r["medicine_url"]
    ]
    rows.sort(key=lambda r: STATUS_RANK[r["medicine_status"]])
    return rows


def match(name: str, atcs: set[str], rows: list[dict], by_key: dict, by_atc: dict):
    """Intoarce (rand EMA, metoda) sau (None, "")."""
    words = tokens(name)
    # 1. aceeasi denumire
    row = by_key.get("".join(words))
    if row:
        return row, "nume"
    # 2. acelasi cod ATC si denumire asemanatoare (generice cu numele tradus:
    #    "ABIRATERONA KRKA" / "Abiraterone Krka", "ACID IBANDRONIC" / "Ibandronic acid")
    ours = " ".join(sorted(words))
    best, best_score = None, 0.0
    for atc in atcs:
        for r in by_atc.get(atc, []):
            their_words = tokens(ema_name(r))
            # ultimul cuvant e firma; un generic al altui producator nu e acelasi produs
            if words[-1] not in their_words:
                continue
            theirs = " ".join(sorted(their_words))
            score = difflib.SequenceMatcher(None, ours, theirs).ratio()
            if score > best_score:
                best, best_score = r, score
    if best and best_score >= 0.8:
        return best, f"atc+nume {best_score:.2f}"
    # 3. denumirea fara ultimele cuvinte (tipul de stilou, forma de prezentare)
    for n in range(len(words) - 1, 0, -1):
        row = by_key.get("".join(words[:n]))
        # EMA poate lista mai multe coduri ATC pentru acelasi produs (ex. insuline)
        if row and (not atcs or any(a[:5] in row["atc_code_human"] for a in atcs)):
            return row, "nume scurtat"
    return None, ""


def exists(url: str) -> bool:
    """Cerere HEAD prin curl: EMA respinge des cererile facute cu urllib."""
    # EMA refuza temporar cererile prea dese; asteptam din ce in ce mai mult
    for wait in (60, 180, 420, 900, 1800, 1800, 1800, 3600, None):
        r = subprocess.run(
            ["curl", "-s", "-I", "-L", "-o", os.devnull, "--max-time", "40",
             "-A", UA["User-Agent"], "-w", "%{http_code} %{content_type}", url],
            capture_output=True,
            text=True,
        )
        cod, _, tip = r.stdout.strip().partition(" ")
        if cod == "200":
            return "pdf" in tip
        if cod in ("404", "410"):
            return False
        cauza = f"HTTP {cod}" if cod and cod != "000" else "fara raspuns"
        if wait is None:
            raise RuntimeError(f"EMA nu raspunde ({cauza}) pentru {url}")
        print(f"  {cauza}; astept {wait}s", flush=True)
        time.sleep(wait)
    return False


def main() -> None:
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    verify = "--no-verify" not in sys.argv
    CACHE.mkdir(parents=True, exist_ok=True)

    products = json.loads(gzip.open(DATA).read())["products"]
    atcs_by_name: dict[str, set[str]] = {}
    for p in products:
        if p["e"]:
            atcs_by_name.setdefault(base_name(p["n"]), set()).add(p["a"])

    rows = load_table()
    by_key, by_atc = {}, {}
    for r in rows:
        by_key.setdefault("".join(tokens(ema_name(r))), r)
        by_atc.setdefault(r["atc_code_human"], []).append(r)

    candidates, methods, unmatched = {}, {}, []
    for name in sorted(atcs_by_name):
        row, method = match(name, atcs_by_name[name] - {""}, rows, by_key, by_atc)
        if row is None:
            unmatched.append(name)
            continue
        candidates[name] = pdf_urls(row)
        methods[method.split(" ")[0]] = methods.get(method.split(" ")[0], 0) + 1
        if method.startswith("atc"):
            print(f"  {method}: {name} -> {ema_name(row)}")
    print(f"{len(atcs_by_name)} denumiri: {len(candidates)} potrivite {methods}, "
          f"{len(unmatched)} nepotrivite")
    for n in unmatched:
        print("  nepotrivit:", n, sorted(atcs_by_name[n]))

    verified = json.loads(VERIFIED.read_text(encoding="utf-8")) if VERIFIED.exists() else {}
    if verify:
        todo = sorted({u for urls in candidates.values() for u in urls if u not in verified})
        print(f"Verific {len(todo)} PDF-uri ({len(verified)} deja verificate)", flush=True)
        for i, url in enumerate(todo, 1):
            verified[url] = exists(url)
            VERIFIED.write_text(json.dumps(verified, indent=0, sort_keys=True), encoding="utf-8")
            if i % 50 == 0 or i == len(todo):
                print(f"  {i}/{len(todo)}", flush=True)
            time.sleep(4)

    def pick(urls: list[str]) -> str:
        """Primul PDF confirmat; daca niciunul nu a fost inca verificat, primul candidat."""
        for u in urls:
            if verified.get(u):
                return u
        return next((u for u in urls if u not in verified), "")

    links = {n: pick(urls) for n, urls in candidates.items()}
    links.update({n: "" for n in unmatched})
    OUT.write_text(json.dumps(links, ensure_ascii=False, indent=0, sort_keys=True), encoding="utf-8")
    ok = sum(1 for u in links.values() if u)
    confirmed = sum(1 for u in links.values() if u and verified.get(u))
    print(f"GATA: {ok} din {len(links)} au link, {confirmed} confirmate prin verificare")
    for n, urls in candidates.items():
        if not links[n]:
            print("  PDF inexistent:", n, urls)


if __name__ == "__main__":
    main()
