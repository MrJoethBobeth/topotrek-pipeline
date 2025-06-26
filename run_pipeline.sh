#!/bin/bash
set -e

# ==============================================================================
# MASTER PIPELINE CONTROL SCRIPT (MODERNIZED)
#
# Usage: ./run_pipeline.sh [all|basemap|terrain|upload|clean]
#
# Arguments:
#   all       - Runs the full pipeline: basemap, terrain, and upload.
#   basemap   - Generates only the vector basemap using Planetiler.
#   terrain   - Generates only the Quantized Mesh terrain tiles using ctod.
#   upload    - Uploads existing .pmtiles files from the ./data directory to R2.
#   clean     - Removes generated data and build artifacts.
# ==============================================================================

# --- Argument Parsing ---
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 [all|basemap|terrain|upload|clean]"
    exit 1
fi

ARG=$1

# --- Function Definitions ---

run_basemap() {
    echo "========================================="
    echo "  STARTING BASEMAP GENERATION PIPELINE   "
    echo "========================================="
   ./scripts/generate_basemap.sh
    echo "========================================="
    echo "  BASEMAP GENERATION COMPLETE          "
    echo "========================================="
}

run_terrain() {
    echo "========================================="
    echo "  STARTING TERRAIN GENERATION PIPELINE   "
    echo "========================================="
   ./scripts/generate_terrain.sh
    echo "========================================="
    echo "  TERRAIN GENERATION COMPLETE          "
    echo "========================================="
}

run_upload() {
    echo "========================================="
    echo "  STARTING UPLOAD TO CLOUDFLARE R2     "
    echo "========================================="
   ./scripts/upload_tiles.sh
    echo "========================================="
    echo "  UPLOAD COMPLETE                      "
    echo "========================================="
}

run_clean() {
    echo "========================================="
    echo "  CLEANING PROJECT WORKSPACE           "
    echo "========================================="
    # The docker-compose command was removed as it is no longer used.
    # We can also add a docker system prune command to clean up any dangling images or containers.
    echo "Pruning unused Docker images and containers..."
    docker system prune -f
    echo "Removing generated data..."
    rm -rf ./data/* ./build/*
    # Keep .gitkeep files if they exist
    touch ./data/.gitkeep ./build/.gitkeep
    echo "Cleanup complete."
    echo "========================================="
}

# --- Main Execution Logic ---

case $ARG in
    all)
        run_basemap
        run_terrain
        run_upload
        ;;
    basemap)
        run_basemap
        ;;
    terrain)
        run_terrain
        ;;
    upload)
        run_upload
        ;;
    clean)
        run_clean
        ;;
    *)
        echo "Invalid argument: $ARG"
        echo "Usage: $0 [all|basemap|terrain|upload|clean]"
        exit 1
        ;;
esac

echo "Pipeline execution finished successfully."
