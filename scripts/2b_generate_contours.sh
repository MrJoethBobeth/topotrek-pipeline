#!/bin/bash
set -e
set -o allexport
# The script is run from the project root, so the path to .env is direct
source ./.env
set +o allexport

# ==============================================================================
# GENERATE VECTOR CONTOURS
#
# This script generates vector contour tiles from a pre-existing DEM.
# It will run the data preparation script if the contour source file
# is not found.
# ==============================================================================

# --- Configuration ---
PLANETILER_IMAGE="ghcr.io/onthegomap/planetiler:latest"
REGION_NAME=$(basename "${GEOFABRIK_PATH}")

# --- File Paths ---
CONTOUR_GPKG_PATH="data/processed/contours.gpkg"
CONTOUR_OUTPUT="data/${REGION_NAME}_contours.pmtiles"
CONTOUR_PROFILE="planetiler_profile/ContourProfile.java"

# --- STEP 1: PREPARE CONTOUR DATA SOURCE ---
echo "--- Checking for contour data source... ---"

if [ ! -f "$CONTOUR_GPKG_PATH" ]; then
    echo "Contour data not found at ${CONTOUR_GPKG_PATH}, running data preparation script..."
    bash ./scripts/1_prepare_data.sh
else
    echo "Contour data (${CONTOUR_GPKG_PATH}) already exists, data preparation will be skipped."
fi

# --- STEP 2: GENERATE SEPARATE CONTOUR TILES ---
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
      --profile="/work/${CONTOUR_PROFILE}" \
      --output="/work/${CONTOUR_OUTPUT}" \
      --bounds=${BBOX} \
      --force
      
    echo "--- Contour tile generation complete: ${CONTOUR_OUTPUT} ---"
else
    echo "--- SKIPPING: Contour tile file ${CONTOUR_OUTPUT} already exists. ---"
fi

echo "--- CONTOUR TILE GENERATION SCRIPT FINISHED SUCCESSFULLY. ---"
