#!/bin/bash
# 03_environment/setup-env.sh
SCENARIO=$1
EIP_INIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROFILE_FILE="$EIP_INIT_DIR/profiles/${SCENARIO}.env"

if [[ ! -f "$PROFILE_FILE" ]]; then
    echo "ERROR: Profile not found: $PROFILE_FILE"
    exit 1
fi

# 1. Establish Absolute Base Paths FIRST
# eip-core-environment/demo/ibmmq/03_environment -> eip-core-integration root
export EIP_BASE_DIR=$(realpath "$EIP_INIT_DIR/../../../..")
# Isolation: Each scenario gets its own cert sub-folder
export EIP_CERT_DIR=$(realpath "$EIP_INIT_DIR/../02_initialization/certs/$SCENARIO")
export EIP_ROUTES_DIR=$(realpath "$EIP_INIT_DIR/../04_routes/test-routes")

echo ">>> Loading dynamic profile: ${SCENARIO}.env"
echo ">>> [SANDBOX] Certified Assets: $EIP_CERT_DIR"

# 2. Source the profile (it can now safely use the variables above)
set -a
source "$PROFILE_FILE"
set +a

# 3. Final verification for Java
export EIP_CONFIG_DIR=${EIP_ROUTES_DIR}
export EIP_ROUTE_DIR=${EIP_ROUTES_DIR}

echo ">>> [SYSTEM] EIP_ROUTE_DIR=$EIP_ROUTE_DIR"
