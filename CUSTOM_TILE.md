# Planetiler Custom Theme Guide for AI Agents

This document describes the minimum necessary steps for an AI agent to add a new custom vector tile theme using Planetiler.

---

## Project Philosophy: Three Principles for Creating Valuable Maps

To maximize the potential of the `planetiler-ai` project, the following three principles are crucial. AI agents should always keep these principles in mind when proposing and creating new themes.

1.  **Maximize the Use of OpenStreetMap (OSM)**
    -   OSM is the most important data source and the foundation of this project. By deeply understanding its vast and detailed data and utilizing it in creative ways, you can derive unique and valuable insights. Aim to go beyond simple feature mapping by analyzing tag combinations and relations to uncover previously unvisualized relationships and patterns.

2.  **Actively Utilize Global Sources Other Than OSM**
    -   To capture global phenomena that cannot be expressed with OSM alone, constantly search for and actively utilize open data sources that cover the entire world. By combining not only established sources like Natural Earth but also datasets published by specialized institutions in various fields (e.g., meteorology, oceanography, energy, economics), you can add multi-layered, professional depth to your maps.

3.  **Maximize Visual Impact at Zoom 0**
    -   The maps you create should have a powerful visual impact at Zoom 0—that is, when viewing the entire Earth—so that the most important message of the theme is conveyed at a glance. Design your schema and style to use bold simplification and symbolic representation at low zoom levels, with detailed information appearing as you zoom in. It is crucial to communicate global challenges and insights intuitively and beautifully.

---

## Prerequisites

-   `data/planet-latest.osm.pbf` must exist.

---

## Troubleshooting: Common Mistakes

Planetiler's schema definition is very flexible, but this also makes it prone to errors if certain conventions are not followed. Below are common mistakes that AI agents tend to make and their solutions.

1.  **Incorrect `sources` format (`Cannot deserialize... from Array value`)**
    -   **Problem**: Defining `sources` as an array (list). Planetiler expects a map format with keys.
    -   **Solution**: Use the `name` of each data source as a top-level key.
        ```yaml
        # Incorrect
        sources:
          - name: osm
            type: osm
            ...
        # Correct
        sources:
          osm:
            type: osm
            ...
        ```

2.  **Incorrect OSM file path specification (`Unrecognized field "path"`)**
    -   **Problem**: Specifying the OSM data source path with `path`.
    -   **Solution**: The correct key is `local_path`.
        ```yaml
        # Incorrect
        osm:
          type: osm
          path: /data/planet-latest.osm.pbf
        # Correct
        osm:
          type: osm
          local_path: /data/planet-latest.osm.pbf
        ```

3.  **Incorrect layer structure (`Unrecognized field "source_layer"`)**
    -   **Problem**: Defining `source` or `source_layer` directly under `layers`.
    -   **Solution**: Create a `features` list within each layer definition (`id`) and define the feature details (`source`, `geometry`, `include_when`, etc.) inside it. `source_layer` is not a property of `features` but is used within `include_when`.
        ```yaml
        # Incorrect
        - id: "land"
          source: natural_earth
          source_layer: "ne_50m_land"
          geometry: polygon
        # Correct
        - id: "land"
          features:
            - source: natural_earth
              geometry: polygon
              include_when:
                '${ feature.source_layer }': ne_50m_land
        ```

4.  **Incorrect `type` for remote sources (`Cannot deserialize... from String "url"`)**
    -   **Problem**: Setting the `type` of a data source fetched from a URL to `url`.
    -   **Solution**: Specify the data type (e.g., `shapefile`, `geopackage`) for `type`, not `url`.
        ```yaml
        # Incorrect
        natural_earth:
          type: url
          url: https://.../ne_50m_land.zip
        # Correct
        natural_earth:
          type: shapefile
          url: https://.../ne_50m_land.zip
        ```

5.  **Data source not downloading (`... does not exist. Run with --download`)**
    -   **Problem**: Remote data sources (like Natural Earth) are not found when running `make`.
    -   **Solution**: Ensure the `--download` flag is set in the `generate-custom` command for the corresponding target in the `Makefile`. It is included by default in most theme generation commands.
        ```makefile
        # Example in Makefile
        themename:
        	... generate-custom \
        		...
        		--download \
        		--force
        ```

---

## Available Data Source Formats

In addition to OpenStreetMap data, Planetiler can integrate and use various formats of vector data sources. When designing a new theme, consider creatively combining these data sources.

The `type` to specify when defining in the `sources` section of `schema.yml` is as follows:

