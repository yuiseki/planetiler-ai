# Natural Earth (General Vector Data)

- **Overview**: A comprehensive global dataset containing physical and cultural vector data in a single GeoPackage. It's ideal for creating base maps with features like country borders, coastlines, and major rivers.
- **Attribution**: Made with Natural Earth. Free vector and raster map data @ [naturalearthdata.com](https://www.naturalearthdata.com).
- **Usage Example**:

  **Source Definition (`natural_earth.yml`):**
  ```yaml
  sources:
    natural_earth:
      type: geopackage
      url: "https://naciscdn.org/naturalearth/packages/natural_earth_vector.gpkg.zip"
      projection: EPSG:4326
  ```

  **Layer Example (`schema.yml`):**
  ```yaml
  layers:
    countries:
      source: natural_earth
      source_layer: ne_10m_admin_0_countries # Layer name within the GeoPackage
      # ... other properties
  ```
