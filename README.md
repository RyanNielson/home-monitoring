# Home Monitoring

Home monitoring stack using Docker Compose. Collects solar production data from an Enphase IQ Gateway and weather data from Open-Meteo, then displays everything in Grafana dashboards backed by InfluxDB.

## Stack

- **InfluxDB 2.x** — time-series storage
- **Grafana** — pre-provisioned dashboards for solar and weather data
- **Solar collector** (Ruby) — polls `production.json` from the Enphase gateway every 60s
- **Weather collector** (Ruby) — polls the Open-Meteo API every 5 minutes

## Getting Started

### 1. Configure

```bash
cp .env.example .env
```

Edit `.env` and fill in the required variables:

#### Infrastructure

| Variable | Required | Description |
|---|---|---|
| `INFLUXDB_TOKEN` | Yes | API token — generate with `openssl rand -hex 32` |
| `INFLUXDB_ADMIN_USER` | No | InfluxDB admin username (default: `admin`) |
| `INFLUXDB_ADMIN_PASSWORD` | No | InfluxDB admin password |
| `INFLUXDB_ORG` | No | InfluxDB org (default: `home`) |
| `INFLUXDB_BUCKET` | No | InfluxDB bucket (default: `home_metrics`) |
| `GRAFANA_ADMIN_USER` | No | Grafana admin username (default: `admin`) |
| `GRAFANA_ADMIN_PASSWORD` | No | Grafana admin password (default: `admin`) |

#### Solar Collector

| Variable | Required | Description |
|---|---|---|
| `SOLAR_ENPHASE_HOST` | Yes | IP address of your Enphase IQ Gateway |
| `SOLAR_ENPHASE_TOKEN` | Yes | JWT token from https://entrez.enphaseenergy.com/tokens |
| `SOLAR_COLLECT_INTERVAL` | No | Poll interval in seconds (default: `60`) |

> **Note:** Docker containers cannot resolve mDNS (`.local`) hostnames. Find your gateway's IP with `ping envoy.local` from the host and use that for `SOLAR_ENPHASE_HOST`.

#### Weather Collector

| Variable | Required | Description |
|---|---|---|
| `WEATHER_LATITUDE` | Yes | Your location's latitude |
| `WEATHER_LONGITUDE` | Yes | Your location's longitude |
| `WEATHER_COLLECT_INTERVAL` | No | Poll interval in seconds (default: `300`) |

Find your coordinates at https://open-meteo.com/en/docs.

### 2. Start

```bash
./start.sh
```

On first start each collector will spend ~30-60 seconds installing gems into a persistent cache volume. Subsequent restarts are instant.

### 3. View logs

```bash
docker logs -f hm-solar-collector
docker logs -f hm-weather-collector
```

### 4. Open Grafana

Visit **http://localhost:3000** (default credentials: admin / admin).

Solar and weather dashboards are pre-loaded.

## Architecture

Two separate Docker Compose files share an external network (`hm-monitoring`):

- **infra/** — InfluxDB + Grafana
- **collectors/solar/** — Enphase gateway collector
- **collectors/weather/** — Open-Meteo weather collector

Collectors share common InfluxDB client setup via `collectors/shared/collector.rb`, mounted into each container.

The `start.sh` script starts infra first (creates the network), then iterates `collectors/*/` to start each collector. `stop.sh` does the reverse.
