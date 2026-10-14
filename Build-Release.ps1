$ErrorActionPreference='Stop'
$package=Join-Path $PSScriptRoot 'gsx-jetway-bell'
$gauge=Join-Path $package 'html_ui\Pages\VCockpit\Instruments\GSXJetwayBell'
New-Item -ItemType Directory -Path $gauge -Force | Out-Null
foreach($name in @('GSXTransport.js','BellState.js','JetwayBell.js','JetwayBell.html')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $gauge -Force}
$modules=Join-Path $package 'modules'
$sound=Join-Path $package 'SimObjects\Airplanes\prosim-b738-2026\sound'
New-Item -ItemType Directory -Path $modules,$sound -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'JetwayDistance.wasm') -Destination $modules -Force
foreach($name in @('GSX_Jetway_Bell.wav','GSX_Jetway_Bell_Cabin.wav','GSX_Jetway_Bell_Open.wav')) {Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $sound -Force}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'package-manifest.json') -Destination (Join-Path $package 'manifest.json') -Force
$parts=@('GSXTransport.js','BellState.js','JetwayBell.js') | ForEach-Object {[IO.File]::ReadAllText((Join-Path $gauge $_))}
[IO.File]::WriteAllText((Join-Path $gauge 'JetwayBellRuntime.js'),($parts -join "`r`n"),(New-Object Text.UTF8Encoding($false)))
$manifestPath=Join-Path $package 'manifest.json'
$manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$manifest.package_version='1.2.4'
[IO.File]::WriteAllText($manifestPath,($manifest | ConvertTo-Json -Depth 20),(New-Object Text.UTF8Encoding($false)))
$entries=@(Get-ChildItem -LiteralPath $package -Recurse -File | Where-Object Name -ne 'layout.json' | ForEach-Object {[pscustomobject]@{path=$_.FullName.Substring($package.Length+1).Replace('\','/');size=$_.Length;date=$_.LastWriteTimeUtc.ToFileTimeUtc()}})
[IO.File]::WriteAllText((Join-Path $package 'layout.json'),(@{content=$entries} | ConvertTo-Json -Depth 20),(New-Object Text.UTF8Encoding($false)))
$dist=Join-Path $PSScriptRoot 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null
$inputs=@($package,(Join-Path $PSScriptRoot 'Setup.ps1'),(Join-Path $PSScriptRoot 'Install.ps1'),(Join-Path $PSScriptRoot 'XmlIO.ps1'),(Join-Path $PSScriptRoot 'INSTALLATION.txt'),(Join-Path $PSScriptRoot 'README.txt'))
$zip=Join-Path $dist 'Jetway-Bell-For-ProSim737-on-MSFS-2024-with-GSX-1.2.4.zip'
Compress-Archive -LiteralPath $inputs -DestinationPath $zip -Force
[IO.File]::WriteAllText((Join-Path $dist 'SHA256SUMS.txt'),((Get-FileHash -LiteralPath $zip).Hash+'  '+(Split-Path $zip -Leaf)))
Get-Item -LiteralPath $zip