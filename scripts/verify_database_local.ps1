[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$npxCommand = Get-Command npx.cmd -ErrorAction SilentlyContinue
if ($null -eq $npxCommand) {
  throw "npx.cmd is required to run the pinned Supabase CLI."
}

$npx = $npxCommand.Source
$supabasePackage = "supabase@2.109.1"
$startedByScript = $false
$verificationFailure = $null
$cleanupFailure = $null

function Invoke-SupabaseChecked {
  param([string[]]$ArgumentList)

  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    & $npx "--yes" $supabasePackage @ArgumentList
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

  if ($exitCode -ne 0) {
    throw "Supabase command failed with exit code ${exitCode}: $($ArgumentList -join ' ')"
  }
}

Push-Location $repoRoot
try {
  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    & $npx "--yes" $supabasePackage "status" "--output" "json" *> $null
    $statusExitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  $stackWasRunning = $statusExitCode -eq 0

  if (-not $stackWasRunning) {
    Invoke-SupabaseChecked @("db", "start")
    $startedByScript = $true
  }

  Invoke-SupabaseChecked @("db", "reset", "--local", "--no-seed")
  Invoke-SupabaseChecked @("test", "db")
  Invoke-SupabaseChecked @("db", "lint", "--local", "--level", "error")
} catch {
  $verificationFailure = $_
} finally {
  if ($startedByScript) {
    try {
      Invoke-SupabaseChecked @("stop", "--no-backup")
    } catch {
      $cleanupFailure = $_
    }
  }
  Pop-Location
}

if ($null -ne $verificationFailure) {
  throw $verificationFailure
}
if ($null -ne $cleanupFailure) {
  throw $cleanupFailure
}

Write-Host "Local database verification passed" -ForegroundColor Green
