# Submarine Cables

- **Overview**: A GeoJSON dataset of the world's submarine telecommunication cables. Ideal for visualizing global connectivity infrastructure.
- **Attribution**: Data © 2024 TeleGeography, Map © 2024 Submarine Cable Map. [submarinecablemap.com](https://www.submarinecablemap.com)
- **Usage Example**:

  **Source Definition (`submarine_cables.yml`):**
  ```yaml
  sources:
    submarine_cables:
      type: geojson
      url: https://www.submarinecablemap.com/api/v3/cable/cable-geo.json
  ```

  **Layer Example (`schema.yml`):**
  ```yaml
  layers:
    cables:
      source: submarine_cables
      # source_layer is not needed for single-layer GeoJSON
  ```
