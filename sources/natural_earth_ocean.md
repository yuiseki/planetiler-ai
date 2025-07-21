# Natural Earth Ocean

- **Overview**: Provides ocean polygons at a 1:50m scale. Essential for creating a base ocean or water layer for your map.
- **Attribution**: Made with Natural Earth.
- **Usage Example**:

  **Source Definition (`natural_earth_ocean.yml`):**
  ```yaml
  sources:
    natural_earth_ocean:
      type: shapefile
      url: https://naturalearth.s3.amazonaws.com/50m_physical/ne_50m_ocean.zip
  ```

  **Layer Example (`schema.yml`):**
  ```yaml
  layers:
    ocean:
      source: natural_earth_ocean
      source_layer: ne_50m_ocean
  ```
