# planetiler-ai

A Proof-of-Concept for an AI agent that generates planet-scale custom map vector tiles.

---

## Example maps created by AI

### World Rivers Map
[https://tile.yuiseki.net/styles/rivers/#1/0/0](https://tile.yuiseki.net/styles/rivers/#1/0/0)

[![Image from Gyazo](https://i.gyazo.com/94e93ff6e5e60fa48cf649c635d89833.png)](https://tile.yuiseki.net/styles/rivers/#1/0/0)

### World Railways Map
[https://tile.yuiseki.net/styles/railways/#1/0/0](https://tile.yuiseki.net/styles/railways/#1/0/0)

[![Image from Gyazo](https://i.gyazo.com/6edfbe4ff7eff9a8bcaa4e439450a6a5.png)](https://tile.yuiseki.net/styles/railways/#1/0/0)

---

## Background

In December 2023, I developed an AI agent called `charites-ai`.

- https://github.com/yuiseki/charites-ai

`charites-ai` was an AI agent capable of generating styles for map vector tiles based on the existing OpenMapTiles schema using natural language.

Now, it's time to move to the next stage.

The OpenMapTiles schema is the best practice and de facto standard for how humans view map vector tiles.

However, it is no longer just humans who view and utilize map vector tiles as data. AIs also use map vector tiles.

I believed that AI agents should be able to create more specialized and diverse map vector tiles with custom schemas tailored to their own or human needs, without being constrained by the existing OpenMapTiles schema. I also thought that the challenge of having AI agents autonomously build various map vector tiles in this way has significant meaning.

This software, `planetiler-ai`, was created to demonstrate that such an AI agent is feasible.

## Overview

`planetiler-ai` is a Proof-of-Concept project for an AI agent to autonomously generate custom vector tiles for specific purposes.

This project uses [Planetiler](https://github.com/onthegomap/planetiler) as its core engine to generate lightweight vector tiles (`.mbtiles`) by extracting only necessary features (e.g., railways, rivers, water bodies) from open geospatial data sources like OpenStreetMap (OSM) and Natural Earth.

The generated tiles are served via [MapTiler Server](https://documentation.maptiler.com/hc/en-us/articles/4405443334417-MapTiler-Server) and can be visualized as maps.

An AI agent can follow the conventions of this framework to add new themes (schemas and styles) and generate execution scripts, enabling it to create new maps successively without human intervention.

## Features

-   **Autonomous Map Generation by AI**: Envisions a workflow where an AI agent defines its own schema, and completes the process up to tile generation and delivery configuration.
-   **Custom Schemas**: Allows for the construction of unique tile sets optimized for specific uses (e.g., analysis of railway networks, visualization of water systems), without being tied to general-purpose schemas like OpenMapTiles.
-   **Planetiler-Based**: Leverages Planetiler, a fast and flexible vector tile generation engine.
-   **Dockerized Environment**: Easy environment setup as `planetiler` and `tileserver-gl` run as Docker containers.

## Usage

This project is primarily intended for use by an AI agent, but it can also be run manually by humans. `CUSTOM_TILE.md` describes the detailed procedure for an AI agent to add a new theme.

### Example of generating tiles with an existing theme (Rivers)

1.  **Download the necessary data.**
    -   According to the project's conventions, place `planet-latest.osm.pbf` in the `data` directory.

2.  **Copy the schema file to the `data` directory.**
    ```bash
    cp theme/rivers/schema.yml data/rivers.yml
    ```

3.  **Run the tile generation script.**
    (This process is time-consuming and memory-intensive)
    ```bash
    chmod +x run_rivers.sh
    ./run_rivers.sh
    ```
    Upon success, `data/rivers.mbtiles` will be generated.

4.  **Start the tile server.**
    ```bash
    docker-compose up -d
    ```

5.  **Check in your browser.**
    -   Access `http://localhost:8000` to see the tile server's admin interface.
    -   To apply the style, you need to edit `data/config.json` and add a setting to reference `data/rivers.json`.

## Directory Structure

```
.
├── data/                  # Directory to store generated tiles and data sources
├── sources/               # Data source definitions (e.g., Natural Earth)
├── theme/                 # Directory to store schemas and styles for each custom theme
│   ├── railways/
│   │   ├── schema.yml     # Schema definition for the railway theme
│   │   └── style.json     # Style definition for the railway theme
│   ├── rivers/
│   │   └── ...
│   └── water/
│       └── ...
├── CUSTOM_SCHEME_TILE.md  # Guide for AI agents to add custom themes
├── run_*.sh               # Execution scripts to generate tiles for each theme
└── docker-compose.yml     # Configuration file to start the tile server
```
