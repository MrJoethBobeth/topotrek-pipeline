#!/bin/bash
set -e
set -o allexport
# The script is run from the project root, so the path to .env is direct
source ./.env
set +o allexport

# ==============================================================================
# GENERATE VECTOR BASEMAP
#
# This script generates the main vector basemap tiles from OpenStreetMap data
# using the OutdoorProfile. It explicitly downloads the main OSM PBF and then
# instructs Planetiler to download the other necessary source data.
# ==============================================================================

# --- Configuration ---
PLANETILER_IMAGE="ghcr.io/onthegomap/planetiler:latest"
AREA_NAME=${GEOFABRIK_PATH}
REGION_NAME=$(basename "${GEOFABRIK_PATH}")


# --- File Paths ---
OSM_PBF_URL="http://download.geofabrik.de/${AREA_NAME}-latest.osm.pbf"
OSM_PBF_PATH="./data/sources/${REGION_NAME}-latest.osm.pbf"
BASEMAP_OUTPUT="data/${REGION_NAME}_basemap.pmtiles"
BASEMAP_PROFILE="planetiler_profile/OutdoorProfile.java"


# --- STEP 1: PREPARE OSM DATA SOURCE ---
# Manually download the primary OSM data file.
if [ ! -f "$OSM_PBF_PATH" ]; then
    echo "Downloading OSM data from ${OSM_PBF_URL}..."
    mkdir -p "$(dirname "$OSM_PBF_PATH")"
    curl -L -o "$OSM_PBF_PATH" "$OSM_PBF_URL"
else
    echo "OSM data (${OSM_PBF_PATH}) already exists, a new version will not be downloaded."
fi


# --- STEP 2: GENERATE VECTOR BASEMAP ---
# We provide the path to the local OSM file, but also use --download
# to ensure Planetiler automatically fetches other profile dependencies
# like Natural Earth, water polygons, etc.
echo "--- Generating vector basemap from OSM data for area: ${AREA_NAME} ---"
echo "--- Planetiler will use local OSM file and download other required sources. ---"

if [ ! -f "$BASEMAP_OUTPUT" ]; then
    docker run --rm \
      -e "JAVA_TOOL_OPTIONS=-Xmx10g" \
      -v "$(pwd):/work" \
      -w /work \
      ${PLANETILER_IMAGE} \
      --profile="/work/${BASEMAP_PROFILE}" \
      --osm-path="/work/${OSM_PBF_PATH}" \
      --bounds="${BBOX}" \
      --output="/work/${BASEMAP_OUTPUT}" \
      --download \
      --force
    echo "--- Basemap generation complete: ${BASEMAP_OUTPUT} ---"
else
    echo "--- SKIPPING: Basemap file ${BASEMAP_OUTPUT} already exists. ---"
fi

echo "--- BASEMAP GENERATION SCRIPT FINISHED SUCCESSFULLY. ---"
