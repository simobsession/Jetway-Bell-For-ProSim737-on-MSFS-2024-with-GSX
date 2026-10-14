param([Parameter(Mandatory=$true)][string]$CommunityRoot)
$ErrorActionPreference='Stop'
$package=Join-Path $CommunityRoot 'gsx-jetway-bell'
$aircraft=Join-Path $CommunityRoot 'prosim-b738'
$soundRel='SimObjects/Airplanes/prosim-b738-2026/sound/sound.xml'
$soundPath=Join-Path $aircraft $soundRel
$audioRoot=Join-Path $package 'SimObjects/Airplanes/prosim-b738-2026/sound'
$dataRoot=Join-Path $PSScriptRoot 'UserData'
$settingsPath=Join-Path $dataRoot 'settings.xml'
$doc=New-Object Xml.XmlDocument;$doc.PreserveWhitespace=$true;$doc.Load($soundPath)
# Remove only generated definitions, retaining unrelated sounds.
foreach($node in @($doc.SelectNodes('//Sound'))){if($node.GetAttribute('FileName') -match '^GSX_Jetway_Custom_[A-Z0-9]{4}_(Cabin|Open)$' -and $node.GetAttribute('LocalVar') -match '^GSX_JETWAY_BELL_AIRPORT_[A-Z0-9]{4}_ACTIVE$'){$node.ParentNode.RemoveChild($node) | Out-Null}}
$settings=New-Object Xml.XmlDocument
if(Test-Path -LiteralPath $settingsPath){$settings.Load($settingsPath)}else{$settings.LoadXml('<SoundSettings><Default file="" /></SoundSettings>')}
if($settings.SelectNodes('/SoundSettings').Count -ne 1){throw 'Invalid sound settings file.'}
$airports=@($settings.SelectNodes('/SoundSettings/Airport'))
$seen=@{}
function Source-Wav($relative){
 if(-not $relative -or $relative -notmatch '^Sounds/[a-fA-F0-9]{32}\.wav$'){throw 'Invalid custom recording path.'}
 $path=Join-Path $dataRoot $relative
 if(-not(Test-Path -LiteralPath $path)){throw "Custom recording missing: $relative"}
 [BellAudio]::Validate($path);return $path
}
if(-not ('BellAudio' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'BellAudio.dll')}
$default=$settings.SelectSingleNode('/SoundSettings/Default')
if($default -and $default.GetAttribute('file')){
 $source=Source-Wav $default.GetAttribute('file')
 [BellAudio]::Prepare($source,(Join-Path $audioRoot 'GSX_Jetway_Bell_Cabin.wav'),$false)
 [BellAudio]::Prepare($source,(Join-Path $audioRoot 'GSX_Jetway_Bell.wav'),$false)
 [BellAudio]::Prepare($source,(Join-Path $audioRoot 'GSX_Jetway_Bell_Open.wav'),$true)
}
$templates=@{}
foreach($eventName in @('custom_sound_10','custom_sound_11','custom_sound_12')){
 $node=$doc.SelectSingleNode("//Sound[@WwiseEvent='$eventName']")
 if(-not $node -or $node.GetAttribute('FileName') -notmatch '^GSX_Jetway_Bell'){throw "Bell template missing: $eventName"}
 $node.SetAttribute('LocalVar','GSX_JETWAY_BELL_DEFAULT_ACTIVE');$templates[$eventName]=$node
}
foreach($airport in $airports){
 $code=$airport.GetAttribute('icao').ToUpperInvariant()
 if($code -notmatch '^[A-Z0-9]{4}$' -or $seen.ContainsKey($code)){throw 'Invalid or duplicate airport ICAO.'};$seen[$code]=$true
 $source=Source-Wav $airport.GetAttribute('file')
 foreach($variant in @('Cabin','Open')){[BellAudio]::Prepare($source,(Join-Path $audioRoot "GSX_Jetway_Custom_${code}_${variant}.wav"),($variant -eq 'Open'))}
 foreach($eventName in @('custom_sound_10','custom_sound_11','custom_sound_12')){
  $node=$templates[$eventName].CloneNode($true)
  $node.SetAttribute('WwiseEvent',"GSX_Jetway_Custom_${code}_${eventName}")
  $variant=if($eventName -eq 'custom_sound_10'){'Open'}else{'Cabin'}
  $node.SetAttribute('FileName',"GSX_Jetway_Custom_${code}_${variant}")
  $node.SetAttribute('LocalVar',"GSX_JETWAY_BELL_AIRPORT_${code}_ACTIVE")
  $templates[$eventName].ParentNode.AppendChild($node) | Out-Null
 }
}
$doc.Save($soundPath)
$codes=@($seen.Keys | Sort-Object)
$config='window.GSXBellAirports = '+(ConvertTo-Json -InputObject $codes -Compress)+';'
$gauge=Join-Path $package 'html_ui/Pages/VCockpit/Instruments/GSXJetwayBell'
$runtime=Join-Path $gauge 'JetwayBellRuntime.js'
$text=[IO.File]::ReadAllText($runtime)
[IO.File]::WriteAllText($runtime,($config+"`r`n"+$text),(New-Object Text.UTF8Encoding($false)))
$layout=Get-Content -LiteralPath (Join-Path $aircraft 'layout.json') -Raw | ConvertFrom-Json
foreach($entry in @($layout.content | Where-Object {$_.path -eq $soundRel})){$item=Get-Item -LiteralPath $soundPath;$entry.size=$item.Length;$entry.date=$item.LastWriteTimeUtc.ToFileTimeUtc()}
[IO.File]::WriteAllText((Join-Path $aircraft 'layout.json'),($layout | ConvertTo-Json -Depth 20),(New-Object Text.UTF8Encoding($false)))
$entries=@(Get-ChildItem -LiteralPath $package -Recurse -File | Where-Object Name -ne 'layout.json' | ForEach-Object {[pscustomobject]@{path=$_.FullName.Substring($package.Length+1).Replace('\','/');size=$_.Length;date=$_.LastWriteTimeUtc.ToFileTimeUtc()}})
[IO.File]::WriteAllText((Join-Path $package 'layout.json'),(@{content=$entries} | ConvertTo-Json -Depth 20),(New-Object Text.UTF8Encoding($false)))
$hashes=@(Get-ChildItem -LiteralPath $package -Recurse -File | ForEach-Object {[pscustomobject]@{path=$_.FullName.Substring($package.Length+1);hash=(Get-FileHash -LiteralPath $_.FullName).Hash}})
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'installed-files.json'),(ConvertTo-Json -InputObject $hashes -Depth 10),(New-Object Text.UTF8Encoding($false)))
Write-Output "Applied custom default and $($codes.Count) airport override(s)."
