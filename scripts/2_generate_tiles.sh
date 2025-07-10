#!/bin/bash
set -e
set -o allexport
source ./.env
set +o allexport

# --- Configuration ---
PLANETILER_IMAGE="ghcr.io/onthegomap/planetiler:latest"
OUTPUT_DIR="./data"
REGION_NAME=$(basename "${GEOFABRIK_PATH}")

# --- File Paths ---
OSM_PBF_URL="https://download.geofabrik.de/${GEOFABRIK_PATH}-latest.osm.pbf"
OSM_PBF_PATH="${OUTPUT_DIR}/sources/${REGION_NAME}-latest.osm.pbf"
CONTOUR_GPKG_PATH="data/processed/contours.gpkg"

# Define output filenames for the separate layers
BASEMAP_OUTPUT="data/${REGION_NAME}_basemap.pmtiles"
CONTOUR_OUTPUT="data/${REGION_NAME}_contours.pmtiles"

# Define the Planetiler profiles to be used
# NOTE: You will need a profile that just processes OSM data.
# The default OpenMapTiles profile is a good starting point.
# We assume you have a custom profile for the basemap. For this example,
# we will reference a hypothetical 'OutdoorProfile.java' that you would
# modify to ONLY handle OSM data (i.e., remove contour logic).
BASEMAP_PROFILE="planetiler_profile/OutdoorProfile.java" # Assumes this is modified to be OSM-only
CONTOUR_PROFILE="planetiler_profile/ContourProfile.java"

# --- STEP 1: PREPARE DATA SOURCES (OSM and Contours) ---
echo "--- Preparing data sources... ---"

if [ ! -f "$OSM_PBF_PATH" ]; then
    echo "Downloading OSM data from ${OSM_PBF_URL}..."
    mkdir -p "$(dirname "$OSM_PBF_PATH")"
    curl -L -o "$OSM_PBF_PATH" "$OSM_PBF_URL"
else
    echo "OSM data (${OSM_PBF_PATH}) already exists, a new version will not be downloaded."
fi

if [ ! -f "$CONTOUR_GPKG_PATH" ]; then
    echo "Contour data not found, running data preparation script..."
    bash ./scripts/1_prepare_data.sh
else
    echo "Contour data (${CONTOUR_GPKG_PATH}) already exists, data preparation will be skipped."
fi


# --- STEP 2: GENERATE VECTOR BASEMAP (OSM ONLY) ---
echo "--- Generating vector basemap from OSM data... ---"

if [ ! -f "$BASEMAP_OUTPUT" ]; then
    docker run --rm \
      -e "JAVA_TOOL_OPTIONS=-Xmx16g" \
      -v "$(pwd):/work" \
      -w /work \
      ${PLANETILER_IMAGE} \
      --profile="${BASEMAP_PROFILE}" \
      --output="${BASEMAP_OUTPUT}" \
      --bounds=${BBOX} \
      --force
    echo "--- Basemap generation complete: ${BASEMAP_OUTPUT} ---"
else
    echo "--- SKIPPING: Basemap file ${BASEMAP_OUTPUT} already exists. ---"
fi


# --- STEP 3: GENERATE SEPARATE CONTOUR TILES ---
echo "--- Generating separate vector contour tiles... ---"
if [ ! -f "$CONTOUR_OUTPUT" ]; then
    if [ ! -f "$CONTOUR_GPKG_PATH" ]; then
        echo "Error: Contour input file not found at ${CONTOUR_GPKG_PATH}"
        echo "You may need to run ./scripts/1_prepare_data.sh first."
        exit 1
    fi

    docker run --rm \
      -e "JAVA_TOOL_OPTIONS=-Xmx8g" \
      -v "$(pwd):/work" \
      -w /work \
      ${PLANETILER_IMAGE} \
      --profile="${CONTOUR_PROFILE}" \
      --output="${CONTOUR_OUTPUT}" \
      --bounds=${BBOX} \
      --force
      
    echo "--- Contour tile generation complete: ${CONTOUR_OUTPUT} ---"
else
    echo "--- SKIPPING: Contour tile file ${CONTOUR_OUTPUT} already exists. ---"
fi

# --- REMOVED: The entire hillshade generation process has been taken out. ---

echo "--- TILE GENERATION SCRIPT FINISHED SUCCESSFULLY. ---"
