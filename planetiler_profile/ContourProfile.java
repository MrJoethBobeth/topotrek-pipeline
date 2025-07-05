// Save as planetiler_profile/ContourProfile.java
import com.onthegomap.planetiler.FeatureCollector;
import com.onthegomap.planetiler.Planetiler;
import com.onthegomap.planetiler.Profile;
import com.onthegomap.planetiler.config.Arguments;
import com.onthegomap.planetiler.reader.SourceFeature;
import com.onthegomap.planetiler.source.Shapefile;

import java.nio.file.Path;

/**
 * A simple Planetiler profile that generates a map containing only contour lines
 * from a specified GeoPackage file.
 */
public class ContourProfile implements Profile {

    @Override
    public void processFeature(SourceFeature sourceFeature, FeatureCollector features) {
        // This profile only processes one source, named "contours".
        if ("contours".equals(sourceFeature.getSource()) && sourceFeature.canBeLine()) {
            features.line("contour")
                // The 'elev' attribute from the shapefile is mapped to 'ele' in the tiles.
                .setAttr("ele", sourceFeature.getTag("elev"))
                .setMinZoom(11)
                // Set a high z-order to ensure contours render on top of other features.
                .setZOrder(100);
        }
    }

    @Override
    public String name() {
        return "Contour Lines";
    }

    @Override
    public String description() {
        return "A map of contour lines from local data.";
    }

    // Main entry point for Planetiler
    public static void main(String[] args) throws Exception {
        run(Arguments.fromArgsOrConfigFile(args));
    }

    static void run(Arguments args) throws Exception {
        // This profile does not process any OSM data, so we don't need an area.
        // It only processes the single, specified shapefile.
        Planetiler.create(args)
            .setProfile(new ContourProfile())
            .addSource(new Shapefile("contours", Path.of("data", "processed", "contours.gpkg")))
            // Overwrite the output file if it already exists.
            .overwrite()
            .run();
    }
}
