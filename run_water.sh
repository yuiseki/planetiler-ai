docker run \
    -u `id -u`:`id -g` \
    -v "$(pwd)/data":/data \
    ghcr.io/onthegomap/planetiler:latest \
        generate-custom \
            --schema=/data/water.yml \
            --download \
            --download-threads=16 \
            --download-chunk-size-mb=1000 \
            --output=/data/water.mbtiles \
            --force
