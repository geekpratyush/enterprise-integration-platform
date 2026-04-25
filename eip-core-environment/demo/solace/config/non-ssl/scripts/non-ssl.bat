@echo off
:: non-ssl/scripts/non-ssl.bat

set SCRIPT_DIR=%~dp0
set DEMO_DIR=%SCRIPT_DIR%..
set CONTAINER_DIR=%DEMO_DIR%\container

echo.
echo >>> Starting Solace Non-SSL Infrastructure (Port 55555)...

pushd "%CONTAINER_DIR%"
docker compose -f solace-standard.yaml down -v --remove-orphans
docker compose -f solace-standard.yaml up -d
popd

echo >>> [1/3] Waiting for Broker (30s)...
timeout /t 30 >nul

:: Provisioning Queue Q.DEMO.1 via SEMP v2 (requires curl for Windows)
echo >>> Provisioning Queue Q.DEMO.1...
curl -X POST -u admin:admin -H "Content-Type: application/json" -d "{\"msgVpnName\":\"default\",\"queueName\":\"Q.DEMO.1\",\"egressEnabled\":true,\"ingressEnabled\":true}" http://localhost:8080/SEMP/v2/config/msgVpns/default/queues

echo.
echo >>> Solace Non-SSL Silo Ready.
