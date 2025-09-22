import csv
import json
import sys
from datetime import datetime
from pathlib import Path
from urllib.request import urlopen

DOWNLOAD_URL = "https://www.uu.se/download/18.74301a071971546b354496ae/1749556887874/Geo_PKO_v.2.3_location_map.csv"

ROOT = Path(__file__).resolve().parents[2]
TMP_DIR = ROOT / "tmp"
CSV_PATH = TMP_DIR / "Geo_PKO_v2_3_location_map.csv"
OUTPUT_PATH = ROOT / "data" / "peacekeeping_network_sites.geojson"
MIN_DATE = datetime(2015, 1, 1)

SPECIALIZED_KEYS = {
    "eng": "工兵",
    "sig": "通信",
    "trans": "輸送",
    "riv": "河川",
    "he.sup": "重火器支援",
    "he.sup.lw": "軽火器支援",
    "sf": "特殊部隊",
    "med": "医療",
    "maint": "整備",
    "recon": "偵察",
    "avia": "航空",
    "mp": "憲兵",
    "demining": "地雷除去",
    "uav": "無人機",
    "obs.base": "監視基地",
    "disarmament": "武装解除"
}


def download_csv(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        print(f"Using cached dataset: {path}")
        return

    print(f"Downloading GeoPKO dataset to {path} ...")
    try:
        with urlopen(DOWNLOAD_URL) as resp, path.open("wb") as f:
            chunk_size = 1024 * 1024
            while True:
                chunk = resp.read(chunk_size)
                if not chunk:
                    break
                f.write(chunk)
    except Exception as exc:  # noqa: BLE001
        if path.exists():
            path.unlink()
        print(f"Failed to download dataset: {exc}", file=sys.stderr)
        raise


def parse_int(value):
    if value is None:
        return 0
    value = value.strip()
    if not value or value.upper() == "NA":
        return 0
    try:
        return int(float(value))
    except ValueError:
        return 0


def parse_date(value):
    if not value or value.upper() == "NA":
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


def collect_contributors(row):
    contributors = []
    for idx in range(1, 18):
        name_key = f"nameoftcc_{idx}"
        if name_key not in row:
            continue
        name = row[name_key].strip()
        if name and name.upper() != "NA":
            contributors.append(name.title())
    return contributors


best_records = {}

download_csv(CSV_PATH)

with CSV_PATH.open(newline='', encoding='utf-8-sig') as f:
    reader = csv.DictReader(f)
    for row in reader:
        lat = row.get("latitude")
        lon = row.get("longitude")
        if not lat or not lon:
            continue
        if lat.upper() == "NA" or lon.upper() == "NA":
            continue
        try:
            lat_f = float(lat)
            lon_f = float(lon)
        except ValueError:
            continue

        mission = row.get("mission", "").strip()
        location = row.get("location", "").strip()
        country = row.get("country", "").strip()
        date_obj = parse_date(row.get("date"))
        troops = parse_int(row.get("no.troops"))

        if not mission or not location or date_obj is None:
            continue
        if date_obj < MIN_DATE:
            continue

        key = (mission, location, round(lat_f, 5), round(lon_f, 5))
        current = best_records.get(key)
        if current is None or date_obj > current["date"]:
            specialized = [label for col, label in SPECIALIZED_KEYS.items() if parse_int(row.get(col)) > 0]
            is_hq = parse_int(row.get("hq")) > 0
            has_unpol = parse_int(row.get("unpol.dummy")) > 0
            has_unmo = parse_int(row.get("unmo.dummy")) > 0
            tcc_count = parse_int(row.get("no.tcc"))
            contributors = collect_contributors(row)
            scale = max(1.0, troops / 150.0, tcc_count * 0.8)
            if is_hq:
                scale += 3
            if has_unpol or has_unmo:
                scale += 1

            record = {
                "mission": mission,
                "location": location,
                "country": country,
                "latitude": lat_f,
                "longitude": lon_f,
                "date": date_obj,
                "troops": troops,
                "is_hq": is_hq,
                "has_unpol": has_unpol,
                "has_unmo": has_unmo,
                "contributors": contributors,
                "specialized_units": specialized,
                "tcc_count": tcc_count,
                "deployment_scale": round(scale, 2)
            }
            best_records[key] = record

features = []
for record in best_records.values():
    date_str = record["date"].date().isoformat()
    properties = {
        "mission": record["mission"],
        "location": record["location"],
        "country": record["country"],
        "reported_date": date_str,
        "troops": record["troops"],
        "tcc_count": record["tcc_count"],
        "is_hq": record["is_hq"],
        "has_unpol": record["has_unpol"],
        "has_unmo": record["has_unmo"],
        "contributors": record["contributors"],
        "specialized_units": record["specialized_units"],
        "deployment_scale": record["deployment_scale"]
    }
    features.append({
        "type": "Feature",
        "geometry": {
            "type": "Point",
            "coordinates": [record["longitude"], record["latitude"]]
        },
        "properties": properties
    })

feature_collection = {
    "type": "FeatureCollection",
    "name": "UN_Peacekeeping_Sites",
    "features": sorted(features, key=lambda f: (f["properties"]["mission"], f["properties"]["reported_date"]))
}

OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
with OUTPUT_PATH.open("w", encoding="utf-8") as f:
    json.dump(feature_collection, f, ensure_ascii=False)

print(f"Wrote {len(features)} features to {OUTPUT_PATH}")
