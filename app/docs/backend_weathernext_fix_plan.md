> **Historical sibling-app research, not the current Android implementation.**
> WeatherNext and MP4 video backgrounds are not installed in this repository.
> See [../../ARCHITECTURE.md](../../ARCHITECTURE.md) for current capabilities.

# Backend Fix Plan — Make WeatherNext Live (All 9 Surfaces) for SIH 2026

**Target repo:** `omsenjalia/weathergpt` (backend at `weathergpt-backend.vercel.app`)
**Current deployed:** v2.1.0, `weathernext.enabled=true`, `auth_mode=oauth`, `project=cool-archery-296710`
**Current failure:** `live_credentials_required` for `cool-archery-296710.weathernext.weathernext_3_0_0_0p1deg`
**You have:** All 9 accesses from your screenshot:
- [x] WeatherNext 2 on Earth Engine
- [x] WeatherNext 2 on BigQuery
- [x] WeatherNext 2 on Google Cloud Storage (Zarr)
- [x] WeatherNext 2 Mean on Earth Engine
- [x] WeatherNext 2 Mean on BigQuery
- [x] WeatherNext 2 Mean on Google Cloud Storage (Zarr)
- [x] WeatherNext 3 on Earth Engine
- [x] WeatherNext 3 on BigQuery
- [x] WeatherNext 3 on Google Cloud Storage (Zarr)

This plan fixes backend to use **all 9** and make Flutter app receive WeatherNext data.

---

## 1. What the 9 Checkboxes Mean

| Checkbox | What it is | Best for | Cost |
|---|---|---|---|
| **WN2 on BigQuery** | WeatherNext 2 (GenCast/GraphCast era) table `weathernext_2_0_0` via Analytics Hub, linked into its **own dataset** (`weathernext_2`) | SQL joins with business data, historical comparison | Billed per bytes scanned, needs billing |
| **WN2 Mean on BigQuery** | WeatherNext 2 Mean — a **separate listing and table** (`weathernext_2_0_0_mean`), smaller/faster | Everyday forecast, cheaper | Same but less data scanned |
| **WN2 on GCS (Zarr)** | Full 64-member ensemble Zarr `gs://weathernext2_*` | Raw ensemble, ML, custom stats | Storage egress, no BigQuery cost |
| **WN2 Mean on GCS (Zarr)** | Statistics Zarr for WN2 | Fast mean/p10-p90 | Same |
| **WN2 on Earth Engine** | WN2 as EE ImageCollection | Maps, raster, NDVI joins | EE quota, no BigQuery |
| **WN2 Mean on Earth Engine** | Mean collection on EE | Map tiles | Same |
| **WN3 on BigQuery** | WeatherNext 3 (current) 0.1° `weathernext_3_0_0_0p1deg` + 0.05° `...0p05deg` | Primary 15-day forecast, 6 stats (mean/p10/p25/p50/p75/p90) | Billed, needs billing |
| **WN3 Mean on BigQuery** | Same as above — WN3 tables ARE mean/stats (confusing name, but WN3 BigQuery only serves stats) | Same as WN3 on BigQuery | Same |
| **WN3 on GCS (Zarr)** | Full fidelity: `gs://weathernext3_spatial/` (raw 64 members + 3D levels) and `gs://weathernext3_statistics_spatial/` (stats) | Ensemble spread, profiles, energy (100m wind), SST | Egress only, best for researcher |
| **WN3 on Earth Engine** | WN3 0.1° and 0.05° collections `projects/gcp-public-data-weathernext/assets/weathernext_3_0_0_0p1deg` | Map tiles for app Explore, researcher maps | EE quota |

**For SIH:** Use **WN3 on BigQuery** as primary (15-day, 0.1°), **WN3 on GCS Zarr** for ensemble/researcher, **WN2** for historical comparison (show improvement). Earth Engine for map tiles.

## 2. Root Cause of Current Failure

Backend uses OAuth refresh token. In Vercel serverless, token refresh fails → `live_credentials_required` → fallback to Open-Meteo.

You have billing issue `untrusted account` when trying to enable billing — but project `cool-archery-296710` already has billing and SA, so backend should use **service account JSON** not OAuth.

## 3. Architecture — Use All 9 Surfaces

```
Flutter App
  /v2/weather?requested_source=weathernext&model=weathernext_3
    → ForecastProvider
      → WN3 BigQuery Adapter (primary, 0.1° + 0.05°)
        → if fails: WN3 GCS Zarr Adapter (stats)
          → if fails: WN2 BigQuery Adapter (historical)
            → if fails: AccuWeather → Open-Meteo

  /v2/weather/ensemble?variable=temperature_2m
    → WN3 GCS Full Ensemble Adapter (gs://weathernext3_spatial/)

  /v2/weather/catalog
    → Returns all 262 capabilities with access_status:
      planned → implemented → verified (track each of your 9)

  /v2/weather/tiles/{var}/{run}/{z}/{x}/{y}.png
    → Earth Engine Adapter (WN2 + WN3) for map tiles
```

