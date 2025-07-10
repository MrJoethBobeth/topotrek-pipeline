# **TopoTrek Map Pipeline**

This repository contains a set of scripts to build a custom, two-layer vector map designed for outdoor use. The pipeline generates a main basemap from OpenStreetMap data and a separate vector contour layer from USGS elevation data. Both layers are output in the cloud-optimized .pmtiles format, ready for hosting and display on a web map.

The entire process is orchestrated using shell scripts and containerized tools to ensure a reproducible and clean environment.

## **Prerequisites**

Before running the pipeline, you only need one piece of software installed and running on your host machine:

* **Docker**: All processing tools are run inside Docker containers, so you do not need to install Java, Python, or GDAL locally.

## **Key Components**

* **Data Sources**:  
  * **OpenStreetMap (OSM)**: Used for all basemap features like roads, buildings, land use, and points of interest. Data is sourced from Geofabrik.  
  * **USGS 3DEP**: 30-meter resolution Digital Elevation Model (DEM) data, sourced via the OpenTopography API, is used to generate contour lines.  
* **Core Technologies**:  
  * **Planetiler**: A high-performance Java-based tool for generating vector tiles from OSM and other data sources. We use it to create both the basemap and the contour tiles.  
  * **Docker**: Used to run all processing tools (Planetiler, GDAL, Python) in isolated containers, avoiding the need to install dependencies on the host machine.  
  * **GDAL**: A powerful geospatial data library used to process the raw DEM and generate contour lines.  
* **Planetiler Profiles**:  
  * planetiler\_profile/OutdoorProfile.java: A custom Java profile that defines the logic for processing OSM data into the layers and features for the main basemap.  
  * planetiler\_profile/ContourProfile.java: A dedicated profile that processes a GeoPackage of contour lines into a simple vector tile layer.  
* **Main Scripts**:  
  * run\_pipeline.sh: The master script that orchestrates the entire process.  
  * scripts/1\_prepare\_data.sh: Downloads the necessary DEM data and uses GDAL to generate a contours.gpkg file.  
  * scripts/2\_generate\_tiles.sh: The core tile generation script. It runs Planetiler twice—once for the basemap and once for the contours—to produce two separate .pmtiles files.  
  * scripts/upload\_tiles.sh: Uploads the final .pmtiles artifacts to a Cloudflare R2 bucket.

## **How to Run**

1. **Configuration**:  
   * Copy env.txt to a new .env file.  
   * Fill in the required values, including the bounding box (BBOX), Geofabrik region, and your Cloudflare R2 credentials.  
2. **Execute the Pipeline**:  
   * To run the entire process from data download to upload, simply execute:  
     ./run\_pipeline.sh all

   * To only generate the map tiles without uploading:  
     ./run\_pipeline.sh basemap

3. **Clean Up**:  
   * To remove all generated data and Docker artifacts, run:  
     ./run\_pipeline.sh clean  
