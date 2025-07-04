#!/bin/bash
set -e

# ==============================================================================
# MASTER PIPELINE CONTROL SCRIPT
#
# Orchestrates the entire Topotrek data processing pipeline.
#
# Usage: ./run_pipeline.sh [all|basemap|terrain|upload|clean]
#
# Arguments:
#   all       - (Default) Runs the full pipeline: basemap, terrain, and upload.
#   basemap   - Generates only the vector basemap using Planetiler.
#   terrain   - Generates only the Quantized Mesh terrain tiles using ctod.
#   upload    - Uploads existing .pmtiles files from the ./data directory to R2.
#   clean     - Removes generated data and build artifacts.
# ==============================================================================

# --- Argument Handling ---
# Set default action to 'all' if no argument is provided.
ARG=${1:-all}

# --- Function Definitions ---

run_basemap() {
    echo "========================================="
    echo "  STARTING BASEMAP GENERATION PIPELINE   "
    echo "========================================="
    if [ -f "./scripts/generate_basemap.sh" ]; then
        ./scripts/generate_basemap.sh
    else
        echo "Error: script 'generate_basemap.sh' not found."
        exit 1
    fi
    echo "========================================="
    echo "  BASEMAP GENERATION COMPLETE          "
    echo "========================================="
}

run_terrain() {
    echo "========================================="
    echo "  STARTING TERRAIN GENERATION PIPELINE   "
    echo "========================================="
    if [ -f "./scripts/generate_terrain.sh" ]; then
        ./scripts/generate_terrain.sh
    else
        echo "Error: script 'generate_terrain.sh' not found."
        exit 1
    fi
    echo "========================================="
    echo "  TERRAIN GENERATION COMPLETE          "
    echo "========================================="
}

run_upload() {
    echo "========================================="
    echo "  STARTING UPLOAD TO CLOUDFLARE R2     "
    echo "========================================="
    if [ -f "./scripts/upload_tiles.sh" ]; then
        ./scripts/upload_tiles.sh
    else
        echo "Error: script 'upload_tiles.sh' not found."
        exit 1
    fi
    echo "========================================="
    echo "  UPLOAD COMPLETE                      "
    echo "========================================="
}

run_clean() {
    echo "========================================="
    echo "  CLEANING PROJECT WORKSPACE           "
    echo "========================================="
    echo "Removing generated data..."
    # Clear out the data and build directories, but keep the directories and .gitkeep files
    rm -f ./data/*.* ./build/*.*
    touch ./data/.gitkeep ./build/.gitkeep
    
    echo "Pruning unused Docker images, containers, and volumes..."
    docker system prune -af

    echo "Cleanup complete."
    echo "========================================="
}

# --- Main Execution Logic ---

# Use a case statement for clear, readable flow control.
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

echo "Pipeline execution finished successfully for target: $ARG"
