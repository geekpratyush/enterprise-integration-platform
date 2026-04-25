#!/bin/bash
# startkafka-route.sh
# Simplified CLI: Non-SSL and mTLS only.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." >/dev/null 2>&1 && pwd)"
DEMO_DIR="$SCRIPT_DIR"

trap "echo -e '\n\033[36m>>> Exiting Kafka CLI...\033[0m'; exit 0" INT

show_menu() {
    clear
    echo "============================"
    echo "  Kafka EIP Platform CLI   "
    echo "============================"
    echo "1. Non-SSL Environment (PLAINTEXT)"
    echo "2. mTLS Kafka (Mutual TLS)"
    echo "C. Force Cleanup (Docker + Context)"
    echo "Q. Quit"
    echo ""
    read -p "Choice: " choice
}

import_env() {
    local env_file="$1"
    if [ -f "$env_file" ]; then
        while IFS='=' read -r key value || [ -n "$key" ]; do
            [[ $key =~ ^#.* ]] && continue
            [ -z "$key" ] && continue
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            export "$key=$value"
        done < "$env_file"
    fi
}

run_scenario() {
    local track="$1"
    local script="$2"
    
    echo -e ">>> Stopping all Gradle Daemons..."
    ./gradlew --stop 2>/dev/null || true
    
    echo -e ">>> Hard-cleaning port 8080/8081..."
    fuser -k 8080/tcp 8081/tcp 2>/dev/null || true
    
    # Force Quarkus to a new port to avoid any lingering 8080 issues
    export QUARKUS_HTTP_PORT=8081
    
    echo -e ">>> Provisioning Kafka environment: $track..."
    bash "$DEMO_DIR/config/$track/scripts/$script"
    
    echo -e ">>> Loading environment variables..."
    import_env "$DEMO_DIR/config/$track/envs/$track.env"
    
    if [ "$track" == "mtls-kafka" ]; then
        CERT_DIR="$DEMO_DIR/config/mtls-kafka/certs"
        export KAFKA_OPTS="-Dssl.keystore.location=$CERT_DIR/client.keystore.p12 -Dssl.keystore.password=password -Dssl.keystore.type=PKCS12 -Dssl.key.password=password -Dssl.truststore.location=$CERT_DIR/audit-truststore.p12 -Dssl.truststore.password=password -Dssl.truststore.type=PKCS12 -Dssl.endpoint.identification.algorithm="
        echo ">>> Injected KAFKA_OPTS for mTLS."
    fi
    
    cd "$ROOT_DIR/eip-core-consumer"
    ./gradlew clean quarkusDev
}

while true; do
    show_menu
    case $choice in
        1) run_scenario "non-ssl" "non-ssl.sh" ;;
        2) run_scenario "mtls-kafka" "mtls-kafka.sh" ;;
        [Cc]) 
            echo ">>> Cleaning up containers..."
            docker ps -q --filter "name=kafka" | xargs -r docker rm -f
            docker network prune -f
            ;;
        [Qq]) exit 0 ;;
        *) echo "Invalid choice." ; sleep 1 ;;
    esac
done
