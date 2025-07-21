# Natural Earth Lakes

- **Overview**: Provides polygons for major lakes and reservoirs at a 1:50m scale. Useful for displaying significant inland water bodies.
- **Attribution**: Made with Natural Earth.
- **Usage Example**:

  **Source Definition (`natural_earth_lakes.yml`):**
  ```yaml
  sources:
    natural_earth_lakes:
      type: shapefile
      url: https://naturalearth.s3.amazonaws.com/50m_physical/ne_50m_lakes.zip
  ```

  **Layer Example (`schema.yml`):**
  ```yaml
  layers:
    lakes:
      source: natural_earth_lakes
      source_layer: ne_50m_lakes # Shapefile name
  ```
