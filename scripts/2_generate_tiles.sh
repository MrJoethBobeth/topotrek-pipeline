#!/bin/bash
set -e
set -o allexport
source ../.env
set +o allexport

# --- Configuration ---
PLANETILER_IMAGE="ghcr.io/onthegomap/planetiler:latest"
GDAL_IMAGE="osgeo/gdal:latest"
OUTPUT_DIR="../data"
REGION_NAME=$(basename "${GEOFABRIK_PATH}") # e.g., us-northeast
BASEMAP_OUTPUT="${OUTPUT_DIR}/${REGION_NAME}_basemap.pmtiles"
HILLSHADE_INPUT="${OUTPUT_DIR}/processed/hillshade.tif"
HILLSHADE_OUTPUT="${OUTPUT_DIR}/${REGION_NAME}_hillshade.pmtiles"

# --- STEP 1: PREPARE AUTHORITATIVE DATA ---
echo "--- Running Data Preparation Script ---"
bash ./1_prepare_data.sh
echo "--- Data Preparation Complete ---"


# --- STEP 2: GENERATE CUSTOM VECTOR BASEMAP ---
echo "--- Starting Planetiler to generate custom vector basemap... ---"
# This command mounts the project folder and tells Planetiler to use your custom profile.
docker run --rm \
  -e "JAVA_TOOL_OPTIONS=-Xmx16g" \
  -v "$(pwd)/..:/work" \
  -w /work \
  ${PLANETILER_IMAGE} java -cp planetiler.jar:planetiler_profile/ OutdoorProfile \
  --area=${GEOFABRIK_PATH} \
  --bounds=${BBOX} \
  --download \
  --output="data/${REGION_NAME}_basemap.pmtiles"

echo "--- Basemap generation complete: ${BASEMAP_OUTPUT} ---"


# --- STEP 3: GENERATE RASTER HILLSHADE TILES ---
echo "--- Generating raster hillshade PMTiles... ---"
# Use rio-pmtiles (installed via pip in the gdal container) to convert the GeoTIFF
docker run --rm \
  -v "$(pwd)/..:/work" \
  -w /work \
  ${GDAL_IMAGE} /bin/bash -c "pip install rio-pmtiles && rio pmtiles ${HILLSHADE_INPUT} ${HILLSHADE_OUTPUT} --zoom-range 8-14"

echo "--- Hillshade generation complete: ${HILLSHADE_OUTPUT} ---"
echo "--- ENTIRE PIPELINE SUCCESSFUL. ---"