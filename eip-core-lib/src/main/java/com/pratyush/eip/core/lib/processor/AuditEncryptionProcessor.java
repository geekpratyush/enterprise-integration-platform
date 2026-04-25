package com.pratyush.eip.core.lib.processor;

import com.pratyush.eip.core.lib.crypto.CryptoUtils;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import org.apache.camel.Exchange;
import org.apache.camel.Processor;
import org.jboss.logging.Logger;

import java.util.Map;

@ApplicationScoped
@Named("auditEncryptionProcessor")
public class AuditEncryptionProcessor implements Processor {

    private static final Logger LOG = Logger.getLogger(AuditEncryptionProcessor.class);
    
    // Header used to force encryption even if global platform toggle is off
    public static final String ENCRYPT_OVERRIDE_HEADER = "EIP_AUDIT_ENCRYPT_OVERRIDE";
    // Header used to provide a manual encryption key (overriding the env var)
    public static final String KEY_OVERRIDE_HEADER = "EIP_AUDIT_KEY_OVERRIDE";

    @Inject
    CryptoUtils crypto;

    @Override
    @SuppressWarnings("unchecked")
    public void process(Exchange exchange) throws Exception {
        // Source configuration from Environment
        boolean globalEncryptEnabled = Boolean.parseBoolean(System.getenv("EIP_AUDIT_ENCRYPT"));
        String defaultSecretKey = System.getenv("EIP_AUDIT_ENCRYPTION_KEY");

        // Check for manual key override in headers
        String manualKey = exchange.getIn().getHeader(KEY_OVERRIDE_HEADER, String.class);
        String secretKey = (manualKey != null && !manualKey.isEmpty()) ? manualKey : defaultSecretKey;

        // ROBUST HEADER DETECTION
        Object overrideObj = exchange.getIn().getHeader(ENCRYPT_OVERRIDE_HEADER);
        boolean isOverride = false;
        if (overrideObj instanceof Boolean) {
            isOverride = (Boolean) overrideObj;
        } else if (overrideObj instanceof String) {
            isOverride = Boolean.parseBoolean((String) overrideObj);
        }
        
        boolean shouldEncrypt = globalEncryptEnabled || isOverride || (manualKey != null);


        if (!shouldEncrypt) {
            return;
        }

        if (secretKey == null || secretKey.isEmpty()) {
            LOG.warn("Encryption requested but EIP_AUDIT_ENCRYPTION_KEY is not set. Skipping.");
            return;
        }

        Object body = exchange.getIn().getBody();
        if (body instanceof Map) {
            Map<String, Object> auditMap = (Map<String, Object>) body;
            Object payload = auditMap.get("payload");
            
            if (payload != null) {
                LOG.infof(">>> EIP Platform: Encrypting audit payload (Override: %b, Payload Length: %d)", 
                        isOverride, payload.toString().length());
                
                // The upgraded crypto engine uses PBKDF2 + AES-256-GCM
                String encrypted = crypto.encrypt(payload.toString(), secretKey);
                
                auditMap.put("payload", encrypted);
                auditMap.put("is_encrypted", true);
            }
        }

    }
}
