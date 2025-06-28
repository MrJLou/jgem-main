# Quick setup script for flutter_application_1 networking
# This script will configure firewall and test connections

Write-Host "🚀 Flutter Application Network Setup" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "⚠️  Administrator privileges required for firewall configuration" -ForegroundColor Yellow
    Write-Host "To run with administrator privileges:" -ForegroundColor White
    Write-Host "1. Right-click PowerShell" -ForegroundColor White
    Write-Host "2. Select 'Run as Administrator'" -ForegroundColor White
    Write-Host "3. Navigate to this directory and run this script again" -ForegroundColor White
    Write-Host ""
    Write-Host "For now, I'll show you what needs to be configured..." -ForegroundColor Yellow
} else {
    Write-Host "✅ Running with administrator privileges" -ForegroundColor Green
}

Write-Host ""
Write-Host "🔍 Checking network configuration..." -ForegroundColor Cyan

# Get network interfaces
try {
    $networkInterfaces = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Virtual -eq $false }
    Write-Host "Active network interfaces:" -ForegroundColor Green
    
    foreach ($interface in $networkInterfaces) {
        $ipConfig = Get-NetIPAddress -InterfaceIndex $interface.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        foreach ($ip in $ipConfig) {
            if ($ip.IPAddress -notmatch "^169\.254\.") {  # Skip APIPA addresses
                Write-Host "  $($interface.Name): $($ip.IPAddress)" -ForegroundColor White
                
                # Check if this is your primary network
                if ($ip.IPAddress -match "^192\.168\.68\.") {
                    Write-Host "    ⭐ Primary network detected!" -ForegroundColor Yellow
                }
            }
        }
    }
} catch {
    Write-Host "❌ Could not retrieve network information: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🔥 Firewall Configuration" -ForegroundColor Cyan

if ($isAdmin) {
    try {
        # Run the firewall configuration
        Write-Host "Configuring firewall rules..." -ForegroundColor Yellow
        & ".\configure_firewall.ps1" -Port 8080 -AppName "flutter_application_1"
        
        Write-Host "✅ Firewall configured successfully!" -ForegroundColor Green
    } catch {
        Write-Host "❌ Error configuring firewall: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "Manual firewall configuration needed:" -ForegroundColor Yellow
    Write-Host "1. Allow flutter_application_1.exe through Windows Firewall" -ForegroundColor White
    Write-Host "2. Allow inbound connections on port 8080 (TCP)" -ForegroundColor White
    Write-Host "3. Allow outbound connections on port 8080 (TCP)" -ForegroundColor White
    Write-Host ""
    Write-Host "Or run this script as Administrator to configure automatically." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🧪 Connection Test" -ForegroundColor Cyan

Write-Host "To test your connection, run:" -ForegroundColor Green
Write-Host "  dart connection_test.dart" -ForegroundColor White

Write-Host ""
Write-Host "📱 Usage Instructions" -ForegroundColor Cyan
Write-Host "1. Start your Flutter app: flutter run -d windows" -ForegroundColor White
Write-Host "2. Navigate to LAN connection settings in the app" -ForegroundColor White
Write-Host "3. Start hosting to get your access code" -ForegroundColor White
Write-Host "4. Share the IP address and access code with other devices" -ForegroundColor White
Write-Host "5. Other devices can connect using the IP and access code" -ForegroundColor White

Write-Host ""
Write-Host "🔧 Troubleshooting" -ForegroundColor Cyan
Write-Host "If connections fail:" -ForegroundColor Yellow
Write-Host "• Check Windows Firewall settings" -ForegroundColor White
Write-Host "• Verify devices are on the same network (192.168.68.x)" -ForegroundColor White
Write-Host "• Run connection_test.dart for detailed diagnostics" -ForegroundColor White
Write-Host "• Check router settings (some routers block device-to-device communication)" -ForegroundColor White

Write-Host ""
Write-Host "✨ Setup completed! Your app should now work across devices." -ForegroundColor Green
