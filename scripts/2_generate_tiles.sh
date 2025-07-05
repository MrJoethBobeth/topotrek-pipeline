#!/bin/bash
set -e
set -o allexport
source ./.env
set +o allexport

# --- Configuration ---
PLANETILER_IMAGE="ghcr.io/onthegomap/planetiler:latest"
GDAL_IMAGE="ghcr.io/osgeo/gdal:ubuntu-small-latest"
OUTPUT_DIR="./data"
REGION_NAME=$(basename "${GEOFABRIK_PATH}")

# --- File Paths ---
OMT_JAR_URL="https://github.com/openmaptiles/planetiler-openmaptiles/releases/download/v3.1.0/openmaptiles.jar"
OMT_JAR_PATH="${OUTPUT_DIR}/openmaptiles.jar"
OMT_OUTPUT="${OUTPUT_DIR}/${REGION_NAME}_openmaptiles.pmtiles"
CONTOUR_INPUT="./data/processed/contours.gpkg"
CONTOUR_OUTPUT="${OUTPUT_DIR}/contours.pmtiles"
FINAL_BASEMAP_OUTPUT="${OUTPUT_DIR}/${REGION_NAME}_basemap.pmtiles"
HILLSHADE_INPUT="./data/processed/hillshade.tif"
HILLSHADE_OUTPUT="${OUTPUT_DIR}/${REGION_NAME}_hillshade.pmtiles"

# --- STEP 1: DOWNLOAD AND VALIDATE PRE-COMPILED OPENMAPTILES PROFILE ---
echo "--- Downloading OpenMapTiles profile JAR... ---"
if [ ! -f "$OMT_JAR_PATH" ]; then
    # Use -L to follow redirects. We remove -f to see potential server errors.
    curl -L -o "$OMT_JAR_PATH" "$OMT_JAR_URL"

    # --- VALIDATION ---
    # Check if the downloaded file is a reasonable size. A corrupted download
    # often results in a very small file. The real JAR is >30MB.
    MIN_SIZE=1000000 # 1MB
    # Use 'stat' to get the file size in bytes.
    FILE_SIZE=$(stat -c%s "$OMT_JAR_PATH")
    if [ "$FILE_SIZE" -lt "$MIN_SIZE" ]; then
        echo "Error: Download of openmaptiles.jar failed. File is too small ($FILE_SIZE bytes)."
        echo "Please check your network connection or the URL: $OMT_JAR_URL"
        # Clean up the corrupted file before exiting.
        rm "$OMT_JAR_PATH"
        exit 1
    fi
    echo "Download successful. File size: $FILE_SIZE bytes."
else
    echo "JAR already exists, skipping download."
fi

# --- STEP 2: GENERATE BASEMAP USING OPENMAPTILES PROFILE ---
echo "--- Generating basemap with OpenMapTiles profile... ---"
# Construct the full download URL to bypass the Geofabrik name lookup.
OSM_DOWNLOAD_URL="https://download.geofabrik.de/${GEOFABRIK_PATH}-latest.osm.pbf"
echo "Using direct download URL: ${OSM_DOWNLOAD_URL}"

# This command runs Planetiler using the pre-compiled OpenMapTiles JAR.
docker run --rm \
  -e "JAVA_TOOL_OPTIONS=-Xmx10g" \
  -v "$(pwd)/data:/data" \
  ${PLANETILER_IMAGE} \
  --osm-url="${OSM_DOWNLOAD_URL}" \
  --bounds=${BBOX} \
  --download \
  --output="/data/$(basename ${OMT_OUTPUT})" \
  --profile="/data/$(basename ${OMT_JAR_PATH})"

echo "--- OpenMapTiles basemap generation complete: ${OMT_OUTPUT} ---"

# --- STEP 3: GENERATE CONTOUR LINES LAYER ---
echo "--- Generating custom contour lines layer... ---"
# This command compiles and runs our new, simple ContourProfile.java.
docker run --rm \
  --entrypoint /bin/bash \
  -e "JAVA_TOOL_OPTIONS=-Xmx2g" \
  -v "$(pwd):/work" \
  -w /work \
  ${PLANETILER_IMAGE} \
  -c "
    javac -cp \"/work/data/openmaptiles.jar\" planetiler_profile/ContourProfile.java && \
    java -cp \"/work/data/openmaptiles.jar:. \" planetiler_profile.ContourProfile \
    --output=\"/work/data/$(basename ${CONTOUR_OUTPUT})\"
  "
echo "--- Contour layer generation complete: ${CONTOUR_OUTPUT} ---"

# --- STEP 4: MERGE BASEMAP AND CONTOURS ---
echo "--- Merging basemap and contour layers... ---"
# Use Planetiler's merge utility to combine the two pmtiles files.
docker run --rm \
  -v "$(pwd)/data:/data" \
  ${PLANETILER_IMAGE} \
  merge "/data/$(basename ${OMT_OUTPUT})" "/data/$(basename ${CONTOUR_OUTPUT})" \
  --output="/data/$(basename ${FINAL_BASEMAP_OUTPUT})"

echo "--- Merge complete. Final basemap at: ${FINAL_BASEMAP_OUTPUT} ---"

# --- STEP 5: GENERATE RASTER HILLSHADE TILES ---
echo "--- Generating raster hillshade PMTiles... ---"
if [ ! -f "$HILLSHADE_INPUT" ]; then
    echo "Error: Hillshade input file not found at ${HILLSHADE_INPUT}"
    exit 1
fi
docker run --rm \
  -v "$(pwd):/work" \
  -w /work \
  ${GDAL_IMAGE} /bin/bash -c "pip install rio-pmtiles && rio pmtiles /work/data/processed/hillshade.tif /work/data/$(basename ${HILLSHADE_OUTPUT}) --zoom-range 8-14"

echo "--- Hillshade generation complete: ${HILLSHADE_OUTPUT} ---"
echo "--- ENTIRE PIPELINE SUCCESSFUL. ---"
