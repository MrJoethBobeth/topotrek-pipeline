#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

#=======================================================================
# GENERATE BASEMAP SCRIPT (MODERNIZED WITH PLANETILER)
#
# This script uses Planetiler to generate a vector tile basemap.
# It performs all steps in a single container:
# 1. Downloads the specified OSM data from Geofabrik.
# 2. Processes the data and generates vector tiles.
# 3. Outputs a cloud-optimized .pmtiles file directly.
#=======================================================================

# --- Configuration ---
# Load variables from .env file (BBOX, GEOFABRIK_PATH, etc.)
set -o allexport
source .env
set +o allexport

OUTPUT_DIR="./data"
# Construct the output filename from the .env variable
OUTPUT_FILE="${OUTPUT_DIR}/${MBTILES_FILE%.*}.pmtiles"
PLANETILER_IMAGE="ghcr.io/onthegomap/planetiler:latest"

# Ensure output directory exists
mkdir -p ${OUTPUT_DIR}

echo "---"
echo "STEP 1: Starting Planetiler to generate vector tiles..."
echo "Source Region: ${GEOFABRIK_PATH}"
echo "Output: ${OUTPUT_FILE}"
echo "This may take some time, but will be much faster than the previous pipeline."
echo "---"

# Run Planetiler in a Docker container
# It requires significant RAM, so we allocate it directly.
# The command downloads the PBF for the specified area, clips it to the BBOX,
# and generates the pmtiles.
# We use `basename` to extract just the region name (e.g., "us-northeast") from the full path.
docker run --rm \
  -e "JAVA_TOOL_OPTIONS=-Xmx16g" \
  -v "$(pwd)/data:/data" \
  ${PLANETILER_IMAGE} \
  --area=$(basename "${GEOFABRIK_PATH}") \
  --bounds=${BBOX} \
  --download \
  --output="/data/${MBTILES_FILE%.*}.pmtiles"

echo "---"
echo "SUCCESS: Basemap generation complete."
echo "Final artifact created at: ${OUTPUT_FILE}"
echo "---"
