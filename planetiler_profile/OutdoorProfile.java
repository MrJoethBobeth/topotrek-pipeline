// Save as planetiler_profile/OutdoorProfile.java
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

        if ("contours".equals(source) && sourceFeature.canBeLine()) {
            features.line("contour")
                .setAttr("ele", sourceFeature.getTag("elev"))
                .setMinZoom(11);
        }

        if ("osm".equals(source)) {
            if (sourceFeature.canBeLine() && sourceFeature.hasTag("highway", "path", "track", "footway", "cycleway", "steps")) {
                features.line("transportation")
                    .setAttr("transportation_name", sourceFeature.getTag("name"))
                    .setAttr("class", "path")
                    .setAttr("subclass", sourceFeature.getTag("highway"))
                    .setAttr("surface", sourceFeature.getTag("surface"))
                    .setAttr("ref", sourceFeature.getTag("ref"))
                    .setAttr("network", sourceFeature.getTag("network"))
                    .setAttr("operator", sourceFeature.getTag("operator"))
                    .setAttr("sac_scale", sourceFeature.getTag("sac_scale"))
                    .setAttr("mtb_scale", sourceFeature.getTag("mtb:scale"))
                    .setAttr("trail_visibility", sourceFeature.getTag("trail_visibility"))
                    .setSortKey(10); // Use setSortKey
            }

            if (sourceFeature.isPoint()) {
                if (sourceFeature.hasTag("natural", "spring", "peak", "saddle")) {
                    features.point("outdoor_poi")
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

    public static void main(String[] args) throws Exception {
        run(Arguments.fromArgsOrConfigFile(args));
    }

    static void run(Arguments args) throws Exception {
        Planetiler.create(args)
            .setProfile(new OutdoorProfile())
            // Use the correct method for GeoPackage files
            .addGeoPackageSource("contours", Path.of("data", "processed", "contours.gpkg"))
            .run();
    }
}