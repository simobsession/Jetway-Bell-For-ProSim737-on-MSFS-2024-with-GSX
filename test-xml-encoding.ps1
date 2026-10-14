$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'XmlIO.ps1')
$fixture=Join-Path $PSScriptRoot ('installer-check\encoding-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Path $fixture | Out-Null
$path=Join-Path $fixture 'sound.xml'
$text='<?xml version="1.0" encoding="utf-8"?>'+"`r`n"+'<!-- '+[char]0x2013+' bell '+[char]0xE9+' -->'+"`r`n"+'<SoundInfo><SimVarSounds><Sound FileName="Door" /></SimVarSounds></SoundInfo>'
[IO.File]::WriteAllBytes($path,[Text.Encoding]::GetEncoding(1252).GetBytes($text))
$original=[IO.File]::ReadAllBytes($path)
$strict=New-Object Xml.XmlDocument;$failed=$false;try{$strict.Load($path)}catch{$failed=$true};if(-not $failed){throw 'Fixture did not reproduce the failure.'}
$doc=Read-BellXml $path
if($doc.OuterXml -notmatch ([string][char]0x2013) -or $doc.OuterXml -notmatch ([string][char]0xE9)){throw 'Legacy characters were lost.'}
if([Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) -ne [Convert]::ToBase64String($original)){throw 'Reader changed source bytes.'}
$doc.Save($path);$strict.Load($path)
[IO.File]::WriteAllText($path,'<SoundInfo><broken></SoundInfo>')
$failed=$false;try{$null=Read-BellXml $path}catch{$failed=$true};if(-not $failed){throw 'Malformed XML was accepted.'}
[IO.File]::WriteAllText($path,$text.Replace('utf-8','utf-16'),[Text.Encoding]::Unicode);$null=Read-BellXml $path
Write-Output 'PASS: encoding error reproduced; legacy characters preserved; source bytes untouched on read; UTF-8 save reparses; UTF-16 works; malformed XML rejected.'
