# Planetiler-AI Makefile

# Default memory settings for Planetiler
MEMORY_OPTIONS_LEGACY = --memory 20g --memory-swap -1
MEMORY_OPTIONS_32G = --memory 40g --memory-swap -1
MEMORY_OPTIONS_64G = --memory 64g --memory-swap -1
MEMORY_OPTIONS = $(MEMORY_OPTIONS_32G)

JAVA_TOOL_OPTIONS_LEGACY = -Xms8g -Xmx8g
JAVA_TOOL_OPTIONS_G1_32G = -Xms32g -Xmx32g
JAVA_TOOL_OPTIONS_ZGC_32G = -XX:+UseZGC -Xms32g -Xmx32g
JAVA_TOOL_OPTIONS = $(JAVA_TOOL_OPTIONS_ZGC_32G)

pwd = $(shell pwd)
DOCKER_IMAGE = ghcr.io/onthegomap/planetiler:latest

# Common Docker run command
define docker_run_with_java
docker run \
    -u `id -u`:`id -g` \
    $(1) \
    -e JAVA_TOOL_OPTIONS="$(2)" \
    -v "$(pwd)/data":/data \
    -v "/everything/osm/planet":/osm_planet:ro \
    $(DOCKER_IMAGE)
endef

DOCKER_RUN = $(call docker_run_with_java,$(MEMORY_OPTIONS),$(JAVA_TOOL_OPTIONS))
DOCKER_RUN_LEGACY = $(call docker_run_with_java,$(MEMORY_OPTIONS_LEGACY),$(JAVA_TOOL_OPTIONS_LEGACY))
DOCKER_RUN_G1_32G = $(call docker_run_with_java,$(MEMORY_OPTIONS_32G),$(JAVA_TOOL_OPTIONS_G1_32G))
DOCKER_RUN_ZGC_32G = $(call docker_run_with_java,$(MEMORY_OPTIONS_32G),$(JAVA_TOOL_OPTIONS_ZGC_32G))
DOCKER_RUN_ZGC_32G_CONTAINER_64G = $(call docker_run_with_java,$(MEMORY_OPTIONS_64G),$(JAVA_TOOL_OPTIONS_ZGC_32G))

FULL_PLANET_PBF = data/planet-latest.osm.pbf
JAPAN_OSM_URL = https://download.geofabrik.de/asia/japan-latest.osm.pbf
JAPAN_OSM_PBF = data/japan-latest.osm.pbf
PLANET_TILE_CONFIG = benchmarks/planet_tiles_z2.json
PLANET_TILE_ROOT_DIR = data/planet_tiles
PLANET_TILE_DIR = $(PLANET_TILE_ROOT_DIR)/simple
PLANET_TILE_COMPLETE_WAYS_DIR = $(PLANET_TILE_ROOT_DIR)/complete_ways
PLANET_TILE_FILTER_DIR = data/planet_tiles_filtered
BENCHMARK_DIR = data/benchmarks
PLANET_TILE_PARALLELISM ?= 16
PLANET_TILE_EXTRACT_STRATEGY = simple

$(JAPAN_OSM_PBF):
	@echo "=== download japan-latest.osm.pbf start: $$(date -Iseconds) ==="
	@rm -f "$@.tmp"
	curl -L --fail --progress-bar "$(JAPAN_OSM_URL)" -o "$@.tmp"
	@mv "$@.tmp" "$@"
	@echo "=== download japan-latest.osm.pbf end: $$(date -Iseconds) ==="
	@ls -lh "$@"

# Default target
all:
	@echo "Please specify a target. Available targets are:"
	@echo "  admins,"
	@echo "  conflicts,"
	@echo "  custom,"
	@echo "  healthcare,"
	@echo "  monaco,"
	@echo "  railways,"
	@echo "  railways_jp,"
	@echo "  rivers,"
	@echo "  water,"
	@echo "  world,"

# Target to generate a specific theme
define generate_theme
.PHONY: $(1)
$(1):
	@echo "Generating theme: $(1)..."
	@cp "theme/$(1)/schema.yml" "data/$(1).yml"
	$(DOCKER_RUN) generate-custom \
		--schema=/data/$(1).yml \
		--output=/data/$(1).mbtiles \
		--download \
		--force
	@echo "Theme $(1) generated successfully."
	@echo "Next steps:"
	@echo "1. Copy the style file: cp theme/$(1)/style.json data/$(1).json"
	@echo "2. Update data/config.json to include the new theme."
endef

