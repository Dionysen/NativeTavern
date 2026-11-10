# Rewrite third-party Flutter plugin Android Gradle scripts so they no longer
# declaratively apply the Kotlin Gradle Plugin (KGP).
#
# Flutter 3.47+ warns (and will later fail) when plugin build files contain
# `apply plugin: 'kotlin-android'` / `id("kotlin-android")`. With
# android.builtInKotlin=false, Flutter itself applies KGP to plugin subprojects
# that do not declare it, so removing the declarative apply clears the warning
# without breaking the build.
#
# Safe to re-run; skips files that are already clean.

$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$PluginsFile = Join-Path $Root '.flutter-plugins-dependencies'
if (-not (Test-Path -LiteralPath $PluginsFile)) {
  Write-Host 'No .flutter-plugins-dependencies yet; run flutter pub get first.'
  exit 0
}

$json = Get-Content -LiteralPath $PluginsFile -Raw | ConvertFrom-Json
$androidPlugins = $json.plugins.android
if ($null -eq $androidPlugins) {
  Write-Host 'No Android plugins listed.'
  exit 0
}

$patched = 0
$skipped = 0

function Test-NeedsKgpPatch([string]$Text) {
  return [regex]::IsMatch(
    $Text,
    '(?m)^[ \t]*apply[ \t]+plugin[ \t]*:[ \t]*[''"](?:kotlin-android|org\.jetbrains\.kotlin\.android)[''"]|[ \t]*(?:id|alias)[ \t]*\([ \t]*[''"](?:kotlin-android|org\.jetbrains\.kotlin\.android)[''"][ \t]*\)|[ \t]*(?:id|alias)[ \t]+[''"](?:kotlin-android|org\.jetbrains\.kotlin\.android)[''"]'
  )
}

function Get-PatchedKgpText([string]$Text) {
  $result = [regex]::Replace(
    $Text,
    '(?m)^[ \t]*apply[ \t]+plugin[ \t]*:[ \t]*[''"](?:kotlin-android|org\.jetbrains\.kotlin\.android)[''"][ \t]*\r?\n',
    ''
  )
  # Kotlin DSL / Groovy plugins { id("kotlin-android") } / id 'kotlin-android'
  $result = [regex]::Replace(
    $result,
    '(?m)^[ \t]*(?:id|alias)[ \t]*\([ \t]*[''"](?:kotlin-android|org\.jetbrains\.kotlin\.android)[''"][ \t]*\)[ \t]*\r?\n',
    ''
  )
  $result = [regex]::Replace(
    $result,
    '(?m)^[ \t]*(?:id|alias)[ \t]+[''"](?:kotlin-android|org\.jetbrains\.kotlin\.android)[''"][ \t]*\r?\n',
    ''
  )
  return $result
}

foreach ($plugin in $androidPlugins) {
  $name = [string]$plugin.name
  $path = [string]$plugin.path
  if ([string]::IsNullOrWhiteSpace($path)) { continue }

  $androidDir = Join-Path $path 'android'
  if (-not (Test-Path -LiteralPath $androidDir)) { continue }

  foreach ($fileName in @('build.gradle', 'build.gradle.kts')) {
    $buildFile = Join-Path $androidDir $fileName
    if (-not (Test-Path -LiteralPath $buildFile)) { continue }

    $original = Get-Content -LiteralPath $buildFile -Raw
    if (-not (Test-NeedsKgpPatch $original)) {
      $skipped++
      continue
    }

    $updated = Get-PatchedKgpText $original
    if ($updated -eq $original) {
      Write-Warning "Detected KGP apply in $name but patch produced no change: $buildFile"
      continue
    }
    if (Test-NeedsKgpPatch $updated) {
      Write-Warning "Incomplete KGP patch for $name : $buildFile"
    }

    Set-Content -LiteralPath $buildFile -Value $updated -NoNewline
    Write-Host "Patched KGP apply out of $name ($fileName)"
    $patched++
  }
}

Write-Host "KGP patch complete: $patched patched, $skipped already clean."
