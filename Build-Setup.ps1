$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'Build-Release.ps1')
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $csc /nologo /target:library /optimize+ "/out:$PSScriptRoot\BellAudio.dll" "$PSScriptRoot\BellAudio.cs"
if($LASTEXITCODE -ne 0){throw 'Audio helper compilation failed.'}
$payload=Join-Path $PSScriptRoot 'dist\setup-payload.zip'
Compress-Archive -LiteralPath @((Join-Path $PSScriptRoot 'gsx-jetway-bell'),(Join-Path $PSScriptRoot 'Install.ps1'),(Join-Path $PSScriptRoot 'Managed-Install.ps1'),(Join-Path $PSScriptRoot 'Apply-SoundSettings.ps1'),(Join-Path $PSScriptRoot 'BellAudio.dll'),(Join-Path $PSScriptRoot 'README.txt'),(Join-Path $PSScriptRoot 'INSTALLATION.txt')) -DestinationPath $payload -Force
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $csc /nologo /target:winexe /optimize+ /reference:System.Xml.Linq.dll /reference:System.Core.dll /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll "/resource:$payload,payload.zip" "/out:$PSScriptRoot\dist\Setup.exe" "$PSScriptRoot\Setup.cs" "$PSScriptRoot\SoundSettings.cs" "$PSScriptRoot\BellAudio.cs"
if($LASTEXITCODE -ne 0){throw 'Setup.exe compilation failed.'}
Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'dist\Setup.exe') | Format-List Algorithm,Hash
