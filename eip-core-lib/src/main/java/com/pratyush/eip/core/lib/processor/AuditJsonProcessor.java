package com.pratyush.eip.core.lib.processor;

import com.pratyush.eip.core.lib.crypto.CryptoUtils;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import org.apache.camel.Exchange;
import org.apache.camel.Processor;
import org.jboss.logging.Logger;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.Stream;

@ApplicationScoped
@Named("auditJsonProcessor")
public class AuditJsonProcessor implements Processor {

    private static final Logger LOG = Logger.getLogger(AuditJsonProcessor.class);

    @Inject
    CryptoUtils crypto;

    @Override
    @SuppressWarnings("unchecked")
    public void process(Exchange exchange) throws Exception {
        Object body = exchange.getIn().getBody();
        if (!(body instanceof Map)) {
            return;
        }

        Map<String, Object> auditMap = (Map<String, Object>) body;
        applyExtraFields(auditMap);
        applyFieldFilters(auditMap);
        applyPayloadEncryption(auditMap);
    }

    private void applyExtraFields(Map<String, Object> auditMap) {
        String extraFields = System.getenv("EIP_AUDIT_EXTRA_FIELDS");
        if (extraFields == null || extraFields.trim().isEmpty()) {
            return;
        }

        parseKeyValuePairs(extraFields).forEach(auditMap::put);
    }

    private void applyFieldFilters(Map<String, Object> auditMap) {
        String includeFields = System.getenv("EIP_AUDIT_FIELDS");
        String excludeFields = System.getenv("EIP_AUDIT_EXCLUDE_FIELDS");

        if (includeFields != null && !includeFields.trim().isEmpty()) {
            Set<String> allowed = parseCommaSeparated(includeFields);
            Set<String> keys = new HashSet<>(auditMap.keySet());
            for (String key : keys) {
                if (!allowed.contains(key)) {
                    auditMap.remove(key);
                }
            }
            return;
        }

        if (excludeFields != null && !excludeFields.trim().isEmpty()) {
            Set<String> denied = parseCommaSeparated(excludeFields);
            denied.forEach(auditMap::remove);
        }
    }

    private void applyPayloadEncryption(Map<String, Object> auditMap) {
        boolean encryptEnabled = Boolean.parseBoolean(System.getenv("EIP_AUDIT_ENCRYPT"));
        String secretKey = System.getenv("EIP_AUDIT_ENCRYPTION_KEY");
        if (!encryptEnabled || secretKey == null || secretKey.isEmpty()) {
            return;
        }

        Object payload = auditMap.get("payload");
        if (payload != null) {
            LOG.debug("Encrypting audit payload...");
            String encrypted = crypto.encrypt(payload.toString(), secretKey);
            auditMap.put("payload", encrypted);
            auditMap.put("isEncrypted", true);
        }
    }

    private Set<String> parseCommaSeparated(String value) {
        return Stream.of(value.split(","))
                .map(String::trim)
                .filter(field -> !field.isEmpty())
                .collect(Collectors.toSet());
    }

    private Map<String, String> parseKeyValuePairs(String value) {
        return Stream.of(value.split(","))
                .map(String::trim)
                .filter(pair -> pair.contains("="))
                .map(pair -> pair.split("=", 2))
                .collect(Collectors.toMap(
                        parts -> parts[0].trim(),
                        parts -> parts[1].trim(),
                        (first, second) -> second
                ));
    }
}
