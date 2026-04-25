package com.pratyush.eip.core.lib.config;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Named;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.*;
import java.util.stream.Collectors;

@ApplicationScoped
public class EipEnvironmentResolver {

    /**
     * Resolves a configuration key from System Properties (-D) first, then
     * Environment Variables.
     */
    public String resolve(String key, String defaultValue) {
        // Try System Property first
        String value = System.getProperty(key);
        if (value == null) {
            // Fallback to Environment Variable
            value = System.getenv(key);
        }
        return (value != null) ? value : defaultValue;
    }

    /**
     * Resolves the configuration directory paths (comma-separated).
     */
    @Produces
    @Named("eipConfigDir")
    public List<Path> getConfigDir() {
        return resolvePaths("EIP_CONFIG_DIR");
    }

    /**
     * Resolves the route directory paths (comma-separated).
     */
    @Produces
    @Named("eipRouteDir")
    public List<Path> getRouteDir() {
        return resolvePaths("EIP_ROUTE_DIR");
    }

    /**
     * Resolves the kamelet directory paths (EIP_KAMELET_DIR, comma-separated).
     */
    @Produces
    @Named("eipKameletDir")
    public List<Path> getKameletDir() {
        return resolvePaths("EIP_KAMELET_DIR");
    }

    private List<Path> resolvePaths(String key) {
        // Try multiple variations: EIP_ROUTE_DIR, EIP_ROUTES_DIR, eip.route.dir, eip.routes.dir
        String pluralKey = key.endsWith("DIR") ? key.replace("DIR", "DIRS") : key + "S";
        String dottedKey = key.toLowerCase().replace("_", ".");
        String dottedPluralKey = dottedKey.replace("dir", "dirs");

        String pathsString = resolve(key, null);
        if (pathsString == null) pathsString = resolve(pluralKey, null);
        if (pathsString == null) pathsString = resolve(dottedKey, null);
        if (pathsString == null) pathsString = resolve(dottedPluralKey, null);

        if (pathsString == null || pathsString.trim().isEmpty()) {
            return Collections.emptyList();
        }
        return Arrays.stream(pathsString.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .map(s -> Paths.get(s).toAbsolutePath())
                .collect(Collectors.toList());
    }

    @Produces
    @Named("eipCertDir")
    public Path getCertDir() {
        String certDirPath = resolve("EIP_CERT_DIR", "./certs");
        return Paths.get(certDirPath).toAbsolutePath();
    }

    @Produces
    @Named("eipAuditUri")
    public String getAuditUri() {
        return resolve("EIP_AUDIT_URI", "");
    }

    @Produces
    @Named("eipAuditGlobal")
    public boolean isAuditGlobal() {
        return Boolean.parseBoolean(resolve("EIP_AUDIT_GLOBAL", "false"));
    }

    /**
     * Resolves generic environment variables for use in Camel beans or components.
     */
    public String getEnv(String key) {
        return System.getenv(key);
    }
}