define generate_theme_pre_filter
data/planet-$(1).osm.pbf: $(PREFILTER_INPUT_$(1))
	@echo "=== osmium tags-filter ($(1)) start: $$$$(date -Iseconds) ==="
	time osmium tags-filter \
		$(PREFILTER_INPUT_$(1)) \
		$(PREFILTER_FILTER_$(1)) \
		-o data/planet-$(1).osm.pbf \
		--overwrite --progress --verbose
	@echo "=== osmium tags-filter ($(1)) end: $$$$(date -Iseconds) ==="
	@ls -lh data/planet-$(1).osm.pbf

.PHONY: planet-$(1)-pbf
planet-$(1)-pbf: data/planet-$(1).osm.pbf

.PHONY: $(1)-pre-filter
$(1)-pre-filter: data/planet-$(1).osm.pbf
	@echo "=== $(1)-pre-filter start: $$$$(date -Iseconds) ==="
	@$(PREFILTER_PREPARE_$(1))
	@cp "theme/$(1)/schema.yml" "data/$(1)-pre-filter.yml"
	@sed -i 's|$(PREFILTER_SCHEMA_MATCH_$(1))|$(PREFILTER_SCHEMA_REPLACE_$(1))|' "data/$(1)-pre-filter.yml"
	$(PREFILTER_DOCKER_RUN_$(1)) generate-custom \
		--schema=/data/$(1)-pre-filter.yml \
		--output=/data/$(1)-pre-filter.mbtiles \
		$(PREFILTER_GENERATE_FLAGS_$(1)) \
		--force
	@echo "=== $(1)-pre-filter end: $$$$(date -Iseconds) ==="
endef

define benchmark_tiled_tags_filter
.PHONY: $(1)-single-bench
$(1)-single-bench: | $(BENCHMARK_DIR)
	@echo "=== $(1) single-pass benchmark start: $$$$(date -Iseconds) ==="
	@rm -f "$(BENCHMARK_DIR)/$(1)-single.osm.pbf" "$(BENCHMARK_DIR)/$(1)-single.time.txt"
	/usr/bin/time -v -o "$(BENCHMARK_DIR)/$(1)-single.time.txt" \
		osmium tags-filter \
			$(FULL_PLANET_PBF) \
			$(2) \
			-o "$(BENCHMARK_DIR)/$(1)-single.osm.pbf" \
			--overwrite --no-progress
	@ls -lh "$(BENCHMARK_DIR)/$(1)-single.osm.pbf"
	@echo "=== $(1) single-pass benchmark end: $$$$(date -Iseconds) ==="

