#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

echo "Starting infra..."
docker-compose --env-file .env -f infra/docker-compose.yml up -d

for dir in collectors/*/; do
  if [ -f "$dir/docker-compose.yml" ]; then
    echo "Starting $(basename "$dir")..."
    docker-compose --env-file .env -f "$dir/docker-compose.yml" up -d
  fi
done

source .env
echo "Done. Grafana at http://localhost:${GRAFANA_PORT:-3030}"
