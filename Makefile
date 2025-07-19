# Planetiler-AI Makefile

# Default memory settings for Planetiler
MEMORY_OPTIONS = --memory 20g --memory-swap -1
JAVA_TOOL_OPTIONS = -Xms8g -Xmx8g

# Common Docker run command
DOCKER_RUN = docker run \
    -u `id -u`:`id -g` \
    $(MEMORY_OPTIONS) \
    -e JAVA_TOOL_OPTIONS="$(JAVA_TOOL_OPTIONS)" \
    -v "$(pwd)/data":/data \
    ghcr.io/onthegomap/planetiler:latest

# Phony targets to avoid conflicts with file names
.PHONY: all clean admins conflicts custom disaster_prevention energy_transition global_connectivity healthcare human_security monaco railways rivers water world

# Default target
all:
	@echo "Please specify a target. Available targets are:"
	@echo "  admins, conflicts, custom, disaster_prevention, energy_transition, global_connectivity, healthcare, human_security, monaco, railways, rivers, water, world"

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

# Themes that follow the standard pattern
$(eval $(call generate_theme,disaster_prevention))
$(eval $(call generate_theme,energy_transition))
$(eval $(call generate_theme,global_connectivity))
$(eval $(call generate_theme,human_security))

# Custom targets for scripts with different parameters
admins:
	$(DOCKER_RUN) generate-custom \
		--schema=/data/admins.yml \
		--output=/data/admins.mbtiles \
		--force \
		--download

conflicts:
	$(DOCKER_RUN) generate-custom \
		--schema=/data/conflicts.yml \
		--output=/data/conflicts.mbtiles \
		--download \
		--force

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

railways:
	$(DOCKER_RUN) generate-custom \
		--schema=/data/railways.yml \
		--output=/data/railways.mbtiles \
		--force

rivers:
	$(DOCKER_RUN) generate-custom \
		--schema=/data/rivers.yml \
		--output=/data/rivers.mbtiles \
		--force

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

world:
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
			--osm-path=/data/planet-250707.osm.pbf \
			--force

clean:
	@echo "Cleaning up generated files..."
	rm -f data/*.mbtiles
	rm -f data/*.yml
	rm -f data/*.json
