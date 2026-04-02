#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

for dir in collectors/*/; do
  if [ -f "$dir/docker-compose.yml" ]; then
    echo "Stopping $(basename "$dir")..."
    docker-compose --env-file .env -f "$dir/docker-compose.yml" down
  elif [ -f "$dir/stop.sh" ]; then
    echo "Stopping $(basename "$dir")..."
    bash "$dir/stop.sh"
  fi
done

echo "Stopping infra..."
docker-compose --env-file .env -f infra/docker-compose.yml down
