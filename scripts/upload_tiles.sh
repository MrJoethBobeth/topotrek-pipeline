#!/bin/bash
set -e

# ==============================================================================
# UPLOAD TILES SCRIPT
#
# This script uploads the processed.pmtiles files to Cloudflare R2.
#
# It performs the following steps:
# 1. Loads credentials from the.env file.
# 2. Generates a temporary rclone.conf file from the template.
# 3. Uses a Dockerized rclone to sync the local data directory with the R2 bucket.
# 4. Cleans up the temporary config file.
# ==============================================================================

# Load variables from .env file
# FIX: Added a space between 'source' and '.env'
set -o allexport
source .env
set +o allexport

# --- Configuration ---
RCLONE_CONFIG_TEMPLATE="./config/rclone.conf.template"
RCLONE_CONFIG_TEMP="./config/rclone.conf.temp"
R2_BUCKET="topotrek-tiles"
SOURCE_DIR="./data"

# --- Validate Credentials ---
# FIX: Replaced the garbled 'if' statement with a valid check for empty variables.
if [ -z "${CF_ACCOUNT_ID}" ] || [ -z "${CF_ACCESS_KEY_ID}" ] || [ -z "${CF_SECRET_ACCESS_KEY}" ]; then
    echo "Error: Cloudflare R2 credentials not found in .env file."
    echo "Please set CF_ACCOUNT_ID, CF_ACCESS_KEY_ID, and CF_SECRET_ACCESS_KEY."
    exit 1
fi

echo "---"
echo "STEP 1: Generating temporary Rclone configuration..."
echo "---"
# Substitute environment variables into the template file
envsubst < "$RCLONE_CONFIG_TEMPLATE" > "$RCLONE_CONFIG_TEMP"

# --- Cleanup function to remove temp config on exit ---
cleanup() {
    echo "Cleaning up temporary Rclone configuration..."
    rm -f "$RCLONE_CONFIG_TEMP"
}
trap cleanup EXIT

echo "---"
echo "STEP 2: Syncing processed tiles to Cloudflare R2 bucket: ${R2_BUCKET}"
echo "---"

# Define the Rclone Docker command
# - Mounts the temporary config file to the container's config location.
# - Mounts the local data directory to be synced.
# - Uses the 'rclone/rclone' official image.
RCLONE_CMD="docker run --rm \
    -v $(pwd)/config/rclone.conf.temp:/config/rclone/rclone.conf \
    -v $(pwd)/data:/data \
    rclone/rclone"

# Sync basemap tiles
BASENAME_PMTILES=$(find "$SOURCE_DIR" -name 'us-northeast-osm.pmtiles' -print -quit)
# FIX: Replaced 'if;' with a valid check to see if the file was found.
if [ -n "$BASENAME_PMTILES" ]; then
    echo "Uploading basemap: $(basename "$BASENAME_PMTILES")"
    # The path inside the container is just /data/filename.
    # FIX: Added --s3-no-check-bucket to skip the bucket existence check.
    $RCLONE_CMD copy "/data/$(basename "$BASENAME_PMTILES")" "r2:${R2_BUCKET}/basemap/" --progress --s3-no-check-bucket
else
    echo "No basemap PMTiles file found to upload."
fi

# Sync terrain tiles
TERRAIN_PMTILES=$(find "$SOURCE_DIR" -name 'us-northeast-terrain.pmtiles' -print -quit)
# FIX: Replaced 'if;' with a valid check to see if the file was found.
if [ -n "$TERRAIN_PMTILES" ]; then
    echo "Uploading terrain: $(basename "$TERRAIN_PMTILES")"
    # FIX: Added --s3-no-check-bucket to skip the bucket existence check.
    $RCLONE_CMD copy "/data/$(basename "$TERRAIN_PMTILES")" "r2:${R2_BUCKET}/terrain/" --progress --s3-no-check-bucket
else
    echo "No terrain PMTiles file found to upload."
fi

echo "---"
echo "SUCCESS: Upload to Cloudflare R2 complete."
echo "---"

# FIX: Removed the extraneous closing brace '}' that was at the end of the original file.
