$ErrorActionPreference='Stop'
function Get-Process {param($Name,$ErrorAction) return $null}
$root=Join-Path $PSScriptRoot ('installer-check\sounds-'+[guid]::NewGuid().ToString('N'))
$testInstallRoot=Join-Path $root 'home';$community=Join-Path $root 'Community'
New-Item -ItemType Directory -Path $testInstallRoot -Force | Out-Null
foreach($file in @('Managed-Install.ps1','Apply-SoundSettings.ps1','Install.ps1','BellAudio.dll')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $testInstallRoot}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'gsx-jetway-bell') -Destination $testInstallRoot -Recurse
$aircraft=Join-Path $community 'prosim-b738';$panel=Join-Path $aircraft 'SimObjects\Airplanes\prosim-b738-2026\panel\panel.cfg';$sound=Join-Path $aircraft 'SimObjects\Airplanes\prosim-b738-2026\sound\sound.xml'
New-Item -ItemType Directory -Path (Split-Path $panel),(Split-Path $sound) -Force | Out-Null
Set-Content -LiteralPath $panel -Value "[VCockpit01]`r`nhtmlgauge00=Other/Gauge.html,0,0,1,1"
Set-Content -LiteralPath $sound -Value '<SoundInfo><SimVarSounds><Sound WwiseEvent="custom_sound_01" FileName="DoorSound" /></SimVarSounds></SoundInfo>'
@{content=@(@{path='SimObjects/Airplanes/prosim-b738-2026/panel/panel.cfg';size=0;date=0},@{path='SimObjects/Airplanes/prosim-b738-2026/sound/sound.xml';size=0;date=0})} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $aircraft 'layout.json')
$data=Join-Path $testInstallRoot 'UserData';New-Item -ItemType Directory -Path (Join-Path $data 'Sounds') -Force | Out-Null
$default='Sounds/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.wav';$airport='Sounds/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.wav'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'GSX_Jetway_Bell.wav') -Destination (Join-Path $data $default)
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'GSX_Jetway_Bell_Open.wav') -Destination (Join-Path $data $airport)
Set-Content -LiteralPath (Join-Path $data 'settings.xml') -Value "<SoundSettings><Default file='$default'/><Airport icao='KDAL' file='$airport'/></SoundSettings>"
$configHash=(Get-FileHash -LiteralPath (Join-Path $data 'settings.xml')).Hash
$wavHash=(Get-FileHash -LiteralPath (Join-Path $data $airport)).Hash
foreach($cycle in 1..2){
 & (Join-Path $testInstallRoot 'Managed-Install.ps1') -CommunityRoot $community -NoRegistration
 $doc=[xml](Get-Content -LiteralPath $sound -Raw)
 if($doc.SelectNodes('//Sound[starts-with(@FileName,"GSX_Jetway_Custom_KDAL_")]').Count -ne 3){throw 'Airport sound definitions missing or duplicated.'}
 if($doc.SelectSingleNode('//Sound[@WwiseEvent="custom_sound_12"]').LocalVar -ne 'GSX_JETWAY_BELL_DEFAULT_ACTIVE'){throw 'Default selection not wired.'}
 if((Get-Content -LiteralPath (Join-Path $data 'settings.xml') -Raw) -notmatch 'KDAL' -or (Get-FileHash -LiteralPath (Join-Path $data 'settings.xml')).Hash -ne $configHash){throw 'Settings not preserved.'}
}
& (Join-Path $testInstallRoot 'Managed-Install.ps1') -CommunityRoot $community -NoRegistration -Uninstall
if(Test-Path -LiteralPath (Join-Path $community 'gsx-jetway-bell')){throw 'Generated package left behind.'}
if((Get-FileHash -LiteralPath (Join-Path $data $airport)).Hash -ne $wavHash){throw 'Custom sound not preserved on uninstall.'}
$doc=[xml](Get-Content -LiteralPath $sound -Raw)
if($doc.SelectNodes('//Sound').Count -ne 1 -or $doc.SelectSingleNode('//Sound').FileName -ne 'DoorSound'){throw 'Unrelated aircraft sounds changed.'}
Write-Output 'PASS: custom default, airport variants, repeated upgrade, settings/WAV preservation, generated-audio uninstall and unrelated door sound preservation.'
# Invalid WAV input must be rejected.
Set-Content -LiteralPath (Join-Path $root 'invalid.wav') -Value 'not audio'
$rejected=$false;try{[BellAudio]::Validate((Join-Path $root 'invalid.wav'))}catch{$rejected=$true};if(-not $rejected){throw 'Invalid audio accepted.'}
Write-Output 'PASS: unsupported audio rejected.'
