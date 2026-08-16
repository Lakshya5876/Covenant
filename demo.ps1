# demo.ps1 - watch Covenant's core loop end to end on Windows, on a disposable
# copy of examples/demo-repo. No install into your real projects.
#
#   Covenant analyzes a repo -> governance is established -> an AI/developer makes
#   a violating change -> Covenant catches it and explains why -> the change is
#   fixed -> Covenant verifies the repo is compliant again.
#
# Usage: .\demo.ps1   (run from anywhere inside the Covenant repo)
$ErrorActionPreference = 'Stop'

function Step($msg) { Write-Host ""; Write-Host "> $msg" -ForegroundColor Cyan }
function Note($msg) { Write-Host "  $msg" -ForegroundColor Yellow }
function Pause() { Read-Host "  Press Enter to continue" | Out-Null }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DemoSrc = Join-Path $ScriptDir 'examples\demo-repo'
$InstallPs1 = Join-Path $ScriptDir 'CovenantWin\install.ps1'

if (-not (Test-Path -LiteralPath $DemoSrc)) { throw "Demo source not found at $DemoSrc" }
if (-not (Test-Path -LiteralPath $InstallPs1)) { throw "install.ps1 not found at $InstallPs1" }

$WorkDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
$DemoRepo = Join-Path $WorkDir 'billing-service'
New-Item -ItemType Directory -Path $WorkDir | Out-Null
Copy-Item -Recurse -Path $DemoSrc -Destination $DemoRepo

Write-Host ""
Write-Host "===============================================================" -ForegroundColor White
Write-Host " Covenant demo - a fresh copy of a small billing service is at:"
Write-Host "   $DemoRepo"
Write-Host "===============================================================" -ForegroundColor White

Step "Step 1 - Initialize the target repo (this is YOUR repo in real usage)"
Set-Location $DemoRepo
git init -q -b main
git config user.email "demo@example.test"
git config user.name "Covenant Demo"
git add -A
git commit -q -m "chore: initial billing service"
git checkout -q -b chore/claude-init
Note "Created $DemoRepo, committed the starting code on 'main', and switched to a setup branch."
Pause

Step "Step 2 - Install Covenant (choose [g] greenfield when prompted)"
Note "This is the real installer - same one you'd run against your own project."
& $InstallPs1
if ($LASTEXITCODE -ne 0) { throw "install.ps1 failed with exit code $LASTEXITCODE" }
Note "Governance installed: git hooks, trust-root lockdown, CI backstop, /init-governance command."
# In real usage, /init-governance (an interactive Claude Code command) asks about
# your stack and fills .claude/covenant_state.json's `commands` block - this demo
# skips that step for a fast walkthrough, so it fills the one command Step 4 below
# actually needs itself: covenantwin.py fails closed (blocks) on a source-file
# commit with no test command configured at all, same as covenant.sh's own
# dynamic stack inference would already have found via this repo's
# requirements.txt on macOS/Linux. Never actually invoked in this demo (tests are
# opt-in at commit, not forced), so it doesn't matter that pytest may not be
# installed on this machine - only that a command is configured.
$statePath = '.claude\covenant_state.json'
$state = Get-Content $statePath -Raw | ConvertFrom-Json
$state.commands.test = 'pytest'
# Windows PowerShell 5.1's `-Encoding utf8` always writes a BOM (there is no
# utf8NoBOM option before PS 6) - and covenantwin.py's json.loads() rejects a
# BOM-prefixed file outright (Python's 'utf-8' codec doesn't strip it),
# silently falling back to a fresh default state (see covenantwin.py's load()
# swallowing JSONDecodeError). That silently threw away the commands.test
# value this block exists to set - found by running this demo end to end,
# not by inspection: Step 4 below then still "succeeded" only because it
# never checked its own exit code either (fixed below). Write raw bytes with
# an explicit no-BOM UTF8Encoding instead.
$json = $state | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText((Resolve-Path $statePath), $json, (New-Object System.Text.UTF8Encoding($false)))
Pause

Step "Step 3 - Simulate an AI making a violating change (a leaked credential)"
Add-Content -Path 'src\infrastructure\billing_repository.py' -Value "`n# TODO: remove before merging`nSTRIPE_API_KEY = `"hardcoded-secret-do-not-commit-9f8e7d6c5b4a3210`"`n"
git add src/infrastructure/billing_repository.py
Note "Staged a change that hardcodes a live-looking API key. Attempting to commit it..."
Write-Host ""
git commit -m "feat: wire up Stripe key for billing"
$commitExit = $LASTEXITCODE
Write-Host ""
if ($commitExit -eq 0) {
    Note "Unexpected: the commit succeeded. Covenant's secrets scan should have blocked this - please report this as a bug."
} else {
    Write-Host "  ^ That's Covenant blocking the commit and explaining exactly what's wrong - no LLM call, just a deterministic pre-commit hook." -ForegroundColor Green
}
Pause

Step "Step 4 - Fix it, and watch Covenant verify the repo again"
git reset -q HEAD src/infrastructure/billing_repository.py
git checkout -q -- src/infrastructure/billing_repository.py
Note "Reverted the leaked key. Committing the same intent without the credential..."
Add-Content -Path 'src\infrastructure\billing_repository.py' -Value "`n# Stripe key is read from the environment, never hardcoded.`n"
git add src/infrastructure/billing_repository.py
git commit -m "feat: document Stripe key handling"
$fixCommitExit = $LASTEXITCODE
Write-Host ""
# Unlike Step 3, this previously printed a success message unconditionally,
# regardless of whether the commit actually went through - a real bug found
# by running this demo end to end: if this "fix" commit was itself
# (unexpectedly) blocked, the demo would still claim Covenant verified and
# passed it, a textbook false sense of protection. Never claim a pass this
# script didn't actually observe.
if ($fixCommitExit -eq 0) {
    Write-Host "  ^ Covenant verified the repo is compliant again and let the commit through." -ForegroundColor Green
} else {
    Write-Host "  ^ Unexpected: this commit should have passed (the credential was removed) but Covenant blocked it - please report this as a bug, and see the COVENANT BLOCK output above for why." -ForegroundColor Red
    throw "Step 4's fix commit was blocked (exit $fixCommitExit) - see output above."
}
Pause

Step "Step 5 - The audit trail this left behind"
if (Test-Path '.claude\covenant_state.json') {
    $state = Get-Content '.claude\covenant_state.json' -Raw | ConvertFrom-Json
    $receiptCount = ($state.receipts | Get-Member -MemberType NoteProperty | Measure-Object).Count
    Note "covenant_state.json now has $receiptCount passing-commit receipt(s) - a tree-keyed record pre-push can fast-path against."
}
Write-Host ""
Write-Host "Done." -ForegroundColor White
Write-Host "The demo repo is left at $DemoRepo if you want to explore further - open Claude"
Write-Host "Code there and run /init-governance for real (it'll interrogate you about the"
Write-Host "stack and generate CLAUDE.md)."
Write-Host ""
