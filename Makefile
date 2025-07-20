# Planetiler-AI Makefile

# Default memory settings for Planetiler
MEMORY_OPTIONS = --memory 20g --memory-swap -1
JAVA_TOOL_OPTIONS = -Xms8g -Xmx8g

pwd = $(shell pwd)

# Common Docker run command
DOCKER_RUN = docker run \
    -u `id -u`:`id -g` \
    $(MEMORY_OPTIONS) \
    -e JAVA_TOOL_OPTIONS="$(JAVA_TOOL_OPTIONS)" \
    -v "$(pwd)/data":/data \
    ghcr.io/onthegomap/planetiler:latest

# Default target
all:
	@echo "Please specify a target. Available targets are:"
	@echo "  admins,"
	@echo "  conflicts,"
	@echo "  custom,"
	@echo "  healthcare,"
	@echo "  monaco,"
	@echo "  railways,"
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

.PHONY: world
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

.PHONY: clean
clean:
	@echo "Cleaning up generated files..."
	rm -f data/*.mbtiles
	rm -f data/*.yml
	rm -f data/*.json
