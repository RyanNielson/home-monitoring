# Solar Monitor

Enphase solar monitoring stack using Docker Compose. Collects data from your local Enphase IQ Gateway and displays it in a Grafana dashboard backed by InfluxDB.

## Stack

- **Ruby** — polls `production.json` from the Enphase gateway every 60s
- **InfluxDB 2.x** — time-series storage
- **Grafana** — pre-provisioned dashboard for production, consumption, and grid power

## Getting Started

### 1. Configure

```bash
cp .env.example .env
```

Edit `.env` and fill in at minimum:

| Variable | Description |
|---|---|
| `ENPHASE_TOKEN` | JWT token from https://entrez.enphaseenergy.com/tokens |
| `INFLUXDB_TOKEN` | Run `openssl rand -hex 32` to generate one |
| `ENPHASE_HOST` | Defaults to `envoy.local` — change to IP if mDNS doesn't resolve inside Docker |

> **Note on `envoy.local`:** Docker containers on macOS can't resolve mDNS names. If the collector fails to reach the gateway, find the IP with `ping envoy.local` from your Mac and set `ENPHASE_HOST` to that IP in `.env`.

### 2. Start

```bash
docker compose up -d
```

On first start the collector will spend ~30–60 seconds installing the `influxdb-client` gem into a persistent cache volume. Subsequent restarts are instant.

### 3. View logs

```bash
docker compose logs -f collector
```

### 4. Open Grafana

Visit **http://localhost:3000** (default credentials: admin / admin)

The Solar dashboard is pre-loaded and refreshes every minute.

## Dashboard Panels

- **Current Production** — live watts from your panels
- **Current Consumption** — live whole-home consumption
- **Grid Power** — net grid exchange (positive = exporting, negative = importing)
- **Energy Today** — Wh produced today
- **Power graph** — production, consumption, and grid over the selected time range
- **Energy Last 7 Days / Lifetime** — cumulative energy stats
- **Active Inverters** — count of reporting microinverters
