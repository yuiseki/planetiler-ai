# Gemini Agent Operation Manual for Planetiler-AI

This document outlines the operational workflow for me, the Gemini agent, to autonomously create and manage custom vector tile themes within the `planetiler-ai` project.

---

## 1. Guiding Principles

My actions will be guided by the three core principles of this project:

1.  **Maximize the Use of OpenStreetMap (OSM)**: I will leverage the rich, detailed data in OSM to create unique and valuable maps, analyzing tags and relations to uncover new patterns.
2.  **Actively Utilize Global Sources Other Than OSM**: I will seek out and integrate diverse, open global datasets to add multi-layered depth to the maps, capturing phenomena beyond what OSM can represent.
3.  **Maximize Visual Impact at Zoom 0**: I will design themes so that their core message is immediately clear and visually impactful when viewing the entire globe.

---

## 2. New Theme Creation Workflow: `{THEME_NAME}`

I will follow these steps to add a new theme.

### Step 1: Create Theme Assets

1.  **Analyze Existing Themes**: I will first examine the `theme/` directory to understand existing conventions for schema and style.
2.  **Create `schema.yml`**: I will create `theme/{THEME_NAME}/schema.yml`. This file will define the data sources and layer structure.
    -   **Sources**: It will always include `osm` pointing to `/data/planet-latest.osm.pbf` and typically `natural_earth` for base layers.
    -   **Layers**: It will define layers for background (land, ocean) and the thematic features.
3.  **Create `style.json`**: I will create `theme/{THEME_NAME}/style.json`.
    -   The `sources` key will be `{THEME_NAME}`.
    -   The `url` will be `mbtiles://{{THEME_NAME}}`.
    -   The `source-layer` in each layer style will match the layer `id` from `schema.yml`.

### Step 2: Generate Vector Tiles

1.  **Update Makefile**: I will add a new target for `{THEME_NAME}` to the `Makefile`, typically using the `generate_theme` macro if no special parameters are needed.
    ```makefile
    $(eval $(call generate_theme,{THEME_NAME}))
    ```
2.  **Run Tile Generation**: I will execute the build process using `make {THEME_NAME}`.
    -   **CRITICAL SAFETY CHECK**: Before running the `make` command, I will execute the following shell script to ensure no other Planetiler process is running. If a process is found, I will wait for 5 minutes and retry, looping until the process is clear.
      ```bash
      while ps aux | grep 'planetiler' | grep -v grep > /dev/null; do
        echo "Another Planetiler process is running. Waiting 5 minutes..."
        sleep 300
      done
      echo "No Planetiler process found. Proceeding with generation."
      make {THEME_NAME}
      ```

### Step 3: Configure Tile Server

1.  **Copy Style File**: I will copy the theme's style to the data directory.
    ```bash
    cp theme/{THEME_NAME}/style.json data/{THEME_NAME}.json
    ```
2.  **Update `config.json`**: I will read `data/config.json`, add the new theme configuration, and write it back.
    -   Add to `styles`:
      ```json
      "{THEME_NAME}": {
        "style": "{THEME_NAME}.json"
      }
      ```
    -   Add to `data`:
      ```json
      "{THEME_NAME}": {
        "mbtiles": "{THEME_NAME}.mbtiles"
      }
      ```

### Step 4: Verify Changes

1.  **Restart Server**: I will restart the tile server to load the new configuration.
    ```bash
    docker compose restart tileserver
    ```
2.  **Take Screenshot**: I will use `screenshot.js` to capture a visual of the new map to confirm the changes were applied correctly. The theme name will be passed as an environment variable.
    ```bash
    THEME={THEME_NAME} OUTPUT={THEME_NAME}.png node screenshot.js
    ```
3.  **Troubleshooting**: If the screenshot fails or the server doesn't respond, I will check the container logs to diagnose the issue.
    ```bash
    docker compose logs tileserver | tail -n 30
    ```
This ensures a complete, verified, and safe workflow for every new theme.
