#!/bin/bash
# ======================================================================
#                ORACLE PKI AUTOMATION
# ======================================================================

set -e
MODE=${MODE:-ssl-oneway}
BASE_DIR="/home/pratyush/software/eip-core-integration/eip-core-environment/demo/oracle"
CERT_DIR="${BASE_DIR}/02_initialization/certs/${MODE}"

mkdir -p "$CERT_DIR"
cd "$CERT_DIR"
# Clean slate for fresh certificates
rm -f *.pem *.p12 *.srl *.csr *.req *.jks

echo ">>> ORACLE PKI: Generating Certificates ($MODE)..."

# 1. ROOT CA
openssl genrsa -out ca-key.pem 2048
openssl req -x509 -new -nodes -key ca-key.pem -days 3650 -out ca-cert.pem -subj "/CN=oracle-ca"

# 2. SERVER CERT
openssl genrsa -out server-key.pem 2048
openssl req -new -key server-key.pem -out server-req.pem -subj "/CN=oracle-platform" \
  -addext "subjectAltName = DNS:oracle-platform, DNS:localhost, IP:127.0.0.1"
openssl x509 -req -in server-req.pem -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial \
  -out server-cert.pem -days 365 -copy_extensions copyall

# 3. CLIENT CERT (For EIP Platform)
openssl genrsa -out client-key.pem 2048
openssl req -new -key client-key.pem -out client-req.pem -subj "/CN=oracle-client"
openssl x509 -req -in client-req.pem -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -out client-cert.pem -days 365

# 4. Packaging for Java (EIP Platform)
echo "    >>> Creating Truststore and Keystore for EIP Platform..."
# Client identity for mTLS
openssl pkcs12 -export -in client-cert.pem -inkey client-key.pem -out oracle-keystore.p12 -name "oracle-client" -passout pass:EipPass123!
# CA trust for 1-way and mTLS
keytool -importcert -alias oracle-ca -file ca-cert.pem -keystore oracle-truststore.p12 -storetype PKCS12 -storepass EipPass123! -noprompt

# 5. Packaging for Oracle Server (Wallet Bridge)
echo "    >>> Creating Server Keystore..."
openssl pkcs12 -export -in server-cert.pem -inkey server-key.pem -certfile ca-cert.pem -out ewallet.p12 -name "oracle-server" -passout pass:EipPass123!

# 6. Final Permissions
chmod 644 *

echo ">>> ORACLE PKI: Generation Complete."
ls -l
