# Read XML normally first; recover legacy Windows-1252 bytes only when UTF-8 decoding is invalid.
function Read-BellXml([string]$Path) {
 $document=New-Object Xml.XmlDocument
 $document.PreserveWhitespace=$true
 $document.XmlResolver=$null
 try {$document.Load($Path);return ,$document}
 catch [Xml.XmlException] {
  $original=$_.Exception
  $bytes=[IO.File]::ReadAllBytes($Path)
  if($bytes.Length -ge 2 -and (($bytes[0] -eq 255 -and $bytes[1] -eq 254) -or ($bytes[0] -eq 254 -and $bytes[1] -eq 255))){throw $original}
  $offset=0
  if($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191){$offset=3}
  $strict=New-Object Text.UTF8Encoding($false,$true)
  $invalidUtf8=$false
  try {$null=$strict.GetString($bytes,$offset,$bytes.Length-$offset)}catch [Text.DecoderFallbackException]{$invalidUtf8=$true}
  if(-not $invalidUtf8){throw $original}
  $text=[Text.Encoding]::GetEncoding(1252).GetString($bytes,$offset,$bytes.Length-$offset)
  $declaration=[regex]::Match($text,'^\s*<\?xml[^?]*encoding\s*=\s*["'']([^"'']+)["'']')
  if($declaration.Success -and $declaration.Groups[1].Value -notmatch '^(utf-8|utf8)$'){throw $original}
  $text=[regex]::Replace($text,'(?i)(<\?xml[^?]*encoding\s*=\s*)["''][^"'']+["'']','$1"utf-8"')
  $document.LoadXml($text)
  Write-Host 'Read legacy Windows-1252 XML bytes; output will be saved as valid UTF-8. Original files are retained in installer backups.'
  return ,$document
 }
}
