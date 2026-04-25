#!/bin/bash
# test_kafka.sh
# Automates testing of Kafka scenarios with a timeout.

KAFKA_DEMO_DIR="/home/pratyush/software/eip-core-integration/eip-core-environment/demo/kafka"
CONSUMER_DIR="/home/pratyush/software/eip-core-integration/eip-core-consumer"
TIMEOUT="45s"

test_scenario() {
    local track=$1
    local env_file="$KAFKA_DEMO_DIR/config/$track/envs/$track.env"
    local setup_script="$KAFKA_DEMO_DIR/config/$track/scripts/$track.sh"
    
    echo -e "\n\033[35m========================================================\033[0m"
    echo -e "\033[35m TESTING SCENARIO: $track \033[0m"
    echo -e "\033[35m========================================================\033[0m"

    # 1. Cleanup old containers
    docker ps -a -q --filter "name=kafka-" | xargs -r docker rm -f
    
    # 2. Run Setup
    if [ -f "$setup_script" ]; then
        echo ">>> Running Setup Script: $setup_script"
        script_dir="$(dirname "$setup_script")"
        pushd "$script_dir" > /dev/null
        bash "$(basename "$setup_script")"
        popd > /dev/null
    else
        echo "ERROR: Setup script not found: $setup_script"
        return 1
    fi


    # 3. Load Envs
    echo ">>> Loading Environment Variables..."
    # We use a subshell for the java run to keep envs isolated
    (
        while IFS='=' read -r name value || [ -n "$name" ]; do
            [[ "$name" =~ ^#.* ]] && continue
            [[ -z "$name" ]] && continue
            export "$name=$value"
        done < "$env_file"
        
        export EIP_CERT_DIR="$KAFKA_DEMO_DIR/config/$track/certs"
        
        # Suppress noise for clearer output (Focus on business logic/routes)
        LOG_SUPPRESS="-Dquarkus.profile=dev -Dquarkus.log.level=INFO"
        LOG_SUPPRESS="$LOG_SUPPRESS -Dquarkus.log.category.org.apache.kafka.level=WARN"
        LOG_SUPPRESS="$LOG_SUPPRESS -Dquarkus.log.category.org.apache.kafka.common.telemetry.level=WARN"
        LOG_SUPPRESS="$LOG_SUPPRESS -Dquarkus.log.category.org.apache.kafka.common.metrics.level=WARN"
        LOG_SUPPRESS="$LOG_SUPPRESS -Dquarkus.log.category.org.apache.kafka.clients.NetworkClient.level=WARN"
        LOG_SUPPRESS="$LOG_SUPPRESS -Dquarkus.log.category.org.apache.kafka.clients.Metadata.level=WARN"
        LOG_SUPPRESS="$LOG_SUPPRESS -Dquarkus.log.category.org.apache.kafka.clients.consumer.internals.level=WARN"
        LOG_SUPPRESS="$LOG_SUPPRESS -Dquarkus.log.category.org.apache.kafka.clients.producer.internals.level=WARN"
        LOG_SUPPRESS="$LOG_SUPPRESS -Dquarkus.log.category.org.apache.kafka.common.utils.AppInfoParser.level=WARN"
        LOG_SUPPRESS="$LOG_SUPPRESS -Dquarkus.log.category.org.mongodb.driver.level=WARN"
        LOG_SUPPRESS="$LOG_SUPPRESS -Dquarkus.log.category.io.quarkus.camel.common.runtime.camel.bootstrap.level=WARN"

        echo ">>> Starting Consumer App (Timeout: $TIMEOUT)..."
        pushd "$CONSUMER_DIR" > /dev/null
        timeout --foreground "$TIMEOUT" java $LOG_SUPPRESS -jar build/quarkus-app/quarkus-run.jar
        popd > /dev/null


    )
    
    echo -e "\033[32m>>> Scenario $track Finished.\033[0m"
}

# Run specific scenario if provided, else all
if [ -n "$1" ]; then
    test_scenario "$1"
else
    test_scenario "non-ssl"
    test_scenario "ssl-kafka"
    test_scenario "ssl-auth-kafka"
    test_scenario "mtls-kafka"
    test_scenario "tx-kafka"
fi

