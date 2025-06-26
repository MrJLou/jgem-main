# Quick network information utility for LAN server setup
Write-Host "🌐 NETWORK INTERFACE INFORMATION" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Get network adapter information
$adapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -ne "127.0.0.1" }

if ($adapters.Count -eq 0) {
    Write-Host "❌ No network interfaces found" -ForegroundColor Red
    exit
}

$primaryIp = $null
$found172Network = $false

foreach ($adapter in $adapters) {
    $ip = $adapter.IPAddress
    $interface = $adapter.InterfaceAlias
    
    $type = ""
    if ($ip.StartsWith("192.168.")) {
        $type = "(Private - WiFi/Ethernet)"
    } elseif ($ip.StartsWith("10.")) {
        $type = "(Private - Corporate)"
    } elseif ($ip.StartsWith("172.")) {
        $type = "(Private - Corporate)"
        if ($ip.StartsWith("172.30.")) {
            $primaryIp = $ip
            $found172Network = $true
        }
    } else {
        $type = "(Public/Other)"
    }
    
    Write-Host "📍 $interface : $ip $type" -ForegroundColor Green
    
    # Set primary IP if we haven't found a 172.30.x.x network yet
    if (-not $found172Network -and $primaryIp -eq $null -and ($ip.StartsWith("192.168.") -or $ip.StartsWith("10.") -or $ip.StartsWith("172."))) {
        $primaryIp = $ip
    }
}

Write-Host ""
if ($primaryIp) {
    Write-Host "⭐ PRIMARY IP (Recommended): $primaryIp" -ForegroundColor Yellow
    Write-Host "   Use this IP for LAN server hosting" -ForegroundColor Yellow
    
    Write-Host ""
    Write-Host "📋 FOR YOUR LAN SERVER:" -ForegroundColor Magenta
    Write-Host "1. Open your Patient Management app" -ForegroundColor White
    Write-Host "2. Go to 'LAN Server Management'" -ForegroundColor White
    Write-Host "3. Enable the server (it will automatically detect this IP)" -ForegroundColor White
    Write-Host "4. Copy the access code and share these details:" -ForegroundColor White
    Write-Host ""
    Write-Host "   Server IP: $primaryIp" -ForegroundColor Cyan
    Write-Host "   Port: 8080" -ForegroundColor Cyan
    Write-Host "   Access Code: [Get from the app]" -ForegroundColor Cyan
    
    Write-Host ""
    Write-Host "📱 FOR CLIENT DEVICES:" -ForegroundColor Magenta
    Write-Host "1. Open the Patient Management app" -ForegroundColor White
    Write-Host "2. Go to 'LAN Client Connection'" -ForegroundColor White
    Write-Host "3. Use 'Update IP' button or enter manually:" -ForegroundColor White
    Write-Host "   - Server IP: $primaryIp" -ForegroundColor Cyan
    Write-Host "   - Port: 8080" -ForegroundColor Cyan
    Write-Host "   - Access Code: [Get from server]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "💡 The server should automatically detect the IP change when you restart it." -ForegroundColor Green
} else {
    Write-Host "❌ No suitable IP address found for hosting" -ForegroundColor Red
}

Write-Host ""
Write-Host "🔄 If your IP changed from a different address to the one shown above:" -ForegroundColor Blue
Write-Host "   - Restart your LAN server in the app" -ForegroundColor White
Write-Host "   - Update all client devices with the new IP" -ForegroundColor White
Write-Host "   - The app has 'Refresh Network Interfaces' and 'Update IP' features" -ForegroundColor White
