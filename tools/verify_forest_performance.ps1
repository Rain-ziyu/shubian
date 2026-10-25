param([string]$GodotPath = 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runName = 'forest-realtime-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,6)
$reportPath = Join-Path (Split-Path $projectPath -Parent) ('verification/' + $runName)
New-Item -ItemType Directory -Path $reportPath -Force | Out-Null
$revision = (git -C $projectPath rev-parse HEAD).Trim()
$dirty = [bool](git -C $projectPath status --porcelain --untracked-files=no)
$benchmark = Join-Path $projectPath 'tools/benchmark_forest_hunt.gd'
$controller = Join-Path $projectPath 'tests/replay_forest_hunt.gd'
$engineLog = Join-Path $reportPath 'engine.log'
$lines = @(& $GodotPath --path $projectPath --script $benchmark --log-file $engineLog 2>&1 | ForEach-Object {
    $line = "$_"
    if ($line -match '^FOREST_HUNT_TARGET:|^FOREST_HUNT_DAMAGE:') { Write-Host $line }
    $line
})
$code = $LASTEXITCODE
$lines | Set-Content -LiteralPath (Join-Path $reportPath 'run.log') -Encoding utf8
function Read-Result([string]$prefix) {
    $matches = @($lines | Where-Object { $_.StartsWith($prefix) })
    if ($matches.Count -ne 1) { return $null }
    try { return $matches[0].Substring($prefix.Length) | ConvertFrom-Json } catch { return $null }
}
$hunt = Read-Result 'FOREST_HUNT: '
$performance = Read-Result 'FOREST_PERFORMANCE: '
$runtimeErrors = @($lines | Where-Object { $_ -match 'SCRIPT ERROR:|^ERROR:|^FAIL:' })
$huntPassed = $code -eq 0 -and $runtimeErrors.Count -eq 0 -and $null -ne $hunt -and $hunt.passed -eq $true -and $hunt.encounters.Count -eq 5 -and $hunt.player_health -gt 0
# Local 60 FPS target: retain every slow frame in the report, including startup.
# The steady-state budget excludes only the first two seconds after scene setup.
$steady = $performance.after_two_seconds
$budgetMet = $null -ne $performance -and $steady.frames -gt 0 -and $steady.p99_ms -le 16.67 -and $steady.over_33ms -eq 0
$summary = [pscustomobject]@{
    passed = $huntPassed -and $budgetMet
    hunt_passed = $huntPassed
    local_frame_budget_met = $budgetMet
    source_revision = $revision
    tracked_changes_present = $dirty
    controller_sha256 = (Get-FileHash -LiteralPath $controller -Algorithm SHA256).Hash
    benchmark_sha256 = (Get-FileHash -LiteralPath $benchmark -Algorithm SHA256).Hash
    harness_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
    exit_code = $code
    runtime_errors = $runtimeErrors
    performance = $performance
    result = $hunt
    scope = 'Native 1280x720 uncapped whole-map hunt, five AI active, continuous resources; local hardware and state-aware controller, not human difficulty or final animation acceptance.'
}
$summaryFile = Join-Path $reportPath 'summary.json'
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryFile -Encoding utf8
Write-Output ('FOREST_REALTIME_REPORT: ' + $summaryFile)
Write-Output ('FOREST_REALTIME_STATUS: ' + $(if ($summary.passed) { 'PASS' } else { 'FAIL' }))
if (-not $summary.passed) { exit 1 }
