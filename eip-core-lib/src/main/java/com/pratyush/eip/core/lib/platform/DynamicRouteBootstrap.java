package com.pratyush.eip.core.lib.platform;

import com.pratyush.eip.core.lib.filter.EipIgnoreEngine;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import org.apache.camel.CamelContext;
import org.apache.camel.spi.Resource;
import org.apache.camel.support.ResourceHelper;
import io.quarkus.runtime.StartupEvent;
import org.apache.camel.support.PluginHelper;
import org.jboss.logging.Logger;

import jakarta.annotation.Priority;
import java.nio.file.Path;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@ApplicationScoped
public class DynamicRouteBootstrap {

    private static final Logger LOG = Logger.getLogger(DynamicRouteBootstrap.class);

    @Inject
    @Named("eipConfigDir")
    List<Path> configDirs;

    @Inject
    @Named("eipRouteDir")
    List<Path> routeDirs;

    @Inject
    CamelContext camelContext;

    void onStart(@Observes @Priority(100) StartupEvent ev) {
        LOG.info(">>> EIP Platform: Dynamic Bootstrap sequence initiated (Framework Managed Mode)...");
        Set<String> processedUris = new HashSet<>();

        // 1. Configuration/Bean Bootstrap
        for (Path configDir : configDirs) {
            LOG.infof("Bootstrapping EIP platform beans/assets from: %s", configDir.toAbsolutePath());
            processDirectory(configDir, processedUris);
        }

        // 2. Route Bootstrap
        for (Path routeDir : routeDirs) {
            LOG.infof("Bootstrapping EIP platform routes from: %s", routeDir.toAbsolutePath());
            processDirectory(routeDir, processedUris);
        }
    }

    private void processDirectory(Path dir, Set<String> processedUris) {
        EipIgnoreEngine engine = new EipIgnoreEngine(dir);
        try {
            List<Path> yamlFiles = engine.scanConfigDirectory(dir);
            yamlFiles.sort(Comparator.comparing(Path::toString));
            for (Path yamlFile : yamlFiles) {
                String uri = yamlFile.toUri().toString();
                if (processedUris.add(uri)) {
                    LOG.infof(">>> EIP Platform: [V6] Loading: %s", uri);
                    Resource resource = ResourceHelper.resolveResource(camelContext, uri);
                    PluginHelper.getRoutesLoader(camelContext).loadRoutes(resource);
                } else {
                    LOG.debugf(">>> EIP Platform: Skipping already processed file: %s", uri);
                }
            }
        } catch (Exception e) {
            LOG.errorf(e, ">>> EIP Platform: [V6 ERROR] Failed to load from directory: %s", dir);
        }
    }
}
