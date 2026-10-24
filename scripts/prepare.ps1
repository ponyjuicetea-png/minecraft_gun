param([string]$WorldPath = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $WorldPath) { $WorldPath = Join-Path $projectRoot 'worlds\frontline' }
$engineRoot = Join-Path $projectRoot 'runtime\luanti'
if (-not (Test-Path -LiteralPath (Join-Path $engineRoot 'bin\luanti.exe'))) { throw 'Run Setup.cmd first.' }
$modSource = Join-Path $projectRoot 'mods\frontline'
if (-not (Test-Path -LiteralPath (Join-Path $modSource 'textures\frontline_rifle_icon.png'))) { throw 'Bundled Frontline assets are missing.' }
New-Item -ItemType Directory -Force -Path $WorldPath | Out-Null
$metadata = Join-Path $WorldPath 'world.mt'
if (-not (Test-Path -LiteralPath $metadata)) {
    $worldSettings = "gameid = voxelibre`nbackend = sqlite3`nplayer_backend = sqlite3`nauth_backend = sqlite3`nmod_storage_backend = sqlite3`nload_mod_frontline = true`n"
    [IO.File]::WriteAllText($metadata, $worldSettings)
}
$worldMods = Join-Path $WorldPath 'worldmods'
New-Item -ItemType Directory -Force -Path $worldMods | Out-Null
Copy-Item -LiteralPath $modSource -Destination $worldMods -Recurse -Force
$textureDestination = Join-Path $engineRoot 'textures'
New-Item -ItemType Directory -Force -Path $textureDestination | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets\frontline_realism') -Destination $textureDestination -Recurse -Force
New-Item -ItemType Directory -Force -Path (Join-Path $projectRoot 'logs') | Out-Null
Write-Host "World ready: $WorldPath"
