#!/bin/bash
set -e
set -o allexport
source ./.env
set +o allexport

# --- Configuration ---
PLANETILER_IMAGE="ghcr.io/onthegomap/planetiler:latest"
GDAL_IMAGE="ghcr.io/osgeo/gdal:ubuntu-small-latest"
OUTPUT_DIR="./data"
REGION_NAME=$(basename "${GEOFABRIK_PATH}")
BASEMAP_OUTPUT="${OUTPUT_DIR}/${REGION_NAME}_basemap.pmtiles"
HILLSHADE_INPUT="${OUTPUT_DIR}/processed/hillshade.tif"
HILLSHADE_OUTPUT="${OUTPUT_DIR}/${REGION_NAME}_hillshade.pmtiles"

# --- Data preparation step has been removed ---
# That process should be run separately using: bash ./scripts/1_prepare_data.sh


# --- STEP 1: GENERATE CUSTOM VECTOR BASEMAP ---
echo "--- Starting Planetiler to generate custom vector basemap... ---"
# --- FIX: Use Planetiler's 'generate-custom' task to correctly compile and run the Java profile ---
# This also reduces the allocated RAM to 10g.
docker run --rm \
  -e "JAVA_TOOL_OPTIONS=-Xmx10g" \
  -v "$(pwd):/work" \
  -w /work \
  ${PLANETILER_IMAGE} \
  generate-custom /work/planetiler_profile/OutdoorProfile.java \
  --area=${GEOFABRIK_PATH} \
  --bounds=${BBOX} \
  --download \
  --output="/work/data/${REGION_NAME}_basemap.pmtiles"

echo "--- Basemap generation complete: ${BASEMAP_OUTPUT} ---"


# --- STEP 2: GENERATE RASTER HILLSHADE TILES ---
echo "--- Generating raster hillshade PMTiles... ---"
docker run --rm \
  -v "$(pwd):/work" \
  -w /work \
  ${GDAL_IMAGE} /bin/bash -c "pip install rio-pmtiles && rio pmtiles /work/${HILLSHADE_INPUT} /work/${HILLSHADE_OUTPUT} --zoom-range 8-14"

echo "--- Hillshade generation complete: ${HILLSHADE_OUTPUT} ---"
echo "--- ENTIRE PIPELINE SUCCESSFUL. ---"
