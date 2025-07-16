docker run \
    -u `id -u`:`id -g` \
    -v "$(pwd)/data":/data \
    ghcr.io/onthegomap/planetiler:latest \
        generate-custom \
            --schema=/data/schema.yml \
            --download \
            --download-threads=16 \
            --download-chunk-size-mb=1000 \
            --output=/data/custom.mbtiles \
            --force
