# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Home solar monitoring stack that collects real-time data from an Enphase IQ Gateway and visualizes it in Grafana, backed by InfluxDB.

## Architecture

Two separate Docker Compose files share an external network (`hm-monitoring`):

- **infra/** — InfluxDB 2.7 + Grafana (the `hm-infra` compose project)
- **collectors/solar/** — Ruby script polling the Enphase gateway every 60s, writing to InfluxDB (the `hm-solar` compose project)

This split lets collectors be added/removed independently. The `start.sh` script starts infra first (creates the network), then iterates `collectors/*/` to start each collector.

### Data flow

```
Enphase Gateway → (HTTPS/JWT) → Ruby Collector → InfluxDB → Grafana
```

### Key conventions

- All Docker resource names (containers, volumes, network) are prefixed with `hm-` to avoid clashes.
- Collectors reference InfluxDB via the Docker service name (`http://influxdb:8086`), not the container name.
- Grafana datasource/dashboard provisioning lives in `infra/grafana/provisioning/` and uses environment variable substitution for tokens/org/bucket.
- The Enphase gateway uses a self-signed cert, so both the Ruby collector (`VERIFY_NONE`) and Grafana datasource (`tlsSkipVerify`) disable SSL verification.

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

# Grafana UI
open http://localhost:3000
```

## Configuration

All config is in `.env` (see `.env.example`). Key variables: `ENPHASE_HOST`, `ENPHASE_TOKEN`, `INFLUXDB_TOKEN`. Docker containers on macOS can't resolve mDNS, so `ENPHASE_HOST` should be set to the gateway's IP address.
