package com.pratyush.eip.core.lib.crypto;

import jakarta.enterprise.context.ApplicationScoped;
import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.PBEKeySpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.ByteBuffer;
import java.security.SecureRandom;
import java.util.Base64;
import java.nio.charset.StandardCharsets;
import org.jboss.logging.Logger;

@ApplicationScoped
public class CryptoUtils {

    private static final Logger LOG = Logger.getLogger(CryptoUtils.class);

    private static final String ALGORITHM = "AES/GCM/NoPadding";
    private static final String KDF_ALGORITHM = "PBKDF2WithHmacSHA256";
    private static final int TAG_LENGTH_BIT = 128;
    private static final int IV_LENGTH_BYTE = 12;
    private static final int SALT_LENGTH_BYTE = 16;
    private static final int ITERATION_COUNT = 65536;
    private static final int KEY_LENGTH_BIT = 256;

    /**
     * Decrypts a Jasypt-style or plain value.
     */
    public String decrypt(String encryptedValue) {
        // Placeholder for Jasypt integration
        return encryptedValue.startsWith("ENC(") ? encryptedValue : encryptedValue;
    }

    /**
     * Professional Grade AES-256-GCM symmetric encryption for audit payloads.
     * Uses PBKDF2 for key derivation from the provided password.
     */
    public String encrypt(String plainText, String password) {
        try {
            if (password == null || password.isEmpty()) {
                return plainText;
            }

            LOG.debug(">>> CryptoUtils: Initializing AES-256-GCM Encryption...");

            // 1. Generate a random salt
            SecureRandom random = new SecureRandom();
            byte[] salt = new byte[SALT_LENGTH_BYTE];
            random.nextBytes(salt);

            // 2. Derive a 256-bit key from the password using the salt
            SecretKeyFactory factory = SecretKeyFactory.getInstance(KDF_ALGORITHM);
            PBEKeySpec spec = new PBEKeySpec(password.toCharArray(), salt, ITERATION_COUNT, KEY_LENGTH_BIT);
            SecretKey tmp = factory.generateSecret(spec);
            SecretKeySpec secretKey = new SecretKeySpec(tmp.getEncoded(), "AES");

            // 3. Generate a random IV
            byte[] iv = new byte[IV_LENGTH_BYTE];
            random.nextBytes(iv);

            // 4. Encrypt using AES-GCM
            final Cipher cipher = Cipher.getInstance(ALGORITHM);
            GCMParameterSpec gcmSpec = new GCMParameterSpec(TAG_LENGTH_BIT, iv);
            cipher.init(Cipher.ENCRYPT_MODE, secretKey, gcmSpec);

            byte[] cipherText = cipher.doFinal(plainText.getBytes(StandardCharsets.UTF_8));

            // 5. Concatenate Salt + IV + CipherText for the final payload
            ByteBuffer byteBuffer = ByteBuffer.allocate(salt.length + iv.length + cipherText.length);
            byteBuffer.put(salt);
            byteBuffer.put(iv);
            byteBuffer.put(cipherText);

            String encoded = Base64.getEncoder().encodeToString(byteBuffer.array());
            LOG.infof(">>> CryptoUtils: Encryption complete. Result length: %d", encoded.length());
            return encoded;
        } catch (Exception e) {
            LOG.error(">>> CryptoUtils: Encryption failed!", e);
            return "ERROR_ENCRYPTING: " + e.getMessage();
        }
    }
}
