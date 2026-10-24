param([ValidateSet('all','client','server')][string]$Mode = 'all')
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$projectRoot = Split-Path -Parent $PSScriptRoot
$lock = Get-Content -LiteralPath (Join-Path $projectRoot 'downloads.lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$cacheRoot = Join-Path $projectRoot '.cache'
$javaRoot = Join-Path $projectRoot 'runtime\java17'
$clientRoot = Join-Path $projectRoot 'client'
$serverRoot = Join-Path $projectRoot 'server'
foreach ($directory in @($cacheRoot,$clientRoot,$serverRoot)) { [IO.Directory]::CreateDirectory($directory) | Out-Null }

function Get-VerifiedDownload([string]$Url,[string]$Path,[string]$Expected,[string]$Algorithm = 'SHA512') {
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "Downloading $([IO.Path]::GetFileName($Path))"
        $temporaryPath = $Path + '.download'
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $temporaryPath -Headers @{ 'User-Agent'='Frontline-Operations-Setup/1.0' }
        if ($Expected -and (Get-FileHash -LiteralPath $temporaryPath -Algorithm $Algorithm).Hash -ne $Expected) { throw "Download integrity failure: $Path" }
        Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
    }
    if ($Expected -and (Get-FileHash -LiteralPath $Path -Algorithm $Algorithm).Hash -ne $Expected) { throw "Cached file integrity failure: $Path" }
}

if (-not (Test-Path -LiteralPath (Join-Path $javaRoot 'bin\java.exe'))) {
    $javaArchive = Join-Path $cacheRoot $lock.java.filename
    Get-VerifiedDownload $lock.java.url $javaArchive $lock.java.sha256 'SHA256'
    $extractRoot = Join-Path $projectRoot 'runtime\java17-extract'
    Expand-Archive -LiteralPath $javaArchive -DestinationPath $extractRoot -Force
    $jdkDirectory = Get-ChildItem -LiteralPath $extractRoot -Directory | Select-Object -First 1
    [IO.Directory]::CreateDirectory($javaRoot) | Out-Null
    Get-ChildItem -LiteralPath $jdkDirectory.FullName -Force | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $javaRoot -Recurse -Force }
}
$java = Join-Path $javaRoot 'bin\java.exe'
$installerName = "forge-1.20.1-$($lock.forge)-installer.jar"
$installer = Join-Path $cacheRoot $installerName
Get-VerifiedDownload "https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.1-$($lock.forge)/$installerName" $installer $lock.forge_installer.sha256 'SHA256'

