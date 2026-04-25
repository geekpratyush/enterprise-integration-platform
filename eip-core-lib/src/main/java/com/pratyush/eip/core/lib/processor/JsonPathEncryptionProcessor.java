package com.pratyush.eip.core.lib.processor;

import com.jayway.jsonpath.Configuration;
import com.jayway.jsonpath.DocumentContext;
import com.jayway.jsonpath.JsonPath;
import com.jayway.jsonpath.Option;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Named;
import org.apache.camel.Exchange;
import org.apache.camel.Processor;
import org.jboss.logging.Logger;

import java.util.Arrays;
import java.util.List;

/**
 * Camel {@link Processor} that encrypts nominated JSON fields in-place before an
 * exchange reaches a sink Kamelet.
 *
 * <p>The set of fields is resolved at runtime from the {@code fieldsToEncrypt} Exchange
 * property (set by {@code intelligent-sink-adapter-action.kamelet.yaml}). Each entry is a
 * <a href="https://github.com/json-path/JsonPath">Jayway JsonPath</a> expression such as
 * {@code $.ssn} or {@code $.payment.card.number}.
 *
 * <p>Actual cryptographic logic is intentionally stubbed out via {@link #cipher(String)}.
 * Replace that method with a real AES-256-GCM implementation (or delegate to
 * {@code CryptoUtils}) before deploying to production.
 */
@ApplicationScoped
@Named("jsonPathEncryptionProcessor")
public class JsonPathEncryptionProcessor implements Processor {

    private static final Logger LOG = Logger.getLogger(JsonPathEncryptionProcessor.class);

    /** Exchange property name published by the adapter Kamelet. */
    private static final String FIELDS_PROP = "fieldsToEncrypt";

    /**
     * Marker prefix prepended to encrypted values so downstream consumers can detect
     * and decode them without ambiguity.
     */
    private static final String ENCRYPTED_PREFIX = "ENC:";

    // ── Jayway JsonPath configuration ──────────────────────────────────────────
    // SUPPRESS_EXCEPTIONS: missing paths are silently skipped rather than thrown.
    // DEFAULT_PATH_LEAF_TO_NULL: absent leaf nodes resolve to null instead of
    //   PathNotFoundException, enabling the same suppress behaviour for reads.
    private static final Configuration JSONPATH_CONFIG = Configuration.defaultConfiguration()
            .addOptions(Option.SUPPRESS_EXCEPTIONS, Option.DEFAULT_PATH_LEAF_TO_NULL);

    @Override
    public void process(Exchange exchange) throws Exception {
        String fieldsRaw = exchange.getProperty(FIELDS_PROP, "", String.class);

        if (fieldsRaw == null || fieldsRaw.isBlank()) {
            // Nothing to encrypt — fast exit.
            return;
        }

        String body = exchange.getIn().getBody(String.class);
        if (body == null || body.isBlank()) {
            LOG.warn("JsonPathEncryptionProcessor: body is null or blank — skipping field encryption.");
            return;
        }

        List<String> paths = Arrays.stream(fieldsRaw.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .toList();

        DocumentContext doc = JsonPath.using(JSONPATH_CONFIG).parse(body);

        for (String path : paths) {
            Object current = doc.read(path);
            if (current == null) {
                LOG.debugf("JsonPathEncryptionProcessor: path '%s' resolved to null — skipping.", path);
                continue;
            }

            String plaintext = current.toString();
            String ciphertext = cipher(plaintext);
            doc.set(path, ENCRYPTED_PREFIX + ciphertext);

            LOG.debugf("JsonPathEncryptionProcessor: encrypted field at path '%s'.", path);
        }

        exchange.getIn().setBody(doc.jsonString());
    }

    // ── Cipher stub ────────────────────────────────────────────────────────────

    /**
     * Placeholder cipher. Replace with a real AES-256-GCM implementation,
     * for example by injecting and delegating to {@code CryptoUtils#encrypt}.
     *
     * @param plaintext the value to encrypt
     * @return an opaque ciphertext string
     */
    private String cipher(String plaintext) {
        // TODO: replace with production-grade AES-256-GCM via CryptoUtils
        //   String key = System.getenv("EIP_AUDIT_ENCRYPTION_KEY");
        //   return cryptoUtils.encrypt(plaintext, key);
        return java.util.Base64.getEncoder().encodeToString(plaintext.getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }
}
