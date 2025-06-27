# Quick network information utility for LAN server setup
Write-Host "Network Interface Information" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host ""

# Get network adapter information
$adapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -ne "127.0.0.1" }

if ($adapters.Count -eq 0) {
    Write-Host "No network interfaces found" -ForegroundColor Red
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
    
    Write-Host "Interface: $interface - IP: $ip $type" -ForegroundColor Green
    
    # Set primary IP if we haven't found a 172.30.x.x network yet
    if (-not $found172Network -and $primaryIp -eq $null -and ($ip.StartsWith("192.168.") -or $ip.StartsWith("10.") -or $ip.StartsWith("172."))) {
        $primaryIp = $ip
    }
}

Write-Host ""
if ($primaryIp) {
    Write-Host "PRIMARY IP (Recommended): $primaryIp" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "YOUR LAN SERVER SETUP:" -ForegroundColor Magenta
    Write-Host "1. Open your Patient Management app" -ForegroundColor White
    Write-Host "2. Go to 'LAN Server Management'" -ForegroundColor White
    Write-Host "3. Enable the server (it will detect this IP automatically)" -ForegroundColor White
    Write-Host "4. Copy the access code and share with clients" -ForegroundColor White
    Write-Host ""
    Write-Host "CLIENT CONNECTION DETAILS:" -ForegroundColor Magenta
    Write-Host "Server IP: $primaryIp" -ForegroundColor Cyan
    Write-Host "Port: 8080" -ForegroundColor Cyan
    Write-Host "Access Code: [Get from server app]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "UPDATE EXISTING CLIENTS:" -ForegroundColor Blue
    Write-Host "- Use 'Update IP' button in client apps" -ForegroundColor White
    Write-Host "- Or manually enter the new IP: $primaryIp" -ForegroundColor White
} else {
    Write-Host "No suitable IP address found for hosting" -ForegroundColor Red
}
