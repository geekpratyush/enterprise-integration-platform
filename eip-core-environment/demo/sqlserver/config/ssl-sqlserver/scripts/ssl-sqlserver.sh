#!/bin/bash
# ssl-sqlserver.sh - Setup SQL Server with Encryption
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
CONFIG_DIR="$(cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"

echo -e "\033[36m>>> Provisioning SQL Server Environment...\033[0m"

# 1. Start Container
docker compose -f "$CONFIG_DIR/container/sqlserver-isolated.yaml" down -v --remove-orphans 2>/dev/null
docker compose -f "$CONFIG_DIR/container/sqlserver-isolated.yaml" up -d

echo -e "\033[33m>>> Waiting for SQL Server (30s)...\033[0m"
sleep 30

# 2. Create Demo Schema
docker exec sqlserver-ssl /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "Eip_password123" -Q "CREATE DATABASE eip_db; GO; USE eip_db; CREATE TABLE demo_audit (id INT IDENTITY(1,1) PRIMARY KEY, message NVARCHAR(255), created_at DATETIME DEFAULT GETDATE()); GO;"

echo -e "\033[32m>>> SQL Server Started on Port 1433 (Encryption Enabled)\033[0m"
