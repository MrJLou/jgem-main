@echo off
echo 🔥 Flutter Application Firewall Setup
echo ====================================
echo.
echo This script will configure Windows Firewall for flutter_application_1
echo.

:: Check for administrator privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo ✅ Running with administrator privileges
    echo.
    goto :configure_firewall
) else (
    echo ⚠️  Administrator privileges required!
    echo.
    echo To configure firewall automatically:
    echo 1. Right-click this file (setup_firewall.bat)
    echo 2. Select "Run as administrator"
    echo.
    echo Manual firewall configuration:
    echo 1. Open Windows Defender Firewall with Advanced Security
    echo 2. Create new Inbound Rule:
    echo    - Rule Type: Port
    echo    - Protocol: TCP
    echo    - Specific Local Ports: 8080
    echo    - Action: Allow the connection
    echo    - Profile: All profiles
    echo    - Name: flutter_application_1 - Port 8080
    echo.
    echo 3. Create new Outbound Rule with same settings
    echo.
    pause
    exit /b 1
)

:configure_firewall
echo 🔧 Configuring Windows Firewall rules...
echo.

:: Remove existing rules
echo Removing any existing rules for flutter_application_1...
netsh advfirewall firewall delete rule name="flutter_application_1" >nul 2>&1

:: Create inbound rules
echo ➕ Creating inbound rule for port 8080...
netsh advfirewall firewall add rule name="flutter_application_1 - HTTP Inbound (Port 8080)" dir=in action=allow protocol=TCP localport=8080 profile=domain,private,public

echo ➕ Creating inbound rule for WebSocket connections...
netsh advfirewall firewall add rule name="flutter_application_1 - WebSocket Inbound" dir=in action=allow protocol=TCP localport=8080 profile=domain,private,public

:: Create outbound rules
echo ➕ Creating outbound rule for port 8080...
netsh advfirewall firewall add rule name="flutter_application_1 - HTTP Outbound (Port 8080)" dir=out action=allow protocol=TCP localport=8080 profile=domain,private,public

echo ➕ Creating outbound rule for WebSocket connections...
netsh advfirewall firewall add rule name="flutter_application_1 - WebSocket Outbound" dir=out action=allow protocol=TCP localport=8080 profile=domain,private,public

:: Create rules for alternative ports
echo ➕ Creating rules for alternative ports...
netsh advfirewall firewall add rule name="flutter_application_1 - Alt Port 8081" dir=in action=allow protocol=TCP localport=8081 profile=private,public
netsh advfirewall firewall add rule name="flutter_application_1 - Alt Port 8082" dir=in action=allow protocol=TCP localport=8082 profile=private,public

:: Create program-based rule if executable exists
set "APP_PATH=%~dp0build\windows\x64\runner\Release\flutter_application_1.exe"
if exist "%APP_PATH%" (
    echo ➕ Creating rule for application executable...
    netsh advfirewall firewall add rule name="flutter_application_1 - Application" dir=in action=allow program="%APP_PATH%" profile=domain,private,public
) else (
    echo ⚠️  Application executable not found at %APP_PATH%
    echo    Port-based rules created instead.
)

echo.
echo ✅ Firewall configuration completed!
echo.
echo 📋 Created firewall rules:
netsh advfirewall firewall show rule name="flutter_application_1" 2>nul | findstr "Rule Name"
echo.
echo 🌐 Your Flutter application can now:
echo   • Accept incoming connections on port 8080
echo   • Establish outgoing connections
echo   • Communicate via WebSocket connections
echo   • Use alternative ports if needed
echo.
echo 💡 Next steps:
echo   1. Run your Flutter application: flutter run -d windows
echo   2. Test connection: dart connection_test.dart
echo   3. Share access code with other devices on your network
echo.
pause
