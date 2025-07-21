# Tectonic Plates

- **Overview**: GeoJSON data representing the Earth's tectonic plates, based on the PB2002 model. Useful for geological and geophysical visualizations.
- **Attribution**: Peter Bird (2003), provided as GeoJSON by user `fraxen` on GitHub.
- **Usage Example**:

  **Source Definition (`tectonic_plates.yml`):**
  ```yaml
  sources:
    tectonic_plates:
      type: geojson
      url: https://raw.githubusercontent.com/fraxen/tectonicplates/master/GeoJSON/PB2002_plates.json
  ```

  **Layer Example (`schema.yml`):**
  ```yaml
  layers:
    plates:
      source: tectonic_plates
      # source_layer is not needed for single-layer GeoJSON
  ```
