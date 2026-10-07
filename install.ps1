param(
    [string]$GameDirectory = 'C:\Program Files (x86)\Steam\steamapps\common\Grand Theft Auto V'
)

$ErrorActionPreference = 'Stop'
$scriptHookVUrl = 'https://www.dev-c.com/files/ScriptHookV_3889.0_1158.13.zip'
$scriptHookVSupportedBuild = '1.0.3889.0'
$shvdnUrl = 'https://github.com/scripthookvdotnet/scripthookvdotnet-nightly/releases/download/v3.7.0-nightly.191/ScriptHookVDotNet-v3.7.0-nightly.191.zip'
$shvdnSha256 = 'a3e07afdfb6714a9e39d807791d757c0af6ff07b547d521e1991f0057001a2f6'

function Write-Stage([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

try {
    if (-not (Test-Path -LiteralPath $GameDirectory -PathType Container)) {
        throw "GTA V folder not found: $GameDirectory. Pass the folder containing GTA5.exe with -GameDirectory."
    }

    $resolvedGameDirectory = (Resolve-Path -LiteralPath $GameDirectory).Path
    $gameExe = Join-Path $resolvedGameDirectory 'GTA5.exe'
    if (-not (Test-Path -LiteralPath $gameExe -PathType Leaf)) {
        throw "GTA5.exe was not found in $resolvedGameDirectory."
    }

    $sourceScript = Join-Path $PSScriptRoot 'scripts\GTA-NG.3.cs'
    if (-not (Test-Path -LiteralPath $sourceScript -PathType Leaf)) {
        throw "Mod source not found: $sourceScript. Keep this installer beside the repository's scripts folder."
    }

    if (-not (Test-Path -LiteralPath (Join-Path $resolvedGameDirectory 'dinput8.dll') -PathType Leaf)) {
        throw "No dinput8.dll ASI loader was found in $resolvedGameDirectory. Use the ASI loader supplied by your game platform (Melty uses Ultimate ASI Loader), then run this installer again."
    }

    $gameVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($gameExe).ProductVersion
    if ($gameVersion -notmatch [regex]::Escape($scriptHookVSupportedBuild)) {
        throw "This installer is pinned to Script Hook V for GTA V build $scriptHookVSupportedBuild, but your GTA5.exe reports '$gameVersion'. It stopped without installing anything. Check the official Script Hook V page for a matching build: https://www.dev-c.com/gtav/scripthookv/"
    }

    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Stage 'Requesting Windows permission to copy files into the GTA V folder'
        $argumentList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $PSCommandPath), '-GameDirectory', ('"{0}"' -f $resolvedGameDirectory))
        $process = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argumentList -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            throw "The elevated installer ended with exit code $($process.ExitCode)."
        }
        return
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $tempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('GTA-NG-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempDirectory | Out-Null

    try {
        $shvZip = Join-Path $tempDirectory 'ScriptHookV.zip'
        $shvdnZip = Join-Path $tempDirectory 'ScriptHookVDotNet.zip'
        $shvExtract = Join-Path $tempDirectory 'ScriptHookV'
        $shvdnExtract = Join-Path $tempDirectory 'ScriptHookVDotNet'

        Write-Stage 'Downloading Script Hook V from its official site'
        Invoke-WebRequest -Uri $scriptHookVUrl -OutFile $shvZip -UseBasicParsing
        Write-Stage 'Downloading ScriptHookVDotNet from its official GitHub nightly release'
        Invoke-WebRequest -Uri $shvdnUrl -OutFile $shvdnZip -UseBasicParsing

        $actualHash = (Get-FileHash -LiteralPath $shvdnZip -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $shvdnSha256) {
            throw "ScriptHookVDotNet download failed its SHA-256 check. Expected $shvdnSha256 but received $actualHash. Nothing from that archive will be installed."
        }

        Write-Stage 'Checking the downloaded archives'
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($shvZip, $shvExtract)
        [System.IO.Compression.ZipFile]::ExtractToDirectory($shvdnZip, $shvdnExtract)

        $shvDll = Get-ChildItem -LiteralPath $shvExtract -Filter 'ScriptHookV.dll' -File -Recurse | Select-Object -First 1
        if ($null -eq $shvDll) {
            throw 'The official Script Hook V archive did not contain ScriptHookV.dll.'
        }

        $shvdnFiles = @('ScriptHookVDotNet.asi', 'ScriptHookVDotNet2.dll', 'ScriptHookVDotNet3.dll')
        $resolvedShvdnFiles = @{}
        foreach ($name in $shvdnFiles) {
            $match = Get-ChildItem -LiteralPath $shvdnExtract -Filter $name -File -Recurse | Select-Object -First 1
            if ($null -eq $match) {
                throw "The official ScriptHookVDotNet archive did not contain $name."
            }
            $resolvedShvdnFiles[$name] = $match.FullName
        }

        Write-Stage 'Installing only the runtime files required by GTA-NG'
        Copy-Item -LiteralPath $shvDll.FullName -Destination (Join-Path $resolvedGameDirectory 'ScriptHookV.dll') -Force
        foreach ($name in $shvdnFiles) {
            Copy-Item -LiteralPath $resolvedShvdnFiles[$name] -Destination (Join-Path $resolvedGameDirectory $name) -Force
        }

        # The existing ASI loader is left alone. In Melty, that is Ultimate ASI Loader.
        $scriptsDirectory = Join-Path $resolvedGameDirectory 'scripts'
        New-Item -ItemType Directory -Path $scriptsDirectory -Force | Out-Null
        Copy-Item -LiteralPath $sourceScript -Destination (Join-Path $scriptsDirectory 'GTA-NG.3.cs') -Force

        Write-Host "`nInstalled GTA-NG and its runtime files to $resolvedGameDirectory" -ForegroundColor Green
        Write-Host 'Launch GTA V Story Mode only. This installer does not install or replace an ASI loader.'
        Write-Host 'This standalone installer downloads third-party runtimes at install time; it does not make the package Melty one-click compatible.'
    }
    finally {
        if (Test-Path -LiteralPath $tempDirectory) {
            Remove-Item -LiteralPath $tempDirectory -Recurse -Force
        }
    }
}
catch {
    Write-Host ''
    Write-Host 'GTA-NG installation did not complete:' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ''
    Write-Host 'Check the GTA folder and Internet connection. For GTA build support, see https://www.dev-c.com/gtav/scripthookv/'
    [void](Read-Host 'Press Enter to close this window')
    exit 1
}

[void](Read-Host 'Press Enter to close this window')

