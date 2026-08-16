[CmdletBinding()]
param([string]$Path = (Get-Location).Path, [ValidateSet('greenfield','brownfield','')][string]$Basket = '', [switch]$Upgrade)
$ErrorActionPreference = 'Stop'
$engine = Join-Path $PSScriptRoot 'src\covenantwin.py'
if (-not (Get-Command python -ErrorAction SilentlyContinue)) { throw 'Python 3.9+ is required on PATH.' }

Write-Host ""
Write-Host "-----------------------------------------------------------"
if ($Upgrade) {
    Write-Host " Covenant Governance Framework (Windows) - Upgrade"
} else {
    Write-Host " Covenant Governance Framework (Windows) - Installer"
}
Write-Host "-----------------------------------------------------------"
Write-Host ""

if ($Upgrade) {
    & python $engine upgrade $Path
    exit $LASTEXITCODE
}

if ([string]::IsNullOrEmpty($Basket)) {
    Write-Host "Which type of repository is this?"
    Write-Host "  [g] Greenfield - new project, no prior history"
    Write-Host "  [b] Brownfield - existing repository with code"
    Write-Host ""
    $answer = Read-Host "Enter g or b"
    switch -Regex ($answer) {
        '^(g|green|greenfield)$' { $Basket = 'greenfield' }
        '^(b|brown|brownfield)$' { $Basket = 'brownfield' }
        default { throw "Invalid input '$answer'. Enter 'g' or 'b', or pass -Basket greenfield|brownfield." }
    }
}

& python $engine install $Path --basket $Basket
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "-----------------------------------------------------------"
Write-Host " Remaining steps - required to complete setup:"
Write-Host "-----------------------------------------------------------"
Write-Host ""
Write-Host "  1. Open Claude Code in this directory:  claude"
Write-Host "  2. Run the init command:  /init-governance"
Write-Host "     Claude Code will interrogate you about your stack, draft governance"
Write-Host "     docs for your approval, and generate CLAUDE.md + enforcement hooks."
Write-Host "  3. Edit .github/CODEOWNERS (replace the placeholder team) and enable"
Write-Host "     'Require review from Code Owners' branch protection on GitHub."
Write-Host "     Until that's done, every control this installs is LOCAL-ONLY."
Write-Host ""
exit 0
