import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import urlopen

USGS_URL = "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/4.5_month.geojson"
ROOT = Path(__file__).resolve().parents[2]
TMP_DIR = ROOT / "tmp"
OUTPUT_PATH = ROOT / "data" / "global_seismic_alerts_events.geojson"


def fetch_feed(url: str) -> dict:
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    cache_path = TMP_DIR / "usgs_m45_month.geojson"
    try:
        with urlopen(url, timeout=60) as resp, cache_path.open("wb") as f:
            while chunk := resp.read(1024 * 1024):
                f.write(chunk)
    except Exception as exc:  # noqa: BLE001
        print(f"Failed to download USGS feed: {exc}", file=sys.stderr)
        raise
    with cache_path.open("r", encoding="utf-8") as f:
        return json.load(f)


def classify_hazard(magnitude: float | None, depth_km: float | None) -> str:
    if magnitude is None:
        magnitude = 0.0
    if depth_km is None:
        depth_km = 999.9
    shallow = depth_km <= 70
    if magnitude >= 7.5:
        return "extreme"
    if magnitude >= 7.0:
        return "severe" if shallow else "high"
    if magnitude >= 6.5:
        return "high" if shallow else "elevated"
    if magnitude >= 6.0:
        return "elevated"
    if magnitude >= 5.0:
        return "watch"
    return "monitor"


def classify_age(event_dt: datetime, now: datetime) -> str:
    delta_hours = (now - event_dt).total_seconds() / 3600
    if delta_hours <= 24:
        return "24h"
    if delta_hours <= 72:
        return "72h"
    if delta_hours <= 168:
        return "7d"
    if delta_hours <= 720:
        return "30d"
    return "older"


def build_feature_collection(raw: dict) -> dict:
    now = datetime.now(timezone.utc)
    features = []
    for feature in raw.get("features", []):
        if feature.get("type") != "Feature":
            continue
        geometry = feature.get("geometry") or {}
        coords = geometry.get("coordinates") or []
        if len(coords) < 3:
            continue
        lon, lat, depth_km = coords[0], coords[1], coords[2]
        try:
            lon = float(lon)
            lat = float(lat)
            depth_km = float(depth_km)
        except (TypeError, ValueError):
            continue
        if not (-90 <= lat <= 90 and -180 <= lon <= 180):
            continue

        props = feature.get("properties") or {}
        mag = props.get("mag")
        try:
            mag = float(mag) if mag is not None else None
        except (TypeError, ValueError):
            mag = None

        time_ms = props.get("time")
        try:
            event_dt = datetime.fromtimestamp(time_ms / 1000, tz=timezone.utc)
        except Exception:  # noqa: BLE001
            event_dt = now

        hazard_level = classify_hazard(mag, depth_km)
        age_bucket = classify_age(event_dt, now)
        tsunami = bool(props.get("tsunami"))
        mag_type = props.get("magType") or ""
        code = props.get("code") or feature.get("id") or ""
        place = props.get("place") or ""
        significance = props.get("sig")

        properties = {
            "mag": mag,
            "depth_km": round(depth_km, 1),
            "time_utc": event_dt.isoformat(),
            "place": place,
            "hazard_level": hazard_level,
            "recent_window": age_bucket,
            "tsunami": tsunami,
            "mag_type": mag_type,
            "event_id": code,
            "significance": significance,
        }
        features.append({
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [lon, lat],
            },
            "properties": properties,
        })

    features.sort(key=lambda f: f["properties"].get("mag") or 0, reverse=True)
    return {
        "type": "FeatureCollection",
        "name": "USGS_Earthquakes_M45_30Days",
        "metadata": {
            "generated_at": now.isoformat(),
            "source": USGS_URL,
            "feature_count": len(features),
        },
        "features": features,
    }


def main() -> None:
    raw = fetch_feed(USGS_URL)
    output = build_feature_collection(raw)
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT_PATH.open("w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False)
    print(f"Wrote {output['metadata']['feature_count']} features to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
