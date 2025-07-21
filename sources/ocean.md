# Ocean Water Polygons (from OSM)

- **Overview**: High-resolution water polygons derived from OpenStreetMap data, split for efficient rendering. This is more detailed than the Natural Earth ocean data and is suitable for higher zoom levels.
- **Attribution**: © OpenStreetMap contributors (Data processed by osmdata.openstreetmap.de)
- **Usage Example**:

  **Source Definition (`ocean.yml`):**
  ```yaml
  sources:
    ocean:
      type: shapefile
      url: https://osmdata.openstreetmap.de/download/water-polygons-split-3857.zip
  ```

  **Layer Example (`schema.yml`):**
  ```yaml
  layers:
    ocean_osm:
      source: ocean
      source_layer: water-polygons-split-3857
  ```
