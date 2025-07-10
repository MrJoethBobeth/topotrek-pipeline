#!/bin/bash
set -e

# ==============================================================================
# MASTER PIPELINE CONTROL SCRIPT (V3)
#
# Orchestrates the entire Topotrek data processing pipeline.
#
# Usage: ./run_pipeline.sh [all|basemap|contours|upload|clean]
#
# Arguments:
#   all       - (Default) Runs the full pipeline: basemap, contours, and upload.
#   basemap   - Generates only the vector basemap from OSM data.
#   contours  - Generates only the vector contour tiles from DEM data.
#   upload    - Uploads existing .pmtiles files from the ./data directory to R2.
#   clean     - Removes generated data and build artifacts.
# ==============================================================================

# --- Argument Handling ---
# Set default action to 'all' if no argument is provided.
ARG=${1:-all}

# --- Function Definitions ---

run_basemap() {
    echo "======================================================"
    echo "  STARTING VECTOR BASEMAP GENERATION  "
    echo "======================================================"
    if [ -f "./scripts/2a_generate_basemap.sh" ]; then
        bash ./scripts/2a_generate_basemap.sh
    else
        echo "Error: script '2a_generate_basemap.sh' not found."
        exit 1
    fi
    echo "========================================="
    echo "  BASEMAP GENERATION COMPLETE          "
    echo "========================================="
}

run_contour() {
    echo "======================================================"
    echo "  STARTING VECTOR CONTOUR TILE GENERATION  "
    echo "======================================================"
    if [ -f "./scripts/2b_generate_contours.sh" ]; then
        bash ./scripts/2b_generate_contours.sh
    else
        echo "Error: script '2b_generate_contours.sh' not found."
        exit 1
    fi
    echo "========================================="
    echo "  CONTOUR TILE GENERATION COMPLETE     "
    echo "========================================="
}


run_upload() {
    echo "========================================="
    echo "  STARTING UPLOAD TO CLOUDFLARE R2     "
    echo "========================================="
    if [ -f "./scripts/upload_tiles.sh" ]; then
        bash ./scripts/upload_tiles.sh
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
    # Clear out the data directory and subdirectories
    rm -rf ./data/*
    # Recreate the directories and gitkeep files
    mkdir -p ./data/sources ./data/processed
    touch ./data/.gitkeep ./data/sources/.gitkeep ./data/processed/.gitkeep

    echo "Pruning unused Docker images, containers, and volumes..."
    docker system prune -af

    echo "Cleanup complete."
    echo "========================================="
}

# --- Main Execution Logic ---

case $ARG in
    all)
        run_basemap
        run_contour
        run_upload
        ;;
    basemap)
        run_basemap
        ;;
    contours)
        run_contour
        ;;
    upload)
        run_upload
        ;;
    clean)
        run_clean
        ;;
    *)
        echo "Invalid argument: $ARG"
        echo "Usage: $0 [all|basemap|contours|upload|clean]"
        exit 1
        ;;
esac

echo "Pipeline execution finished successfully for target: $ARG"
