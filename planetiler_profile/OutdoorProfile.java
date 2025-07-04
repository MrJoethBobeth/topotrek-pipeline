// Save as planetiler_profile/OutdoorProfile.java
package com.onthegomap.planetiler.examples;

import com.onthegomap.planetiler.FeatureCollector;
import com.onthegomap.planetiler.Planetiler;
import com.onthegomap.planetiler.Profile;
import com.onthegomap.planetiler.config.Arguments;
import com.onthegomap.planetiler.reader.SourceFeature;
import com.onthegomap.planetiler.util.ZoomFunction;

import java.nio.file.Path;

public class OutdoorProfile implements Profile {

    @Override
    public void processFeature(SourceFeature sourceFeature, FeatureCollector features) {
        String source = sourceFeature.getSource();

        // === AUTHORITATIVE DATA SOURCES ===
        if ("contours".equals(source) && sourceFeature.canBeLine()) {
            features.line("contour")
                .setAttr("ele", sourceFeature.getTag("elev"))
                .setMinZoom(11);
        }

        if ("padus".equals(source) && sourceFeature.canBePolygon()) {
            features.polygon("protected_area")
                .setAttr("name", sourceFeature.getTag("UNIT_NM"))
                .setAttr("manager", sourceFeature.getTag("MNG_AGENCY"))
                .setAttr("access", sourceFeature.getTag("ACCESS_TYP"))
                .setZOrder(-1) // Draw below other features
                .setMinZoom(8);
        }

        // === OPENSTREETMAP SOURCE ===
        if ("osm".equals(source)) {
            // --- TRAIL PROCESSING ---
            if (sourceFeature.canBeLine() && sourceFeature.hasTag("highway", "path", "track", "footway", "cycleway", "steps")) {
                var feature = features.line("transportation")
                    .setAttr("transportation_name", sourceFeature.getTag("name"))
                    .setAttr("class", "path") // General class for all trails
                    .setAttr("subclass", sourceFeature.getTag("highway")) // Specific type
                    .setAttr("surface", sourceFeature.getTag("surface"))
                    .setAttr("ref", sourceFeature.getTag("ref"))
                    .setAttr("network", sourceFeature.getTag("network"))
                    .setAttr("operator", sourceFeature.getTag("operator"))
                    // Hiking & MTB Difficulty Scales
                    .setAttr("sac_scale", sourceFeature.getTag("sac_scale"))
                    .setAttr("mtb_scale", sourceFeature.getTag("mtb:scale"))
                    .setAttr("trail_visibility", sourceFeature.getTag("trail_visibility"));
                
                // Set z-order to ensure trails draw above minor roads
                feature.setZOrder(10);
            }

            // --- OUTDOOR POI PROCESSING ---
            if (sourceFeature.isPoint()) {
                if (sourceFeature.hasTag("natural", "spring", "peak", "saddle")) {
                    var poi = features.point("outdoor_poi")
                        .setAttr("class", sourceFeature.getTag("natural"))
                        .setAttr("name", sourceFeature.getTag("name"))
                        .setAttr("ele", sourceFeature.getTag("ele"));
                }
                if (sourceFeature.hasTag("tourism", "viewpoint", "wilderness_hut", "alpine_hut")) {
                     features.point("outdoor_poi")
                        .setAttr("class", sourceFeature.getTag("tourism"))
                        .setAttr("name", sourceFeature.getTag("name"));
                }
            }
        }
    }

    @Override
    public String name() {
        return "Outdoor Hiking Map";
    }

    // Main entry point for Planetiler
    public static void main(String[] args) throws Exception {
        run(Arguments.fromArgsOrConfigFile(args));
    }

    static void run(Arguments args) throws Exception {
        String area = args.getString("area", "geofabrik area to download", "monaco");
        Planetiler.create(args)
            .setProfile(new OutdoorProfile())
            // Register OSM Source
            .addOsmSource("osm", Path.of("data", "sources", area + ".osm.pbf"), "geofabrik:" + area)
            // Register Authoritative Sources (from our pre-processing script)
            .addShapefileSource("padus", Path.of("data", "processed", "protected_areas_simplified.gpkg"))
            .addShapefileSource("contours", Path.of("data", "processed", "contours.gpkg"))
            .overwriteOutput("pmtiles", Path.of("data", "output.pmtiles"))
            .run();
    }
}