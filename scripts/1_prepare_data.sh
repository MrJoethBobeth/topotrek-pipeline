#!/bin/bash
set -e
set -o allexport
# The script is run from the project root, so the path to .env is direct
source ./.env
set +o allexport

# --- Configuration ---
BBOX_COORDS="${BBOX}"
# Paths are relative to the project root
SOURCES_DIR="./data/sources"
PROCESSED_DIR="./data/processed"
mkdir -p ${SOURCES_DIR} ${PROCESSED_DIR}

DEM_RAW="${SOURCES_DIR}/dem_raw.tif"
CONTOURS_VECTOR="${PROCESSED_DIR}/contours.gpkg"

GDAL_IMAGE="ghcr.io/osgeo/gdal:ubuntu-small-latest"
PYTHON_IMAGE="python:3.9-slim"

# Define Docker commands to mount the project root
GDAL_CMD="docker run --rm -v $(pwd)/data:/data ${GDAL_IMAGE}"
PYTHON_CMD="docker run --rm -v $(pwd):/work -w /work/scripts ${PYTHON_IMAGE}"


echo "--- STEP 1: DOWNLOADING AND PROCESSING TERRAIN DATA (USGS 3DEP) ---"
echo "Fetching DEM using Python script..."
# Use a bash shell in the container to install requests before running the python script
$PYTHON_CMD /bin/bash -c "pip install requests && python3 1a_fetch_dem.py '${OPENTOPOGRAPHY_API_KEY}' '${BBOX_COORDS}' '/work/data/sources/dem_raw.tif'"


# Generate Contour Lines inside a container
echo "Generating contour lines from DEM..."
$GDAL_CMD gdal_contour -a elev -i 40 "/data/sources/dem_raw.tif" "/data/processed/contours.gpkg"

# REMOVED: The hillshade generation step is no longer needed.
# echo "Generating hillshade..."
# $GDAL_CMD gdaldem hillshade -of GTiff "/data/sources/dem_raw.tif" "/data/processed/hillshade.tif"


echo "--- Terrain data preparation complete. ---"