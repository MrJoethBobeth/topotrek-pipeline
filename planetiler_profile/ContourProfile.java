package planetiler_profile;

import com.onthegomap.planetiler.FeatureCollector;
import com.onthegomap.planetiler.Planetiler;
import com.onthegomap.planetiler.Profile;
import com.onthegomap.planetiler.config.Arguments;
import com.onthegomap.planetiler.reader.SourceFeature;

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
                // Use setSortKey for z-ordering in recent Planetiler versions
                .setSortKey(100);
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
        // It only processes the single, specified GeoPackage.
        Planetiler.create(args)
            .setProfile(new ContourProfile())
            // The addGeoPackageSource method now requires the layer name as the third argument.
            .addGeoPackageSource("contours", Path.of("data", "processed", "contours.gpkg"), "contours")
            .run();
    }
}
