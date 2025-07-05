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
BASEMAP_OUTPUT="${OUTPUT_DIR}/${REGION_NAME}_basemap.pmtiles"
HILLSHADE_INPUT="./data/processed/hillshade.tif"
HILLSHADE_OUTPUT="${OUTPUT_DIR}/${REGION_NAME}_hillshade.pmtiles"

# --- Data preparation step has been removed ---
# That process should be run separately using: bash ./scripts/1_prepare_data.sh


# --- STEP 1: GENERATE CUSTOM VECTOR BASEMAP ---
echo "--- Starting Planetiler to generate custom vector basemap... ---"
# --- FIX: Use a wildcard classpath to include all JARs in the /app directory.
# This is more robust to changes in the Planetiler image's internal structure and
# ensures the Java compiler can find all necessary library files.
docker run --rm \
  --entrypoint /bin/bash \
  -e "JAVA_TOOL_OPTIONS=-Xmx10g" \
  -v "$(pwd):/work" \
  -w /work \
  ${PLANETILER_IMAGE} \
  -c "
    # 1. Compile the custom Java profile against the planetiler libraries.
    #    Using a wildcard '/app/*' for the classpath is more robust than
    #    assuming a single fat jar. The single quotes prevent the shell from
    #    expanding the wildcard; javac will handle it.
    javac -cp '/app/*' planetiler_profile/OutdoorProfile.java && \
    # 2. Run the compiled profile by specifying its main class.
    #    The classpath must include the planetiler libraries AND the current directory ('.')
    #    so that Java can find both the planetiler libraries and your new .class file.
    java -cp '/app/*:.' planetiler_profile.OutdoorProfile \
    --area=${GEOFABRIK_PATH} \
    --bounds=${BBOX} \
    --download \
    --output=\"/work/data/${REGION_NAME}_basemap.pmtiles\"
  "

echo "--- Basemap generation complete: ${BASEMAP_OUTPUT} ---"


# --- STEP 2: GENERATE RASTER HILLSHADE TILES ---
echo "--- Generating raster hillshade PMTiles... ---"
# Check if the hillshade input file exists before proceeding
if [ ! -f "$HILLSHADE_INPUT" ]; then
    echo "Error: Hillshade input file not found at ${HILLSHADE_INPUT}"
    echo "Please run the data preparation script first: bash ./scripts/1_prepare_data.sh"
    exit 1
fi
docker run --rm \
  -v "$(pwd):/work" \
  -w /work \
  ${GDAL_IMAGE} /bin/bash -c "pip install rio-pmtiles && rio pmtiles /work/data/processed/hillshade.tif /work/data/${REGION_NAME}_hillshade.pmtiles --zoom-range 8-14"

echo "--- Hillshade generation complete: ${HILLSHADE_OUTPUT} ---"
echo "--- ENTIRE PIPELINE SUCCESSFUL. ---"
