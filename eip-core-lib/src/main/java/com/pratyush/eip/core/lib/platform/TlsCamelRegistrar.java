package com.pratyush.eip.core.lib.platform;

import io.quarkus.arc.Unremovable;
import jakarta.enterprise.context.ApplicationScoped;
import org.apache.camel.CamelContext;
import org.apache.camel.spi.CamelContextCustomizer;
import org.apache.camel.support.jsse.KeyManagersParameters;
import org.apache.camel.support.jsse.KeyStoreParameters;
import org.apache.camel.support.jsse.SSLContextParameters;
import org.apache.camel.support.jsse.TrustManagersParameters;
import org.eclipse.microprofile.config.ConfigProvider;
import org.jboss.logging.Logger;

import java.io.FileInputStream;
import java.security.KeyStore;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.util.HashSet;
import java.util.Set;
import java.util.stream.StreamSupport;

/**
 * Platform Component: Dynamic TLS Registry Registrar.
 * Uses total-programmatic loading to bypass environmental resource-loading quirks.
 */
@ApplicationScoped
@Unremovable
public class TlsCamelRegistrar implements CamelContextCustomizer {

    private static final Logger LOG = Logger.getLogger(TlsCamelRegistrar.class);

    @Override
    public void configure(CamelContext camelContext) {
        LOG.info(">>> EIP Platform: Initializing Metadata-Driven TLS Registry Registrar...");

        var config = ConfigProvider.getConfig();
        Set<String> configNames = new HashSet<>();

        StreamSupport.stream(config.getPropertyNames().spliterator(), false)
                .filter(p -> p.startsWith("quarkus.tls.") || p.startsWith("QUARKUS_TLS_"))
                .forEach(p -> {
                    String name;
                    if (p.startsWith("QUARKUS_TLS_")) {
                        String[] parts = p.split("_");
                        if (parts.length > 2) {
                            name = parts[2].toLowerCase();
                            configNames.add(name);
                        }
                    } else {
                        String[] parts = p.split("\\.");
                        if (parts.length > 2) {
                            name = parts[2].toLowerCase();
                            configNames.add(name);
                        }
                    }
                });

        for (String configName : configNames) {
            try {
                String prefix = "QUARKUS_TLS_" + configName.toUpperCase() + "_";
                
                String trustStoreJksPath = config.getOptionalValue(prefix + "TRUST_STORE_JKS_PATH", String.class).orElse(null);
                String trustStoreJksPass = config.getOptionalValue(prefix + "TRUST_STORE_JKS_PASSWORD", String.class).orElse("changeit");
                String trustCertPemPath = config.getOptionalValue(prefix + "TRUST_STORE_PEM_CERTS", String.class).orElse(null);
                
                String keyStorePath = config.getOptionalValue(prefix + "KEY_STORE_P12_PATH", String.class).orElse(null);
                String keyStorePass = config.getOptionalValue(prefix + "KEY_STORE_P12_PASSWORD", String.class).orElse("changeit");

                if (trustStoreJksPath == null && trustCertPemPath == null && keyStorePath == null) continue;

                LOG.infof(">>> EIP Platform: [TLS] [V3] Constructing SSLContextParameters for: '%s'", configName);
                SSLContextParameters ssl = new SSLContextParameters();

                // 1. Trust Manager Logic (Total Programmatic)
                TrustManagersParameters tmp = new TrustManagersParameters();
                final KeyStore ts;
                if (trustStoreJksPath != null) {
                    ts = KeyStore.getInstance("JKS");
                    try (FileInputStream fis = new FileInputStream(trustStoreJksPath)) {
                        ts.load(fis, trustStoreJksPass.toCharArray());
                    }
                    LOG.infof("    [TRUST] Programmatically loaded JKS truststore: %s", trustStoreJksPath);
                } else if (trustCertPemPath != null) {
                    CertificateFactory cf = CertificateFactory.getInstance("X.509");
                    ts = KeyStore.getInstance(KeyStore.getDefaultType());
                    ts.load(null, null);
                    try (FileInputStream fis = new FileInputStream(trustCertPemPath)) {
                        X509Certificate caCert = (X509Certificate) cf.generateCertificate(fis);
                        ts.setCertificateEntry("external-ca", caCert);
                    }
                    LOG.infof("    [TRUST] Programmatically loaded PEM cert: %s", trustCertPemPath);
                } else {
                    ts = null;
                }

                if (ts != null) {
                    KeyStoreParameters ksp = new KeyStoreParameters() {
                        @Override public KeyStore createKeyStore() { return ts; }
                    };
                    tmp.setKeyStore(ksp);
                    ssl.setTrustManagers(tmp);
                }

                // 2. Key Manager Logic (Total Programmatic)
                if (keyStorePath != null) {
                    KeyStore ks = KeyStore.getInstance("PKCS12");
                    try (FileInputStream fis = new FileInputStream(keyStorePath)) {
                        ks.load(fis, keyStorePass.toCharArray());
                    }
                    KeyStoreParameters ksp = new KeyStoreParameters() {
                        @Override public KeyStore createKeyStore() { return ks; }
                    };
                    KeyManagersParameters kmp = new KeyManagersParameters();
                    kmp.setKeyStore(ksp);
                    kmp.setKeyPassword(keyStorePass);
                    ssl.setKeyManagers(kmp);
                    LOG.infof("    [KEY] Programmatically loaded identity P12: %s", keyStorePath);
                }

                camelContext.getRegistry().bind(configName, SSLContextParameters.class, ssl);
                LOG.infof(">>> EIP Platform: [TLS] [SUCCESS] Registered SSLContextParameters bean: '%s'", configName);

            } catch (Exception e) {
                LOG.errorf(">>> EIP Platform: [TLS] [ERROR] Failed to register '%s': %s", configName, e.getMessage());
            }
        }
    }
}
