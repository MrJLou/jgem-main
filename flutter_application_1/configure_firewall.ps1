# PowerShell script to configure Windows Firewall for flutter_application_1
# Run this script as Administrator

param(
    [int]$Port = 8080,
    [string]$AppName = "flutter_application_1",
    [string]$AppPath = ""
)

Write-Host "🔥 Configuring Windows Firewall for $AppName..." -ForegroundColor Cyan
Write-Host "Port: $Port" -ForegroundColor Yellow

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "❌ This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

try {
    # Get the application executable path if not provided
    if ([string]::IsNullOrEmpty($AppPath)) {
        $currentDir = Get-Location
        $buildDir = Join-Path $currentDir "build\windows\x64\runner\Release"
        $AppPath = Join-Path $buildDir "$AppName.exe"
        
        if (-not (Test-Path $AppPath)) {
            $debugDir = Join-Path $currentDir "build\windows\x64\runner\Debug"
            $AppPath = Join-Path $debugDir "$AppName.exe"
        }
        
        if (-not (Test-Path $AppPath)) {
            Write-Host "⚠️  Application executable not found. Creating port-based rules only." -ForegroundColor Yellow
            $AppPath = ""
        } else {
            Write-Host "📱 Found application at: $AppPath" -ForegroundColor Green
        }
    }

    Write-Host "🔍 Checking existing firewall rules..." -ForegroundColor Cyan

    # Remove existing rules for this application
    $existingRules = Get-NetFirewallRule -DisplayName "*$AppName*" -ErrorAction SilentlyContinue
    if ($existingRules) {
        Write-Host "🧹 Removing existing firewall rules for $AppName..." -ForegroundColor Yellow
        $existingRules | Remove-NetFirewallRule
    }

    # Create inbound rule for the application executable (if found)
    if (-not [string]::IsNullOrEmpty($AppPath) -and (Test-Path $AppPath)) {
        Write-Host "➕ Creating inbound rule for application executable..." -ForegroundColor Green
        New-NetFirewallRule -DisplayName "$AppName - Inbound (App)" `
                           -Direction Inbound `
                           -Program $AppPath `
                           -Action Allow `
                           -Profile Domain,Private,Public `
                           -Description "Allow $AppName to receive incoming connections"

        Write-Host "➕ Creating outbound rule for application executable..." -ForegroundColor Green
        New-NetFirewallRule -DisplayName "$AppName - Outbound (App)" `
                           -Direction Outbound `
                           -Program $AppPath `
                           -Action Allow `
                           -Profile Domain,Private,Public `
                           -Description "Allow $AppName to make outgoing connections"
    }

    # Create port-based rules for HTTP server
    Write-Host "➕ Creating inbound rule for port $Port (HTTP)..." -ForegroundColor Green
    New-NetFirewallRule -DisplayName "$AppName - Inbound Port $Port (HTTP)" `
                       -Direction Inbound `
                       -Protocol TCP `
                       -LocalPort $Port `
                       -Action Allow `
                       -Profile Domain,Private,Public `
                       -Description "Allow incoming HTTP connections on port $Port for $AppName"

    Write-Host "➕ Creating outbound rule for port $Port (HTTP)..." -ForegroundColor Green
    New-NetFirewallRule -DisplayName "$AppName - Outbound Port $Port (HTTP)" `
                       -Direction Outbound `
                       -Protocol TCP `
                       -LocalPort $Port `
                       -Action Allow `
                       -Profile Domain,Private,Public `
                       -Description "Allow outgoing HTTP connections on port $Port for $AppName"

    # Create rules for WebSocket connections (usually same port, but different protocol handling)
    Write-Host "➕ Creating WebSocket rules for port $Port..." -ForegroundColor Green
    New-NetFirewallRule -DisplayName "$AppName - WebSocket Inbound Port $Port" `
                       -Direction Inbound `
                       -Protocol TCP `
                       -LocalPort $Port `
                       -Action Allow `
                       -Profile Domain,Private,Public `
                       -Description "Allow incoming WebSocket connections on port $Port for $AppName"

    # Create rules for common alternative ports
    $alternatePorts = @(8081, 8082, 8083, 8090, 3000, 5000)
    foreach ($altPort in $alternatePorts) {
        Write-Host "➕ Creating rule for alternate port $altPort..." -ForegroundColor Blue
        New-NetFirewallRule -DisplayName "$AppName - Alternate Port $altPort" `
                           -Direction Inbound `
                           -Protocol TCP `
                           -LocalPort $altPort `
                           -Action Allow `
                           -Profile Private `
                           -Description "Allow connections on alternate port $altPort for $AppName"
    }

    # Allow Flutter/Dart executables
    $dartSdk = Get-Command dart -ErrorAction SilentlyContinue
    if ($dartSdk) {
        Write-Host "➕ Creating rule for Dart SDK..." -ForegroundColor Green
        New-NetFirewallRule -DisplayName "$AppName - Dart SDK" `
                           -Direction Inbound `
                           -Program $dartSdk.Source `
                           -Action Allow `
                           -Profile Domain,Private,Public `
                           -Description "Allow Dart SDK for $AppName"
    }

    # Check for Flutter executable
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutterCmd) {
        Write-Host "➕ Creating rule for Flutter..." -ForegroundColor Green
        New-NetFirewallRule -DisplayName "$AppName - Flutter" `
                           -Direction Inbound `
                           -Program $flutterCmd.Source `
                           -Action Allow `
                           -Profile Domain,Private,Public `
                           -Description "Allow Flutter for $AppName"
    }

    Write-Host "✅ Firewall configuration completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Summary of created rules:" -ForegroundColor Cyan
    
    $newRules = Get-NetFirewallRule -DisplayName "*$AppName*"
    foreach ($rule in $newRules) {
        $status = if ($rule.Enabled) { "✅ Enabled" } else { "❌ Disabled" }
        Write-Host "  $($rule.DisplayName) - $status" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "🌐 Your application should now be able to:" -ForegroundColor Green
    Write-Host "  • Accept incoming connections on port $Port" -ForegroundColor White
    Write-Host "  • Establish outgoing connections" -ForegroundColor White
    Write-Host "  • Communicate via WebSocket connections" -ForegroundColor White
    Write-Host "  • Use alternative ports if needed" -ForegroundColor White

    Write-Host ""
    Write-Host "💡 Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Run your Flutter application" -ForegroundColor White
    Write-Host "  2. Test the connection using connection_test.dart" -ForegroundColor White
    Write-Host "  3. Share the access code with other devices on your network" -ForegroundColor White

} catch {
    Write-Host "❌ Error configuring firewall: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🔥 Firewall configuration script completed!" -ForegroundColor Cyan
