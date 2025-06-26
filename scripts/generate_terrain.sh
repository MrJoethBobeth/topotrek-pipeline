#!/bin/bash
set -e

# ==============================================================================
# GENERATE TERRAIN SCRIPT
#
# This script orchestrates the custom pipeline for generating Terrain-RGB tiles.
#
# It performs the following steps:
# 1. Builds the dedicated GDAL processing Docker image.
# 2. Creates necessary input/output directories.
# 3. Downloads high-resolution USGS 3DEP data via the OpenTopography API.
# 4. Runs the GDAL container to perform the processing chain:
#    a. Merge and reproject source GeoTIFFs.
#    b. Encode elevation data into Terrain-RGB format.
#    c. Tile the RGB raster into a Z/X/Y directory structure.
# 5. Packages the final tile directory into a.pmtiles archive.
# ==============================================================================

# Load variables from.env for BBOX, API key, etc.
set -o allexport
source .env
set +o allexport

TERRAIN_DIR="./data/terrain"
RAW_DEM_DIR="${TERRAIN_DIR}/raw_dem"
PROCESSED_DEM_DIR="${TERRAIN_DIR}/processed_dem"
TILES_DIR="${TERRAIN_DIR}/tiles"
OUTPUT_FILENAME="us-northeast-terrain.pmtiles"

echo "---"
echo "STEP 1: Building GDAL processing image..."
echo "---"
docker build -t topotrek/gdal-processor -f docker/Dockerfile.gdal .

echo "---"
echo "STEP 2: Setting up terrain directories..."
echo "---"
mkdir -p $RAW_DEM_DIR $PROCESSED_DEM_DIR $TILES_DIR

echo "---"
echo "STEP 3: Downloading high-resolution DEM from OpenTopography API..."
echo "This may take some time depending on the area size."
echo "---"
# Note: A Python script 'download_dem.py' would be called here.
# This script would use the OPENTOPOGRAPHY_API_KEY and BBOX from.env
# to fetch GeoTIFFs and place them in $RAW_DEM_DIR.
# For this example, we assume the files are manually placed for now.
# python3 scripts/download_dem.py
echo "Skipping download for now. Assuming DEM files exist in ${RAW_DEM_DIR}"
if [ -z "$(ls -A $RAW_DEM_DIR)" ]; then
   echo "Error: ${RAW_DEM_DIR} is empty. Please add source GeoTIFF files."
   exit 1
fi


echo "---"
echo "STEP 4: Processing DEM to Terrain-RGB tiles..."
echo "This is a very long-running step."
echo "---"
# This command runs the entire processing chain inside the GDAL container.
# It mounts the data directory and executes an inline script.
docker run --rm -v "$(pwd)/data/terrain:/data" topotrek/gdal-processor /bin/bash -c '
  set -e
  echo "--> Merging and Warping to EPSG:3857"
  gdalbuildvrt /data/processed_dem/source.vrt /data/raw_dem/*.tif
  gdalwarp -t_srs EPSG:3857 -r bilinear -of GTiff /data/processed_dem/source.vrt /data/processed_dem/warped.tif

  echo "--> Encoding to Terrain-RGB"
  rio rgbify -b -10000 -i 0.1 /data/processed_dem/warped.tif /data/processed_dem/rgb.tif

  echo "--> Tiling with gdal2tiles"
  gdal2tiles.py --zoom=8-14 --processes=4 -p raster /data/processed_dem/rgb.tif /data/tiles
'

echo "---"
echo "STEP 5: Packaging tiles into PMTiles archive..."
echo "---"
# Use the pmtiles CLI to convert the directory of tiles into a single archive.
docker run --rm -v "$(pwd)/data:/data" protomaps/go-pmtiles \
  pmtiles convert /data/tiles /data/${OUTPUT_FILENAME}

echo "---"
echo "SUCCESS: Terrain generation complete."
echo "Final artifact created at:./data/${OUTPUT_FILENAME}"
echo "---"
