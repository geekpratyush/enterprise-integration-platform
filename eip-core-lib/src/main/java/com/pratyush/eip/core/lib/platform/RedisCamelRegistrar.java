package com.pratyush.eip.core.lib.platform;

import jakarta.annotation.Priority;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;
import io.quarkus.runtime.StartupEvent;
import org.apache.camel.CamelContext;
import org.eclipse.microprofile.config.ConfigProvider;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.connection.RedisPassword;
import org.springframework.data.redis.connection.RedisStandaloneConfiguration;
import org.springframework.data.redis.connection.RedisSentinelConfiguration;
import org.springframework.data.redis.connection.jedis.JedisClientConfiguration;
import org.springframework.data.redis.connection.jedis.JedisConnectionFactory;

import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSocketFactory;
import javax.net.ssl.TrustManagerFactory;
import java.io.FileInputStream;
import java.net.URI;
import java.security.KeyStore;
import java.util.Optional;

@ApplicationScoped
public class RedisCamelRegistrar {

    private static final Logger LOG = LoggerFactory.getLogger(RedisCamelRegistrar.class);

    @Inject
    CamelContext camelContext;

    public void onStart(@Observes @Priority(10) StartupEvent event) {
        Optional<String> hostsOpt = ConfigProvider.getConfig()
                .getOptionalValue("quarkus.redis.hosts", String.class);
        if (hostsOpt.isEmpty()) return;

        try {
            URI uri = URI.create(hostsOpt.get());
            String host = uri.getHost() != null ? uri.getHost() : "127.0.0.1";
            int port = uri.getPort() > 0 ? uri.getPort() : 6379;
            boolean useSsl = "rediss".equalsIgnoreCase(uri.getScheme());

            String username = null;
            String password = null;
            if (uri.getUserInfo() != null) {
                String info = uri.getUserInfo();
                int idx = info.indexOf(':');
                if (idx >= 0) {
                    String u = info.substring(0, idx);
                    if (!u.isEmpty() && !"default".equals(u)) username = u;
                    password = info.substring(idx + 1);
                } else {
                    password = info;
                }
            }

            Optional<String> sentinelMaster = ConfigProvider.getConfig()
                    .getOptionalValue("SENTINEL_MASTER", String.class);

            // Build client config (with or without SSL)
            JedisClientConfiguration clientConfig;
            if (useSsl) {
                SSLSocketFactory sslFactory = buildSslSocketFactory();
                if (sslFactory != null) {
                    clientConfig = JedisClientConfiguration.builder()
                            .useSsl().sslSocketFactory(sslFactory).and()
                            .usePooling().build();
                } else {
                    clientConfig = JedisClientConfiguration.builder()
                            .useSsl().and().usePooling().build();
                }
            } else {
                clientConfig = JedisClientConfiguration.builder().usePooling().build();
            }

            JedisConnectionFactory factory;

            if (sentinelMaster.isPresent() && !sentinelMaster.get().isBlank()) {
                String sHost = ConfigProvider.getConfig()
                        .getOptionalValue("SENTINEL_HOST", String.class).orElse(host);
                int sPort = ConfigProvider.getConfig()
                        .getOptionalValue("SENTINEL_PORT", Integer.class).orElse(26379);
                RedisSentinelConfiguration cfg = new RedisSentinelConfiguration();
                cfg.setMaster(sentinelMaster.get());
                cfg.sentinel(sHost, sPort);
                if (password != null && !password.isBlank()) cfg.setPassword(RedisPassword.of(password));
                if (username != null) cfg.setUsername(username);
                factory = new JedisConnectionFactory(cfg, clientConfig);
                LOG.info(">>> EIP Redis: SENTINEL factory (master={}, sentinel={}:{})", sentinelMaster.get(), sHost, sPort);
            } else {
                RedisStandaloneConfiguration cfg = new RedisStandaloneConfiguration(host, port);
                if (username != null) cfg.setUsername(username);
                if (password != null && !password.isBlank()) cfg.setPassword(RedisPassword.of(password));
                factory = new JedisConnectionFactory(cfg, clientConfig);
                LOG.info(">>> EIP Redis: STANDALONE factory ({}:{}, auth={}, ssl={})", host, port,
                        password != null && !password.isBlank(), useSsl);
            }

            factory.afterPropertiesSet();
            camelContext.getRegistry().bind("redisConnectionFactory", factory);
            LOG.info(">>> EIP Redis: redisConnectionFactory bound.");
        } catch (Exception e) {
            LOG.error(">>> EIP Redis: FAILED: {}", e.getMessage(), e);
        }
    }

    private SSLSocketFactory buildSslSocketFactory() {
        try {
            Optional<String> trustPath = ConfigProvider.getConfig()
                    .getOptionalValue("REDIS_TRUSTSTORE_PATH", String.class);
            Optional<String> trustPass = ConfigProvider.getConfig()
                    .getOptionalValue("REDIS_TRUSTSTORE_PASSWORD", String.class);
            Optional<String> keyPath = ConfigProvider.getConfig()
                    .getOptionalValue("REDIS_KEYSTORE_PATH", String.class);
            Optional<String> keyPass = ConfigProvider.getConfig()
                    .getOptionalValue("REDIS_KEYSTORE_PASSWORD", String.class);

            if (trustPath.isEmpty()) return null;

            KeyStore trustStore = KeyStore.getInstance("PKCS12");
            try (FileInputStream fis = new FileInputStream(trustPath.get())) {
                trustStore.load(fis, trustPass.orElse("changeit").toCharArray());
            }
            TrustManagerFactory tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
            tmf.init(trustStore);

            SSLContext ctx = SSLContext.getInstance("TLS");

            if (keyPath.isPresent()) {
                KeyStore keyStore = KeyStore.getInstance("PKCS12");
                try (FileInputStream fis = new FileInputStream(keyPath.get())) {
                    keyStore.load(fis, keyPass.orElse("changeit").toCharArray());
                }
                KeyManagerFactory kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
                kmf.init(keyStore, keyPass.orElse("changeit").toCharArray());
                ctx.init(kmf.getKeyManagers(), tmf.getTrustManagers(), null);
            } else {
                ctx.init(null, tmf.getTrustManagers(), null);
            }

            LOG.info(">>> EIP Redis: SSL context built (truststore={}, keystore={})", trustPath.get(), keyPath.orElse("none"));
            return ctx.getSocketFactory();
        } catch (Exception e) {
            LOG.warn(">>> EIP Redis: SSL context failed, falling back to default: {}", e.getMessage());
            return null;
        }
    }
}
