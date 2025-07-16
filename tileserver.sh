docker run --rm -it \
    -v ./data:/data \
    -p 8000:8080 \
    --name tileserver \
    maptiler/tileserver-gl:latest