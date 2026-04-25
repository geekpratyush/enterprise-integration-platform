#!/bin/bash
# ssl-postgres.sh - Setup SSL Enabled PostgreSQL
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
CONFIG_DIR="$(cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
CERT_DIR="$CONFIG_DIR/certs"

echo -e "\033[36m>>> Provisioning PostgreSQL SSL Environment...\033[0m"

# 1. Generate Certificates
if [ ! -f "$CERT_DIR/server.crt" ]; then
    echo ">>> Generating Postgres SSL Certificates..."
    mkdir -p "$CERT_DIR"
    
    # Create Root CA
    openssl genrsa -out "$CERT_DIR/root.key" 2048
    openssl req -x509 -new -nodes -key "$CERT_DIR/root.key" -sha256 -days 3650 -out "$CERT_DIR/root.crt" -subj "/CN=Postgres-CA"

    # Create Server Key/Cert
    openssl genrsa -out "$CERT_DIR/server.key" 2048
    openssl req -new -key "$CERT_DIR/server.key" -out "$CERT_DIR/server.csr" -subj "/CN=localhost"
    
    echo "subjectAltName = DNS:localhost,IP:127.0.0.1" > "$CERT_DIR/server_ext.conf"
    openssl x509 -req -in "$CERT_DIR/server.csr" -CA "$CERT_DIR/root.crt" -CAkey "$CERT_DIR/root.key" -CAcreateserial -out "$CERT_DIR/server.crt" -days 365 -sha256 -extfile "$CERT_DIR/server_ext.conf"
    
    # Fixing permissions for Postgres (Key must be 600)
    chmod 600 "$CERT_DIR/server.key"
    chmod 644 "$CERT_DIR/server.crt" "$CERT_DIR/root.crt"
fi

# 2. Start Container
docker compose -f "$CONFIG_DIR/container/postgres-isolated.yaml" down -v --remove-orphans 2>/dev/null
docker compose -f "$CONFIG_DIR/container/postgres-isolated.yaml" up -d

echo -e "\033[33m>>> Waiting for Postgres (5s)...\033[0m"
sleep 5

# 3. Create Demo Schema/Table
docker exec -e PGPASSWORD=eip_password postgres-ssl psql -U eip_user -d eip_db -c "CREATE TABLE IF NOT EXISTS demo_audit (id SERIAL PRIMARY KEY, message TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"

echo -e "\033[32m>>> PostgreSQL SSL Started on Port 5432 (SSL Enabled)\033[0m"
