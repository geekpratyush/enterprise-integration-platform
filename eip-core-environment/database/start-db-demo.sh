#!/bin/bash

# Configuration and Fuel Paths
ENV_FILE="./demo/non-tls/envs/mongo-postgres.env"
ROUTE_FILE="./demo/non-tls/routes/test-route.yaml"

# Load the fuel if exists
if [ -f "$ENV_FILE" ]; then
    echo "Loading environment parameters (fuel) for the agnostic-db extension..."
    export $(grep -v '^#' $ENV_FILE | xargs)
else
    echo "Warning: Fuel file ($ENV_FILE) not found. Extension will only work if default config exists."
fi

# Run the Camel demo with JBang
# Note: We include the extension source so Camel can find the Translator bean
# Note: Use --local-kamelet-dir to let Camel find our custom Kamelet locally
# Note: Use --stub=true for local simulation without real databases
echo "Powering up the Camel Agnostic DB Demo..."
jbang run camel@apache/camel run $ROUTE_FILE \
  --local-kamelet-dir=./kamelets \
  --stub=true


