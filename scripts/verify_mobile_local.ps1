[CmdletBinding()]
param(
  [string]$DeviceId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$mobileDir = Join-Path $repoRoot "apps\mobile"
$androidDir = Join-Path $mobileDir "android"
$flutterWrapper = Join-Path $mobileDir "flutterw.cmd"
$dart = Join-Path $repoRoot ".toolchains\flutter\bin\dart.bat"
$gradleWrapper = Join-Path $androidDir "gradlew.bat"
$cacheVerifier = Join-Path $repoRoot "scripts\verify_flutter_cache.ps1"
$envFile = Join-Path $mobileDir ".env"

function Assert-RequiredFile {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Required file is missing: $Path"
  }
}

function Invoke-CheckedCommand {
  param(
    [string]$FilePath,
    [string[]]$ArgumentList,
    [string]$WorkingDirectory
  )

  Push-Location $WorkingDirectory
  try {
    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
      throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($ArgumentList -join ' ')"
    }
  } finally {
    Pop-Location
  }
}

foreach ($path in @($flutterWrapper, $dart, $gradleWrapper, $cacheVerifier)) {
  Assert-RequiredFile $path
}

Invoke-CheckedCommand $flutterWrapper @("pub", "get") $mobileDir
Invoke-CheckedCommand $dart @(
  "format",
  "--output=none",
  "--set-exit-if-changed",
  "lib",
  "test",
  "integration_test"
) $mobileDir
Invoke-CheckedCommand $flutterWrapper @("analyze", "--no-pub") $mobileDir
Invoke-CheckedCommand $flutterWrapper @("test", "--no-pub") $mobileDir
Invoke-CheckedCommand $gradleWrapper @(
  ":app:testDebugUnitTest"
) $androidDir

$integrationArguments = @("test")
if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
  $integrationArguments += @("-d", $DeviceId)
}
$integrationArguments += @(
  "integration_test/app_startup_test.dart",
  "--no-pub"
)
Invoke-CheckedCommand $flutterWrapper $integrationArguments $mobileDir

$buildArguments = @("build", "apk", "--debug", "--no-pub")
if (Test-Path -LiteralPath $envFile -PathType Leaf) {
  $buildArguments += "--dart-define-from-file=.env"
}
Invoke-CheckedCommand $flutterWrapper $buildArguments $mobileDir

& $cacheVerifier
if ($LASTEXITCODE -ne 0) {
  throw "Flutter cache verification failed with exit code $LASTEXITCODE."
}

Write-Host "Local mobile verification passed" -ForegroundColor Green
