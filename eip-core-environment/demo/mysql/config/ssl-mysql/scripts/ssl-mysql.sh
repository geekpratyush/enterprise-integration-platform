#!/bin/bash
# ssl-mysql.sh - Setup SSL Enabled MySQL
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
CONFIG_DIR="$(cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
CERT_DIR="$CONFIG_DIR/certs"

echo -e "\033[36m>>> Provisioning MySQL SSL Environment...\033[0m"

# 1. Generate Certificates
if [ ! -f "$CERT_DIR/server-cert.pem" ]; then
    echo ">>> Generating MySQL SSL Certificates..."
    mkdir -p "$CERT_DIR"
    
    # Create Root CA
    openssl genrsa -out "$CERT_DIR/ca-key.pem" 2048
    openssl req -x509 -new -nodes -key "$CERT_DIR/ca-key.pem" -sha256 -days 3650 -out "$CERT_DIR/ca-cert.pem" -subj "/CN=MySQL-CA"

    # Create Server Key/Cert
    openssl genrsa -out "$CERT_DIR/server-key.pem" 2048
    openssl req -new -key "$CERT_DIR/server-key.pem" -out "$CERT_DIR/server.csr" -subj "/CN=localhost"
    
    echo "subjectAltName = DNS:localhost,IP:127.0.0.1" > "$CERT_DIR/server_ext.conf"
    openssl x509 -req -in "$CERT_DIR/server.csr" -CA "$CERT_DIR/ca-cert.pem" -CAkey "$CERT_DIR/ca-key.pem" -CAcreateserial -out "$CERT_DIR/server-cert.pem" -days 365 -sha256 -extfile "$CERT_DIR/server_ext.conf"
    
    # Fixing permissions
    chmod 644 "$CERT_DIR/"*
fi

# 2. Start Container
docker compose -f "$CONFIG_DIR/container/mysql-isolated.yaml" down -v --remove-orphans 2>/dev/null
docker compose -f "$CONFIG_DIR/container/mysql-isolated.yaml" up -d

echo -e "\033[33m>>> Waiting for MySQL (15s)...\033[0m"
sleep 15

# 3. Create Demo Table
docker exec -e MYSQL_PWD=eip_password mysql-ssl mysql -u eip_user -D eip_db -e "CREATE TABLE IF NOT EXISTS demo_audit (id INT AUTO_INCREMENT PRIMARY KEY, message VARCHAR(255), created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"

echo -e "\033[32m>>> MySQL SSL Started on Port 3306 (SSL Enabled)\033[0m"
