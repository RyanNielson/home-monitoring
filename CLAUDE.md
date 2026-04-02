# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Home monitoring stack that collects real-time data from various sources and visualizes it in Grafana, backed by InfluxDB.

## Architecture

Infrastructure runs in Docker; collectors are either Docker Compose projects or host-native processes:

- **infra/** — InfluxDB 2.7 + Grafana (the `hm-infra` compose project)
- **collectors/solar/** — Ruby script polling the Enphase gateway every 60s (Docker)
- **collectors/weather/** — Ruby script polling Open-Meteo API (Docker)
- **collectors/network/** — Ruby script for ping/DNS/HTTP/speedtest metrics (Docker)
- **collectors/system/** — Telegraf running natively on macOS for CPU, memory, disk, network, and battery metrics (host-native, not Docker)

This split lets collectors be added/removed independently. The `start.sh` script starts infra first (creates the network), then iterates `collectors/*/` to start each collector. Docker collectors use `docker-compose.yml`; host-native collectors use their own `start.sh`/`stop.sh` scripts.

### Data flow

```
Enphase Gateway → (HTTPS/JWT) → Ruby Collector → InfluxDB → Grafana
Open-Meteo API  → (HTTPS)     → Ruby Collector → InfluxDB → Grafana
Network targets → (ping/HTTP) → Ruby Collector → InfluxDB → Grafana
macOS host      → (Telegraf)  →                  InfluxDB → Grafana
```

### Key conventions

- All Docker resource names (containers, volumes, network) are prefixed with `hm-` to avoid clashes.
- Docker collectors reference InfluxDB via the Docker service name (`http://influxdb:8086`); host-native collectors use `http://localhost:8086`.
- Grafana datasource/dashboard provisioning lives in `infra/grafana/provisioning/` and uses environment variable substitution for tokens/org/bucket.
- The Enphase gateway uses a self-signed cert, so both the Ruby collector (`VERIFY_NONE`) and Grafana datasource (`tlsSkipVerify`) disable SSL verification.
- The system collector (Telegraf) auto-installs via Homebrew on first run and is managed via a PID file (`.telegraf.pid`).

## Commands

```bash
# Start everything (infra first, then collectors)
./start.sh

# Stop everything (collectors first, then infra)
./stop.sh

# Or manually:
docker compose --env-file .env -f infra/docker-compose.yml up -d
docker compose --env-file .env -f collectors/solar/docker-compose.yml up -d

# View collector logs
docker logs -f hm-solar-collector
tail -f logs/telegraf.log

# Grafana UI
open http://localhost:3000
```

## Configuration

All config is in `.env` (see `.env.example`). Key variables: `ENPHASE_HOST`, `ENPHASE_TOKEN`, `INFLUXDB_TOKEN`. Docker containers on macOS can't resolve mDNS, so `ENPHASE_HOST` should be set to the gateway's IP address.
