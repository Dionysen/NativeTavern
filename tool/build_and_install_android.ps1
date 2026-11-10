# Build arm64 release APK and install it onto an adb device.
#
# Usage:
#   .\tool\build_and_install_android.ps1 <device-id>
#   .\tool\build_and_install_android.ps1 -l
#   .\tool\build_and_install_android.ps1 --uninstall-first <device-id>
#
# Example:
#   .\tool\build_and_install_android.ps1 adb-R5CW929XXFH-AujM9A._adb-tls-connect._tcp

$ErrorActionPreference = 'Stop'

$ScriptName = Split-Path -Leaf $PSCommandPath
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Apk = Join-Path $Root 'build\app\outputs\flutter-apk\app-arm64-v8a-release.apk'
$PackageId = 'com.miaomiaoxworld.nativetavern'
$UninstallFirst = $false
$Device = $null

function Show-Usage {
  @"
Usage:
  $ScriptName <device-id>
  $ScriptName -l | --list
  $ScriptName --uninstall-first <device-id>

Builds:
  flutter build apk --split-per-abi --target-platform android-arm64

Then installs:
  adb -s <device-id> install -r build\app\outputs\flutter-apk\app-arm64-v8a-release.apk

Options:
  -l, --list             List adb devices and exit
  --uninstall-first      Uninstall existing app before install (clears data;
                         use when signatures do not match)
  -h, --help             Show this help
"@
}

function Write-Err([string]$Message) {
  [Console]::Error.WriteLine($Message)
}

function Get-AdbDevices {
  & adb devices -l
  if ($LASTEXITCODE -ne 0) {
    throw "adb devices failed with exit code $LASTEXITCODE"
  }
}

function Test-CommandExists([string]$Name) {
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-ConnectedDeviceIds {
  $lines = & adb devices
  if ($LASTEXITCODE -ne 0) {
    throw "adb devices failed with exit code $LASTEXITCODE"
  }
  $ids = New-Object System.Collections.Generic.List[string]
  foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^List of devices') {
      continue
    }
    $parts = ($line -split '\s+', 2)
    if ($parts.Count -ge 2 -and $parts[1] -eq 'device') {
      [void]$ids.Add($parts[0])
    }
  }
  return $ids
}

function Format-FileSize([string]$Path) {
  $bytes = (Get-Item -LiteralPath $Path).Length
  if ($bytes -ge 1GB) { return ('{0:N1}G' -f ($bytes / 1GB)) }
  if ($bytes -ge 1MB) { return ('{0:N1}M' -f ($bytes / 1MB)) }
  if ($bytes -ge 1KB) { return ('{0:N1}K' -f ($bytes / 1KB)) }
  return "$bytes B"
}

$argv = @($args)
$i = 0
while ($i -lt $argv.Count) {
  $arg = $argv[$i]
  switch ($arg) {
    { $_ -in @('-h', '--help') } {
      Show-Usage
      exit 0
    }
    { $_ -in @('-l', '--list') } {
      Get-AdbDevices
      exit 0
    }
    '--uninstall-first' {
      $UninstallFirst = $true
      $i++
      break
    }
    default {
      if ($arg.StartsWith('-')) {
        Write-Err "Unknown option: $arg"
        Show-Usage | ForEach-Object { Write-Err $_ }
        exit 2
      }
      if (-not [string]::IsNullOrWhiteSpace($Device)) {
        Write-Err "Unexpected argument: $arg"
        Show-Usage | ForEach-Object { Write-Err $_ }
        exit 2
      }
      $Device = $arg
      $i++
      break
    }
  }
}

if ([string]::IsNullOrWhiteSpace($Device)) {
  Write-Err 'Missing device id.'
  Write-Err ''
  Show-Usage | ForEach-Object { Write-Err $_ }
  Write-Err ''
  Write-Err 'Connected devices:'
  Get-AdbDevices | ForEach-Object { Write-Err $_ }
  exit 2
}

if (-not (Test-CommandExists 'flutter')) {
  Write-Err 'flutter not found in PATH'
  exit 1
}
if (-not (Test-CommandExists 'adb')) {
  Write-Err 'adb not found in PATH'
  exit 1
}

$connected = @(Get-ConnectedDeviceIds)
if ($connected -notcontains $Device) {
  Write-Err "Device not connected (or not in 'device' state): $Device"
  Write-Err ''
  Get-AdbDevices | ForEach-Object { Write-Err $_ }
  exit 1
}

Set-Location $Root

Write-Host '==> Patching plugin Android Gradle files (remove declarative KGP apply)'
& (Join-Path $PSScriptRoot 'patch_android_plugin_kgp.ps1')
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Host '==> Building arm64 release APK'
& flutter build apk --split-per-abi --target-platform android-arm64
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

if (-not (Test-Path -LiteralPath $Apk)) {
  Write-Err "APK not found after build: $Apk"
  exit 1
}

Write-Host "==> Installing to $Device"
Write-Host ("    $Apk ({0})" -f (Format-FileSize $Apk))

if ($UninstallFirst) {
  Write-Host "==> Uninstalling $PackageId (data will be cleared)"
  & adb -s $Device uninstall $PackageId 1>$null 2>$null
}

$installOut = & adb -s $Device install -r $Apk 2>&1 | Out-String
$installStatus = $LASTEXITCODE
Write-Host $installOut.TrimEnd()

if ($installStatus -ne 0) {
  if ($installOut -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE') {
    Write-Err ''
    Write-Err 'Signature mismatch with the installed app.'
    Write-Err 'Re-run with --uninstall-first to replace it (clears app data):'
    Write-Err "  $ScriptName --uninstall-first `"$Device`""
  }
  exit $installStatus
}

Write-Host '==> Done'
