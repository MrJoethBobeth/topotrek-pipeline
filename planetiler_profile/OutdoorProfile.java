package planetiler_profile;

import com.onthegomap.planetiler.FeatureCollector;
import com.onthegomap.planetiler.config.Arguments;
import com.onthegomap.planetiler.reader.SourceFeature;
import org.openmaptiles.OpenMapTilesProfile;
import org.openmaptiles.util.Utils;

import java.nio.file.Path;

/**
 * A custom Planetiler profile that extends the official OpenMapTiles (OMT) profile
 * to create a detailed outdoor and hiking basemap.
 *
 * This profile follows the "import, extend, and customize" pattern:
 * 1. INHERITS all the standard OMT layers (roads, water, cities, etc.).
 * 2. ADDS rich, hiking-specific attributes to the transportation layer.
 * 3. ENHANCES the park layer to better classify public lands.
 * 4. ENHANCES the POI layers to include detailed outdoor features like peaks with elevation.
 * 5. REMOVES unnecessary layers (like housenumbers and aeroways) to simplify the map.
 */
public class OutdoorProfile extends OpenMapTilesProfile {

    public OutdoorProfile(Arguments arguments) {
        super(arguments);

        // --- CUSTOMIZATION ---
        // This is where we override the default OMT layers with our enhanced versions.

        // 1. Enhance the 'transportation' layer with hiking details.
        this.replaceLayer("transportation", new TransportationLayerWithHiking(this.arguments));

        // 2. Enhance the 'park' layer with more detailed public land classification.
        this.replaceLayer("park", new ParkLayerWithPublicLands(this.arguments));

        // 3. Consolidate and enhance POI and mountain peak layers.
        this.removeLayer("poi"); // Remove the original POI layer
        this.removeLayer("mountain_peak"); // Remove the original mountain_peak layer
        this.registerSourceHandler("osm", new PoiLayerWithOutdoor(this.arguments)); // Add our combined, enhanced layer

        // 4. Remove layers we don't need for a clean outdoor map.
        this.removeLayer("housenumber");
        this.removeLayer("aeroway");
    }

    // Define a custom name for our profile.
    @Override
    public String name() {
        return "TopoTrek Outdoor Basemap";
    }

    // Define a custom description.
    @Override
    public String description() {
        return "A basemap based on OpenMapTiles, enhanced for outdoor and hiking use.";
    }


    /**
     * =================================================================================
     * CUSTOM LAYER IMPLEMENTATION: Transportation
     * =================================================================================
     * This class extends the default OMT Transportation layer. It keeps all the
     * original logic for roads, ferries, etc., but adds special attributes for trails.
     */
    class TransportationLayerWithHiking extends TransportationLayer {

        public TransportationLayerWithHiking(Arguments arguments) {
            super(arguments);
        }

        @Override
        public void processFeature(SourceFeature feature, FeatureCollector features) {
            // First, run the original OMT processing for this feature.
            super.processFeature(feature, features);

            // After OMT has processed it, we check if it's a path feature.
            // If so, we add our custom hiking tags to it.
            if (feature.canBeLine() && feature.hasTag("highway", "path", "footway", "track", "cycleway", "bridleway", "steps")) {
                features.line(this.name())
                    // Add detailed attributes for styling hiking/biking trails
                    .setAttr("sac_scale", feature.getTag("sac_scale"))
                    .setAttr("mtb_scale", feature.getTag("mtb:scale"))
                    .setAttr("trail_visibility", feature.getTag("trail_visibility"))
                    .setAttr("surface", feature.getTag("surface"));
            }
        }
    }

    /**
     * =================================================================================
     * CUSTOM LAYER IMPLEMENTATION: Park
     * =================================================================================
     * This class extends the default OMT Park layer to add more specific
     * classifications for different types of public land, similar to Gaia Topo.
     */
    class ParkLayerWithPublicLands extends ParkLayer {

        public ParkLayerWithPublicLands(Arguments arguments) {
            super(arguments);
        }

        @Override
        public void processFeature(SourceFeature feature, FeatureCollector features) {
            // First, run the original OMT processing.
            super.processFeature(feature, features);

            // Now, add our more specific public land classifications.
            if (feature.isPolygon() && feature.hasTag("boundary", "protected_area")) {
                FeatureCollector.Feature parkFeature = features.polygon(this.name())
                    .setAttr("name", feature.getTag("name"))
                    .setAttr("rank", feature.getInteger("rank", 1));

                // Extract the 'protection_title' to get specific land manager info
                String protectionTitle = feature.getString("protection_title", "").toLowerCase();
                if (protectionTitle.contains("national forest")) {
                    parkFeature.setAttr("subclass", "national_forest");
                } else if (protectionTitle.contains("state park")) {
                    parkFeature.setAttr("subclass", "state_park");
                } else if (protectionTitle.contains("wilderness")) {
                    parkFeature.setAttr("subclass", "wilderness");
                }
            }
        }
    }

    /**
     * =================================================================================
     * CUSTOM LAYER IMPLEMENTATION: POI and Mountain Peaks
     * =================================================================================
     * This class handles all POIs. It runs the original OMT POI and Mountain Peak logic
     * and then adds our own custom outdoor-specific points.
     */
    class PoiLayerWithOutdoor extends Handler {
        private final PoiLayer poiLayer;
        private final MountainPeakLayer mountainPeakLayer;

        public PoiLayerWithOutdoor(Arguments arguments) {
            this.poiLayer = new PoiLayer(arguments);
            this.mountainPeakLayer = new MountainPeakLayer(arguments);
        }
        
        @Override
        public void handle(SourceFeature feature, FeatureCollector features) {
            // Run the original OMT logic for both standard POIs and mountain peaks
            poiLayer.handle(feature, features);
            mountainPeakLayer.handle(feature, features);

            // Now, add our custom logic for specific outdoor POIs
            if (feature.isPoint()) {
                if (feature.hasTag("natural", "spring", "peak", "saddle")) {
                    features.point("mountain_peak") // Use the OMT standard layer name
                        .setAttr("class", feature.getTag("natural"))
                        .setAttr("name", feature.getTag("name"))
                        .setAttr("ele", feature.getTag("ele"));
                }
                if (feature.hasTag("tourism", "viewpoint", "wilderness_hut", "alpine_hut")) {
                     features.point("poi") // Use the OMT standard layer name
                        .setAttr("class", feature.getTag("tourism"))
                        .setAttr("subclass", feature.getTag("tourism"))
                        .setAttr("name", feature.getTag("name"));
                }
            }
        }
    }


    /**
     * =================================================================================
     * MAIN METHOD
     * =================================================================================
     * This is the entry point for Planetiler. The shell script (`2_generate_tiles.sh`)
     * will call this and pass in the necessary arguments, like the OSM file path.
     */
    public static void main(String[] args) throws Exception {
        run(Arguments.fromArgsOrConfigFile(args));
    }

    static void run(Arguments args) throws Exception {
        String area = args.getString("area", "geofabrik area to download", "us-northeast");

        Planetiler.create(args)
            .setProfile(new OutdoorProfile(args))
            .addOsmSource("osm",
                Path.of("data", "sources", area + ".osm.pbf"),
                "pbf"
            )
            .overwriteOutput("pmtiles", Path.of("data", "basemap.pmtiles"))
            .run();
    }
}
