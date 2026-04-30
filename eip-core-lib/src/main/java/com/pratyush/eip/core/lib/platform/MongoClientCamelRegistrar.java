package com.pratyush.eip.core.lib.platform;

import com.mongodb.MongoClientSettings;
import com.mongodb.ConnectionString;
import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import io.quarkus.arc.Unremovable;
import jakarta.enterprise.context.ApplicationScoped;
import org.apache.camel.CamelContext;
import org.apache.camel.spi.CamelContextCustomizer;
import org.eclipse.microprofile.config.ConfigProvider;
import org.jboss.logging.Logger;

import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManagerFactory;
import java.io.FileInputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.security.KeyStore;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.util.stream.StreamSupport;

/**
 * Platform Component: Total Metadata-Driven MongoDB Registry Bridge.
 * Links Connection Beans to TLS Identities via 'TLS_CONFIGURATION_NAME'
 * metadata.
 */
@ApplicationScoped
@Unremovable
public class MongoClientCamelRegistrar implements CamelContextCustomizer {

    private static final Logger LOG = Logger.getLogger(MongoClientCamelRegistrar.class);

    @Override
    public void configure(CamelContext camelContext) {
        var config = ConfigProvider.getConfig();
        boolean enabled = config.getOptionalValue("quarkus.mongodb.enabled", Boolean.class).orElse(true);
        if (!enabled) {
            LOG.info(">>> EIP Platform: [LIB] MongoDB is disabled. Skipping registry bridge.");
            return;
        }

        LOG.info(">>> EIP Platform: Initializing Total-External MongoDB Registry Bridge...");

        StreamSupport.stream(config.getPropertyNames().spliterator(), false)
                .filter(p -> (p.startsWith("quarkus.mongodb.") && p.endsWith(".connection-string")) ||
                        (p.startsWith("QUARKUS_MONGODB_") && p.endsWith("_CONNECTION_STRING")))
                .forEach(propName -> {
                    String clientName;
                    String configPrefix;
                    if (propName.startsWith("QUARKUS_MONGODB_")) {
                        configPrefix = propName.replace("CONNECTION_STRING", "");
                        clientName = propName.replace("QUARKUS_MONGODB_", "").replace("_CONNECTION_STRING", "")
                                .toLowerCase();
                    } else {
                        configPrefix = propName.replace("connection-string", "");
                        clientName = propName.replace("quarkus.mongodb.", "").replace(".connection-string", "");
                    }

                    if (clientName.isEmpty() || clientName.contains(".") || clientName.contains("_"))
                        return;

                    try {
                        String url = config.getValue(propName, String.class);
                        LOG.infof(">>> EIP Platform: [LIB] Constructing external client '%s'...", clientName);

                        MongoClientSettings.Builder settingsBuilder = MongoClientSettings.builder()
                                .applyConnectionString(new ConnectionString(url));

                        // Named Link Lookup: QUARKUS_MONGODB_CLIENT1_TLS_CONFIGURATION_NAME
                        String tlsConfigName = config
                                .getOptionalValue(configPrefix + "TLS_CONFIGURATION_NAME", String.class)
                                .orElse(null);

                        if (tlsConfigName != null) {
                            LOG.infof(">>> EIP Platform: [LINK] Client '%s' linked to TLS Configuration: '%s'",
                                    clientName, tlsConfigName);
                            applyTlsContext(settingsBuilder, tlsConfigName, config);
                        }

                        MongoClient client = MongoClients.create(settingsBuilder.build());
                        camelContext.getRegistry().bind(clientName, MongoClient.class, client);

                        LOG.infof(">>> EIP Platform: [LIB] [SUCCESS] External MongoClient '%s' is registered and ready",
                                clientName);
                    } catch (Exception e) {
                        LOG.errorf(">>> EIP Platform: [LIB] [ERROR] Failed to construct client '%s': %s", clientName,
                                e.getMessage());
                    }
                });
    }

    private void applyTlsContext(MongoClientSettings.Builder builder, String configName,
            org.eclipse.microprofile.config.Config config) {
        try {
            String prefix = "QUARKUS_TLS_" + configName.toUpperCase() + "_";
            String trustCertPath = config.getOptionalValue(prefix + "TRUST_STORE_PEM_CERTS", String.class).orElse(null);
            String keyStorePath = config.getOptionalValue(prefix + "KEY_STORE_P12_PATH", String.class).orElse(null);
            String keyStorePass = config.getOptionalValue(prefix + "KEY_STORE_P12_PASSWORD", String.class)
                    .orElse("changeit");

            if (trustCertPath == null)
                return;

            // 1. Trust Manager
            CertificateFactory cf = CertificateFactory.getInstance("X.509");
            X509Certificate caCert;
            try (FileInputStream fis = new FileInputStream(trustCertPath)) {
                caCert = (X509Certificate) cf.generateCertificate(fis);
            }
            KeyStore ts = KeyStore.getInstance(KeyStore.getDefaultType());
            ts.load(null, null);
            ts.setCertificateEntry("ca", caCert);
            TrustManagerFactory tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
            tmf.init(ts);

            // 2. Key Manager (For mTLS)
            KeyManagerFactory kmf = null;
            if (keyStorePath != null && Files.exists(Paths.get(keyStorePath))) {
                KeyStore ks = KeyStore.getInstance("PKCS12");
                try (FileInputStream fis = new FileInputStream(keyStorePath)) {
                    ks.load(fis, keyStorePass.toCharArray());
                }
                kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
                kmf.init(ks, keyStorePass.toCharArray());
            }

            SSLContext sslContext = SSLContext.getInstance("TLS");
            sslContext.init(kmf != null ? kmf.getKeyManagers() : null, tmf.getTrustManagers(), null);
            builder.applyToSslSettings(ssl -> ssl.enabled(true).context(sslContext).invalidHostNameAllowed(true));
        } catch (Exception e) {
            LOG.errorf(">>> EIP Platform: [TLS] Failed to apply context '%s': %s", configName, e.getMessage());
        }
    }
}
