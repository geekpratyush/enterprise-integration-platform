#!/bin/bash
# startsolace-route.sh
# Comprehensive DECENTRALIZED Menu-Driven Entry Point for Solace PubSub+ Connectivity.

# Find the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." >/dev/null 2>&1 && pwd)"

# Trap SIGINT (Ctrl+C) to exit cleanly instead of returning to the menu
trap "echo -e '\n\033[36m>>> Interrupted by user. Exiting Platform CLI...\033[0m'; exit 0" INT

# Array to track variables loaded from environment files
IMPORTED_ENV_VARS=()

clear_env_vars() {
    # 1. Unset all dynamically tracked variables from the previous iteration
    for var in "${IMPORTED_ENV_VARS[@]}"; do
        unset "$var"
    done
    IMPORTED_ENV_VARS=()

    # 2. Fallback: Unset all related variables using an expanded list of prefixes to ensure a clean start
    for var in $(compgen -v | grep -E '^(SOLACE_|JMS_|EIP_|CAMEL_|QUARKUS_|SPRING_|KAFKA_|AMQ_|DB_)'); do
        unset "$var"
    done
}

import_env_file() {
    local path="$1"
    local base_dir="$2"
    if [ -f "$path" ]; then
        while IFS='=' read -r name value || [ -n "$name" ]; do
            # Trim whitespace
            name="$(echo -e "${name}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            
            # Skip empty lines or lines starting with #
            if [[ -z "$name" || "$name" == \#* ]]; then
                continue
            fi
            
            value="$(echo -e "${value}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            
            if [ -n "$value" ]; then
                if [[ "$name" == *_PATH || "$name" == *_DIR ]]; then
                    # Only resolve relative to base_dir if it's not already an absolute path
                    if [[ "$value" == /* ]]; then
                        export "$name=$value"
                    elif command -v realpath >/dev/null 2>&1; then
                        export "$name=$(realpath -m "$base_dir/$value")"
                    else
                        export "$name=$base_dir/$value"
                    fi
                else
                    export "$name=$value"
                fi
            else
                export "$name="
            fi
            
            # Keep track of the imported variable so we can cleanly unset it in the next selection
            IMPORTED_ENV_VARS+=("$name")
        done < "$path"
    fi
}

while true; do
    clear
    echo -e "\033[36m==============================\033[0m"
    echo -e "\033[36mSolace EIP Platform CLI\033[0m"
    echo -e "\033[36m==============================\033[0m"
    echo "Select Environment Type:"
    echo "1. Non-SSL Environment"
    echo "2. SSL (One-way / CA Cert Only)"
    echo "3. mTLS (Mutual Auth)"
    echo "C. Force Cleanup (Ports 8080/55555 + Docker)"
    echo "Q. Quit"
    echo ""
    read -p "Choice: " choice

    track=""
    env_file=""
    script=""

    case "$choice" in
        1) track="non-ssl"; env_file="config/non-ssl/envs/non-ssl.env"; script="scripts/non-ssl.sh" ;;
        2) track="ssl-jms"; env_file="config/ssl-jms/envs/ssl-jms.env"; script="scripts/ssl-jms.sh" ;;
        3) track="mtls-jms"; env_file="config/mtls-jms/envs/mtls-jms.env"; script="scripts/mtls-jms.sh" ;;
        [Cc])
            echo -e "\033[33m>>> Performing Force Cleanup...\033[0m"
            # Stop all running containers
            if command -v docker >/dev/null 2>&1; then
                running_containers=$(docker ps -a --format '{{.Names}}' | grep solace)
                if [ -n "$running_containers" ]; then
                    echo "Stopping Solace containers: $running_containers"
                    docker stop $running_containers
                    docker rm $running_containers
                fi
            fi
            # Kill processes on relevant ports
            for port in 8080 55555 55443 1943 1443; do
                if command -v fuser >/dev/null 2>&1; then
                    fuser -k ${port}/tcp 2>/dev/null
                elif command -v lsof >/dev/null 2>&1; then
                    lsof -ti:${port} | xargs kill -9 2>/dev/null
                fi
            done
            echo -e "\033[32m>>> Cleanup Complete.\033[0m"
            sleep 2
            continue
            ;;
        [Qq]) exit 0 ;;
        *) continue ;;
    esac

    if [ -n "$track" ]; then
        clear_env_vars
        DEMO_DIR="$SCRIPT_DIR/config/$track"
        ENV_FILE_PATH="$SCRIPT_DIR/$env_file"
        
        # 1. Load the silo-specific env file.
        if [ ! -f "$ENV_FILE_PATH" ]; then
            echo -e "\033[31m>>> Error: Env file not found: $ENV_FILE_PATH\033[0m"
            sleep 2
            continue
        fi
        import_env_file "$ENV_FILE_PATH" "$SCRIPT_DIR"

        # 2. Invoke the PRIVATE setup script belonging to this SILO
        setup_script="$DEMO_DIR/$script"
        if [ -f "$setup_script" ]; then
            pushd "$DEMO_DIR" > /dev/null
            chmod +x "$setup_script"
            source "$setup_script"
            popd > /dev/null
        else
            echo "Setup script not found: $setup_script" >&2
            sleep 2
            continue
        fi
        
        echo -e "\n\033[36m>>> Starting Consumer App using tracks from: $track\033[0m"
        sleep 2

        # Launch Quarkus
        pushd "$ROOT_DIR/eip-core-consumer" > /dev/null
        
        # Hardening flags required for Solace JCSMP on Java 17+
        ./gradlew clean quarkusDev \
          -Dsolace.transport.netty.native.disable=true \
          -Dquarkus.netty.native-transport=false \
          -Dio.netty.noUnsafe=true \
          -Djava.net.preferIPv4Stack=true \
          -Dquarkus.profile=dev \
          -Dquarkus.args="--add-opens java.base/java.nio=ALL-UNNAMED"
          
        popd > /dev/null
        
        echo -e "\n\033[90m>>> Session Finished. Returning to menu...\n\033[0m"
        sleep 5
    fi
done
