#!/usr/bin/env pwsh
param ($URI, $Proxy, $Extra)
$ErrorActionPreference = 'Stop'
$SaveName = 'notFoundName'

function isURI($address) { 
  $null -ne ($address -as [System.URI]).AbsoluteURI 
}
function getExe {
  return (Get-Item N_*.exe -Exclude '*SimpleG*').fullname
}
function dealTheURI($address) {
  if ($null -eq $address) {
    $(throw "URI parameter is required.")
  }
  $address = $address.Trim()
  if (!$address.endswith('/')) {
    $address = $address + '/'
  }
  if (!(isURI($address))) {
    throw "The URI is not a valid URI"
  }
  return $address
}

$CurrentDir = (Get-Item .).FullName
# Deal the URI ==================================================

if ($args.Length -eq 1) {
  $URI = $args.Get(0)
}
if (!$URI) {
  # https://docs.microsoft.com/zh-cn/powershell/module/microsoft.powershell.core/about/about_environment_variables?view=powershell-7.2
  $URI = $env:URI
}

$URI = dealTheURI($URI)
$temp = ($URI -as [System.URI]).Segments
if ($temp.Length -eq 1) {
  throw "The URI not catain the file name"
}
$SaveName = $temp[$temp.Length - 1].replace('/', '')

Write-Output "URI: $URI"  "SaveName: $SaveName"
if ($null -ne $Proxy) {
  Write-Output "Proxy: $Proxy"
}
# Find m3u8 link ==================================================

$m3u8 = (Invoke-WebRequest "$URI" -useb).content | Select-String -Pattern 'https?\:\/\/.+\.m3u8' -ALL | ForEach-Object {$_.matches[0].value}
Write-Output "m3u8 path: $m3u8"

# call Call the N_m3u8DL-CLI  ==================================================

$N_m3u8DL_URI = 'https://github.com/bxb100/N_m3u8DL-CLI/releases/download/2.9.9/N_m3u8DL-CLI.zip'
$N_m3u8DL_ZIP = "N_m3u8DL.zip"

$N_m3u8DL_EXE = getExe
if ( -not ((getExe -ne $null) -and (getExe | Test-path)) )  {
  Invoke-WebRequest $N_m3u8DL_URI -OutFile $N_m3u8DL_ZIP -UseBasicParsing

  if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
    Expand-Archive $N_m3u8DL_ZIP -Destination $CurrentDir -Force
  } else {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($N_m3u8DL_ZIP, $CurrentDir)
  }

  Remove-Item $N_m3u8DL_ZIP
}
$N_m3u8DL_EXE = getExe
Write-Output "N_m3u8DL_EXE: $N_m3u8DL_EXE"

Try {
  if (Test-path $N_m3u8DL_EXE) {
    $command = "$N_m3u8DL_EXE $m3u8 --workDir '.' --saveName $SaveName --enableDelAfterDone "
    if ($Proxy) {
      $command += " --proxyAddress '$Proxy'"
    }
    if ($Extra) {
      $command += " $Extra"
    }
    Write-Output "execute command: $command"
    Invoke-Expression -Command "$command"
  } else {
    throw "N_m3u8DL_EXE not found"
    exit -1
  }
} Finally {
  if (Test-path $SaveName) {
    Write-Host "\r`nCleaning the resource..."
    Remove-Item -Recurse -Force $SaveName
  }
}

