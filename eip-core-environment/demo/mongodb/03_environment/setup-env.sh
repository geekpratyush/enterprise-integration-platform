#!/bin/bash
# 03_environment/setup-env.sh - DYNAMIC PROFILE LOADER

EIP_SETUP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCENARIO="${1:-non-ssl-mongo}"
PROFILE_DIR="$EIP_SETUP_DIR/profiles"

# Resolve Profile
PROFILE="${SCENARIO}.env"
if [[ ! -f "$PROFILE_DIR/$PROFILE" ]]; then
    echo -e "\033[31mERROR: Scenario '$SCENARIO' not found in $PROFILE_DIR\033[0m"
    return 1
fi

ENV_FILE="$PROFILE_DIR/$PROFILE"
echo ">>> Loading dynamic profile: $PROFILE"

# 1. Establish Absolute Base Paths FIRST
# eip-core-environment/demo/mongodb/03_environment -> eip-core-integration root
export EIP_BASE_DIR=$(realpath "$EIP_SETUP_DIR/../../../..")
# Isolation: Each scenario gets its own cert sub-folder
export EIP_CERT_DIR=$(realpath "$EIP_SETUP_DIR/../02_initialization/certs/$SCENARIO")
export EIP_ROUTES_DIR=$(realpath "$EIP_SETUP_DIR/../04_routes/test-routes")

# 2. Export Variables from Profile
while read -r line || [[ -n "$line" ]]; do
  [[ "$line" =~ ^#.*$ ]] && continue
  [[ -z "$line" ]] && continue
  # Expand variables during export (allows ${EIP_CERT_DIR} usage in .env files)
  export "$(eval echo $line)"
done < "$ENV_FILE"

echo ">>> [SANDBOX] Certified Assets: $EIP_CERT_DIR"
echo ">>> [SYSTEM] EIP_ROUTE_DIR=$EIP_ROUTES_DIR"
