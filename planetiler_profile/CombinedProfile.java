package planetiler_profile;

import com.onthegomap.planetiler.FeatureCollector;
import com.onthegomap.planetiler.Planetiler;
import com.onthegomap.planetiler.Profile;
import com.onthegomap.planetiler.config.Arguments;
import com.onthegomap.planetiler.reader.SourceFeature;
// We'll use the official OpenMapTiles profile as a base
import org.openmaptiles.OpenMapTilesProfile;

import java.nio.file.Path;

/**
 * A combined Planetiler profile that generates a full basemap by wrapping the
 * official OpenMapTiles profile and adding a custom contour layer source.
 */
public class CombinedProfile implements Profile {

    // Instantiate the OpenMapTiles profile to use its feature processing logic.
    private final OpenMapTilesProfile openmaptiles = new OpenMapTilesProfile();

    @Override
    public void processFeature(SourceFeature sourceFeature, FeatureCollector features) {
        // If the feature is from the "osm" source, process it using the OpenMapTiles logic.
        if ("osm".equals(sourceFeature.getSource())) {
            openmaptiles.processFeature(sourceFeature, features);
        }

        // If the feature is from our custom "contours" source, add it to a 'contour' layer.
        if ("contours".equals(sourceFeature.getSource()) && sourceFeature.canBeLine()) {
            features.line("contour")
                // Map the 'elev' attribute from the GeoPackage to the vector tile.
                .setAttr("ele", sourceFeature.getTag("elev"))
                // Also create an attribute for elevation in feet, which is common for US maps.
                .setAttr("ele_ft", (int) (sourceFeature.getDouble("elev") * 3.28084))
                .setMinZoom(11)
                // Set a sort key to influence draw order; higher numbers are generally drawn on top.
                .setSortKey(100);
        }
    }

    @Override
    public String name() {
        return "TopoTrek Outdoor Basemap";
    }

    @Override
    public String description() {
        return "A combined basemap with OpenMapTiles features and custom contour lines.";
    }

    @Override
    public String attribution() {
        // Use the standard OpenMapTiles attribution.
        return openmaptiles.attribution();
    }

    // Main entry point for running this profile with Planetiler.
    public static void main(String[] args) throws Exception {
        run(Arguments.fromArgsOrConfigFile(args));
    }

    static void run(Arguments args) throws Exception {
        // Get the path to the OSM PBF file from arguments passed by the shell script.
        String osmPath = args.getString("osm_path", "data/sources/us-northeast-latest.osm.pbf");

        Planetiler.create(args)
            .setProfile(new CombinedProfile())
            // Define the primary OSM data source.
            .addOsmSource("osm", Path.of(osmPath))
            // Define the custom contour data source from the GeoPackage.
            // The third argument specifies the layer within the gpkg to use.
            .addGeoPackageSource("contours", Path.of("data/processed/contours.gpkg"), "contours")
            .run();
    }
}
