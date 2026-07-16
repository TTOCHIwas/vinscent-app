[CmdletBinding()]
param()

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$mobileDir = Join-Path $repoRoot "apps\mobile"
$expectedPubCache = [System.IO.Path]::GetFullPath(
  (Join-Path $repoRoot ".toolchains\pub-cache")
)
$globalPubCache = [System.IO.Path]::GetFullPath(
  (Join-Path $env:LOCALAPPDATA "Pub\Cache")
)

$generatedFiles = @(
  Join-Path $mobileDir ".dart_tool\package_config.json"
  Join-Path $mobileDir ".flutter-plugins-dependencies"
)

$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Convert-ToNormalizedPath {
  param([string]$Value)

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return $null
  }

  $candidate = $Value
  $uri = $null
  if ([Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri) -and $uri.IsFile) {
    $candidate = $uri.LocalPath
  }

  try {
    return [System.IO.Path]::GetFullPath($candidate)
  } catch {
    return $null
  }
}

function Test-IsPathWithin {
  param(
    [string]$Path,
    [string]$Root
  )

  $comparison = [StringComparison]::OrdinalIgnoreCase
  $rootPrefix = $Root.TrimEnd([char[]]"\/") + [System.IO.Path]::DirectorySeparatorChar
  return $Path.Equals($Root, $comparison) -or $Path.StartsWith($rootPrefix, $comparison)
}

function Get-DependencyPaths {
  param([string]$GeneratedFile)

  $config = Get-Content -LiteralPath $GeneratedFile -Raw -Encoding UTF8 | ConvertFrom-Json
  $pathValues = @()

  if ([System.IO.Path]::GetFileName($GeneratedFile) -eq "package_config.json") {
    $pathValues += $config.pubCache
    foreach ($package in @($config.packages)) {
      $pathValues += $package.rootUri
    }
  } else {
    foreach ($platform in $config.plugins.PSObject.Properties) {
      foreach ($plugin in @($platform.Value)) {
        $pathValues += $plugin.path
      }
    }
  }

  foreach ($pathValue in $pathValues) {
    $normalizedPath = Convert-ToNormalizedPath $pathValue
    if ($null -ne $normalizedPath) {
      $normalizedPath
    }
  }
}

foreach ($generatedFile in $generatedFiles) {
  if (-not (Test-Path -LiteralPath $generatedFile)) {
    $warnings.Add("Generated dependency file not found: $generatedFile")
    continue
  }

  try {
    $dependencyPaths = @(Get-DependencyPaths $generatedFile)
  } catch {
    $failures.Add("Failed to parse dependency JSON: $generatedFile ($($_.Exception.Message))")
    continue
  }

  foreach ($dependencyPath in $dependencyPaths) {
    if (Test-IsPathWithin $dependencyPath $globalPubCache) {
      $failures.Add("$generatedFile contains the global Pub cache path: $globalPubCache")
      break
    }
  }

  $containsExpectedPath = $false
  foreach ($dependencyPath in $dependencyPaths) {
    if (Test-IsPathWithin $dependencyPath $expectedPubCache) {
      $containsExpectedPath = $true
      break
    }
  }

  if (-not $containsExpectedPath) {
    $failures.Add("$generatedFile does not contain the expected Pub cache path: $expectedPubCache")
  }
}

if ($failures.Count -gt 0) {
  Write-Host "Flutter Pub cache verification failed" -ForegroundColor Red
  foreach ($failure in $failures) {
    Write-Host "- $failure" -ForegroundColor Red
  }
  exit 1
}

if ($warnings.Count -gt 0) {
  Write-Host "Flutter Pub cache verification warnings" -ForegroundColor Yellow
  foreach ($warning in $warnings) {
    Write-Host "- $warning" -ForegroundColor Yellow
  }
}

Write-Host "Flutter Pub cache verification passed" -ForegroundColor Green
Write-Host "- Expected path: $expectedPubCache"
