param([ValidateSet('Play','Server','Join','Stop')][string]$Mode = 'Play')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$serverRoot = Join-Path $projectRoot 'server'
$java = Join-Path $projectRoot 'runtime\java17\bin\java.exe'
$pidPath = Join-Path $serverRoot 'frontline.pid'
$lock = Get-Content -LiteralPath (Join-Path $projectRoot 'downloads.lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
function Quote-Arg([string]$Value) { '"' + $Value.Replace('"','\"') + '"' }
function Get-OwnedServer {
    if (Test-Path -LiteralPath $pidPath) {
        $serverProcessId = [int](Get-Content -LiteralPath $pidPath)
        $process = Get-CimInstance Win32_Process -Filter "ProcessId = $serverProcessId" -ErrorAction SilentlyContinue
        if ($process -and $process.ExecutablePath -eq $java -and $process.CommandLine.Contains("-Dfrontline.root=$serverRoot")) { return $process }
    }
    return $null
}
if ($Mode -eq 'Stop') {
    if (Get-OwnedServer) {
        [IO.File]::WriteAllText((Join-Path $serverRoot 'frontline-stop-request'),'stop')
        Write-Host 'Server will save and stop within one second.'
    } else { Write-Host 'No server started by this project is running.' }
    exit 0
}
if (-not (Test-Path -LiteralPath $java)) { throw 'Run Setup.cmd first.' }
if ($Mode -ne 'Join') {
    $argsFile = "libraries/net/minecraftforge/forge/1.20.1-$($lock.forge)/win_args.txt"
    if (-not (Test-Path -LiteralPath (Join-Path $serverRoot $argsFile))) { throw 'Run Setup.cmd first.' }
    if (-not (Get-OwnedServer)) {
        if (Get-NetTCPConnection -LocalPort 25565 -State Listen -ErrorAction SilentlyContinue) { throw 'TCP 25565 is in use by another server.' }
        $eulaPath = Join-Path $serverRoot 'eula.txt'
        $accepted = (Test-Path -LiteralPath $eulaPath) -and ((Get-Content -LiteralPath $eulaPath -Raw) -match '(?m)^\s*eula\s*=\s*true\s*$')
        if (-not $accepted) {
            Write-Host 'Minecraft server requires acceptance of the official EULA: https://www.minecraft.net/eula'
            $agreement = Read-Host 'If you accept the EULA, type YES; otherwise press Enter to cancel'
            if ($agreement -cne 'YES') { throw 'Server not started: EULA was not accepted.' }
            [IO.File]::WriteAllText($eulaPath,"# Accepted by the user $(Get-Date -Format 'yyyy-MM-dd')`neula=true`n")
        }
        $stopRequest = Join-Path $serverRoot 'frontline-stop-request'
        if (Test-Path -LiteralPath $stopRequest) { Remove-Item -LiteralPath $stopRequest }
        $arguments = @('-Xms1G','-Xmx4G',(Quote-Arg "-Dfrontline.root=$serverRoot"),(Quote-Arg "@$argsFile"),'nogui')
        if ($Mode -eq 'Server') {
            Write-Host 'Minecraft Java server: TCP 25565. Stop-Server.cmd saves and stops it.'
            $process = Start-Process -FilePath $java -ArgumentList $arguments -WorkingDirectory $serverRoot -NoNewWindow -PassThru
        } else {
            $process = Start-Process -FilePath $java -ArgumentList $arguments -WorkingDirectory $serverRoot -WindowStyle Hidden -PassThru
        }
        [IO.File]::WriteAllText($pidPath,[string]$process.Id)
        Write-Host 'Starting native Minecraft Forge server. First world generation may take a few minutes.'
        for ($attempt=0; $attempt -lt 300; $attempt++) {
            if ($process.HasExited) { throw 'Server exited; see server\logs\latest.log.' }
            if (Get-NetTCPConnection -LocalPort 25565 -State Listen -ErrorAction SilentlyContinue) { break }
            Start-Sleep -Milliseconds 500
        }
        if (-not (Get-NetTCPConnection -LocalPort 25565 -State Listen -ErrorAction SilentlyContinue)) {
            throw 'Server is still starting; see server\logs\latest.log, then run this shortcut again.'
        }
        if ($Mode -eq 'Server') { $process.WaitForExit(); exit $process.ExitCode }
    }
}
if ($Mode -eq 'Join') {
    Write-Host 'Use your own Minecraft Java account. In Multiplayer / Direct Connection, enter the host IP followed by :25565.'
} else { Write-Host 'In Minecraft Multiplayer / Direct Connection, enter 127.0.0.1:25565.' }
if ($Mode -ne 'Join') {
    Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.IPAddress -notlike '169.254.*' -and $_.AddressState -eq 'Preferred' } |
        ForEach-Object { Write-Host "LAN friend connection: $($_.IPAddress):25565" }
}
Write-Host 'Choose Frontline - TaCZ NPC Co-op in the official Minecraft Launcher, then Play.'
$launcher = Get-StartApps | Where-Object { $_.AppID -like 'Microsoft.4297127D64EC6*' } | Select-Object -First 1
if ($launcher) {
    Start-Process explorer.exe -ArgumentList "shell:AppsFolder\$($launcher.AppID)" | Out-Null
} else {
    $classicLauncher = 'C:\Program Files (x86)\Minecraft Launcher\MinecraftLauncher.exe'
    if (Test-Path -LiteralPath $classicLauncher) { Start-Process -FilePath $classicLauncher | Out-Null }
    else { Write-Host 'Open the official Minecraft Launcher from the Start menu.' }
}