-   **`osm`**: OpenStreetMap PBF format (`.osm.pbf`). The primary data source for the project.
-   **`shapefile`**: Esri Shapefile format (zip file containing `.shp`). Widely used for geospatial data.
-   **`geopackage`**: OGC GeoPackage format (`.gpkg`). A more modern, single-file format alternative to Shapefile.
-   **`geojson`**: GeoJSON format (`.geojson` or `.json`). A lightweight format standardly used on the web.

These sources can be specified by a local path (`local_path`) or a URL (`url`). If a URL is specified, ensure that the `--download` flag is used in the `Makefile` target.

---

## New Theme Addition Workflow

The procedure for adding a new theme `{THEME_NAME}` consists of the following three steps.

### Step 1: Create Theme Assets (`theme/{THEME_NAME}/`)

Create the definition files for the new theme. To streamline the work and maintain consistency, it is strongly recommended to copy an existing theme from the `theme` directory (e.g., `railways`) and modify it.

1.  **Create Schema Definition (`schema.yml`)**
    -   Create `theme/{THEME_NAME}/schema.yml`.
    -   **Purpose**: To define which data to extract from OpenStreetMap and other data sources, and what the layer structure should be.
    -   **Required Items**: 
        -   `schema_name`, `schema_description`, `attribution`
        -   `sources`: Define the data sources.
            -   **OSM**: As a project convention, always include `/data/planet-latest.osm.pbf` as the `osm` source.
            -   **Natural Earth**: It is standard to include `natural_earth` as a URL source for low-zoom level base maps.
            -   **Other Sources**: If necessary, you can use additional vector sources like GeoPackage or Shapefile. Data can be made available to Planetiler by placing it under the `data` directory or by specifying a URL.
        -   `layers`:
            -   Define `land`, `ocean`, `lakes` layers for the background from the Natural Earth source.
            -   Define layers to extract thematic features (e.g., `waterway: river`) from the OSM source.

2.  **Create Style Definition (`style.json`)**
    -   Create `theme/{THEME_NAME}/style.json`.
    -   **Purpose**: To define how to visually render the layers defined in `schema.yml` (colors, line widths, etc.).
    -   **Important Conventions**:
        -   The key for the `sources` object should be `{THEME_NAME}`, and the `url` should be set to `mbtiles://{{THEME_NAME}}` according to convention.
        -   The `source` for `layers` should be `{THEME_NAME}`, and the `source-layer` must match the `id` defined in `schema.yml`.

### Step 2: Generate Vector Tiles

Generate the `.mbtiles` file based on the defined schema. This project uses a `Makefile` to manage the tile generation process for each theme.

1.  **Add Target to Makefile (if necessary)**
    -   Add a target for the new theme `{THEME_NAME}` to the `Makefile`.
    -   **Purpose**: To enable running tile generation with the `make {THEME_NAME}` command.
    -   Since many themes follow a common pattern, you can easily add them using the `generate_theme` macro.
        ```makefile
        # Add a theme with a common pattern at the end of the Makefile
        $(eval $(call generate_theme,{THEME_NAME}))
        ```
    -   If the theme requires special parameters (like different memory settings), define a new target by referencing existing custom targets (e.g., `healthcare`, `monaco`).
        ```makefile
        # Example of adding a custom target to the Makefile
        {THEME_NAME}:
        	@echo "Generating theme: {THEME_NAME}..."
        	@cp "theme/{THEME_NAME}/schema.yml" "data/{THEME_NAME}.yml"
        	$(DOCKER_RUN) generate-custom \
        		--schema=/data/{THEME_NAME}.yml \
        		--output=/data/{THEME_NAME}.mbtiles \
        		--download \
        		--force
        ```

2.  **Run the Generation Process**
    -   Simply run the following command to execute tile generation. The `Makefile` recipe will also automatically copy the schema.
    ```bash
    # Run tile generation (this will take time)
    make {THEME_NAME}
    ```

### Step 3: Configure the Tile Server

Configure the tile server to serve the generated tiles and style.

1.  **Copy the Style File**
    -   Copy the style file to the `data` directory.
    ```bash
    cp theme/{THEME_NAME}/style.json data/{THEME_NAME}.json
    ```

2.  **Update Configuration File (`config.json`)**
    -   Edit `data/config.json` and add entries for the new theme to both the `styles` and `data` objects.
    -   **Add to the `styles` object:**
        ```json
        "{\"THEME_NAME\"}": {
          "style": "{\"THEME_NAME\"}.json"
        }
        ```
    -   **Add to the `data` object:**
        ```json
        "{\"THEME_NAME\"}": {
          "mbtiles": "{\"THEME_NAME\"}.mbtiles"
        }
        ```

With these steps, the addition of a new custom theme is complete.
