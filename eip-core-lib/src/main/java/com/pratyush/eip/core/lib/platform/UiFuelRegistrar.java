package com.pratyush.eip.core.lib.platform;

import io.quarkus.runtime.StartupEvent;
import io.vertx.ext.web.Router;
import io.vertx.ext.web.handler.StaticHandler;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import java.io.File;
import java.util.Optional;

/**
 * UiFuelRegistrar - Reactive High-Performance Asset Server
 * 
 * Replaces basic JAX-RS wildcards with a native Vert.x StaticHandler.
 * This provides zero-copy file transfers, proper MIME-type discovery,
 * and robust caching headers for the EIP Designer UIs.
 */
@ApplicationScoped
public class UiFuelRegistrar {

    private static final Logger LOG = Logger.getLogger(UiFuelRegistrar.class);

    @ConfigProperty(name = "EIP_UI_DIR")
    Optional<String> uiDir;

    /**
     * Registers the static asset handler at the /fuel-ui/ root.
     * Use Vert.x directly to bypass JAX-RS path interference and 
     * provide better performance for binary/static designer assets.
     */
    public void setup(@Observes StartupEvent ev, Router router) {
        if (uiDir.isEmpty()) {
            LOG.warn(">>> [SKIPPED] EIP_UI_DIR not set. Designer UI will not be served.");
            return;
        }

        String actualPath = uiDir.get();
        File dir = new File(actualPath);

        if (!dir.exists() || !dir.isDirectory()) {
            LOG.errorf(">>> [ERROR] UI Directory does not exist: %s", actualPath);
            return;
        }

        LOG.infof(">>> [INDUSTRIALIZED] Serving Fuel Assets from: %s", actualPath);

        // 1. Pretty URL Handler: Map /fuel-ui/mx-to-mt to /fuel-ui/mx-to-mt.html
        router.route("/fuel-ui/:page").handler(ctx -> {
            String page = ctx.pathParam("page");
            // Only reroute if page is not empty, has no extension, and is not 'index'
            if (page != null && !page.isEmpty() && !page.contains(".") && !page.equals("index")) {
                ctx.reroute("/fuel-ui/" + page + ".html");
            } else {
                ctx.next();
            }
        });

        // 2. Register the Vert.x Static Handler
        router.route("/fuel-ui/*").handler(StaticHandler.create()
                .setAllowRootFileSystemAccess(true)
                .setWebRoot(actualPath)
                .setDefaultContentEncoding("UTF-8")
                .setIncludeHidden(false)
                .setDirectoryListing(false)
                .setIndexPage("index.html")
        );
    }
}
