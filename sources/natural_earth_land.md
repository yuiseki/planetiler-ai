# Natural Earth Land

- **Overview**: Contains land polygons, including major islands, at a 1:50m scale. This is a fundamental dataset for creating a base land layer.
- **Attribution**: Made with Natural Earth.
- **Usage Example**:

  **Source Definition (`natural_earth_land.yml`):**
  ```yaml
  sources:
    natural_earth_land:
      type: shapefile
      url: https://naturalearth.s3.amazonaws.com/50m_physical/ne_50m_land.zip
  ```

  **Layer Example (`schema.yml`):**
  ```yaml
  layers:
    land:
      source: natural_earth_land
      source_layer: ne_50m_land
  ```
