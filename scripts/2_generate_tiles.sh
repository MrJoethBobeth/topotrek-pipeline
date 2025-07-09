#!/bin/bash
set -e
set -o allexport
source ./.env
set +o allexport

# --- Configuration ---
PLANETILER_IMAGE="ghcr.io/onthegomap/planetiler:latest"
PMTILES_IMAGE="protomaps/go-pmtiles:latest"
# A python image for running rio-mbtiles
RIO_IMAGE="python:3.9-slim"
OUTPUT_DIR="./data"
REGION_NAME=$(basename "${GEOFABRIK_PATH}")

# --- File Paths ---
OSM_PBF_URL="https://download.geofabrik.de/${GEOFABRIK_PATH}-latest.osm.pbf"
OSM_PBF_PATH="${OUTPUT_DIR}/sources/${REGION_NAME}-latest.osm.pbf"
CONTOUR_GPKG_PATH="data/processed/contours.gpkg"
FINAL_BASEMAP_OUTPUT="data/${REGION_NAME}_basemap.pmtiles"
HILLSHADE_INPUT="data/processed/hillshade.tif"
# Temporary mbtiles file for the intermediate step
HILLSHADE_MBTILES="data/processed/hillshade.mbtiles"
HILLSHADE_OUTPUT="data/${REGION_NAME}_hillshade.pmtiles"
COMBINED_PROFILE="planetiler_profile/CombinedProfile.java"

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


# --- STEP 2: GENERATE COMBINED BASEMAP (OSM + CONTOURS) ---
echo "--- Generating combined basemap with custom profile... ---"

if [ ! -f "$FINAL_BASEMAP_OUTPUT" ]; then
    docker run --rm \
      -e "JAVA_TOOL_OPTIONS=-Xmx16g" \
      -v "$(pwd):/work" \
      -w /work \
      ${PLANETILER_IMAGE} \
      --profile="${COMBINED_PROFILE}" \
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

    # Clean up previous intermediate file if it exists
    rm -f ${HILLSHADE_MBTILES}

    echo "--- Step 3a: Converting GeoTIFF to MBTiles with rio-mbtiles... ---"
    # This is a more robust method than gdal2tiles. It creates a single MBTiles file directly.
    # We must first install the libexpat1 system dependency for rasterio to work correctly.
    docker run --rm \
      -v "$(pwd)/data:/data" \
      ${RIO_IMAGE} \
      /bin/bash -c "apt-get update && apt-get install -y libexpat1 && pip install rasterio rio-mbtiles && rio mbtiles /data/processed/hillshade.tif -o /data/processed/hillshade.mbtiles --zoom-levels 7..14"

    echo "--- Step 3b: Packaging MBTiles into PMTiles with the 'pmtiles' CLI... ---"
    # The pmtiles tool efficiently converts the mbtiles archive to the final pmtiles format.
    docker run --rm \
      -v "$(pwd)/data:/data" \
      ${PMTILES_IMAGE} \
      convert "/data/processed/hillshade.mbtiles" "/data/$(basename ${HILLSHADE_OUTPUT})"

    # Clean up the intermediate mbtiles file
    echo "--- Cleaning up intermediate MBTiles file... ---"
    rm -f ${HILLSHADE_MBTILES}

    echo "--- Hillshade generation complete: ${HILLSHADE_OUTPUT} ---"
else
    echo "--- SKIPPING: Hillshade file ${HILLSHADE_OUTPUT} already exists. ---"
fi

echo "--- TILE GENERATION SCRIPT FINISHED SUCCESSFULLY. ---"