foreach ($mod in $lock.mods) {
    if ($Mode -eq 'server' -and $mod.side -ne 'both') { continue }
    $archive = Join-Path $cacheRoot $mod.filename
    Get-VerifiedDownload $mod.url $archive $mod.hashes.sha512
    if ($Mode -ne 'client' -and $mod.side -eq 'both') {
        [IO.Directory]::CreateDirectory((Join-Path $serverRoot 'mods')) | Out-Null
        Copy-Item -LiteralPath $archive -Destination (Join-Path $serverRoot "mods\$($mod.filename)") -Force
    }
    if ($Mode -ne 'server') {
        $folder = switch ($mod.side) { 'shader' { 'shaderpacks' } 'resourcepack' { 'resourcepacks' } default { 'mods' } }
        $destination = Join-Path $clientRoot $folder
        [IO.Directory]::CreateDirectory($destination) | Out-Null
        Copy-Item -LiteralPath $archive -Destination (Join-Path $destination $mod.filename) -Force
    }
}
$ownJar = Join-Path $projectRoot 'addon\frontline-operations-1.20.1-1.0.0.jar'
if (-not (Test-Path -LiteralPath $ownJar)) { throw 'Frontline addon JAR is missing from this installer package.' }
if ($Mode -ne 'client') {
    Copy-Item -LiteralPath $ownJar -Destination (Join-Path $serverRoot 'mods') -Force
    if (-not (Test-Path -LiteralPath (Join-Path $serverRoot "libraries\net\minecraftforge\forge\1.20.1-$($lock.forge)\win_args.txt"))) {
        & $java -jar $installer --installServer $serverRoot
        if ($LASTEXITCODE -ne 0) { throw 'Forge server installation failed.' }
    }
    foreach ($file in @('server.properties','eula.txt')) {
        $destination = Join-Path $serverRoot $file
        if (-not (Test-Path -LiteralPath $destination)) { Copy-Item -LiteralPath (Join-Path $projectRoot "templates\$file") -Destination $destination }
    }
    [IO.Directory]::CreateDirectory((Join-Path $serverRoot 'config')) | Out-Null
    $npcConfig = Join-Path $serverRoot 'config\tacz_npc-common.toml'
    if (-not (Test-Path -LiteralPath $npcConfig)) { Copy-Item -LiteralPath (Join-Path $projectRoot 'templates\tacz_npc-common.toml') -Destination $npcConfig }
}
if ($Mode -ne 'server') {
    Copy-Item -LiteralPath $ownJar -Destination (Join-Path $clientRoot 'mods') -Force
    $minecraftRoot = Join-Path $env:APPDATA '.minecraft'
    $profilePath = Join-Path $minecraftRoot 'launcher_profiles.json'
    if (-not (Test-Path -LiteralPath $profilePath)) { throw 'Open the official Minecraft Launcher once, then run this installer again.' }
    $backupPath = Join-Path $minecraftRoot "launcher_profiles.frontline-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    Copy-Item -LiteralPath $profilePath -Destination $backupPath
    $versionRoot = Join-Path $minecraftRoot 'versions\1.20.1'
    [IO.Directory]::CreateDirectory($versionRoot) | Out-Null
    $manifest = Invoke-RestMethod -Uri 'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json'
    $version = $manifest.versions | Where-Object id -EQ '1.20.1' | Select-Object -First 1
    $versionJson = Join-Path $versionRoot '1.20.1.json'
    Get-VerifiedDownload $version.url $versionJson $version.sha1 'SHA1'
    $metadata = Get-Content -LiteralPath $versionJson -Raw -Encoding UTF8 | ConvertFrom-Json
    Get-VerifiedDownload $metadata.downloads.client.url (Join-Path $versionRoot '1.20.1.jar') $metadata.downloads.client.sha1 'SHA1'
    & $java -jar $installer --installClient $minecraftRoot
    if ($LASTEXITCODE -ne 0) { throw 'Forge client installation failed.' }
    $profile = [ordered]@{ name='Frontline - TaCZ NPC Co-op'; type='custom'; created=[DateTime]::UtcNow.ToString('o'); lastUsed=[DateTime]::UtcNow.ToString('o');
        gameDir=$clientRoot; lastVersionId="1.20.1-forge-$($lock.forge)"; javaDir=(Join-Path $javaRoot 'bin\javaw.exe'); javaArgs='-Xms1G -Xmx5G -XX:+UseG1GC'; icon='Furnace' }
    $profiles = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $profiles.profiles | Add-Member -MemberType NoteProperty -Name 'frontline-tacz-native' -Value $profile -Force
    $profiles | Add-Member -MemberType NoteProperty -Name 'selectedProfile' -Value 'frontline-tacz-native' -Force
    [IO.File]::WriteAllText($profilePath,($profiles | ConvertTo-Json -Depth 40),(New-Object Text.UTF8Encoding($false)))
    [IO.Directory]::CreateDirectory((Join-Path $clientRoot 'config')) | Out-Null
    foreach ($file in @('options.txt','config\oculus.properties','config\tacz_npc-common.toml')) {
        $destination = Join-Path $clientRoot $file
        if (-not (Test-Path -LiteralPath $destination)) { Copy-Item -LiteralPath (Join-Path $projectRoot "templates\client\$file") -Destination $destination }
    }
    Get-ChildItem -LiteralPath (Join-Path $projectRoot 'templates\client\shaderpacks') -File | ForEach-Object {
        $destination = Join-Path $clientRoot "shaderpacks\$($_.Name)"
        if (-not (Test-Path -LiteralPath $destination)) { Copy-Item -LiteralPath $_.FullName -Destination $destination }
    }
    $serverList = Join-Path $clientRoot 'servers.dat'
    if (-not (Test-Path -LiteralPath $serverList)) {
        Copy-Item -LiteralPath (Join-Path $projectRoot 'templates\client\servers.dat') -Destination $serverList
    }
}
Write-Host 'Ready: choose Frontline - TaCZ NPC Co-op in the official Minecraft Launcher.'
