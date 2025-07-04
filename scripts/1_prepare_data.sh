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
PADUS_ZIP="${SOURCES_DIR}/padus.zip"
# FIX: Updated to the new Geodatabase folder name for PAD-US 4.1
PADUS_GDB_PATH="${SOURCES_DIR}/PADUS4_1Geodatabase.gdb"
PROTECTED_AREAS_VECTOR="${PROCESSED_DIR}/protected_areas_simplified.gpkg"

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


echo "--- STEP 2: DOWNLOADING AND SIMPLIFYING PROTECTED AREAS (PAD-US) ---"
echo "Downloading PAD-US data from USGS ScienceBase..."
# FIX: Updated to the stable download link for the latest version (PAD-US 4.1)
curl -L -A "Mozilla/5.0" -o ${PADUS_ZIP} "https://www.sciencebase.gov/catalog/file/get/652d4fc5d34e44db0e2ee45e?f=__disk__5b%2Ffe%2F16%2F5bfe1621235397e5a3299706634732d8479e54d5"

# Unzip and Simplify polygons inside a container
echo "Unzipping and simplifying protected area polygons..."
# FIX: Updated the gdal command to use the new GDB path and the new layer name ('PADUS4_1Combined')
$GDAL_CMD /bin/bash -c "unzip -o /data/sources/padus.zip -d /data/sources && \
  ogr2ogr -f GPKG /data/processed/protected_areas_simplified.gpkg \
  /data/sources/PADUS4_1Geodatabase.gdb \
  -sql 'SELECT * FROM PADUS4_1Combined' \
  -simplify 0.001 \
  -nln protected_areas \
  -clipdst $(echo ${BBOX_COORDS} | cut -d',' -f1) $(echo ${BBOX_COORDS} | cut -d',' -f2) $(echo ${BBOX_COORDS} | cut -d',' -f3) $(echo ${BBOX_COORDS} | cut -d',' -f4)"


echo "--- Data preparation complete. ---"