## 4. Implementation Steps

### 4.1 Service Account (covers all 9)

In `cool-archery-296710`:

- IAM → Service Accounts → `weathergpt-backend` → Roles:
  - `BigQuery Job User`, `BigQuery Data Viewer` (for WN2 + WN3 BigQuery)
  - `Storage Object Viewer` (for WN2 + WN3 GCS Zarr)
  - `Earth Engine Resource Viewer` (for WN2 + WN3 Earth Engine)
- Keys → JSON → Add to Vercel env `GOOGLE_APPLICATION_CREDENTIALS_JSON` (stringified, never commit)

Vercel env:
```
GOOGLE_APPLICATION_CREDENTIALS_JSON={"type":"service_account",...}
GOOGLE_CLOUD_PROJECT=cool-archery-296710
GOOGLE_CLOUD_QUOTA_PROJECT=cool-archery-296710
WEATHERNEXT_TABLE_3=cool-archery-296710.weathernext.weathernext_3_0_0_0p1deg
WEATHERNEXT_TABLE_3_HR=cool-archery-296710.weathernext.weathernext_3_0_0_0p05deg
# WN2 and WN3 are separate Analytics Hub listings, so each is linked into its
# own dataset. Setting the dataset name is enough; the table keeps the
# published name (composed default: <project>.<dataset>.weathernext_2_0_0).
WEATHERNEXT_BQ_DATASET_3=weathernext
WEATHERNEXT_BQ_DATASET_2=weathernext_2
WEATHERNEXT_TABLE_2=cool-archery-296710.weathernext_2.weathernext_2_0_0
WEATHERNEXT_TABLE_2_MEAN=cool-archery-296710.weathernext_2.weathernext_2_0_0_mean
WEATHERNEXT_GCS_BUCKET_3=weathernext3_spatial
WEATHERNEXT_GCS_STATS_3=weathernext3_statistics_spatial
WEATHERNEXT_GCS_BUCKET_2=weathernext2_spatial
WEATHERNEXT_ENABLED=1
```

### 4.2 Auth Helper (covers BigQuery + GCS + EE)

`backend/services/weathernext_auth.py` (new):

```python
import json, os
from google.oauth2 import service_account
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request

def get_credentials(scopes):
    sa_json = os.getenv("GOOGLE_APPLICATION_CREDENTIALS_JSON")
    if sa_json:
        info = json.loads(sa_json)
        return service_account.Credentials.from_service_account_info(info, scopes=scopes)
    # fallback to ADC / OAuth as before
    ...

def get_bq_client():
    from google.cloud import bigquery
    creds = get_credentials(["https://www.googleapis.com/auth/bigquery"])
    if not creds: raise RuntimeError("live_credentials_required")
    return bigquery.Client(credentials=creds, project=os.getenv("GOOGLE_CLOUD_PROJECT"))

def get_gcs_client():
    from google.cloud import storage
    creds = get_credentials(["https://www.googleapis.com/auth/devstorage.read_only"])
    return storage.Client(credentials=creds)

def get_ee_credentials():
    # EE uses same SA, but needs earthengine scope
    return get_credentials(["https://www.googleapis.com/auth/earthengine"])
```

### 4.3 BigQuery Adapters — All Versions

**WN2 and WN3 cannot live in one dataset.** They are separate Analytics Hub
listings, so each subscription is linked into its own dataset in
`cool-archery-296710` (WN3 → `weathernext`, WN2 → `weathernext_2`), and the WN2
Mean listing is a separate table again (`weathernext_2_0_0_mean`). The backend
composes `<project>.<dataset>.<published table>` per model, rejects a WN2 table
that points into the WN3 dataset (`WEATHERNEXT_BQ_ALLOW_SHARED_DATASET=1` is the
documented escape hatch), and repairs a stale table id after a rename with one
metadata-only `list_tables` call (`WEATHERNEXT_BQ_TABLE_DISCOVERY=1`).

`backend/services/weathernext_bigquery.py`:

```python
TABLES = {
    "wn3_0p1": "<project>.weathernext.weathernext_3_0_0_0p1deg",   # WN3 listing
    "wn3_0p05": "<project>.weathernext.weathernext_3_0_0_0p05deg", # WN3 high-res
    "wn2_0p1": "<project>.weathernext_2.weathernext_2_0_0",         # WN2 listing (own dataset)
    "wn2_mean": "<project>.weathernext_2.weathernext_2_0_0_mean",   # WN2 Mean listing (own table)
}

def query_wn3_point(lat, lon, init_time):
    # Uses wn3_0p1 table — 19 vars, 6 stats each (mean/p10/p25/p50/p75/p90)
    # Always WHERE init_time = TIMESTAMP(...) to prune partitions
    # SELECT f.temperature_2m_mean, f.temperature_2m_p10, f.temperature_2m_p90, ...
    # ST_DWITHIN(geography, ST_GEOGPOINT(lon, lat), 10000)
    # max_bytes_billed=1GB

def query_wn2_point(lat, lon, init_time):
    # WN2 table in its own linked dataset — for comparison / historical

def query_wn2_mean_point(lat, lon, init_time):
    # WN2 Mean table (separate listing) — mean/p10..p90 only

def query_wn3_mean_point(...):
    # WN3 Mean on BigQuery — same WN3 table, but only _mean columns (cheaper)
```

### 4.4 GCS Zarr Adapters — Full Ensemble + Mean

`backend/services/weathernext_gcs.py` (new):

```python
import xarray as xr
import obstore as obs

BUCKETS = {
    "wn3_full": "gs://weathernext3_spatial/weathernext_3_0_0/zarr/",
    "wn3_stats": "gs://weathernext3_statistics_spatial/weathernext_3_0_0/zarr/",
    "wn2_full": "gs://weathernext2_spatial/...",
    "wn2_mean": "gs://weathernext2_statistics_spatial/..."
}

def open_wn3_ensemble(init_time):
    # xr.open_zarr(BUCKETS["wn3_full"], chunks={})
    # Select init_time, then point via sel(lat, lon, method="nearest")
    # Returns 64 members for ensemble spread

def open_wn3_stats(init_time):
    # For p10-p90, mean — used for Everyone enrichments

# Used by:
# /v2/weather/ensemble?variable=temperature_2m&lat=..&lon=..
# /v2/weather/profile?variable=temperature&levels=...
```

No BigQuery cost, only GCS egress — good for SIH when billing blocked.

### 4.5 Earth Engine Adapters — Map Tiles

`backend/services/weathernext_ee.py` (new):

```python
import ee

def init_ee():
    creds = get_ee_credentials()
    ee.Initialize(credentials=creds, project=os.getenv("GOOGLE_CLOUD_PROJECT"))

def get_tile_url(variable, run_id, col_name):
    # col_name: "projects/gcp-public-data-weathernext/assets/weathernext_3_0_0_0p1deg"
    # or "weathernext_2_..." for WN2
    # For WN3 on Earth Engine and WN2 on Earth Engine
    # Return EE map tile URL for /v2/weather/tiles/{var}/{run}/{z}/{x}/{y}.png
```

Used by Flutter Explore map — keeps Windy but adds WeatherNext tiles.

### 4.6 v2 Router — Use All

`backend/routers/v2_weather.py`:

```python
from ..services import weathernext_bigquery as bq
from ..services import weathernext_gcs as gcs

async def fetch_weathernext(lat, lon, requested_model="weathernext_3"):
    tried = []
    # 1. WN3 on BigQuery (primary)
    try:
        return await bq.query_wn3_point(lat, lon), "weathernext", "bigquery", "wn3_0p1deg"
    except Exception as e:
        tried.append({"provider": "weathernext", "reason": str(e), "surface": "bigquery", "table": TABLES["wn3_0p1"]})

    # 2. WN3 on GCS Zarr (stats)
    try:
        return await gcs.open_wn3_stats(lat, lon), "weathernext", "gcs_zarr", "weathernext3_statistics"
    except Exception as e:
        tried.append({"provider": "weathernext", "reason": str(e), "surface": "gcs", "bucket": BUCKETS["wn3_stats"]})

    # 3. WN2 on BigQuery (fallback historical)
    try:
        return await bq.query_wn2_point(lat, lon), "weathernext", "bigquery", "wn2_0p1deg"
    except Exception as e:
        tried.append({"provider": "weathernext", "reason": str(e), "surface": "bigquery", "table": TABLES["wn2_0p1"]})

    # 4. WN2 on GCS
    try:
        return await gcs.open_wn2_mean(lat, lon), "weathernext", "gcs_zarr", "wn2_mean"
    except Exception as e:
        tried.append({"provider": "weathernext", "reason": str(e), "surface": "gcs"})

    raise Unavailable(fallback_reasons=tried)
```

Provenance must include `surface`, `table`/`bucket`, `model_version` (2 vs 3), `is_ensemble`.

