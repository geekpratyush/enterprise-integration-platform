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
