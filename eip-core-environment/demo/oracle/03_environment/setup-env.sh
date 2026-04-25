#!/bin/bash
# 03_environment/setup-env.sh - DYNAMIC PROFILE LOADER
# Purpose: Metadata-driven environment resolution for Oracle

SCENARIO="${1:-non-ssl-oracle}"
ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="$ENV_DIR/profiles"

# Dynamic discovery
PROFILE="${SCENARIO}.env"

if [[ ! -f "$PROFILE_DIR/$PROFILE" ]]; then
    STACK_PROFILE="$(ls $PROFILE_DIR/${SCENARIO}*.env 2>/dev/null | head -n 1)"
    if [[ -z "$STACK_PROFILE" ]]; then
        echo -e "\033[31mERROR: Scenario '$SCENARIO' not found in $PROFILE_DIR\033[0m"
        echo "Available scenarios: $(ls $PROFILE_DIR/*.env | xargs -n 1 basename | sed 's/.env//' 2>/dev/null)"
        return 1
    fi
    PROFILE="$(basename $STACK_PROFILE)"
fi

ENV_FILE="$PROFILE_DIR/$PROFILE"
echo ">>> Loading dynamic profile: $PROFILE"

# 1. Base Framework Paths
export EIP_BASE_DIR=$(realpath "${EIP_BASE_DIR:-../../../}")
export EIP_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export EIP_INIT_DIR=$(realpath "${EIP_INIT_DIR:-$EIP_SCRIPT_DIR/02_initialization}")
export EIP_ROUTE_DIR=$(realpath "${EIP_ROUTE_DIR:-$EIP_SCRIPT_DIR/04_routes}")
export EIP_CERT_DIR=$(realpath "$EIP_INIT_DIR/certs")

# 2. Export Variables from Profile
while read -r line || [[ -n "$line" ]]; do
  [[ "$line" =~ ^#.*$ ]] && continue
  [[ -z "$line" ]] && continue
  export "$(eval echo $line)"
done < "$ENV_FILE"

echo ">>> [BOOTSTRAP] Configuration Loaded for Oracle Scenario: $SCENARIO"
