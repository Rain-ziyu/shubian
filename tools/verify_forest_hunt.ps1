param([string]$GodotPath = 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe',[switch]$RequireWeakness)
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runName = 'forest-hunt-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,6)
$reportPath = Join-Path (Split-Path $projectPath -Parent) ('verification/' + $runName)
New-Item -ItemType Directory -Path $reportPath -Force | Out-Null
$revision = (git -C $projectPath rev-parse HEAD).Trim()
$dirty = [bool](git -C $projectPath status --porcelain --untracked-files=no)
$controller = Join-Path $projectPath 'tests/replay_forest_hunt.gd'
$engineLog = Join-Path $reportPath 'engine.log'
$engineArguments = @('--headless','--path',$projectPath,'--fixed-fps','60','--script',$controller,'--log-file',$engineLog,'--quit-after','40000')
if ($RequireWeakness) { $engineArguments += @('--','--weakness-tactics','--require-weakness') }
$lines = @(& $GodotPath @engineArguments 2>&1 | ForEach-Object {
    $line = "$_"
    if ($line -match '^FOREST_HUNT_TARGET:|^FOREST_HUNT_DAMAGE:|^FOREST_HUNT_PROGRESS:') { Write-Host $line }
    $line
})
$code = $LASTEXITCODE
$lines | Set-Content -LiteralPath (Join-Path $reportPath 'run.log') -Encoding utf8
$result = $null
$resultLines = @($lines | Where-Object { $_ -match '^FOREST_HUNT: ' })
if ($resultLines.Count -eq 1) {
    try { $result = ($resultLines[0] -replace '^FOREST_HUNT: ','') | ConvertFrom-Json } catch { $result = $null }
}
$runtimeErrors = @($lines | Where-Object { $_ -match 'SCRIPT ERROR:|^ERROR:|^FAIL:' })
$species = @('mossback','thornhorn','mistfrill','reedclaw','stormcrest')
$encounterSpecies = @($result.encounters | ForEach-Object { $_.species } | Sort-Object -Unique)
$missing = @($species | Where-Object { $_ -notin $encounterSpecies })
$passed = $code -eq 0 -and $runtimeErrors.Count -eq 0 -and $null -ne $result -and $result.passed -eq $true -and $result.player_health -gt 0 -and $result.distance_walked -gt 100 -and $result.encounters.Count -eq 5 -and $missing.Count -eq 0
$missingWeakness = $species
if ($null -ne $result -and $null -ne $result.weak_contacts) {
    $missingWeakness = @($species | Where-Object { [int]($result.weak_contacts.PSObject.Properties[$_].Value) -le 0 })
}
if ($RequireWeakness -and ($missingWeakness.Count -gt 0 -or $result.weakness_tactics -ne $true)) { $passed = $false }
$summary = [pscustomobject]@{
    passed = $passed
    source_revision = $revision
    tracked_changes_present = $dirty
    controller_sha256 = (Get-FileHash -LiteralPath $controller -Algorithm SHA256).Hash
    harness_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
    exit_code = $code
    runtime_errors = $runtimeErrors
    weakness_required = [bool]$RequireWeakness
    missing_weakness = $missingWeakness
    result = $result
}
$summaryFile = Join-Path $reportPath 'summary.json'
$summary | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $summaryFile -Encoding utf8
Write-Output ('FOREST_HUNT_REPORT: ' + $summaryFile)
Write-Output ('FOREST_HUNT_STATUS: ' + $(if ($passed) { 'PASS' } else { 'FAIL' }))
if (-not $passed) { exit 1 }
