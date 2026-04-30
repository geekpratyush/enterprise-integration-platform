#!/bin/bash
SCENARIO="${1:-non-ssl-no-auth}"
export EIP_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export EIP_BASE_DIR=$(cd "$EIP_SCRIPT_DIR/../../.." && pwd)
export PROFILE_FILE="$EIP_SCRIPT_DIR/03_environment/profiles/${SCENARIO}.yaml"
export EIP_CERT_DIR=~/.eip/certs/ibmmq/${SCENARIO}
export CAMEL_MAIN_ROUTES_INCLUDE_PATTERN="file:$EIP_SCRIPT_DIR/04_routes/test-routes/**/*.yaml"

while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    key="${line%%:*}"
    value="${line#*:}"
    clean_key=$(echo "$key" | sed -e 's/^export //' -e 's/[[:space:]]*$//')
    clean_value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/^[ \"'\'']*//' -e 's/[ \"'\'']*$//')
    # Resolve variables
    resolved_value=${clean_value//\~/$HOME}
    resolved_value=${resolved_value//\$\{HOME\}/$HOME}
    resolved_value=${resolved_value//\$\{EIP_BASE_DIR\}/$EIP_BASE_DIR}
    
    export "$clean_key=$resolved_value"
done < "$PROFILE_FILE"
export SMALLRYE_CONFIG_LOCATIONS="file://$PROFILE_FILE"
