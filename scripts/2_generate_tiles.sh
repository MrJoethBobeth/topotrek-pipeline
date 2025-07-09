#!/bin/bash
set -e
set -o allexport
source ./.env
set +o allexport

# --- Configuration ---
PLANETILER_IMAGE="ghcr.io/onthegomap/planetiler:latest"
GDAL_IMAGE="ghcr.io/osgeo/gdal:ubuntu-full-latest"
# The mb-util and pmtiles images are no longer needed
UTILITY_IMAGE="alpine:latest"
OUTPUT_DIR="./data"
REGION_NAME=$(basename "${GEOFABRIK_PATH}")

# --- File Paths ---
OSM_PBF_URL="https://download.geofabrik.de/${GEOFABRIK_PATH}-latest.osm.pbf"
OSM_PBF_PATH="${OUTPUT_DIR}/sources/${REGION_NAME}-latest.osm.pbf"
CONTOUR_GPKG_PATH="data/processed/contours.gpkg"
FINAL_BASEMAP_OUTPUT="data/${REGION_NAME}_basemap.pmtiles"
HILLSHADE_INPUT="data/processed/hillshade.tif"
HILLSHADE_OUTPUT="data/${REGION_NAME}_hillshade.pmtiles"
# Path to the new combined profile
COMBINED_PROFILE="planetiler_profile/CombinedProfile.java"

# --- STEP 1: PREPARE DATA SOURCES (OSM and Contours) ---
echo "--- Preparing data sources... ---"

# Download OSM data if it doesn't exist
if [ ! -f "$OSM_PBF_PATH" ]; then
    echo "Downloading OSM data from ${OSM_PBF_URL}..."
    mkdir -p "$(dirname "$OSM_PBF_PATH")"
    curl -L -o "$OSM_PBF_PATH" "$OSM_PBF_URL"
else
    echo "OSM data (${OSM_PBF_PATH}) already exists, a new version will not be downloaded."
fi

# We check for the final output of the prep script.
if [ ! -f "$CONTOUR_GPKG_PATH" ]; then
    echo "Contour data not found, running data preparation script..."
    bash ./scripts/1_prepare_data.sh
else
    echo "Contour data (${CONTOUR_GPKG_PATH}) already exists, data preparation will be skipped."
fi


# --- STEP 2: GENERATE COMBINED BASEMAP (OSM + CONTOURS) ---
echo "--- Generating combined basemap with custom profile... ---"

# Skip the entire basemap generation if the final file already exists.
if [ ! -f "$FINAL_BASEMAP_OUTPUT" ]; then
    docker run --rm \
      -e "JAVA_TOOL_OPTIONS=-Xmx10g" \
      -v "$(pwd):/work" \
      -w /work \
      ${PLANETILER_IMAGE} \
      --profile="/work/${COMBINED_PROFILE}" \
      --output="${FINAL_BASEMAP_OUTPUT}" \
      --bounds=${BBOX} \
      --osm_path="${OSM_PBF_PATH}" \
      --force
    echo "--- Combined basemap generation complete: ${FINAL_BASEMAP_OUTPUT} ---"
else
    echo "--- SKIPPING: Final basemap file ${FINAL_BASEMAP_OUTPUT} already exists. ---"
fi


# --- STEP 3: GENERATE RASTER HILLSHADE TILES ---
echo "--- Generating raster hillshade PMTiles... ---"
if [ ! -f "$HILLSHADE_OUTPUT" ]; then
    if [ ! -f "$HILLSHADE_INPUT" ]; then
        echo "Error: Hillshade input file not found at ${HILLSHADE_INPUT}"
        echo "You may need to run ./scripts/1_prepare_data.sh first."
        exit 1
    fi

    echo "--- Converting GeoTIFF to PMTiles with gdal_translate... ---"
    # CORRECTED: Use the direct gdal_translate command to convert the GeoTIFF to PMTiles.
    # This is the most stable and direct method, avoiding all previous issues.
    docker run --rm \
      -v "$(pwd):/work" \
      -w /work \
      ${GDAL_IMAGE} \
      gdal_translate ${HILLSHADE_INPUT} ${HILLSHADE_OUTPUT} -of PMTILES

    echo "--- Hillshade generation complete: ${HILLSHADE_OUTPUT} ---"
else
    echo "--- SKIPPING: Hillshade file ${HILLSHADE_OUTPUT} already exists. ---"
fi

echo "--- TILE GENERATION SCRIPT FINISHED SUCCESSFULLY. ---"
