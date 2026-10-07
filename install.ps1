param(
    [string]$GameDirectory = 'C:\Program Files (x86)\Steam\steamapps\common\Grand Theft Auto V'
)

$ErrorActionPreference = 'Stop'

try {
    if (-not (Test-Path -LiteralPath $GameDirectory -PathType Container)) {
        throw "GTA V folder not found: $GameDirectory. Pass the folder containing GTA5.exe with -GameDirectory."
    }

    $resolvedGameDirectory = (Resolve-Path -LiteralPath $GameDirectory).Path
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
        throw ("Required files are missing from the GTA V folder: {0}. Install a Script Hook V build compatible with your GTA version and ScriptHookVDotNet v3 nightly.89 or later, then retry." -f ($missingFiles -join ', '))
    }

    $sourceScript = Join-Path $PSScriptRoot 'scripts\GTA-NG.3.cs'
    if (-not (Test-Path -LiteralPath $sourceScript -PathType Leaf)) {
        throw "Mod source not found: $sourceScript. Keep install.ps1 beside the repository's scripts folder; download the repository branch as a ZIP or clone it."
    }

    $targetDirectory = Join-Path $resolvedGameDirectory 'scripts'
    New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null

    $targetScript = Join-Path $targetDirectory 'GTA-NG.3.cs'
    Copy-Item -LiteralPath $sourceScript -Destination $targetScript -Force

    Write-Host "Installed GTA-NG script to: $targetScript" -ForegroundColor Green
    Write-Host 'Launch GTA V Story Mode to load it. Do not launch GTA Online with Script Hook mods installed.'
}
catch {
    Write-Host ''
    Write-Host 'GTA-NG installation did not complete:' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ''
    Write-Host 'Check the missing file/path above. If the GTA folder is under Program Files, run PowerShell as Administrator.'
    Write-Host 'If PowerShell says script execution is disabled, run: Set-ExecutionPolicy -Scope Process Bypass'
    [void](Read-Host 'Press Enter to close this window')
    return
}

[void](Read-Host 'Press Enter to close this window')
