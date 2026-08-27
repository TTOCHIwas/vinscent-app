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

  & $npx "--yes" $supabasePackage @ArgumentList
  if ($LASTEXITCODE -ne 0) {
    throw "Supabase command failed with exit code ${LASTEXITCODE}: $($ArgumentList -join ' ')"
  }
}

Push-Location $repoRoot
try {
  & $npx "--yes" $supabasePackage "status" "--output" "json" *> $null
  $stackWasRunning = $LASTEXITCODE -eq 0

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
