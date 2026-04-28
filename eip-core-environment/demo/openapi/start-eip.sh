#!/bin/bash
# start-eip.sh - OPENAPI & SWAGGER MISSION CONTROL
# Lifecycle: Env -> Launch (No Infra/Security)

EIP_SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONSUMER_DIR=$(realpath "$EIP_SCRIPT_DIR/../../../eip-core-consumer")

echo "======================================================================"
echo "                EIP OPENAPI & SWAGGER MISSION CONTROL                  "
echo "======================================================================"
echo "Scenario: openapi (Simplified: Env + Routes Only)"
echo "======================================================================"
echo ""

# PHASE 0: ENVIRONMENT RESOLUTION
echo -e "\033[34m>>> PHASE 0: ENVIRONMENT PREP\033[0m"
source "$EIP_SCRIPT_DIR/03_environment/setup-env.sh" "openapi"

# PHASE 1: CLEANUP
echo -e "\033[34m>>> PHASE 1: CLEANUP\033[0m"
pkill -f "eip-core-consumer" > /dev/null 2>&1 || true
echo "    >>> Cleanup Complete."

# PHASE 4: LAUNCHING CONSUMER
echo -e "\033[34m>>> PHASE 4: LAUNCHING ENGINE\033[0m"
cd "$CONSUMER_DIR"

# Fix for Netty 'CleanerJava9' NPE on Java 17+ and Route Discovery
# Using JDK_JAVA_OPTIONS ensures all forked JVMs (Gradle/Quarkus) inherit these critical opens
export JDK_JAVA_OPTIONS="--add-opens java.base/java.nio=ALL-UNNAMED --add-opens java.base/jdk.internal.misc=ALL-UNNAMED --add-opens java.base/sun.nio.ch=ALL-UNNAMED --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.base/jdk.internal.ref=ALL-UNNAMED"

./gradlew quarkusDev -Dquarkus.profile=prod -Dcamel.main.routes-include-pattern=file:${EIP_ROUTES_DIR}/*.yaml -Dcamel.main.dump-routes=true -Dio.netty.tryReflectionSetAccessible=true
