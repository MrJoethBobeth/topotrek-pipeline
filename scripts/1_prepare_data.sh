#!/bin/bash
set -e
set -o allexport
source ../.env
set +o allexport

# --- Configuration ---
BBOX_COORDS="${BBOX}"
SOURCES_DIR="../data/sources"
PROCESSED_DIR="../data/processed"
mkdir -p ${SOURCES_DIR} ${PROCESSED_DIR}

DEM_RAW="${SOURCES_DIR}/dem_raw.tif"
HILLSHADE_RASTER="${PROCESSED_DIR}/hillshade.tif"
CONTOURS_VECTOR="${PROCESSED_DIR}/contours.gpkg"

# Note: PAD-US variables and processing steps have been removed for development.
# PADUS_ZIP="${SOURCES_DIR}/padus.zip"
# PADUS_GDB_PATH="${SOURCES_DIR}/PADUS4_1Geodatabase.gdb"
# PROTECTED_AREAS_VECTOR="${PROCESSED_DIR}/protected_areas_simplified.gpkg"

GDAL_IMAGE="ghcr.io/osgeo/gdal:ubuntu-small-latest"
PYTHON_IMAGE="python:3.9-slim"

# Define Docker commands
GDAL_CMD="docker run --rm -v $(pwd)/../data:/data ${GDAL_IMAGE}"
PYTHON_CMD="docker run --rm -v $(pwd)/..:/work -w /work/scripts ${PYTHON_IMAGE}"


echo "--- STEP 1: DOWNLOADING AND PROCESSING TERRAIN DATA (USGS 3DEP) ---"
# Use the Python script to robustly download the DEM
echo "Fetching DEM using Python script..."
$PYTHON_CMD /bin/bash -c "pip install requests && python3 1a_fetch_dem.py '${OPENTOPOGRAPHY_API_KEY}' '${BBOX_COORDS}' '/work/data/sources/dem_raw.tif'"


# Generate Contour Lines inside a container
echo "Generating contour lines..."
$GDAL_CMD gdal_contour -a elev -i 40 "/data/sources/dem_raw.tif" "/data/processed/contours.gpkg"

# Generate Hillshade Raster inside a container
echo "Generating hillshade..."
$GDAL_CMD gdaldem hillshade -of GTiff "/data/sources/dem_raw.tif" "/data/processed/hillshade.tif"


echo "--- STEP 2 (OMITTED): DOWNLOADING AND SIMPLIFYING PROTECTED AREAS (PAD-US) ---"
echo "Skipping PAD-US data processing."


echo "--- Data preparation complete. ---"
