#!/bin/bash
set -e
set -o allexport
source ../.env
set +o allexport

# --- Configuration ---
BBOX_LAT_MIN=$(echo $BBOX | cut -d',' -f2)
BBOX_LON_MIN=$(echo $BBOX | cut -d',' -f1)
BBOX_LAT_MAX=$(echo $BBOX | cut -d',' -f4)
BBOX_LON_MAX=$(echo $BBOX | cut -d',' -f3)

SOURCES_DIR="../data/sources"
PROCESSED_DIR="../data/processed"
mkdir -p ${SOURCES_DIR} ${PROCESSED_DIR}

DEM_RAW="${SOURCES_DIR}/dem_raw.tif"
DEM_PROCESSED="${PROCESSED_DIR}/dem_processed.tif"
HILLSHADE_RASTER="${PROCESSED_DIR}/hillshade.tif"
CONTOURS_VECTOR="${PROCESSED_DIR}/contours.gpkg"
PADUS_ZIP="${SOURCES_DIR}/padus.zip"
PADUS_SHP="${SOURCES_DIR}/PADUS3_0Geopackage.gpkg/PADUS3_0Combined_Proclamation_Marine_Fee_Designation_Easement.shp"
PROTECTED_AREAS_VECTOR="${PROCESSED_DIR}/protected_areas_simplified.gpkg"

echo "--- STEP 1: DOWNLOADING AND PROCESSING TERRAIN DATA (USGS 3DEP) ---"
# Download 10m DEM data for the bounding box using the OpenTopography API
curl -o ${DEM_RAW} "https://portal.opentopography.org/API/globaldem?demtype=SRTMGL3&south=${BBOX_LAT_MIN}&north=${BBOX_LAT_MAX}&west=${BBOX_LON_MIN}&east=${BBOX_LON_MAX}&outputFormat=GTiff&API_Key=${OPENTOPOGRAPHY_API_KEY}"

# Generate Contour Lines (every 40 feet)
echo "Generating contour lines..."
gdal_contour -a elev -i 40 ${DEM_RAW} ${CONTOURS_VECTOR}

# Generate Hillshade Raster
echo "Generating hillshade..."
gdaldem hillshade -of GTiff ${DEM_RAW} ${HILLSHADE_RASTER}

echo "--- STEP 2: DOWNLOADING AND SIMPLIFYING PROTECTED AREAS (PAD-US) ---"
# Download PAD-US data (note: this is a large file)
echo "Downloading PAD-US data..."
curl -o ${PADUS_ZIP} -L "https://s3.amazonaws.com/padus/PAD_US3_0.zip"
unzip -o ${PADUS_ZIP} -d ${SOURCES_DIR}

# Simplify PAD-US polygons to reduce file size and improve performance
# The simplification tolerance (0.001) may need adjustment
echo "Simplifying protected area polygons..."
ogr2ogr -f GPKG ${PROTECTED_AREAS_VECTOR} ${PADUS_SHP} \
  -simplify 0.001 \
  -nln protected_areas \
  -clipdst ${BBOX_LON_MIN} ${BBOX_LAT_MIN} ${BBOX_LON_MAX} ${BBOX_LAT_MAX}

echo "--- Data preparation complete. ---"