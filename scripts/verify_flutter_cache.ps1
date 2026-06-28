[CmdletBinding()]
param()

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$mobileDir = Join-Path $repoRoot "apps\mobile"
$expectedPubCache = Join-Path $repoRoot ".toolchains\pub-cache"
$globalPubCache = Join-Path $env:LOCALAPPDATA "Pub\Cache"

$generatedFiles = @(
  Join-Path $mobileDir ".dart_tool\package_config.json"
  Join-Path $mobileDir ".flutter-plugins-dependencies"
)

$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

$expectedPatterns = @(
  $expectedPubCache
  ($expectedPubCache -replace "\\", "/")
)

$unexpectedPatterns = @(
  $globalPubCache
  ($globalPubCache -replace "\\", "/")
)

foreach ($generatedFile in $generatedFiles) {
  if (-not (Test-Path -LiteralPath $generatedFile)) {
    $warnings.Add("생성 파일이 아직 없습니다: $generatedFile")
    continue
  }

  $rawContent = Get-Content -LiteralPath $generatedFile -Raw -Encoding UTF8

  foreach ($unexpectedPattern in $unexpectedPatterns) {
    if ($rawContent.Contains($unexpectedPattern)) {
      $failures.Add("$generatedFile 에 전역 Pub cache 경로가 남아 있습니다: $unexpectedPattern")
      break
    }
  }

  $containsExpectedPattern = $false
  foreach ($expectedPattern in $expectedPatterns) {
    if ($rawContent.Contains($expectedPattern)) {
      $containsExpectedPattern = $true
      break
    }
  }

  if (-not $containsExpectedPattern) {
    $warnings.Add("$generatedFile 에 로컬 Pub cache 경로가 아직 보이지 않습니다.")
  }
}

if ($failures.Count -gt 0) {
  Write-Host "Flutter Pub cache 경로 검증 실패" -ForegroundColor Red
  foreach ($failure in $failures) {
    Write-Host "- $failure" -ForegroundColor Red
  }
  exit 1
}

if ($warnings.Count -gt 0) {
  Write-Host "Flutter Pub cache 경로 검증 경고" -ForegroundColor Yellow
  foreach ($warning in $warnings) {
    Write-Host "- $warning" -ForegroundColor Yellow
  }
}

Write-Host "Flutter Pub cache 경로 검증 통과" -ForegroundColor Green
Write-Host "- 기대 경로: $expectedPubCache"
