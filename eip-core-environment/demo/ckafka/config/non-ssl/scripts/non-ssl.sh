#!/bin/bash
# scripts/non-ssl.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
CONFIG_DIR="$(cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"

echo -e "\033[36m>>> Provisioning Kafka Non-SSL Environment...\033[0m"

# Ensure container setup is clean
docker compose -f "$CONFIG_DIR/container/kafka-isolated.yaml" down -v --remove-orphans 2>/dev/null
docker compose -f "$CONFIG_DIR/container/kafka-isolated.yaml" up -d

echo -e "\033[33m>>> [1/2] Waiting for Broker (10s)...\033[0m"
sleep 10
docker exec kafka-nonssl kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic demo-topic --partitions 1 --replication-factor 1
docker exec kafka-nonssl kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic demo-topic-out --partitions 1 --replication-factor 1

echo -e "\033[32m>>> Kafka KRaft Non-SSL Started on Port 9092\033[0m"

