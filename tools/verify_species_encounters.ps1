param([string]$GodotPath = 'D:/Godot/Godot_v4.7.2-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw "Godot executable not found: $GodotPath" }
$runName = 'encounters-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,6)
$reportPath = Join-Path (Split-Path $projectPath -Parent) ('verification/' + $runName)
New-Item -ItemType Directory -Path $reportPath -Force | Out-Null
$cases = @(
    @{ Species = 'mossback'; Script = 'replay_tactical.gd' },
    @{ Species = 'thornhorn'; Script = 'replay_flank_tactics.gd' },
    @{ Species = 'reedclaw'; Script = 'replay_flank_tactics.gd' },
    @{ Species = 'mistfrill'; Script = 'replay_weakpoints.gd' },
    @{ Species = 'stormcrest'; Script = 'replay_weakpoints.gd' }
)
$reports = @()
$sourceRevision = (git -C $projectPath rev-parse HEAD).Trim()
$sourceDirty = [bool](git -C $projectPath status --porcelain --untracked-files=no)
foreach ($case in $cases) {
    $arguments = @('--headless','--path',$projectPath,'--fixed-fps','60','--script',('res://tests/' + $case.Script),'--quit-after','8500','--',('--species=' + $case.Species),'--require-weakness')
    $lines = @(& $GodotPath @arguments 2>&1 | ForEach-Object { "$_" })
    $code = $LASTEXITCODE
    $log = Join-Path $reportPath ($case.Species + '.log')
    $lines | Set-Content -LiteralPath $log -Encoding utf8
    # Read only this execution's console output, never a stale result file.
    $resultLine = @($lines | Where-Object { $_ -match '^(ENCOUNTER_REPLAY|WEAKPOINT_REPLAY): ' } | Select-Object -Last 1)
    $result = $null
    if ($resultLine.Count -eq 1) {
        try { $result = ($resultLine[0] -replace '^[A-Z_]+: ','') | ConvertFrom-Json } catch { $result = $null }
    }
    $runtimeErrors = @($lines | Where-Object { $_ -match 'SCRIPT ERROR:|^ERROR:|^FAIL:' })
    $passed = $code -eq 0 -and $runtimeErrors.Count -eq 0 -and $null -ne $result -and $result.species -eq $case.Species -and $result.passed -eq $true -and $result.outcome -eq 'victory' -and $result.monster_health -le 0 -and $result.contacts -gt 0 -and $result.weak_contacts -gt 0
    $controllerPath = Join-Path $projectPath ('tests/' + $case.Script)
    $reports += [pscustomobject]@{ species = $case.Species; passed = $passed; exit_code = $code; runtime_errors = $runtimeErrors; controller = $case.Script; controller_sha256 = (Get-FileHash -LiteralPath $controllerPath -Algorithm SHA256).Hash; result = $result; log = $log }
    Write-Output ($case.Species + ': ' + $(if ($passed) { 'PASS' } else { 'FAIL - see ' + $log }))
}
$allPassed = @($reports | Where-Object { -not $_.passed }).Count -eq 0
$summary = [pscustomobject]@{
    passed = $allPassed
    source_revision = $sourceRevision
    tracked_changes_present = $sourceDirty
    harness_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
    scope = 'Five separate live single-monster fights with privileged state-aware controllers; ordinary movement and combat requests; not human difficulty, multi-enemy, or final animation acceptance.'
    cases = $reports
}
$summaryFile = Join-Path $reportPath 'summary.json'
$summary | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $summaryFile -Encoding utf8
Write-Output ('ENCOUNTER_SUITE_REPORT: ' + $summaryFile)
if (-not $allPassed) { exit 1 }
