#!/bash
# 02_initialization/setup-pki.sh (Clean Binary Authority)
set -e

SCENARIO=$1
if [ -z "$SCENARIO" ]; then
    echo "Usage: $0 <scenario-name>"
    exit 1
fi

EIP_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CERT_DIR="${EIP_SCRIPT_DIR}/certs/${SCENARIO}"
mkdir -p "$CERT_DIR"

if [[ "$SCENARIO" == "http-rest" ]]; then
    echo ">>> REST: No PKI required for HTTP mode."
    exit 0
fi

echo ">>> REST: Initializing PKI assets for [${SCENARIO}] (Native Java JKS)..."

# 1. Clean stale assets
rm -f "${CERT_DIR}/"*.jks "${CERT_DIR}/"*.p12 "${CERT_DIR}/"*.crt

# 2. Generate Server Identity (RSA 2048 with SAN for localhost compliance)
keytool -genkeypair -alias wiremock \
  -keyalg RSA -keysize 2048 -validity 365 \
  -dname "CN=localhost, OU=EIP, O=Industrial, L=Digital, S=Global, C=UN" \
  -ext "SAN=dns:localhost,ip:127.0.0.1" \
  -keystore "${CERT_DIR}/keystore.jks" \
  -storepass changeit -keypass changeit -storetype JKS -noprompt > /dev/null 2>&1

# 3. Create Trust Anchor (Export from identity and import to truststore)
keytool -exportcert -alias wiremock -rfc \
  -keystore "${CERT_DIR}/keystore.jks" \
  -storepass changeit -file "${CERT_DIR}/server.crt" -noprompt > /dev/null 2>&1

keytool -importcert -alias wiremock-server \
  -file "${CERT_DIR}/server.crt" \
  -keystore "${CERT_DIR}/truststore.jks" \
  -storepass changeit -noprompt > /dev/null 2>&1

# 4. Generate Client Identity (P12 format for consumer mTLS)
keytool -importkeystore \
  -srckeystore "${CERT_DIR}/keystore.jks" -srcstorepass changeit -srcalias wiremock \
  -destkeystore "${CERT_DIR}/client.p12" -deststorepass changeit -deststoretype PKCS12 \
  -noprompt > /dev/null 2>&1

# Cleanup intermediate PEM
rm -f "${CERT_DIR}/server.crt"

chmod 644 "${CERT_DIR}/"*.jks "${CERT_DIR}/"*.p12
echo "    Binary PKI Generation Complete."
