"""Genereaza iconita aplicatiei pentru iOS, Android si web: capsula lucioasa
galben-rosu, desenata in tool/icon_variante.py.

Rulare:  python tool/build_icon.py [alb]     (fara argument: fond albastru)
"""
import json
import sys
from pathlib import Path

from PIL import Image

import icon_variante as v

ROOT = Path(__file__).resolve().parent.parent

ADAPTIV = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""

FUNDAL_ALBASTRU = """<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient android:startColor="#1558D6" android:endColor="#0B2F7A" android:angle="315"/>
</shape>
"""

FUNDAL_ALB = """<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#FFFFFF"/>
</shape>
"""


def prim_plan(marime: int) -> Image.Image:
    """Stratul din fata al iconitei adaptive (Android 8+): capsula pe fond
    transparent, micsorata ca sa ramana in zona pe care sistemul nu o decupeaza."""
    return v.capsula_lucioasa(marime * v.S, scara=0.62).resize((marime, marime), Image.LANCZOS)


def main() -> None:
    alb = "alb" in sys.argv[1:]
    master = v.randeaza(10 if alb else 9, 1024)

    ios = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for intrare in json.loads((ios / "Contents.json").read_text())["images"]:
        pixeli = round(float(intrare["size"].split("x")[0]) * int(intrare["scale"][0]))
        master.resize((pixeli, pixeli), Image.LANCZOS).save(ios / intrare["filename"])

    android = ROOT / "android/app/src/main/res"
    for densitate, pixeli in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        master.resize((pixeli, pixeli), Image.LANCZOS).save(android / f"mipmap-{densitate}/ic_launcher.png")
    for densitate, pixeli in {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}.items():
        prim_plan(pixeli).save(android / f"mipmap-{densitate}/ic_launcher_foreground.png")
    (android / "mipmap-anydpi-v26").mkdir(exist_ok=True)
    (android / "mipmap-anydpi-v26/ic_launcher.xml").write_text(ADAPTIV, encoding="utf-8")
    (android / "drawable/ic_launcher_background.xml").write_text(
        FUNDAL_ALB if alb else FUNDAL_ALBASTRU, encoding="utf-8"
    )

    web = ROOT / "web"
    for pixeli in (192, 512):
        master.resize((pixeli, pixeli), Image.LANCZOS).save(web / f"icons/Icon-{pixeli}.png")
        master.resize((pixeli, pixeli), Image.LANCZOS).save(web / f"icons/Icon-maskable-{pixeli}.png")
    master.resize((32, 32), Image.LANCZOS).save(web / "favicon.png")
    print("iconite generate:", "fond alb" if alb else "fond albastru")


if __name__ == "__main__":
    main()
