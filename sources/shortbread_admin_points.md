# Shortbread Admin Points

- **Overview**: Provides administrative points (e.g., capitals, major cities) derived from OpenStreetMap data. This dataset is part of Geofabrik's "Shortbread" project.
- **Attribution**: © OpenStreetMap contributors (Data from Geofabrik GmbH)
- **Usage Example**:

  **Source Definition (`shortbread_admin_points.yml`):**
  ```yaml
  sources:
    admin_points:
      type: shapefile
      url: https://shortbread.geofabrik.de/shapefiles/admin-points-4326.zip
  ```

  **Layer Example (`schema.yml`):**
  ```yaml
  layers:
    capital_cities:
      source: admin_points
      source_layer: admin-points-4326
      features:
        - admin_level: 2 # Filter for national capitals
  ```
