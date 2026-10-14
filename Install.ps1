param([string]$CommunityRoot = "$env:APPDATA\Microsoft Flight Simulator 2024\Packages\Community")
$ErrorActionPreference = 'Stop'
$sourceRoot = $PSScriptRoot
$aircraftRoot = Join-Path $CommunityRoot 'prosim-b738'
$panelRelative = 'SimObjects/Airplanes/prosim-b738-2026/panel/panel.cfg'
$soundRelative = 'SimObjects/Airplanes/prosim-b738-2026/sound/sound.xml'
$wavRelative = 'SimObjects/Airplanes/prosim-b738-2026/sound/GSX_Jetway_Bell.wav'
$panelPath = Join-Path $aircraftRoot $panelRelative
$soundPath = Join-Path $aircraftRoot $soundRelative
$wavPath = Join-Path $aircraftRoot $wavRelative
$cabinRelative = 'SimObjects/Airplanes/prosim-b738-2026/sound/GSX_Jetway_Bell_Cabin.wav'
$cabinPath = Join-Path $aircraftRoot $cabinRelative
$aircraftLayout = Join-Path $aircraftRoot 'layout.json'
foreach ($path in @($panelPath,$soundPath,$aircraftLayout)) { if (-not (Test-Path -LiteralPath $path)) { throw "Required ProSim file missing: $path" } }
$panelText = [IO.File]::ReadAllText($panelPath)
$soundDoc = New-Object System.Xml.XmlDocument
$soundDoc.PreserveWhitespace = $true
$soundDoc.Load($soundPath)
# Upgrade legacy personalized identifiers in memory; originals are backed up below.
$panelText=[regex]::Replace($panelText,'\b\w*GSXJetwayBell/JetwayBell\.html','GSXJetwayBell/JetwayBell.html')
foreach($node in @($soundDoc.SelectNodes('//Sound[contains(@FileName,"GSX_Jetway_Bell")]'))) {
 foreach($attribute in @('FileName','LocalVar')) {
  $value=$node.GetAttribute($attribute)
  $node.SetAttribute($attribute,([regex]::Replace($value,'^[^_]+_(GSX_)','$1')))
 }
 foreach($curve in @($node.SelectNodes('VolumeCurve'))) {
  $curve.SetAttribute('LocalVar',([regex]::Replace($curve.GetAttribute('LocalVar'),'^[^_]+_(GSX_)','$1')))
 }
}
$bellNode = $soundDoc.SelectSingleNode('//Sound[@WwiseEvent="custom_sound_12" and (@FileName="GSX_Jetway_Bell" or @FileName="GSX_Jetway_Bell_Cabin")]')
$outsideNode = $soundDoc.SelectSingleNode('//Sound[@WwiseEvent="custom_sound_11"]')
if ($outsideNode -and $outsideNode.GetAttribute('FileName') -notin @('GSX_Jetway_Bell','GSX_Jetway_Bell_Cabin')) { throw 'Sound slot custom_sound_11 is already used by another sound.' }
if ($null -eq $bellNode -and $soundDoc.SelectSingleNode('//Sound[@WwiseEvent="custom_sound_12"]')) { throw 'Sound slot custom_sound_12 is already used by another sound.' }
$openExisting=$soundDoc.SelectSingleNode('//Sound[@WwiseEvent="custom_sound_10"]')
if ($openExisting -and $openExisting.GetAttribute('FileName') -ne 'GSX_Jetway_Bell_Open') { throw 'Sound slot custom_sound_10 is already used by another sound.' }
$backupRoot = Join-Path $sourceRoot ('backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $backupRoot | Out-Null
foreach ($relative in @($panelRelative,$soundRelative,$wavRelative,$cabinRelative,'layout.json')) {
 $path=Join-Path $aircraftRoot $relative
 if(Test-Path -LiteralPath $path) { $saved=Join-Path (Join-Path $backupRoot 'prosim-b738') $relative; New-Item -ItemType Directory -Path (Split-Path -Parent $saved) -Force | Out-Null; Copy-Item -LiteralPath $path -Destination $saved }
}
$packageSource = Join-Path $sourceRoot 'gsx-jetway-bell'
$packageDestination = Join-Path $CommunityRoot 'gsx-jetway-bell'
foreach($file in Get-ChildItem -LiteralPath $packageSource -Recurse -File) {
 $relative=$file.FullName.Substring($packageSource.Length+1)
 $destination=Join-Path $packageDestination $relative
 New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
 Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
}
[IO.File]::WriteAllText($panelPath,$panelText,(New-Object Text.UTF8Encoding($false)))
if(-not $panelText.Contains('GSXJetwayBell/JetwayBell.html')) {
 $numbers=@([regex]::Matches($panelText,'(?im)^\[VCockpit(\d+)\]') | ForEach-Object { [int]$_.Groups[1].Value })
 $nextNumber=1
 if($numbers.Count -gt 0) { $nextNumber=($numbers | Measure-Object -Maximum).Maximum+1 }
 $sectionLabel = '{0:D2}' -f [int]$nextNumber
 $panelText += "`r`n; GSX bell: invisible manager, no external application.`r`n[VCockpit$sectionLabel]`r`nsize_mm=1,1`r`npixel_size=1,1`r`ntexture=NO_TEXTURE`r`nhtmlgauge00=GSXJetwayBell/JetwayBell.html,0,0,1,1`r`n"
 [IO.File]::WriteAllText($panelPath,$panelText,(New-Object Text.UTF8Encoding($false)))
}
if($null -eq $bellNode) {
 $container=$soundDoc.SelectSingleNode('/SoundInfo/SimVarSounds')
 if($null -eq $container) { throw 'ProSim SimVarSounds container missing.' }
 $bellNode=$soundDoc.CreateElement('Sound')
 $attributes=[ordered]@{WwiseData='false';WwiseEvent='custom_sound_12';FileName='GSX_Jetway_Bell';LocalVar='GSX_JETWAY_BELL_ACTIVE';Continuous='true';BreakOnStop='false';FadeOutType='0';ViewPoint='All';Panning='-5000';FullScaleDistance='0'}
 foreach($attribute in $attributes.GetEnumerator()) { $bellNode.SetAttribute($attribute.Key,$attribute.Value) }
 $range=$soundDoc.CreateElement('Range');$range.SetAttribute('LowerBound','1');$range.SetAttribute('UpperBound','1');$bellNode.AppendChild($range) | Out-Null
 $container.AppendChild($bellNode) | Out-Null
 $soundDoc.Save($soundPath)
}
# Upgrade our existing bell in place; retain the working operation trigger.
$bellNode.SetAttribute('FileName','GSX_Jetway_Bell_Cabin')
$bellNode.SetAttribute('ViewPoint','Inside')
$bellNode.SetAttribute('MuteOnVPChange','true')
if (-not $outsideNode) {
 $outsideNode=$bellNode.CloneNode($true)
 $outsideNode.SetAttribute('WwiseEvent','custom_sound_11')
 $outsideNode.SetAttribute('FileName','GSX_Jetway_Bell')
 $outsideNode.SetAttribute('ViewPoint','Outside')
 $bellNode.ParentNode.AppendChild($outsideNode) | Out-Null
}
$outsideNode.SetAttribute('FileName','GSX_Jetway_Bell_Cabin')
foreach($node in @($bellNode,$outsideNode)) {
 foreach($old in @($node.SelectNodes('VolumeCurve'))) { $node.RemoveChild($old) | Out-Null }
 $curve=$soundDoc.CreateElement('VolumeCurve')
 $curve.SetAttribute('LocalVar','GSX_BELL_VOLUME');$curve.SetAttribute('Units','number')
 foreach($v in @(0,100)) { $point=$soundDoc.CreateElement('Point');$point.SetAttribute('SimValue',[string]$v);$point.SetAttribute('Output',[string]$v);$curve.AppendChild($point) | Out-Null }
 $node.AppendChild($curve) | Out-Null
}
$outsideNode.SelectSingleNode('VolumeCurve').SetAttribute('LocalVar','GSX_BELL_PLAYBACK_VOLUME')
# Inside: crossfade the approved closed sound with a clearer open-door sound.
$bellNode.SelectSingleNode('VolumeCurve').SetAttribute('LocalVar','GSX_BELL_CLOSED_VOLUME')
if (-not $openExisting) {
 $openExisting=$bellNode.CloneNode($true)
 $openExisting.SetAttribute('WwiseEvent','custom_sound_10')
 $openExisting.SetAttribute('FileName','GSX_Jetway_Bell_Open')
 $bellNode.ParentNode.AppendChild($openExisting) | Out-Null
}
$openExisting.SelectSingleNode('VolumeCurve').SetAttribute('LocalVar','GSX_BELL_OPEN_VOLUME')
$soundDoc.Save($soundPath)
# Bell WAVs live in our package at the aircraft's virtual sound path.
# Verify the packaged copies before removing only our old aircraft copies.
foreach ($relative in @($wavRelative,$cabinRelative)) {
 $packagedPath=Join-Path $packageDestination $relative
 $sourcePath=Join-Path $packageSource $relative
 if (-not (Test-Path -LiteralPath $packagedPath)) { throw "Packaged bell WAV missing: $relative" }
 if ((Get-FileHash -LiteralPath $packagedPath).Hash -ne (Get-FileHash -LiteralPath $sourcePath).Hash) { throw "Packaged bell WAV verification failed: $relative" }
 $oldPath=Join-Path $aircraftRoot $relative
 if (Test-Path -LiteralPath $oldPath) { Remove-Item -LiteralPath $oldPath }
}
$layout=Get-Content -LiteralPath $aircraftLayout -Raw | ConvertFrom-Json
$layout.content=@($layout.content | Where-Object { $_.path -notin @($wavRelative,$cabinRelative) })
[IO.File]::WriteAllText($aircraftLayout,($layout | ConvertTo-Json -Depth 20),(New-Object Text.UTF8Encoding($false)))
function Update-Entries($root,$relatives) {
 $layoutPath=Join-Path $root 'layout.json'
 $layout=Get-Content -LiteralPath $layoutPath -Raw | ConvertFrom-Json
 foreach($relative in $relatives) {
  $file=Get-Item -LiteralPath (Join-Path $root $relative)
  $entry=@($layout.content | Where-Object { $_.path -eq $relative })
  if($entry.Count -gt 1) { throw "Duplicate layout entry: $relative" }
  if($entry.Count -eq 1) { $entry[0].size=$file.Length;$entry[0].date=$file.LastWriteTimeUtc.ToFileTimeUtc() }
  else { $layout.content += [pscustomobject]@{path=$relative;size=$file.Length;date=$file.LastWriteTimeUtc.ToFileTimeUtc()} }
 }
 [IO.File]::WriteAllText($layoutPath,($layout | ConvertTo-Json -Depth 20),(New-Object Text.UTF8Encoding($false)))
 $verify=Get-Content -LiteralPath $layoutPath -Raw | ConvertFrom-Json
 foreach($relative in $relatives) { $entry=@($verify.content | Where-Object {$_.path -eq $relative}); if($entry.Count -ne 1 -or $entry[0].size -ne (Get-Item -LiteralPath (Join-Path $root $relative)).Length) { throw "Layout check failed: $relative" } }
}
Update-Entries $aircraftRoot @($panelRelative,$soundRelative)
# Remove only our earlier KDAL bell/controller; leave all other scenery behavior intact.
$kdalRoot=Join-Path $CommunityRoot 'iblueyonder-airport-kdal-dallas-love-field'
$kdalSoundRelative='SimObjects/Landmarks/KDAL_Jetways/soundai/soundai.xml'
if(Test-Path -LiteralPath (Join-Path $kdalRoot $kdalSoundRelative)) {
 $changed=@()
 $kdalDoc=New-Object System.Xml.XmlDocument;$kdalDoc.PreserveWhitespace=$true;$kdalDoc.Load((Join-Path $kdalRoot $kdalSoundRelative))
 $oldBell=$kdalDoc.SelectSingleNode('//Sound[@FileName="jetway-bell"]')
 if($null -ne $oldBell) {
  $saved=Join-Path (Join-Path $backupRoot 'kdal') $kdalSoundRelative;New-Item -ItemType Directory -Path (Split-Path -Parent $saved) -Force | Out-Null;Copy-Item -LiteralPath (Join-Path $kdalRoot $kdalSoundRelative) -Destination $saved
  $oldBell.ParentNode.RemoveChild($oldBell) | Out-Null;$kdalDoc.Save((Join-Path $kdalRoot $kdalSoundRelative));$changed += $kdalSoundRelative
 }
 foreach($relative in @('SimObjects/Landmarks/KDAL_Jetways/model/KDAL_jetway.xml','SimObjects/Landmarks/KDAL_Jetways/model.tall/KDAL_jetway_tall.xml')) {
  $path=Join-Path $kdalRoot $relative
  $text=[IO.File]::ReadAllText($path)
  $modelDoc=New-Object System.Xml.XmlDocument;$modelDoc.PreserveWhitespace=$true
  $modelDoc.LoadXml('<Root>'+[regex]::Replace($text,'^\s*<\?xml[^?]*\?>','')+'</Root>')
  $controllers=@($modelDoc.SelectNodes('/Root/ModelBehaviors/Component[@ID="Hood"]/UseTemplate[@Name="ASOBO_GT_Update"][UPDATE_CODE[contains(text(),"IBY_KDAL_JetwayBellActive")]]'))
  if($controllers.Count -gt 0) {
   $saved=Join-Path (Join-Path $backupRoot 'kdal') $relative;New-Item -ItemType Directory -Path (Split-Path -Parent $saved) -Force | Out-Null;Copy-Item -LiteralPath $path -Destination $saved
   foreach($controller in $controllers) { $controller.ParentNode.RemoveChild($controller) | Out-Null }
   [IO.File]::WriteAllText($path,('<?xml version="1.0" encoding="utf-8"?>'+"`r`n"+$modelDoc.DocumentElement.InnerXml),(New-Object Text.UTF8Encoding($false)))
   $changed += $relative
  }
 }
 if($changed.Count -gt 0) { Copy-Item -LiteralPath (Join-Path $kdalRoot 'layout.json') -Destination (Join-Path $backupRoot 'kdal\layout.json');Update-Entries $kdalRoot $changed }
}
$verifiedSound=[xml](Get-Content -LiteralPath $soundPath -Raw)
if($verifiedSound.SelectNodes('//Sound[@FileName="GSX_Jetway_Bell_Cabin"]').Count -ne 2) { throw 'Bell definition validation failed.' }
if(([regex]::Matches([IO.File]::ReadAllText($panelPath),'GSXJetwayBell/JetwayBell.html')).Count -ne 1) { throw 'Gauge installation validation failed.' }
"Installed independent GSX bell package. Backup: $backupRoot"
'GSX files unchanged. Restart MSFS to load the hidden ProSim gauge.'