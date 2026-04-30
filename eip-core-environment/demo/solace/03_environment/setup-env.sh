#!/bin/bash
SCENARIO="${1:-non-ssl-mongo}"
export EIP_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export PROFILE_FILE="$EIP_SCRIPT_DIR/03_environment/profiles/${SCENARIO}.yaml"

# 1. Base Framework Paths
export EIP_CERT_DIR=~/.eip/certs/solace/${SCENARIO}
export CAMEL_MAIN_ROUTES_INCLUDE_PATTERN="file:$EIP_SCRIPT_DIR/04_routes/test-routes/**/*.yaml"

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
    
    # Resolve tilde
    resolved_value=${clean_value//\~/$HOME}
    
    export "$clean_key=$resolved_value"
    
    # DEBUG TRACE
done < "$PROFILE_FILE"

export SMALLRYE_CONFIG_LOCATIONS="file://$PROFILE_FILE"
echo ">>> [SYSTEM] MongoDB Connectivity Profile: ${SCENARIO}.yaml"
