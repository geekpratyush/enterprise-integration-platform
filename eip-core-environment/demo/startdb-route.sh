#!/bin/bash
# startdb-route.sh
# Master CLI for Database EIP Scenarios

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." >/dev/null 2>&1 && pwd)"
DEMO_DIR="$SCRIPT_DIR"

trap "echo -e '\n\033[36m>>> Exiting Database CLI...\033[0m'; exit 0" INT

show_menu() {
    clear
    echo "================================="
    echo "    EIP Platform: Database CLI   "
    echo "================================="
    echo "1. PostgreSQL (SSL Enabled)"
    echo "2. MongoDB (SSL & Auth)"
    echo "3. MySQL (SSL Enabled)"
    echo "4. Cassandra (mTLS/JKS)"
    echo "5. SQL Server (Encryption)"
    echo "6. Oracle Free"
    echo "---------------------------------"
    echo "C. Force Cleanup (Docker DBs)"
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
    local folder="$1"
    local track="$2"
    local script="$3"
    
    echo -e ">>> Stopping all Gradle Daemons..."
    ./gradlew --stop 2>/dev/null || true
    
    echo -e ">>> Provisioning environment: $track..."
    bash "$DEMO_DIR/$folder/config/$track/scripts/$script"
    
    echo -e ">>> Loading environment variables..."
    import_env "$DEMO_DIR/$folder/config/$track/envs/$track.env"
    
    cd "$ROOT_DIR/eip-core-consumer"
    ./gradlew clean quarkusDev
}

while true; do
    show_menu
    case $choice in
        1) run_scenario "postgres" "ssl-postgres" "ssl-postgres.sh" ;;
        2) run_scenario "mongodb" "ssl-mongo" "ssl-mongo.sh" ;;
        3) run_scenario "mysql" "ssl-mysql" "ssl-mysql.sh" ;;
        4) run_scenario "cassandra" "ssl-cassandra" "ssl-cassandra.sh" ;;
        5) run_scenario "sqlserver" "ssl-sqlserver" "ssl-sqlserver.sh" ;;
        6) run_scenario "oracle" "ssl-oracle" "ssl-oracle.sh" ;;
        [Cc]) 
            echo ">>> Cleaning up database containers..."
            docker ps -a --format '{{.Names}}' | grep -E 'postgres|mongo|mysql|cassandra|sqlserver|oracle' | xargs -r docker rm -f
            ;;
        [Qq]) exit 0 ;;
        *) echo "Invalid choice." ; sleep 1 ;;
    esac
done
