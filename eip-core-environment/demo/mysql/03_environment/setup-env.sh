#!/bin/bash
SCENARIO="${1:-non-ssl-mysql}"
export EIP_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export EIP_BASE_DIR=$(cd "$EIP_SCRIPT_DIR/../../.." && pwd)
export PROFILE_FILE="$EIP_SCRIPT_DIR/03_environment/profiles/${SCENARIO}.yaml"

# 1. Base Framework Paths
export EIP_CERT_DIR="${EIP_CERT_DIR:-$EIP_SCRIPT_DIR/02_initialization/certs/$SCENARIO}"
export CAMEL_MAIN_ROUTES_INCLUDE_PATTERN="file:${EIP_SCRIPT_DIR}/04_routes/**/*.yaml"
export QUARKUS_CAMEL_ROUTES_DISCOVERY_PATHS="file:${EIP_SCRIPT_DIR}/04_routes/"

# 1.5. Infrastructure Purge (Prevent leakage from other tracks)
unset QUARKUS_MONGODB_CONNECTION_STRING
unset QUARKUS_MONGODB_EIP1_CONNECTION_STRING
unset QUARKUS_MONGODB_EIP2_CONNECTION_STRING
unset MONGODB_CONNECTION_STRING

# 2. Bridge YAML to Shell (Industrialized Parser)
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    
    # Split only at the first colon
    key="${line%%:*}"
    value="${line#*:}"
    
    # Strip leading/trailing whitespace and legacy 'export'
    clean_key=$(echo "$key" | sed -e 's/^export //' -e 's/[[:space:]]*$//')
    clean_value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/^[ \"'\'']*//' -e 's/[ \"'\'']*$//')
    
    # Resolve variables
    resolved_value=${clean_value//\~/$HOME}
    resolved_value=${resolved_value//\$\{HOME\}/$HOME}
    resolved_value=${resolved_value//\$\{EIP_BASE_DIR\}/$EIP_BASE_DIR}
    resolved_value=${resolved_value//\$\{EIP_SCRIPT_DIR\}/$EIP_SCRIPT_DIR}
    resolved_value=${resolved_value//\$\{EIP_CERT_DIR\}/$EIP_CERT_DIR}
    
    export "$clean_key=$resolved_value"
done < "$PROFILE_FILE"

export SMALLRYE_CONFIG_LOCATIONS="file://$PROFILE_FILE"
echo ">>> [SYSTEM] MySQL Connectivity Profile: ${SCENARIO}.yaml"