### 4.7 Catalog — Track Your 9

`/v2/weather/catalog` should return 262 entries with:

```json
{
  "capability_id": "gcs_ensemble_temperature_2m",
  "product": "weathernext_3_0_0",
  "surface": "gcs_ensemble",
  "access_status": "planned" -> "implemented" -> "verified",
  "backend_route": "/v2/weather/ensemble"
}
```

Map your 9 checkboxes to catalog:

- WN2 BigQuery → `bigquery` surface, `weathernext_2_0_0` product, linked dataset `weathernext_2`
- WN2 Mean BigQuery → its own listing/table `weathernext_2_0_0_mean` (not `_mean` columns of the WN2 table)
- WN2 GCS → `gcs_ensemble` vs `gcs_statistics`
- WN3 BigQuery → `bigquery` 0p1deg + 0p05deg in the `weathernext` dataset
- WN3 GCS → `weathernext3_spatial` (full) + `statistics_spatial` (mean)
- Earth Engine → `earth_engine` surface

Update `by_state` counts as you implement.

### 4.8 Testing All 9

```bash
# WN3 BigQuery (your main)
curl ".../v2/weather?lat=22.56&lon=72.95&requested_source=weathernext&model=weathernext_3" | jq .provenance.selected_source
# → weathernext

# WN2 BigQuery (comparison)
curl ".../v2/weather?lat=22.56&lon=72.95&requested_source=weathernext&model=weathernext_2" | jq .

# WN3 GCS Ensemble
curl ".../v2/weather/ensemble?lat=22.56&lon=72.95&variable=temperature_2m" | jq .

# WN3 Earth Engine tiles
curl ".../v2/weather/tiles/temperature_2m/latest/6/10/20.png" --output tile.png

# Health
curl .../v2/weather/health | jq .provider_health.weathernext
# → eligible true, reason null
```

## 5. Flutter App — Already Ready for All

Current app branch calls `/v2/weather` and parses `selected_source`, `fallbackReasons`, `model`. Once backend returns WN2/WN3, provenance bar shows blue WeatherNext badge.

To use specific types in researcher mode:

- `/v2/weather?model=weathernext_2` → WN2
- `/v2/weather?model=weathernext_3` → WN3
- `/v2/weather/ensemble` → full 64 members for spread (p10-p90)
- Map tiles from Earth Engine for Explore

No diagnostic screen needed — honest fallback chain is enough for SIH.

## 6. SIH Billing Untrusted Fix

You have billing in cool-archery-296710, but personal account fails. For SIH:

- Use that project's SA, not personal billing
- Set budget alert $5, max_bytes_billed 1GB per query
- 2 runs/day = 510 GiB/month fits in 1TB free tier
- If still blocked, use GCS Zarr path (no BigQuery cost) for demo + show catalog as proof of access

## 7. Done

- [ ] SA with BQ Job User + Data Viewer + Storage Viewer + EE Viewer
- [ ] Vercel env GOOGLE_APPLICATION_CREDENTIALS_JSON set
- [ ] WN2 and WN3 linked into **separate** datasets (`weathernext_2` / `weathernext`); `/v2/weather/health` shows no shared-dataset error
- [ ] WN3 BigQuery primary works → selected_source weathernext
- [ ] WN3 GCS ensemble works → /v2/weather/ensemble returns members
- [ ] WN2 BigQuery works for comparison (own dataset + WN2 Mean table)
- [ ] Earth Engine tiles work → /v2/weather/tiles
- [ ] Catalog updated: planned → implemented for your 9
- [ ] Flutter shows WeatherNext badge

Once done, Flutter app receives WeatherNext data automatically.

---

## 8. Publish status (2026-09-19)

The separate-dataset change is implemented in the backend submodule
(`services/config.py`, `services/weathernext_bigquery.py`, `services/weathernext_catalog.py`,
`main.py`, `routers/dev.py`) and covered by `backend/tests/test_weathernext_datasets.py`.

- Confirmed with the project owner: WN2 dataset `weathernext_2` holds
  `weathernext_2_0_0` and `weathernext_2_0_0_mean`; WN3 stays in `weathernext`.
- The backend commit could **not** be pushed to `omsenjalia/weathergpt` from the
  Arena session (HTTP 403 — the session identity has no write access to that
  repository). A ready-to-apply patch is kept outside the repositories as
  `weathergpt-wn2-dataset-fix.patch`.
- Because of that, the `backend/` submodule pointer in this repository is
  intentionally still `fc78632`. Push the submodule (then `./scripts/push-all.sh`)
  or apply the patch and bump the pointer once repository access is restored.