.PHONY: $(1)-tiled-bench
$(1)-tiled-bench: $(PLANET_TILE_DIR)/.extract-complete | $(BENCHMARK_DIR)
	@echo "=== $(1) tiled-parallel benchmark start: $$$$(date -Iseconds) ==="
	@rm -rf "$(PLANET_TILE_FILTER_DIR)/$(1)"
	@mkdir -p "$(PLANET_TILE_FILTER_DIR)/$(1)"
	@rm -f "$(BENCHMARK_DIR)/$(1)-tiled.osm.pbf" "$(BENCHMARK_DIR)/$(1)-tiled-filter.time.txt" "$(BENCHMARK_DIR)/$(1)-tiled-merge.time.txt"
	/usr/bin/time -v -o "$(BENCHMARK_DIR)/$(1)-tiled-filter.time.txt" \
		bash -lc 'set -euo pipefail; \
		running=0; \
		for tile in $(PLANET_TILE_DIR)/*.osm.pbf; do \
			in="$$$$tile"; \
			base=$$$$(basename "$$$$in"); \
			osmium tags-filter "$$$$in" $(2) -o "$(PLANET_TILE_FILTER_DIR)/$(1)/$$$$base" --overwrite --no-progress & \
			running=$$$$((running + 1)); \
			if [ "$$$$running" -ge "$(PLANET_TILE_PARALLELISM)" ]; then \
				wait -n; \
				running=$$$$((running - 1)); \
			fi; \
		done; \
		wait'
	/usr/bin/time -v -o "$(BENCHMARK_DIR)/$(1)-tiled-merge.time.txt" \
		osmium merge \
			"$(PLANET_TILE_FILTER_DIR)/$(1)"/*.osm.pbf \
			-o "$(BENCHMARK_DIR)/$(1)-tiled.osm.pbf" \
			--overwrite --no-progress
	@ls -lh "$(BENCHMARK_DIR)/$(1)-tiled.osm.pbf"
	@echo "=== $(1) tiled-parallel benchmark end: $$$$(date -Iseconds) ==="
endef

define benchmark_planetiler_gc_prefilter
.PHONY: $(1)-pre-filter-g1-32g
$(1)-pre-filter-g1-32g: data/planet-$(1).osm.pbf | $(BENCHMARK_DIR)
	@echo "=== $(1) pre-filter G1 32g benchmark start: $$$$(date -Iseconds) ==="
	@cp "theme/$(1)/schema.yml" "data/$(1)-pre-filter-g1-32g.yml"
	@sed -i 's|/data/planet-latest.osm.pbf|/data/planet-$(1).osm.pbf|' "data/$(1)-pre-filter-g1-32g.yml"
	@rm -f "$(BENCHMARK_DIR)/$(1)-pre-filter-g1-32g.mbtiles" "$(BENCHMARK_DIR)/$(1)-pre-filter-g1-32g.time.txt"
	/usr/bin/time -v -o "$(BENCHMARK_DIR)/$(1)-pre-filter-g1-32g.time.txt" \
		$(DOCKER_RUN_G1_32G) generate-custom \
			--schema=/data/$(1)-pre-filter-g1-32g.yml \
			--output=/data/benchmarks/$(1)-pre-filter-g1-32g.mbtiles \
			--force
	@ls -lh "$(BENCHMARK_DIR)/$(1)-pre-filter-g1-32g.mbtiles"
	@echo "=== $(1) pre-filter G1 32g benchmark end: $$$$(date -Iseconds) ==="

.PHONY: $(1)-pre-filter-zgc-32g
$(1)-pre-filter-zgc-32g: data/planet-$(1).osm.pbf | $(BENCHMARK_DIR)
	@echo "=== $(1) pre-filter ZGC 32g benchmark start: $$$$(date -Iseconds) ==="
	@cp "theme/$(1)/schema.yml" "data/$(1)-pre-filter-zgc-32g.yml"
	@sed -i 's|/data/planet-latest.osm.pbf|/data/planet-$(1).osm.pbf|' "data/$(1)-pre-filter-zgc-32g.yml"
	@rm -f "$(BENCHMARK_DIR)/$(1)-pre-filter-zgc-32g.mbtiles" "$(BENCHMARK_DIR)/$(1)-pre-filter-zgc-32g.time.txt"
	/usr/bin/time -v -o "$(BENCHMARK_DIR)/$(1)-pre-filter-zgc-32g.time.txt" \
		$(DOCKER_RUN_ZGC_32G) generate-custom \
			--schema=/data/$(1)-pre-filter-zgc-32g.yml \
			--output=/data/benchmarks/$(1)-pre-filter-zgc-32g.mbtiles \
			--force
	@ls -lh "$(BENCHMARK_DIR)/$(1)-pre-filter-zgc-32g.mbtiles"
	@echo "=== $(1) pre-filter ZGC 32g benchmark end: $$$$(date -Iseconds) ==="

.PHONY: $(1)-pre-filter-zgc-32g-container-64g
$(1)-pre-filter-zgc-32g-container-64g: data/planet-$(1).osm.pbf | $(BENCHMARK_DIR)
	@echo "=== $(1) pre-filter ZGC 32g / 64g container benchmark start: $$$$(date -Iseconds) ==="
	@cp "theme/$(1)/schema.yml" "data/$(1)-pre-filter-zgc-32g-container-64g.yml"
	@sed -i 's|/data/planet-latest.osm.pbf|/data/planet-$(1).osm.pbf|' "data/$(1)-pre-filter-zgc-32g-container-64g.yml"
	@rm -f "$(BENCHMARK_DIR)/$(1)-pre-filter-zgc-32g-container-64g.mbtiles" "$(BENCHMARK_DIR)/$(1)-pre-filter-zgc-32g-container-64g.time.txt"
	/usr/bin/time -v -o "$(BENCHMARK_DIR)/$(1)-pre-filter-zgc-32g-container-64g.time.txt" \
		$(DOCKER_RUN_ZGC_32G_CONTAINER_64G) generate-custom \
			--schema=/data/$(1)-pre-filter-zgc-32g-container-64g.yml \
			--output=/data/benchmarks/$(1)-pre-filter-zgc-32g-container-64g.mbtiles \
			--force
	@ls -lh "$(BENCHMARK_DIR)/$(1)-pre-filter-zgc-32g-container-64g.mbtiles"
	@echo "=== $(1) pre-filter ZGC 32g / 64g container benchmark end: $$$$(date -Iseconds) ==="

.PHONY: $(1)-pre-filter-gc-compare
$(1)-pre-filter-gc-compare: $(1)-pre-filter-g1-32g $(1)-pre-filter-zgc-32g
endef

$(BENCHMARK_DIR):
	@mkdir -p "$@"

$(PLANET_TILE_DIR)/.extract-complete: $(FULL_PLANET_PBF) $(PLANET_TILE_CONFIG)
	@echo "=== planet z2 tile extract start: $$(date -Iseconds) ==="
	@mkdir -p "$(PLANET_TILE_DIR)"
	@rm -f "$(PLANET_TILE_DIR)"/*.osm.pbf "$@"
	time osmium extract \
		--config "$(PLANET_TILE_CONFIG)" \
		--directory "$(PLANET_TILE_DIR)" \
		--strategy="$(PLANET_TILE_EXTRACT_STRATEGY)" \
		--overwrite \
		"$(FULL_PLANET_PBF)"
	@touch "$@"
	@find "$(PLANET_TILE_DIR)" -maxdepth 1 -name '*.osm.pbf' -printf '%f\t%s\n' | sort
	@echo "=== planet z2 tile extract end: $$(date -Iseconds) ==="

.PHONY: planet-tiles-z2
planet-tiles-z2: $(PLANET_TILE_DIR)/.extract-complete

# Themes that follow the standard pattern
.PHONY: disaster_prevention
$(eval $(call generate_theme,disaster_prevention))

.PHONY: energy_transition
$(eval $(call generate_theme,energy_transition))

.PHONY: global_connectivity
$(eval $(call generate_theme,global_connectivity))

.PHONY: water_stress
$(eval $(call generate_theme,water_stress))

.PHONY: biodiversity
$(eval $(call generate_theme,biodiversity))

.PHONY: debug_test
$(eval $(call generate_theme,debug_test))

.PHONY: railways_jp
$(eval $(call generate_theme,railways_jp))

.PHONY: climate_change_impacts
$(eval $(call generate_theme,climate_change_impacts))

.PHONY: debug_test_climate
$(eval $(call generate_theme,debug_test_climate))

.PHONY: volcanoes
$(eval $(call generate_theme,volcanoes))

# Custom targets for scripts with different parameters
.PHONY: admins
admins:
	$(DOCKER_RUN) generate-custom \
		--schema=/data/admins.yml \
		--output=/data/admins.mbtiles \
		--force \
		--download

.PHONY: conflicts
conflicts:
	$(DOCKER_RUN) generate-custom \
		--schema=/data/conflicts.yml \
		--output=/data/conflicts.mbtiles \
		--download \
		--force

.PHONY: peacekeeping_network
peacekeeping_network:
	@echo "Preparing data for theme: peacekeeping_network..."
	@mkdir -p tmp
	@python theme/peacekeeping_network/build_geojson.py
	@echo "Generating theme: peacekeeping_network..."
	@cp "theme/peacekeeping_network/schema.yml" "data/peacekeeping_network.yml"
	$(DOCKER_RUN) generate-custom \
		--schema=/data/peacekeeping_network.yml \
		--output=/data/peacekeeping_network.mbtiles \
		--download \
		--force
	@echo "Theme peacekeeping_network generated successfully."
	@echo "Next steps:"
	@echo "1. Copy the style file: cp theme/peacekeeping_network/style.json data/peacekeeping_network.json"
	@echo "2. Update data/config.json to include the new theme."

.PHONY: global_seismic_alerts
global_seismic_alerts:
	@echo "Preparing data for theme: global_seismic_alerts..."
	@mkdir -p tmp
	@python theme/global_seismic_alerts/build_geojson.py
	@echo "Generating theme: global_seismic_alerts..."
	@cp "theme/global_seismic_alerts/schema.yml" "data/global_seismic_alerts.yml"
	$(DOCKER_RUN) generate-custom \
		--schema=/data/global_seismic_alerts.yml \
		--output=/data/global_seismic_alerts.mbtiles \
		--download \
		--force
	@echo "Theme global_seismic_alerts generated successfully."
	@echo "Next steps:"
	@echo "1. Copy the style file: cp theme/global_seismic_alerts/style.json data/global_seismic_alerts.json"
	@echo "2. Update data/config.json to include the new theme."

.PHONY: custom
custom:
	docker run \
		-u `id -u`:`id -g` \
		-v "$(pwd)/data":/data \
		ghcr.io/onthegomap/planetiler:latest \
			generate-custom \
				--schema=/data/schema.yml \
				--download \
				--download-threads=16 \
				--download-chunk-size-mb=1000 \
				--output=/data/custom.mbtiles \
				--force

.PHONY: healthcare
healthcare:
	docker run \
		-u `id -u`:`id -g` \
		--memory 20g --memory-swap -1 \
		-e JAVA_TOOL_OPTIONS="-Xms16g -Xmx16g" \
		-v "$(pwd)/data":/data \
		ghcr.io/onthegomap/planetiler:latest \
			generate-custom \
			--schema=/data/healthcare.yml \
			--output=/data/healthcare.mbtiles \
			--download \
			--force

.PHONY: monaco
monaco:
	docker run \
		-u `id -u`:`id -g` \
		-e JAVA_TOOL_OPTIONS="-Xmx1g" \
		-v "$(pwd)/data":/data \
		ghcr.io/onthegomap/planetiler:latest \
			--download \
			--area=monaco \
			--download-threads=16 \
			--download-chunk-size-mb=1000 \
			--output=/data/monaco.mbtiles \
			--force

.PHONY: railways
railways:
	$(DOCKER_RUN) generate-custom \
		--schema=/data/railways.yml \
		--output=/data/railways.mbtiles \
		--force

.PHONY: rivers
rivers:
	$(DOCKER_RUN) generate-custom \
		--schema=/data/rivers.yml \
		--output=/data/rivers.mbtiles \
		--force

.PHONY: water
water:
	docker run \
		-u `id -u`:`id -g` \
		-v "$(pwd)/data":/data \
		ghcr.io/onthegomap/planetiler:latest \
			generate-custom \
				--schema=/data/water.yml \
				--download \
				--download-threads=16 \
				--download-chunk-size-mb=1000 \
				--output=/data/water.mbtiles \
				--force

.PHONY: planet
planet:
	docker run \
		-u `id -u`:`id -g` \
		--memory 90g \
		--memory-swap 90g \
		--memory-swappiness 10 \
		-e JAVA_TOOL_OPTIONS="-XX:+AlwaysPreTouch -Xms28g -Xmx28g" \
		-v "$(pwd)/data":/data \
		ghcr.io/onthegomap/planetiler:latest \
			--area=planet \
			--bounds=planet \
			--download \
			--download-threads=16 \
			--download-chunk-size-mb=1000 \
			--fetch-wikidata \
			--nodemap-type=sparsearray \
			--nodemap-storage=mmap \
			--osm-path=/data/planet-latest.osm.pbf \
			--output=/data/planet-new.mbtiles \
			--force

.PHONY: planet-mlt
planet-mlt:
	docker run \
		-u `id -u`:`id -g` \
		--memory 90g \
		--memory-swap 90g \
		--memory-swappiness 10 \
		-e JAVA_TOOL_OPTIONS="-XX:+AlwaysPreTouch -Xms28g -Xmx28g" \
		-v "$(pwd)/data":/data \
		ghcr.io/onthegomap/planetiler:latest \
			--area=planet \
			--bounds=planet \
			--download \
			--download-threads=16 \
			--download-chunk-size-mb=1000 \
			--fetch-wikidata \
			--nodemap-type=sparsearray \
			--nodemap-storage=mmap \
			--osm-path=/data/planet-latest.osm.pbf \
			--tile-format=mlt \
			--output=/data/planet-mlt.mbtiles \
			--force

.PHONY: planet-profile
planet-profile:
	docker run \
		-u `id -u`:`id -g` \
		--memory 90g \
		--memory-swap 90g \
		--memory-swappiness 10 \
		-e JAVA_TOOL_OPTIONS="-XX:+AlwaysPreTouch -Xms28g -Xmx28g -XX:StartFlightRecording=filename=/data/planet.jfr,duration=5h,settings=profile,disk=true,dumponexit=true,maxsize=5g" \
		-v "$(pwd)/data":/data \
		ghcr.io/onthegomap/planetiler:latest \
			--area=planet \
			--bounds=planet \
			--download \
			--download-threads=16 \
			--download-chunk-size-mb=1000 \
			--fetch-wikidata \
			--nodemap-type=sparsearray \
			--nodemap-storage=mmap \
			--osm-path=/data/planet-latest.osm.pbf \
			--output=/data/planet-new.mbtiles \
			--force

# ==========================================================
# Theme-specific pre-filter
#   Shrink the input OSM PBF with `osmium tags-filter` before
#   feeding it to Planetiler for faster theme iteration.
# ==========================================================

# Local planet-based themes.
PREFILTER_INPUT_admins = $(FULL_PLANET_PBF)
PREFILTER_FILTER_admins = wr/boundary=administrative
PREFILTER_SCHEMA_MATCH_admins = /data/planet-latest.osm.pbf
PREFILTER_SCHEMA_REPLACE_admins = /data/planet-admins.osm.pbf
PREFILTER_PREPARE_admins = true
PREFILTER_DOCKER_RUN_admins = $(DOCKER_RUN)
PREFILTER_GENERATE_FLAGS_admins = --download

PREFILTER_INPUT_biodiversity = $(FULL_PLANET_PBF)
PREFILTER_FILTER_biodiversity = wr/natural=coastline,glacier,scrub,heath,grassland,wood,wetland wr/landuse=forest
PREFILTER_SCHEMA_MATCH_biodiversity = /data/planet-latest.osm.pbf
PREFILTER_SCHEMA_REPLACE_biodiversity = /data/planet-biodiversity.osm.pbf
PREFILTER_PREPARE_biodiversity = true
PREFILTER_DOCKER_RUN_biodiversity = $(DOCKER_RUN)
PREFILTER_GENERATE_FLAGS_biodiversity = --download

PREFILTER_INPUT_disaster_prevention = $(FULL_PLANET_PBF)
PREFILTER_FILTER_disaster_prevention = nwr/amenity=shelter,fire_station,police,water_point,drinking_water nwr/aeroway=heliport,helipad
PREFILTER_SCHEMA_MATCH_disaster_prevention = /data/planet-latest.osm.pbf
PREFILTER_SCHEMA_REPLACE_disaster_prevention = /data/planet-disaster_prevention.osm.pbf
PREFILTER_PREPARE_disaster_prevention = true
PREFILTER_DOCKER_RUN_disaster_prevention = $(DOCKER_RUN)
PREFILTER_GENERATE_FLAGS_disaster_prevention = --download

PREFILTER_INPUT_energy_transition = $(FULL_PLANET_PBF)
PREFILTER_FILTER_energy_transition = nwr/natural=sand,desert nwr/power=plant nwr/man_made=petroleum_well nwr/resource=coal
PREFILTER_SCHEMA_MATCH_energy_transition = /data/planet-latest.osm.pbf
PREFILTER_SCHEMA_REPLACE_energy_transition = /data/planet-energy_transition.osm.pbf
PREFILTER_PREPARE_energy_transition = true
PREFILTER_DOCKER_RUN_energy_transition = $(DOCKER_RUN)
PREFILTER_GENERATE_FLAGS_energy_transition = --download

PREFILTER_INPUT_global_connectivity = $(FULL_PLANET_PBF)
PREFILTER_FILTER_global_connectivity = nwr/industrial=port nwr/aeroway=aerodrome
PREFILTER_SCHEMA_MATCH_global_connectivity = /data/planet-latest.osm.pbf
PREFILTER_SCHEMA_REPLACE_global_connectivity = /data/planet-global_connectivity.osm.pbf
PREFILTER_PREPARE_global_connectivity = true
PREFILTER_DOCKER_RUN_global_connectivity = $(DOCKER_RUN)
PREFILTER_GENERATE_FLAGS_global_connectivity = --download

PREFILTER_INPUT_global_seismic_alerts = $(FULL_PLANET_PBF)
PREFILTER_FILTER_global_seismic_alerts = nwr/capital=yes
PREFILTER_SCHEMA_MATCH_global_seismic_alerts = /osm_planet/planet-latest.osm.pbf
PREFILTER_SCHEMA_REPLACE_global_seismic_alerts = /data/planet-global_seismic_alerts.osm.pbf
PREFILTER_PREPARE_global_seismic_alerts = mkdir -p tmp && python theme/global_seismic_alerts/build_geojson.py
PREFILTER_DOCKER_RUN_global_seismic_alerts = $(DOCKER_RUN)
PREFILTER_GENERATE_FLAGS_global_seismic_alerts = --download

PREFILTER_INPUT_healthcare = $(FULL_PLANET_PBF)
PREFILTER_FILTER_healthcare = nwr/amenity=hospital,clinic,doctors,dentist,pharmacy,health_post nwr/healthcare
PREFILTER_SCHEMA_MATCH_healthcare = /data/planet-latest.osm.pbf
PREFILTER_SCHEMA_REPLACE_healthcare = /data/planet-healthcare.osm.pbf
PREFILTER_PREPARE_healthcare = true
PREFILTER_DOCKER_RUN_healthcare = docker run -u `id -u`:`id -g` --memory 20g --memory-swap -1 -e JAVA_TOOL_OPTIONS="-Xms16g -Xmx16g" -v "$(pwd)/data":/data ghcr.io/onthegomap/planetiler:latest
PREFILTER_GENERATE_FLAGS_healthcare = --download

PREFILTER_INPUT_railways = $(FULL_PLANET_PBF)
PREFILTER_FILTER_railways = wr/railway
PREFILTER_SCHEMA_MATCH_railways = /data/planet-latest.osm.pbf
PREFILTER_SCHEMA_REPLACE_railways = /data/planet-railways.osm.pbf
PREFILTER_PREPARE_railways = true
PREFILTER_DOCKER_RUN_railways = $(DOCKER_RUN)
PREFILTER_GENERATE_FLAGS_railways =

PREFILTER_INPUT_rivers = $(FULL_PLANET_PBF)
PREFILTER_FILTER_rivers = wr/waterway=river
PREFILTER_SCHEMA_MATCH_rivers = /data/planet-latest.osm.pbf
PREFILTER_SCHEMA_REPLACE_rivers = /data/planet-rivers.osm.pbf
PREFILTER_PREPARE_rivers = true
PREFILTER_DOCKER_RUN_rivers = $(DOCKER_RUN)
PREFILTER_GENERATE_FLAGS_rivers =

PREFILTER_INPUT_volcanoes = $(FULL_PLANET_PBF)
PREFILTER_FILTER_volcanoes = nwr/natural=volcano
PREFILTER_SCHEMA_MATCH_volcanoes = /data/planet-latest.osm.pbf
PREFILTER_SCHEMA_REPLACE_volcanoes = /data/planet-volcanoes.osm.pbf
PREFILTER_PREPARE_volcanoes = true
PREFILTER_DOCKER_RUN_volcanoes = $(DOCKER_RUN)
PREFILTER_GENERATE_FLAGS_volcanoes = --download

# Japan-based themes.
PREFILTER_INPUT_debug_test_climate = $(JAPAN_OSM_PBF)
PREFILTER_FILTER_debug_test_climate = nwr/natural=coastline,volcano,wood nwr/landuse=forest nwr/man_made=dyke
PREFILTER_SCHEMA_MATCH_debug_test_climate = url: https://download.geofabrik.de/asia/japan-latest.osm.pbf
PREFILTER_SCHEMA_REPLACE_debug_test_climate = local_path: /data/planet-debug_test_climate.osm.pbf
PREFILTER_PREPARE_debug_test_climate = true
PREFILTER_DOCKER_RUN_debug_test_climate = $(DOCKER_RUN)
PREFILTER_GENERATE_FLAGS_debug_test_climate = --download

PREFILTER_INPUT_railways_jp = $(JAPAN_OSM_PBF)
PREFILTER_FILTER_railways_jp = wr/railway
PREFILTER_SCHEMA_MATCH_railways_jp = url: https://download.geofabrik.de/asia/japan-latest.osm.pbf
PREFILTER_SCHEMA_REPLACE_railways_jp = local_path: /data/planet-railways_jp.osm.pbf
PREFILTER_PREPARE_railways_jp = true
PREFILTER_DOCKER_RUN_railways_jp = $(DOCKER_RUN)
PREFILTER_GENERATE_FLAGS_railways_jp = --download

$(eval $(call generate_theme_pre_filter,admins))
$(eval $(call generate_theme_pre_filter,biodiversity))
$(eval $(call generate_theme_pre_filter,disaster_prevention))
$(eval $(call generate_theme_pre_filter,energy_transition))
$(eval $(call generate_theme_pre_filter,global_connectivity))
$(eval $(call generate_theme_pre_filter,global_seismic_alerts))
$(eval $(call generate_theme_pre_filter,healthcare))
$(eval $(call generate_theme_pre_filter,railways))
$(eval $(call generate_theme_pre_filter,railways_jp))
$(eval $(call generate_theme_pre_filter,rivers))
$(eval $(call generate_theme_pre_filter,volcanoes))
$(eval $(call generate_theme_pre_filter,debug_test_climate))
$(eval $(call benchmark_tiled_tags_filter,railways,wr/railway))
$(eval $(call benchmark_tiled_tags_filter,rivers,wr/waterway=river))
$(eval $(call benchmark_planetiler_gc_prefilter,railways))
$(eval $(call benchmark_planetiler_gc_prefilter,rivers))

# Full planet.pbf input + JFR profiling (slow baseline).
.PHONY: railways-profile
railways-profile:
	@echo "=== railways-profile (full planet.pbf + JFR) start: $$(date -Iseconds) ==="
	@cp theme/railways/schema.yml data/railways.yml
	time docker run \
		-u `id -u`:`id -g` \
		--memory 30g --memory-swap -1 \
		-e JAVA_TOOL_OPTIONS="-Xms16g -Xmx16g -XX:StartFlightRecording=filename=/data/railways.jfr,duration=6h,settings=profile,disk=true,dumponexit=true,maxsize=5g" \
		-v "$(pwd)/data":/data \
		-v "/everything/osm/planet":/osm_planet:ro \
		ghcr.io/onthegomap/planetiler:latest \
			generate-custom \
				--schema=/data/railways.yml \
				--output=/data/railways-profile.mbtiles \
				--force
	@echo "=== railways-profile end: $$(date -Iseconds) ==="

# osmium-filtered mini-pbf input + JFR profiling (fast expected).
.PHONY: railways-pre-filter-profile
railways-pre-filter-profile: data/planet-railways.osm.pbf
	@echo "=== railways-pre-filter-profile (osmium-filtered + JFR) start: $$(date -Iseconds) ==="
	@cp theme/railways/schema.yml data/railways-pre-filter.yml
	@sed -i 's|/data/planet-latest.osm.pbf|/data/planet-railways.osm.pbf|' data/railways-pre-filter.yml
	time docker run \
		-u `id -u`:`id -g` \
		--memory 30g --memory-swap -1 \
		-e JAVA_TOOL_OPTIONS="-Xms16g -Xmx16g -XX:StartFlightRecording=filename=/data/railways-pre-filter.jfr,duration=6h,settings=profile,disk=true,dumponexit=true,maxsize=5g" \
		-v "$(pwd)/data":/data \
		-v "/everything/osm/planet":/osm_planet:ro \
		ghcr.io/onthegomap/planetiler:latest \
			generate-custom \
				--schema=/data/railways-pre-filter.yml \
				--output=/data/railways-pre-filter.mbtiles \
				--force
	@echo "=== railways-pre-filter-profile end: $$(date -Iseconds) ==="

.PHONY: admins-pre-filter-profile
admins-pre-filter-profile: data/planet-admins.osm.pbf
	@echo "=== admins-pre-filter-profile (osmium-filtered + JFR) start: $$(date -Iseconds) ==="
	@cp theme/admins/schema.yml data/admins-pre-filter.yml
	@sed -i 's|/data/planet-latest.osm.pbf|/data/planet-admins.osm.pbf|' data/admins-pre-filter.yml
	time docker run \
		-u `id -u`:`id -g` \
		--memory 30g --memory-swap -1 \
		-e JAVA_TOOL_OPTIONS="-Xms16g -Xmx16g -XX:StartFlightRecording=filename=/data/admins-pre-filter.jfr,duration=6h,settings=profile,disk=true,dumponexit=true,maxsize=5g" \
		-v "$(pwd)/data":/data \
		-v "/everything/osm/planet":/osm_planet:ro \
		ghcr.io/onthegomap/planetiler:latest \
			generate-custom \
				--schema=/data/admins-pre-filter.yml \
				--output=/data/admins-pre-filter.mbtiles \
				--force
	@echo "=== admins-pre-filter-profile end: $$(date -Iseconds) ==="

# ==========================================================
# osmium-tool parallelization experiment
#   Confirm OSMIUM_POOL_THREADS has no effect on tags-filter
#   Evidence for new Issue to osmcode/osmium-tool
# ==========================================================

# Phase 1: Quick scaling curve on japan (2.2GB, ~20s/run expected)
.PHONY: osmium-threads-bench-japan
osmium-threads-bench-japan:
	@echo "=== Thread scaling: japan railways ==="
	@for T in 1 4 8 16 32; do \
		rm -f /tmp/osmium-bench-japan.pbf; \
		echo ""; \
		echo "--- OSMIUM_POOL_THREADS=$$T ---"; \
		/usr/bin/time -v env OSMIUM_POOL_THREADS=$$T osmium tags-filter \
			$(JAPAN_OSM_PBF) \
			wr/railway \
			-o /tmp/osmium-bench-japan.pbf \
			--overwrite 2>&1 | grep -E 'Elapsed|Percent|Peak' ; \
	done
	@rm -f /tmp/osmium-bench-japan.pbf

# Phase 2: Planet-scale confirmation (3 points, ~40min total)
.PHONY: osmium-threads-bench-planet
osmium-threads-bench-planet:
	@echo "=== Thread scaling: planet railways (long) ==="
	@for T in 1 8 32; do \
		rm -f /tmp/osmium-bench-planet.pbf; \
		echo ""; \
		echo "--- OSMIUM_POOL_THREADS=$$T ---"; \
		/usr/bin/time -v env OSMIUM_POOL_THREADS=$$T osmium tags-filter \
			$(FULL_PLANET_PBF) \
			wr/railway \
			-o /tmp/osmium-bench-planet.pbf \
			--overwrite 2>&1 | grep -E 'Elapsed|Percent|Peak' ; \
	done
	@rm -f /tmp/osmium-bench-planet.pbf

# Phase 3: Thread-level CPU breakdown during osmium run
# Usage: `make osmium-pidstat-monitor` in one terminal, then run osmium in another.
.PHONY: osmium-pidstat-monitor
osmium-pidstat-monitor:
	@echo "Waiting for osmium process to start..."
	@while ! pgrep -x osmium > /dev/null; do sleep 1; done
	@PID=$$(pgrep -n -x osmium); echo "Monitoring PID $$PID"; \
	pidstat -t -p $$PID 5
