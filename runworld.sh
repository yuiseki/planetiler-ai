docker run \
    -u `id -u`:`id -g` \
    --memory 90g \
    --memory-swap 90g \
    --memory-swappiness 10 \
    -e JAVA_TOOL_OPTIONS="-XX:+AlwaysPreTouch -Xms28g -Xmx28g" \
    -v "$(pwd)/data":/data \
    ghcr.io/onthegomap/planetiler:latest \
        --area=planet \
        --bounds=planet \
        --download \
        --download-threads=16 \
        --download-chunk-size-mb=1000 \
        --fetch-wikidata \
        --nodemap-type=sparsearray \
        --nodemap-storage=mmap \
        --osm-path=/data/planet-250707.osm.pbf \
        --force