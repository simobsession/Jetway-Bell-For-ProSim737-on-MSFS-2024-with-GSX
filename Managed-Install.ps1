param([Parameter(Mandatory=$true)][string]$CommunityRoot,[switch]$Uninstall,[switch]$NoRegistration)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'XmlIO.ps1')
if(Get-Process -Name FlightSimulator,FlightSimulator2024 -ErrorAction SilentlyContinue){throw 'Close MSFS completely before installing or uninstalling.'}
$CommunityRoot=(Resolve-Path -LiteralPath $CommunityRoot).Path
$aircraft=Join-Path $CommunityRoot 'prosim-b738'
$panelRel='SimObjects/Airplanes/prosim-b738-2026/panel/panel.cfg'
$soundRel='SimObjects/Airplanes/prosim-b738-2026/sound/sound.xml'
$panel=Join-Path $aircraft $panelRel;$sound=Join-Path $aircraft $soundRel;$layoutPath=Join-Path $aircraft 'layout.json'
foreach($file in @($panel,$sound,$layoutPath)){if(-not(Test-Path -LiteralPath $file)){throw "Required aircraft file missing: $file"}}
$package=Join-Path $CommunityRoot 'gsx-jetway-bell'
$registry='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\GSXJetwayBellProSim'
$backup=Join-Path $PSScriptRoot ('backup-managed-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item -LiteralPath $panel -Destination (Join-Path $backup 'panel.cfg')
Copy-Item -LiteralPath $sound -Destination (Join-Path $backup 'sound.xml')
Copy-Item -LiteralPath $layoutPath -Destination (Join-Path $backup 'layout.json')
$hadPackage=Test-Path -LiteralPath $package
if($hadPackage){Copy-Item -LiteralPath $package -Destination (Join-Path $backup 'gsx-jetway-bell') -Recurse}
try {
 if($Uninstall){
  # Validate package ownership before modifying aircraft files. Never delete unknown files.
  $source=Join-Path $PSScriptRoot 'gsx-jetway-bell'
  $owned=@()
  $recorded=@{}
  $recordPath=Join-Path $PSScriptRoot 'installed-files.json'
  if(Test-Path -LiteralPath $recordPath){foreach($record in (Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json)){$recorded[$record.path]=$record.hash}}
  if($hadPackage){
   foreach($file in Get-ChildItem -LiteralPath $package -Recurse -File){
    $relative=$file.FullName.Substring($package.Length+1);$original=Join-Path $source $relative
    if($recorded.ContainsKey($relative)) {if((Get-FileHash -LiteralPath $file.FullName).Hash -ne $recorded[$relative]){throw "Package file was changed; retained: $relative"};$owned+=$file.FullName;continue}
    if(-not(Test-Path -LiteralPath $original)){throw "Unrecognized package file; retained: $relative"}
    if((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $original).Hash){throw "Package file was changed; retained: $relative"}
    $owned+=$file.FullName
   }
  }
  $panelText=[IO.File]::ReadAllText($panel)
  $sections=[regex]::Split($panelText,'(?m)(?=^\[)')
  $kept=foreach($section in $sections){
   if($section -match '(?im)^htmlgauge\d+\s*=\s*GSXJetwayBell/JetwayBell\.html'){
    $clean=[regex]::Replace($section,'(?im)^htmlgauge\d+\s*=\s*GSXJetwayBell/JetwayBell\.html[^\r\n]*\r?\n?','')
    $substantive=[regex]::Replace($clean,'(?im)^\s*(\[VCockpit\d+\]|;[^\r\n]*|size_mm\s*=\s*1,1|pixel_size\s*=\s*1,1|texture\s*=\s*NO_TEXTURE)\s*$','').Trim()
    if($substantive){$clean}
   }else{$section}
  }
  $panelText=($kept -join '')
  $panelText=[regex]::Replace($panelText,'(?im)^; GSX bell: invisible manager, no external application\.\r?\n?','')
  $doc=New-Object Xml.XmlDocument;$doc.PreserveWhitespace=$true;$doc=Read-BellXml $sound
  foreach($node in @($doc.SelectNodes('//Sound'))){
   if(($node.GetAttribute('FileName') -match '^GSX_Jetway_(Bell(_Cabin|_Open)?|Custom_[A-Z0-9]{4}_(Cabin|Open))$') -and ($node.GetAttribute('LocalVar') -match '^GSX_JETWAY_BELL_(ACTIVE|DEFAULT_ACTIVE|AIRPORT_[A-Z0-9]{4}_ACTIVE)$')){$node.ParentNode.RemoveChild($node) | Out-Null}
  }
  [IO.File]::WriteAllText($panel,$panelText,(New-Object Text.UTF8Encoding($false)));$doc.Save($sound)
  $layout=Get-Content -LiteralPath $layoutPath -Raw | ConvertFrom-Json
  foreach($relative in @($panelRel,$soundRel)){
   $file=Get-Item -LiteralPath (Join-Path $aircraft $relative);$entries=@($layout.content | Where-Object {$_.path -eq $relative})
   if($entries.Count -ne 1){throw "Expected one aircraft layout entry: $relative"}
   $entries[0].size=$file.Length;$entries[0].date=$file.LastWriteTimeUtc.ToFileTimeUtc()
  }
  [IO.File]::WriteAllText($layoutPath,($layout | ConvertTo-Json -Depth 20),(New-Object Text.UTF8Encoding($false)))
  # Full path is resolved and must remain within the explicitly selected Community directory.
  if($hadPackage){
   $resolved=(Resolve-Path -LiteralPath $package).Path
   if($resolved -ne (Join-Path $CommunityRoot 'gsx-jetway-bell')){throw 'Unexpected package path.'}
   foreach($ownedFile in $owned){Remove-Item -LiteralPath $ownedFile}
   Get-ChildItem -LiteralPath $package -Directory -Recurse | Sort-Object {$_.FullName.Length} -Descending | ForEach-Object {if(-not(Get-ChildItem -LiteralPath $_.FullName -Force)){Remove-Item -LiteralPath $_.FullName}}
   if(-not(Get-ChildItem -LiteralPath $package -Force)){Remove-Item -LiteralPath $package}
  }
  if(-not $NoRegistration){
   foreach($shortcut in @((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Jetway Bell Sound Settings.lnk'),(Join-Path ([Environment]::GetFolderPath('Programs')) 'Jetway Bell Sound Settings.lnk'))){if(Test-Path -LiteralPath $shortcut){Remove-Item -LiteralPath $shortcut}}
   Remove-Item -LiteralPath $registry -ErrorAction SilentlyContinue}
  Write-Output 'Uninstalled bell package and aircraft integration. Other aircraft sounds and GSX settings were preserved.'
 }else{
  & (Join-Path $PSScriptRoot 'Install.ps1') -CommunityRoot $CommunityRoot
  & (Join-Path $PSScriptRoot 'Apply-SoundSettings.ps1') -CommunityRoot $CommunityRoot
  if(-not $NoRegistration){
   $shell=New-Object -ComObject WScript.Shell
   foreach($directory in @([Environment]::GetFolderPath('Desktop'),[Environment]::GetFolderPath('Programs'))){
    $link=$shell.CreateShortcut((Join-Path $directory 'Jetway Bell Sound Settings.lnk'));$link.TargetPath=Join-Path $PSScriptRoot 'Setup.exe';$link.Arguments='/settings';$link.WorkingDirectory=$PSScriptRoot;$link.Save()
   }
   New-Item -Path $registry -Force | Out-Null
   $properties=@{DisplayName='Jetway Bell For ProSim737 on MSFS 2024 with GSX';DisplayVersion='1.2.1';Publisher='GSX Jetway Bell';InstallLocation=$PSScriptRoot;CommunityRoot=$CommunityRoot;UninstallString=('"'+(Join-Path $PSScriptRoot 'Setup.exe')+'" /uninstall');DisplayIcon=(Join-Path $PSScriptRoot 'Setup.exe')}
   foreach($key in $properties.Keys){New-ItemProperty -Path $registry -Name $key -Value $properties[$key] -PropertyType String -Force | Out-Null}
   New-ItemProperty -Path $registry -Name NoModify -Value 1 -PropertyType DWord -Force | Out-Null
   New-ItemProperty -Path $registry -Name NoRepair -Value 1 -PropertyType DWord -Force | Out-Null
  }
  Write-Output 'Installation complete. The uninstaller is available in Windows Installed apps and in Setup.exe.'
 }
 Write-Output "Recovery backups: $backup"
}catch{
 Copy-Item -LiteralPath (Join-Path $backup 'panel.cfg') -Destination $panel -Force
 Copy-Item -LiteralPath (Join-Path $backup 'sound.xml') -Destination $sound -Force
 Copy-Item -LiteralPath (Join-Path $backup 'layout.json') -Destination $layoutPath -Force
 if($hadPackage){Copy-Item -Path (Join-Path $backup 'gsx-jetway-bell\*') -Destination $package -Recurse -Force}
 throw
}
