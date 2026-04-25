@echo off
setlocal enabledelayedexpansion

:: startsolace-route.bat
:: Windows version of the Solace EIP Platform CLI

set SCRIPT_DIR=%~dp0
set ROOT_DIR=%SCRIPT_DIR%..\..\..

:menu
cls
echo ==============================
echo Solace EIP Platform CLI
echo ==============================
echo Select Environment Type:
echo 1. Non-SSL Environment
echo C. Force Cleanup
echo Q. Quit
echo.

set /p choice="Choice: "

if "%choice%"=="1" (
    set track=non-ssl
    set env_file=config\non-ssl\envs\non-ssl.env
    set script=scripts\non-ssl.bat
) else if /i "%choice%"=="C" (
    echo >>> Performing Force Cleanup...
    for /f "tokens=*" %%i in ('docker ps -q') do docker stop %%i
    echo >>> Cleanup Complete.
    timeout /t 2 >nul
    goto menu
) else if /i "%choice%"=="Q" (
    exit /b 0
) else (
    goto menu
)

if defined track (
    :: Basic env loading (simplified for batch)
    for /f "usebackq tokens=1,2 delims==" %%a in ("%SCRIPT_DIR%%env_file%") do (
        set %%a=%%b
    )
    
    set DEMO_DIR=%SCRIPT_DIR%config\%track%
    set setup_script=%DEMO_DIR%\%script%
    
    if exist "%setup_script%" (
        pushd "%DEMO_DIR%"
        call "%setup_script%"
        popd
    )
    
    echo.
    echo >>> Starting Consumer App...
    timeout /t 2 >nul
    
    pushd "%ROOT_DIR%\eip-core-consumer"
    java -Dquarkus.profile=dev -jar build\quarkus-app\quarkus-run.jar
    popd
    
    echo.
    echo >>> Session Finished. Returning to menu...
    timeout /t 5 >nul
    goto menu
)
