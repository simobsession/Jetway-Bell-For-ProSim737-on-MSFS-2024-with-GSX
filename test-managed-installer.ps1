$ErrorActionPreference='Stop'
# Fixture tests never touch the live simulator or Windows uninstall registration.
function Get-Process {param($Name,$ErrorAction) return $null}
$root=Join-Path $PSScriptRoot 'installer-check\managed-tests'
$community=Join-Path $root 'Community'
$aircraft=Join-Path $community 'prosim-b738'
$panel=Join-Path $aircraft 'SimObjects\Airplanes\prosim-b738-2026\panel\panel.cfg'
$sound=Join-Path $aircraft 'SimObjects\Airplanes\prosim-b738-2026\sound\sound.xml'
New-Item -ItemType Directory -Path (Split-Path $panel),(Split-Path $sound) -Force | Out-Null
[IO.File]::WriteAllText($panel,"[VCockpit01]`r`nsize_mm=1024,768`r`nhtmlgauge00=Other/Gauge.html,0,0,10,10`r`n")
[IO.File]::WriteAllText($sound,'<SoundInfo><SimVarSounds><Sound WwiseEvent="custom_sound_01" FileName="MyDoor" LocalVar="MY_DOOR" /></SimVarSounds></SoundInfo>')
$layout=@{content=@(@{path='SimObjects/Airplanes/prosim-b738-2026/panel/panel.cfg';size=(Get-Item $panel).Length;date=0},@{path='SimObjects/Airplanes/prosim-b738-2026/sound/sound.xml';size=(Get-Item $sound).Length;date=0},@{path='unrelated.dat';size=123;date=0})}
$layout | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $aircraft 'layout.json')
& (Join-Path $PSScriptRoot 'Managed-Install.ps1') -CommunityRoot $community -NoRegistration
Start-Sleep -Milliseconds 1100
& (Join-Path $PSScriptRoot 'Managed-Install.ps1') -CommunityRoot $community -NoRegistration
# User changes made after installation must survive uninstall.
Add-Content -LiteralPath $panel -Value "`r`n[UserSection]`r`nvalue=keep"
& (Join-Path $PSScriptRoot 'Managed-Install.ps1') -CommunityRoot $community -NoRegistration -Uninstall
$panelText=Get-Content -LiteralPath $panel -Raw
if($panelText -match 'GSXJetwayBell|\[VCockpit02\]'){throw 'Bell gauge section left behind.'}
if($panelText -notmatch 'Other/Gauge.html' -or $panelText -notmatch 'value=keep'){throw 'Unrelated panel settings lost.'}
$doc=[xml](Get-Content -LiteralPath $sound -Raw)
if($doc.SelectNodes('//Sound').Count -ne 1 -or $doc.SelectSingleNode('//Sound').FileName -ne 'MyDoor'){throw 'Unrelated door sounds lost.'}
if(Test-Path -LiteralPath (Join-Path $community 'gsx-jetway-bell')){throw 'Bell package left behind.'}
& (Join-Path $PSScriptRoot 'Managed-Install.ps1') -CommunityRoot $community -NoRegistration -Uninstall
Write-Output 'PASS: fresh installation, repeated upgrade, targeted uninstall, repeat uninstall, preservation of later user settings and unrelated door sounds.'
& (Join-Path $PSScriptRoot 'Managed-Install.ps1') -CommunityRoot $community -NoRegistration
$sentinel=Join-Path $community 'gsx-jetway-bell\unrelated.txt';Set-Content -LiteralPath $sentinel -Value 'Keep me'
$before=(Get-FileHash -LiteralPath $panel).Hash
$rejected=$false
try{& (Join-Path $PSScriptRoot 'Managed-Install.ps1') -CommunityRoot $community -NoRegistration -Uninstall}catch{$rejected=$true}
if(-not $rejected -or -not(Test-Path -LiteralPath $sentinel) -or (Get-FileHash -LiteralPath $panel).Hash -ne $before){throw 'Unknown file safety check failed.'}
Write-Output 'PASS: unknown package files prevent removal and preserve aircraft configuration.'
