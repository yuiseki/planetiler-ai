#!/bin/bash
# This script runs the Planetiler process to generate the human_security.mbtiles file.

# Stop on first error
set -e

THEME_NAME="human_security"

# Copy the schema file to the data directory, where Planetiler can access it.
# The Docker container mounts the `data` directory to `/data`.
echo "Copying schema file..."
cp "theme/${THEME_NAME}/schema.yml" "data/${THEME_NAME}.yml"

echo "Running Planetiler..."
docker run \
    -u `id -u`:`id -g` \
    --memory 20g --memory-swap -1 \
    -e JAVA_TOOL_OPTIONS="-Xms8g -Xmx8g" \
    -v "$(pwd)/data":/data \
    ghcr.io/onthegomap/planetiler:latest \
        generate-custom \
        --schema=/data/${THEME_NAME}.yml \
        --output=/data/${THEME_NAME}.mbtiles \
        --download \
        --force

echo "Planetiler process finished for theme: ${THEME_NAME}"
echo "Next steps:"
echo "1. Copy the style file: cp theme/${THEME_NAME}/style.json data/${THEME_NAME}.json"
echo "2. Update data/config.json to include the new theme."

