#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# ==============================================================================
# GENERATE BASEMAP SCRIPT
#
# This script orchestrates the OpenMapTiles pipeline to generate a vector tile
# basemap for the region specified in the.env file.
#
# It performs the following steps:
# 1. Pulls the latest required Docker images.
# 2. Initializes required directories.
# 3. Downloads the specified OSM data from Geofabrik.
# 4. Imports supplementary data (Natural Earth, etc.).
# 5. Imports the main OSM data into PostGIS.
# 6. Imports Wikidata for multilingual labels.
# 7. Generates the final vector tiles in.mbtiles format.
# ==============================================================================

echo "---"
echo "STEP 1: Pulling OpenMapTiles Docker images..."
echo "---"
docker-compose pull

echo "---"
echo "STEP 2: Initializing directories..."
echo "---"
# Create the necessary directories for data and build artifacts.
mkdir -p ./data ./build

echo "---"
echo "STEP 3: Downloading OSM data for US Northeast from Geofabrik..."
echo "---"
# The import-data image expects the action as a direct command, not a script.
docker-compose run --rm import-data download-geofabrik

echo "---"
echo "STEP 4: Importing supplementary data (Natural Earth, Lake Labels)..."
echo "---"
# This also uses the import-data image with a different command.
docker-compose run --rm import-data import-data

echo "---"
echo "STEP 5: Importing OpenStreetMap data into PostGIS..."
echo "This is a long-running step."
echo "---"
# Run the OSM import script
docker-compose run --rm import-osm ./import-osm.sh

echo "---"
echo "STEP 6: Importing Wikidata for multilingual labels..."
echo "---"
# Run the Wikidata import script
docker-compose run --rm import-wikidata ./import-wikidata.sh

echo "---"
echo "STEP 7: Running SQL post-processing..."
echo "---"
# Run the SQL import script
docker-compose run --rm import-sql ./import-sql.sh

echo "---"
echo "STEP 8: Generating vector tiles..."
echo "This is the final, long-running generation step."
echo "---"
# Run the tile generation script
docker-compose run --rm generate-vectortiles ./generate-vectortiles.sh

# Load variables from.env file to get the output filename
set -o allexport
source .env
set +o allexport

echo "---"
echo "SUCCESS: Basemap generation complete."
echo "Output file created at:./data/${MBTILES_FILE}"
echo "---"

echo "---"
echo "STEP 9: Converting MBTiles to cloud-optimized PMTiles..."
echo "---"
docker-compose run --rm pmtiles-converter

echo "---"
echo "SUCCESS: PMTiles conversion complete."
# The output filename will be the MBTILES_FILE name with the extension changed.
PMTILES_FILE="${MBTILES_FILE%.*}.pmtiles"
echo "Final artifact created at:./data/${PMTILES_FILE}"
echo "---"
