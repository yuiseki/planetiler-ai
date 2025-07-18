#!/bin/bash
docker run \
    -u `id -u`:`id -g` \
    --memory 20g --memory-swap -1 \
    -e JAVA_TOOL_OPTIONS="-Xms8g -Xmx8g" \
    -v "$(pwd)/data":/data \
    ghcr.io/onthegomap/planetiler:latest \
        generate-custom \
        --schema=/data/admins.yml \
        --output=/data/admins.mbtiles \
        --force \
        --download

