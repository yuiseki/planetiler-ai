docker run \
    -u `id -u`:`id -g` \
    -e JAVA_TOOL_OPTIONS="-Xmx1g" \
    -v "$(pwd)/data":/data \
    ghcr.io/onthegomap/planetiler:latest \
        --download \
        --area=monaco \
        --download-threads=16 \
        --download-chunk-size-mb=1000 \
        --output=/data/monaco.mbtiles \
        --force
