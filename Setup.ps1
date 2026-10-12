param([string]$CommunityRoot)
$ErrorActionPreference='Stop'
try {
 if (-not $CommunityRoot) {
  $candidates=@()
  foreach ($cfg in @((Join-Path $env:APPDATA 'Microsoft Flight Simulator 2024\UserCfg.opt'),(Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.Limitless_8wekyb3d8bbwe\LocalCache\UserCfg.opt'))) {
   if (Test-Path -LiteralPath $cfg) {
    $match=[regex]::Match([IO.File]::ReadAllText($cfg),'(?m)^InstalledPackagesPath\s+"([^"]+)"')
    if($match.Success) { $candidates+=Join-Path $match.Groups[1].Value 'Community' }
   }
  }
  $candidates+=Join-Path $env:APPDATA 'Microsoft Flight Simulator 2024\Packages\Community'
  $found=@($candidates | Select-Object -Unique | Where-Object { Test-Path -LiteralPath (Join-Path $_ 'prosim-b738\SimObjects\Airplanes\prosim-b738-2026\panel\panel.cfg') })
  if ($found.Count -eq 1) { $CommunityRoot=$found[0] }
  else {
   Write-Host 'Enter the MSFS 2024 Community folder containing prosim-b738.'
   $CommunityRoot=(Read-Host 'Community folder').Trim().Trim('"')
  }
 }
 if (-not (Test-Path -LiteralPath $CommunityRoot -PathType Container)) {throw 'Community folder does not exist.'}
 $CommunityRoot=(Resolve-Path -LiteralPath $CommunityRoot).Path
 Write-Host "Installing to: $CommunityRoot"
 & (Join-Path $PSScriptRoot 'Install.ps1') -CommunityRoot $CommunityRoot
 Write-Host 'Installation complete. Restart MSFS.'
} catch {
 Write-Host ('Installation failed: '+$_.Exception.Message) -ForegroundColor Red
 throw
}