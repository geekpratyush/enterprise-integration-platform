package com.pratyush.eip.core.lib.crypto;

import org.apache.camel.CamelContext;
import org.apache.camel.CamelContextAware;

import javax.net.ssl.*;
import java.io.FileInputStream;
import java.io.IOException;
import java.net.InetAddress;
import java.net.Socket;
import java.security.KeyStore;
import java.security.SecureRandom;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * A Camel-aware {@link SSLSocketFactory} for IBM MQ JMS connections configured via Kamelets.
 *
 * <h2>Purpose</h2>
 * <p>
 * IBM MQ's {@code MQConnectionFactory} requires a concrete {@link SSLSocketFactory} instance
 * to establish TLS-secured JMS connections. This class acts as that factory, loading
 * TrustStore and KeyStore material from PKCS12 files and constructing an {@link SSLContext}
 * internally — without requiring any external CDI producer or framework-level TLS registry.
 * </p>
 *
 * <h2>Kamelet Integration</h2>
 * <p>
 * This class is instantiated as a named bean inside IBM MQ Kamelet YAML definitions using
 * Camel's {@code #class:} bean syntax. All properties are injected via Kamelet property
 * placeholders (e.g. {@code {{truststorepath}}}), which in turn resolve from environment
 * variables, application properties, or inline Camel route URI parameters — in that
 * priority order.
 * </p>
 * <p>Example Kamelet bean definition:</p>
 * <pre>{@code
 * beans:
 *   - name: sslFactory
 *     type: "#class:com.pratyush.eip.core.lib.crypto.EipSslSocketFactory"
 *     properties:
 *       trustStorePath: '{{truststorepath}}'
 *       trustStorePassword: '{{truststorepassword}}'
 *       keyStorePath: '{{keystorepath}}'
 *       keyStorePassword: '{{keystorepassword}}'
 *       useIbmCipherMappings: '{{useibmciphermappings}}'
 *       debugSsl: '{{debugssl}}'
 *       eagerInit: '{{eagerinit}}'
 *       reloadPeriodSeconds: '{{reloadperiodseconds}}'
 * }</pre>
 *
 * <h2>SSL Initialization Modes</h2>
 * <p>Three initialization modes are supported, controlled by {@code eagerInit} and
 * {@code reloadPeriodSeconds}:</p>
 * <ul>
 *   <li><b>Lazy (default)</b> — {@link SSLContext} is built on the first call to any
 *       {@code createSocket} method. Suitable for development and demo environments.</li>
 *   <li><b>Eager</b> — {@link SSLContext} is built immediately when Camel binds the
 *       {@link CamelContext}, i.e. at application startup. Fails fast if cert files are
 *       missing or corrupt. Recommended for production.</li>
 *   <li><b>Periodic Reload</b> — {@link SSLContext} is rebuilt from disk at a configurable
 *       interval via a background daemon thread. Enables zero-restart certificate rotation:
 *       when cert files are replaced on disk (e.g. by cert-manager or Vault), the new
 *       material is picked up automatically without redeployment. On reload failure the
 *       existing delegate is retained so live connections are never disrupted.</li>
 * </ul>
 *
 * <h2>One-way SSL vs mTLS</h2>
 * <ul>
 *   <li><b>One-way SSL</b> — set {@code trustStorePath} only. {@code keyStorePath} may be
 *       left empty or omitted.</li>
 *   <li><b>Mutual TLS (mTLS)</b> — set both {@code trustStorePath} and {@code keyStorePath}.
 *       Both stores must be PKCS12 format.</li>
 *   <li><b>No TLS / JVM default</b> — if {@code trustStorePath} is empty or not provided,
 *       the factory silently delegates to {@link SSLSocketFactory#getDefault()}, preserving
 *       backwards compatibility with non-SSL MQ channels.</li>
 * </ul>
 *
 * <h2>IBM MQ Cipher Mapping</h2>
 * <p>
 * IBM MQ uses its own cipher suite naming convention by default, which conflicts with the
 * standard JSSE names used by Java. Setting {@code useIbmCipherMappings=false} (recommended)
 * forces IBM MQ classes to use standard JSSE cipher suite names, avoiding handshake failures
 * when specifying ciphers such as {@code TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384}.
 * This is applied via the JVM system property
 * {@code com.ibm.mq.cfg.useIBMCipherMappings}.
 * </p>
 *
 * <h2>Thread Safety</h2>
 * <p>
 * The internal delegate is declared {@code volatile} and initialised inside a
 * {@code synchronized} block (double-checked locking). The reload scheduler runs on a
 * single daemon thread and writes atomically to the volatile field, so concurrent
 * {@code createSocket} calls always observe either the previous or the new delegate —
 * never a partially constructed one.
 * </p>
 *
 * <h2>Configuration Reference</h2>
 * <table border="1" cellpadding="4">
 *   <tr><th>Property</th><th>Env Variable (source kamelet)</th><th>Type</th><th>Default</th><th>Description</th></tr>
 *   <tr><td>trustStorePath</td><td>CAMEL_KAMELET_IBMMQ_SOURCE_TRUSTSTOREPATH</td><td>String</td><td>""</td><td>Absolute path to PKCS12 TrustStore. Empty = JVM default SSL.</td></tr>
 *   <tr><td>trustStorePassword</td><td>CAMEL_KAMELET_IBMMQ_SOURCE_TRUSTSTOREPASSWORD</td><td>String</td><td>""</td><td>Password for the TrustStore.</td></tr>
 *   <tr><td>keyStorePath</td><td>CAMEL_KAMELET_IBMMQ_SOURCE_KEYSTOREPATH</td><td>String</td><td>""</td><td>Absolute path to PKCS12 KeyStore. Empty = one-way SSL only.</td></tr>
 *   <tr><td>keyStorePassword</td><td>CAMEL_KAMELET_IBMMQ_SOURCE_KEYSTOREPASSWORD</td><td>String</td><td>""</td><td>Password for the KeyStore.</td></tr>
 *   <tr><td>useIbmCipherMappings</td><td>CAMEL_KAMELET_IBMMQ_SOURCE_USEIBMCIPHERMAPPINGS</td><td>boolean</td><td>false</td><td>Whether to use IBM cipher suite naming. Set false to use standard JSSE names.</td></tr>
 *   <tr><td>debugSsl</td><td>CAMEL_KAMELET_IBMMQ_SOURCE_DEBUGSSL</td><td>boolean</td><td>false</td><td>Enables {@code javax.net.debug=ssl,handshake} JVM-level SSL debug logging.</td></tr>
 *   <tr><td>eagerInit</td><td>CAMEL_KAMELET_IBMMQ_SOURCE_EAGERINIT</td><td>boolean</td><td>false</td><td>Build SSLContext at startup (CamelContext bind time) instead of on first use.</td></tr>
 *   <tr><td>reloadPeriodSeconds</td><td>CAMEL_KAMELET_IBMMQ_SOURCE_RELOADPERIODSECONDS</td><td>long</td><td>0</td><td>Interval in seconds to rebuild SSLContext from disk. 0 = disabled.</td></tr>
 * </table>
 *
 * @see SSLSocketFactory
 * @see CamelContextAware
 * @see javax.net.ssl.SSLContext
 */
public class EipSslSocketFactory extends SSLSocketFactory implements CamelContextAware {

    /**
     * Absolute filesystem path to the PKCS12 TrustStore containing the CA certificate(s)
     * used to verify the IBM MQ server's identity.
     * <p>
     * If empty, {@code null}, or the literal string {@code "null"}, the factory falls back
     * to the JVM's default {@link SSLSocketFactory}, effectively disabling custom TLS.
     * </p>
     */
    private String trustStorePath;

    /**
     * Password used to unlock the PKCS12 TrustStore at {@link #trustStorePath}.
     * May be empty if the store was created without a password.
     */
    private String trustStorePassword;

    /**
     * Absolute filesystem path to the PKCS12 KeyStore containing the client certificate
     * and private key, required for mutual TLS (mTLS) authentication.
     * <p>
     * Leave empty or omit for one-way SSL where only the server is authenticated.
     * </p>
     */
    private String keyStorePath;

    /**
     * Password used to unlock the PKCS12 KeyStore at {@link #keyStorePath} and to
     * decrypt the private key entry within it.
     */
    private String keyStorePassword;

    /**
     * Controls whether IBM MQ classes use their proprietary cipher suite naming convention
     * rather than standard JSSE names.
     * <p>
     * Set to {@code false} (recommended) when specifying cipher suites using standard JSSE
     * names such as {@code TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384}. Applied via the JVM
     * system property {@code com.ibm.mq.cfg.useIBMCipherMappings}.
     * </p>
     */
    private boolean useIbmCipherMappings = false;

    /**
     * When {@code true}, enables JVM-level SSL/TLS debug output by setting the system
     * property {@code javax.net.debug=ssl,handshake}. Useful for diagnosing handshake
     * failures but should never be enabled in production due to verbose output.
     */
    private boolean debugSsl = false;

    /**
     * When {@code true}, the {@link SSLContext} is built immediately during
     * {@link #setCamelContext(CamelContext)} (application startup), rather than lazily
     * on the first {@code createSocket} call.
     * <p>
     * Recommended for production: ensures cert file errors are surfaced at startup
     * rather than at runtime during the first connection attempt.
     * </p>
     */
    private boolean eagerInit = false;

    /**
     * Interval in seconds at which the {@link SSLContext} is rebuilt by reading cert
     * files from disk again. Enables zero-restart certificate rotation: replace the cert
     * files on disk and the new material is picked up automatically within one period.
     * <p>
     * Set to {@code 0} (default) to disable periodic reloading.
     * If reload fails (e.g. file not found or corrupt), the existing delegate is retained
     * and an error is logged — live connections are never disrupted.
     * </p>
     * <p>Suggested value for production: {@code 28800} (8 hours).</p>
     */
    private long reloadPeriodSeconds = 0;

    /** The Camel context, used to resolve property placeholders in path and password fields. */
    private CamelContext camelContext;

    /**
     * The currently active {@link SSLSocketFactory} delegate, built from the configured
     * TrustStore/KeyStore. Declared {@code volatile} to ensure visibility across threads
     * when the reload scheduler replaces it.
     */
    private volatile SSLSocketFactory delegate;

    /**
     * Background scheduler responsible for periodic delegate rebuilds when
     * {@link #reloadPeriodSeconds} is greater than zero. Runs as a single daemon thread
     * so it does not prevent JVM shutdown.
     */
    private ScheduledExecutorService reloadScheduler;

    /**
     * No-argument constructor required by Camel's YAML bean instantiation via
     * {@code #class:} syntax. All configuration is injected via setter methods.
     */
    public EipSslSocketFactory() {}

    // -------------------------------------------------------------------------
    // Setters — called by Camel's bean factory from Kamelet property placeholders
    // -------------------------------------------------------------------------

    /**
     * Sets the absolute path to the PKCS12 TrustStore file.
     *
     * @param p absolute filesystem path, or empty/null to use the JVM default SSL context
     */
    public void setTrustStorePath(String p)        { this.trustStorePath = p; }

    /**
     * Sets the password for the PKCS12 TrustStore.
     *
     * @param p store password; may be empty if the store has no password
     */
    public void setTrustStorePassword(String p)    { this.trustStorePassword = p; }

    /**
     * Sets the absolute path to the PKCS12 KeyStore file for mTLS client authentication.
     *
     * @param p absolute filesystem path, or empty/null for one-way SSL
     */
    public void setKeyStorePath(String p)          { this.keyStorePath = p; }

    /**
     * Sets the password for the PKCS12 KeyStore and its private key entry.
     *
     * @param p store and key password; may be empty if the store has no password
     */
    public void setKeyStorePassword(String p)      { this.keyStorePassword = p; }

    /**
     * Sets whether IBM MQ's proprietary cipher suite naming should be used.
     * Defaults to {@code false} so that standard JSSE cipher names are accepted.
     *
     * @param b {@code true} to use IBM cipher mappings, {@code false} for JSSE names
     */
    public void setUseIbmCipherMappings(boolean b) { this.useIbmCipherMappings = b; }

    /**
     * Enables or disables JVM-level SSL debug logging ({@code javax.net.debug=ssl,handshake}).
     * Must not be enabled in production.
     *
     * @param b {@code true} to enable SSL debug output
     */
    public void setDebugSsl(boolean b)             { this.debugSsl = b; }

    /**
     * Controls whether the {@link SSLContext} is built eagerly at startup.
     * When {@code true}, initialisation occurs in {@link #setCamelContext(CamelContext)}.
     *
     * @param b {@code true} to initialise at startup; {@code false} for lazy initialisation
     */
    public void setEagerInit(boolean b)            { this.eagerInit = b; }

    /**
     * Sets the interval in seconds for periodic {@link SSLContext} reload from disk.
     * Set to {@code 0} to disable. The scheduler starts in {@link #setCamelContext(CamelContext)}.
     *
     * @param s reload interval in seconds; {@code 0} disables reloading
     */
    public void setReloadPeriodSeconds(long s)     { this.reloadPeriodSeconds = s; }

    // -------------------------------------------------------------------------
    // CamelContextAware — lifecycle hook used for eager init and reload scheduling
    // -------------------------------------------------------------------------

    /**
     * Called by Camel after all bean properties have been set. This is the earliest point
     * at which property placeholders can be resolved, so eager initialisation and reload
     * scheduling are both triggered here.
     *
     * @param camelContext the active {@link CamelContext}; never {@code null}
     */
    @Override
    public void setCamelContext(CamelContext camelContext) {
        this.camelContext = camelContext;
        if (eagerInit) {
            buildDelegate();
        }
        if (reloadPeriodSeconds > 0) {
            startReloadScheduler();
        }
    }

    /**
     * Returns the {@link CamelContext} previously set via {@link #setCamelContext(CamelContext)}.
     *
     * @return the active {@link CamelContext}, or {@code null} if not yet set
     */
    @Override
    public CamelContext getCamelContext() {
        return this.camelContext;
    }

    // -------------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------------

    /**
     * Resolves a value through Camel's property placeholder mechanism.
     * If resolution fails (e.g. the value is not a placeholder expression) the
     * original literal value is returned unchanged.
     *
     * @param value a raw property value, which may be a {@code {{placeholder}}} expression
     * @return the resolved string, or {@code value} if resolution is not possible
     */
    private String resolve(String value) {
        if (value == null || camelContext == null) return value;
        try {
            return camelContext.resolvePropertyPlaceholders(value);
        } catch (Exception e) {
            return value;
        }
    }

    /**
     * Constructs a new {@link SSLSocketFactory} from the configured TrustStore and
     * optionally a KeyStore, then atomically replaces {@link #delegate}.
     *
     * <p>Behaviour:</p>
     * <ul>
     *   <li>If {@code trustStorePath} is empty or {@code null} after placeholder resolution,
     *       the JVM default {@link SSLSocketFactory} is used as the delegate.</li>
     *   <li>If {@code keyStorePath} is non-empty, a {@link KeyManagerFactory} is initialised
     *       for mTLS client authentication.</li>
     *   <li>The IBM MQ cipher mapping system property and SSL debug flag are applied each
     *       time this method runs, including on reloads.</li>
     * </ul>
     *
     * @return the newly built {@link SSLSocketFactory}
     * @throws RuntimeException if any cryptographic or I/O operation fails
     */
    private SSLSocketFactory buildDelegate() {
        String tsPath = resolve(trustStorePath);
        String tsPass = resolve(trustStorePassword);
        String ksPath = resolve(keyStorePath);
        String ksPass = resolve(keyStorePassword);

        if (tsPath == null || tsPath.trim().isEmpty() || tsPath.equals("null")) {
            SSLSocketFactory fallback = (SSLSocketFactory) SSLSocketFactory.getDefault();
            delegate = fallback;
            return fallback;
        }

        try {
            if (debugSsl) System.setProperty("javax.net.debug", "ssl,handshake");
            System.setProperty("com.ibm.mq.cfg.useIBMCipherMappings", String.valueOf(useIbmCipherMappings));

            KeyStore ts = KeyStore.getInstance("PKCS12");
            try (FileInputStream fis = new FileInputStream(tsPath)) {
                ts.load(fis, tsPass != null ? tsPass.toCharArray() : new char[0]);
            }
            TrustManagerFactory tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
            tmf.init(ts);

            KeyManager[] kms = null;
            if (ksPath != null && !ksPath.trim().isEmpty() && !ksPath.equals("null")) {
                KeyStore ks = KeyStore.getInstance("PKCS12");
                try (FileInputStream fis = new FileInputStream(ksPath)) {
                    ks.load(fis, ksPass != null ? ksPass.toCharArray() : new char[0]);
                }
                KeyManagerFactory kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
                kmf.init(ks, ksPass != null ? ksPass.toCharArray() : new char[0]);
                kms = kmf.getKeyManagers();
            }

            SSLContext ctx = SSLContext.getInstance("TLS");
            ctx.init(kms, tmf.getTrustManagers(), new SecureRandom());
            SSLSocketFactory built = ctx.getSocketFactory();
            delegate = built;
            return built;
        } catch (Exception e) {
            throw new RuntimeException("SSL initialization failed", e);
        }
    }

    /**
     * Starts a single-threaded daemon scheduler that calls {@link #buildDelegate()} at
     * every {@link #reloadPeriodSeconds} interval.
     *
     * <p>If a reload attempt throws an exception, the error is logged to {@code System.err}
     * and the existing delegate is retained unchanged, ensuring that live connections are
     * never interrupted by a failed cert reload (e.g. a file temporarily locked during
     * rotation).</p>
     *
     * <p>The scheduler thread is a daemon thread named {@code eip-ssl-reload}, so it will
     * not prevent the JVM from shutting down normally.</p>
     */
    private void startReloadScheduler() {
        reloadScheduler = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "eip-ssl-reload");
            t.setDaemon(true);
            return t;
        });
        reloadScheduler.scheduleAtFixedRate(() -> {
            try {
                buildDelegate();
            } catch (Exception e) {
                System.err.println("[EipSslSocketFactory] Cert reload failed, retaining current delegate: " + e.getMessage());
            }
        }, reloadPeriodSeconds, reloadPeriodSeconds, TimeUnit.SECONDS);
    }

    /**
     * Returns the active {@link SSLSocketFactory} delegate, building it lazily on first
     * call if neither eager initialisation nor a prior reload has done so.
     *
     * <p>Uses double-checked locking to guarantee that {@link #buildDelegate()} is called
     * at most once in the lazy path, even under concurrent access.</p>
     *
     * @return the active {@link SSLSocketFactory} delegate; never {@code null}
     */
    private SSLSocketFactory getDelegate() {
        if (delegate != null) return delegate;
        synchronized (this) {
            if (delegate != null) return delegate;
            return buildDelegate();
        }
    }

    // -------------------------------------------------------------------------
    // SSLSocketFactory delegation — all calls forwarded to the active delegate
    // -------------------------------------------------------------------------

    /**
     * {@inheritDoc}
     * Delegated to the active {@link SSLSocketFactory} returned by {@link #getDelegate()}.
     */
    @Override
    public String[] getDefaultCipherSuites() { return getDelegate().getDefaultCipherSuites(); }

    /**
     * {@inheritDoc}
     * Delegated to the active {@link SSLSocketFactory} returned by {@link #getDelegate()}.
     */
    @Override
    public String[] getSupportedCipherSuites() { return getDelegate().getSupportedCipherSuites(); }

    /**
     * {@inheritDoc}
     * Delegated to the active {@link SSLSocketFactory} returned by {@link #getDelegate()}.
     */
    @Override
    public Socket createSocket(Socket s, String h, int p, boolean a) throws IOException { return getDelegate().createSocket(s, h, p, a); }

    /**
     * {@inheritDoc}
     * Delegated to the active {@link SSLSocketFactory} returned by {@link #getDelegate()}.
     */
    @Override
    public Socket createSocket(String h, int p) throws IOException { return getDelegate().createSocket(h, p); }

    /**
     * {@inheritDoc}
     * Delegated to the active {@link SSLSocketFactory} returned by {@link #getDelegate()}.
     */
    @Override
    public Socket createSocket(String h, int p, InetAddress lh, int lp) throws IOException { return getDelegate().createSocket(h, p, lh, lp); }

    /**
     * {@inheritDoc}
     * Delegated to the active {@link SSLSocketFactory} returned by {@link #getDelegate()}.
     */
    @Override
    public Socket createSocket(InetAddress h, int p) throws IOException { return getDelegate().createSocket(h, p); }

    /**
     * {@inheritDoc}
     * Delegated to the active {@link SSLSocketFactory} returned by {@link #getDelegate()}.
     */
    @Override
    public Socket createSocket(InetAddress a, int p, InetAddress la, int lp) throws IOException { return getDelegate().createSocket(a, p, la, lp); }
}
