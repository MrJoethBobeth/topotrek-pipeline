#!/bin/bash
set -e

#=======================================================================
# GENERATE TERRAIN SCRIPT (MODERNIZED WITH CTOD)
#
# This script orchestrates the pipeline for generating Quantized Mesh terrain tiles.
# 1. Downloads high-resolution USGS 3DEP data.
# 2. Uses `ctod` to convert the source DEMs into a directory of .terrain tiles.
# 3. Uses `pmtiles` to package the tile directory into a single archive.
#=======================================================================

# --- Configuration ---
set -o allexport
source .env
set +o allexport

TERRAIN_DIR="./data/terrain"
RAW_DEM_DIR="${TERRAIN_DIR}/raw_dem"
TILES_DIR="${TERRAIN_DIR}/quantized_mesh_tiles"
OUTPUT_FILE="./data/us-northeast-terrain.pmtiles"
CTOD_IMAGE="tumgis/ctod:latest" # Or another suitable ctod container
PMTILES_IMAGE="protomaps/pmtiles:latest"

# Create necessary directories
mkdir -p $RAW_DEM_DIR $TILES_DIR

echo "---"
echo "STEP 1: Downloading high-resolution DEM from OpenTopography API..."
# This step remains the same as your original plan.
# A Python script using the OPENTOPOGRAPHY_API_KEY and BBOX would be called here.
# For this example, we assume the GeoTIFF files are manually placed.
echo "Assuming DEM files exist in ${RAW_DEM_DIR}"
if [ -z "$(ls -A $RAW_DEM_DIR)" ]; then
   echo "Error: ${RAW_DEM_DIR} is empty. Please add source GeoTIFF files."
   exit 1
fi
echo "---"

echo "STEP 2: Processing DEM to Quantized Mesh tiles with 'ctod'..."
echo "This is a high-performance C++ tool."
echo "---"
# Run the `ctod` container to process all GeoTIFFs in the input directory.
docker run --rm \
  -v "$(pwd)/data/terrain:/data" \
  ${CTOD_IMAGE} \
  ctod --input-dir /data/raw_dem --output-dir /data/quantized_mesh_tiles

echo "---"
echo "STEP 3: Packaging Quantized Mesh tiles into PMTiles archive..."
echo "---"
# Use the pmtiles CLI to convert the directory of tiles into a single archive.
docker run --rm \
  -v "$(pwd)/data:/data" \
  ${PMTILES_IMAGE} \
  convert \
  "/data/terrain/quantized_mesh_tiles" \
  "/data/us-northeast-terrain.pmtiles"

echo "---"
echo "SUCCESS: Terrain generation complete."
echo "Final artifact created at: ${OUTPUT_FILE}"
echo "---"