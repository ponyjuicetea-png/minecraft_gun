param(
    [ValidateSet('Play','Player2','Server','Join','Menu','Stop')][string]$Mode = 'Play',
    [string]$Address = '',
    [string]$PlayerName = '',
    [ValidateSet('balanced','high','performance')][string]$Quality = 'balanced'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $root 'runtime\luanti\bin\luanti.exe'
$world = Join-Path $root 'worlds\frontline'
$pidFile = Join-Path $world 'server.pid'
Set-Location -LiteralPath $root
function Quote-Argument([string]$Value) { '"' + $Value.Replace('"','\"') + '"' }
function Get-LocalServer {
    if (Test-Path -LiteralPath $pidFile) {
        $serverProcessId = [int](Get-Content -LiteralPath $pidFile)
        $serverProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $serverProcessId" -ErrorAction SilentlyContinue
        if ($serverProcess -and $serverProcess.ExecutablePath -eq $engine -and $serverProcess.CommandLine.Contains('--server') -and $serverProcess.CommandLine.Contains($world)) {
            return $serverProcess
        }
    }
    return $null
}
if ($Mode -eq 'Stop') {
    $serverProcess = Get-LocalServer
    if ($serverProcess) {
        # Console-less Windows servers lack an interactive /shutdown console.
        # The stop request is consumed by our server mod, which flushes all DBs.
        Set-Content -LiteralPath (Join-Path $world 'frontline-stop-request') -Value 'stop' -Encoding ASCII
        Write-Host 'Shutdown requested. The server will save and stop within one second.'
    } else { Write-Host 'This project has no running background server.' }
    exit 0
}
if (-not (Test-Path -LiteralPath $engine)) {
    & python (Join-Path $PSScriptRoot 'bootstrap.py')
    if ($LASTEXITCODE -ne 0) { throw 'Dependency setup failed.' }
}
& (Join-Path $PSScriptRoot 'prepare.ps1')
if ($Mode -eq 'Server') {
    if (Get-LocalServer) { throw 'The background server is already running. Use Stop-Server.cmd before opening a console server.' }
    if (Get-NetUDPEndpoint -LocalPort 30000 -ErrorAction SilentlyContinue) { throw 'UDP 30000 is already in use.' }
    $staleStopRequest = Join-Path $world 'frontline-stop-request'
    if (Test-Path -LiteralPath $staleStopRequest) { Remove-Item -LiteralPath $staleStopRequest }
    Write-Host 'Frontline server: UDP 30000. Ctrl+C saves and stops.'
    & $engine --server --world $world --config (Join-Path $root 'config\server.conf') --logfile (Join-Path $root 'logs\server.log')
    exit $LASTEXITCODE
}
if ($Mode -in @('Play','Player2')) {
    if (-not (Get-LocalServer)) {
        $occupied = Get-NetUDPEndpoint -LocalPort 30000 -ErrorAction SilentlyContinue
        if ($occupied) { throw 'UDP 30000 is already in use. If Start-Server.cmd is running, use Join-Game.cmd with 127.0.0.1.' }
        $stopRequest = Join-Path $world 'frontline-stop-request'
        if (Test-Path -LiteralPath $stopRequest) { Remove-Item -LiteralPath $stopRequest }
        $serverArguments = @('--server','--world',(Quote-Argument $world),'--config',(Quote-Argument (Join-Path $root 'config\server.conf')),'--logfile',(Quote-Argument (Join-Path $root 'logs\server.log')))
        $serverProcess = Start-Process -FilePath $engine -ArgumentList $serverArguments -WindowStyle Hidden -PassThru
        Set-Content -LiteralPath $pidFile -Value $serverProcess.Id -Encoding ASCII
        Write-Host 'Starting local server...'
        $serverReady = $false
        for ($attempt = 0; $attempt -lt 120; $attempt++) {
            if ($serverProcess.HasExited) { throw 'Server exited. See logs\server.log.' }
            if (Get-NetUDPEndpoint -LocalPort 30000 -ErrorAction SilentlyContinue) { $serverReady = $true; break }
            Start-Sleep -Milliseconds 250
        }
        if (-not $serverReady) { throw 'Server startup timed out. See logs\server.log.' }
    }
    $Address = '127.0.0.1'
    if (-not $PlayerName) { $PlayerName = if ($Mode -eq 'Player2') { 'Player2' } else { 'Player1' } }
} else {
    if (-not $Address) { $Address = Read-Host 'Server IP (for example 192.168.1.10)' }
    if (-not $Address) { $Address = '127.0.0.1' }
    if (-not $PlayerName) { $PlayerName = 'Player' }
}
if ($PlayerName -notmatch '^[A-Za-z0-9_-]{1,20}$') { throw 'Player name must contain 1-20 letters, digits, _ or -.' }
if ($Address -match '[\r\n]') { throw 'Invalid address.' }
$clientConfig = Join-Path $root "config\client-$PlayerName.conf"
if (-not (Test-Path -LiteralPath $clientConfig)) { Copy-Item -LiteralPath (Join-Path $root 'config\client.conf') -Destination $clientConfig }
$texturePath = Join-Path $root 'assets\frontline_realism'
$configText = Get-Content -LiteralPath $clientConfig | Where-Object { $_ -notmatch '^(address|remote_port|name|texture_path|enable_dynamic_shadows|enable_volumetric_lighting|shadow_map_texture_size)\s*=' }
$shadows = if ($Quality -eq 'performance') { 'false' } else { 'true' }
$volumetric = if ($Quality -eq 'high') { 'true' } else { 'false' }
$shadowSize = if ($Quality -eq 'high') { 4096 } else { 2048 }
$updatedConfig = @($configText; "address = $Address"; 'remote_port = 30000'; "name = $PlayerName"; "texture_path = $texturePath"; "enable_dynamic_shadows = $shadows"; "enable_volumetric_lighting = $volumetric"; "shadow_map_texture_size = $shadowSize") -join "`n"
[IO.File]::WriteAllText($clientConfig,$updatedConfig,(New-Object Text.UTF8Encoding($false)))
$clientArguments = @('--config',(Quote-Argument $clientConfig),'--address',(Quote-Argument $Address),'--port','30000','--name',(Quote-Argument $PlayerName),'--logfile',(Quote-Argument (Join-Path $root "logs\client-$PlayerName.log")))
if ($Mode -in @('Play','Player2')) {
    $credential = Join-Path $root "config\client-$PlayerName.password"
    if (-not (Test-Path -LiteralPath $credential)) { [IO.File]::WriteAllText($credential,[Guid]::NewGuid().ToString('N')) }
    $clientArguments += @('--go','--password-file',(Quote-Argument $credential))
}
# A visible window is intentional here: this is the game the user launched.
Start-Process -FilePath $engine -ArgumentList $clientArguments -WorkingDirectory $root | Out-Null
