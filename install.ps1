param(
    [string]$GameDirectory = 'C:\Program Files (x86)\Steam\steamapps\common\Grand Theft Auto V'
)

$ErrorActionPreference = 'Stop'
$resolvedGameDirectory = (Resolve-Path -LiteralPath $GameDirectory -ErrorAction Stop).Path
$requiredFiles = @(
    'GTA5.exe',
    'ScriptHookV.dll',
    'ScriptHookVDotNet.asi',
    'ScriptHookVDotNet3.dll'
)

$missingFiles = @(
    $requiredFiles | Where-Object {
        -not (Test-Path -LiteralPath (Join-Path $resolvedGameDirectory $_) -PathType Leaf)
    }
)

if ($missingFiles.Count -gt 0) {
    throw ("Missing required GTA V/script runtime files: {0}. Install a Script Hook V build compatible with your GTA version and ScriptHookVDotNet v3 nightly.89 or later, then run this installer again." -f ($missingFiles -join ', '))
}

$sourceScript = Join-Path $PSScriptRoot 'scripts\GTA-NG.3.cs'
if (-not (Test-Path -LiteralPath $sourceScript -PathType Leaf)) {
    throw "Could not find the mod script next to this installer: $sourceScript"
}

$targetDirectory = Join-Path $resolvedGameDirectory 'scripts'
New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null

$targetScript = Join-Path $targetDirectory 'GTA-NG.3.cs'
Copy-Item -LiteralPath $sourceScript -Destination $targetScript -Force

Write-Host "Installed GTA-NG script to: $targetScript"
Write-Host 'Launch GTA V Story Mode to load it. Do not launch GTA Online with Script Hook mods installed.'
