# WARNING: Importing the full planet requires significant resources.
# This system has 94GB of RAM. Allocating 80GB to this container.
# Processing will likely take a very long time (potentially days).

# Pre-processing the PBF file to a format Overpass understands.
# Using --overwrite to handle retries on existing files.
export OVERPASS_PLANET_PREPROCESS="osmium cat /data/planet.osm.pbf -o /db/planet.osm.bz2 --overwrite"

docker run \
    -d \
    --memory=80g \
    -e OVERPASS_META=yes \
    -e OVERPASS_MODE=init \
    -e OVERPASS_PLANET_URL=file:///db/planet.osm.bz2 \
    -e OVERPASS_DIFF_URL=https://planet.openstreetmap.org/replication/minute/ \
    -e OVERPASS_RULES_LOAD=10 \
    -e OVERPASS_PLANET_PREPROCESS \
    -v ./data/planet-latest.osm.pbf:/data/planet.osm.pbf:ro \
    -v ./data/overpass_db_planet/:/db \
    -p 8002:80 \
    --name overpass_planet \
    wiktorn/overpass-api
