docker run \
    --memory 90g \
    --memory-swap 90g \
    --memory-swappiness 10 \
    --shm-size=40g \
    --rm \
    -it \
    -e PBF_PATH=/nominatim/data/planet-latest.osm.pbf \
    -e IMPORT_STYLE=admin \
    -p 8001:8080 \
    -v nominatim-flatnode:/nominatim/flatnode \
    -v nominatim-postgresql:/var/lib/postgresql/16/main \
    -v ./data:/nominatim/data \
    --name nominatim_planet \
    mediagis/nominatim:5.1
