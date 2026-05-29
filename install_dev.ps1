#!/usr/bin/env pwsh
# smallcode — dev-branch installer
#
# Installs SmallCode from source (scardoso-lu/smallcode) via npm link,
# making 'smallcode', 'smallcode-init', and 'smallcode-rag-index' available
# globally without needing a release tarball.
#
# Usage:
#   .\install_dev.ps1                          # clone + install default branch
#   .\install_dev.ps1 -Branch feature-branch   # specific branch
#   .\install_dev.ps1 -SkipClone               # run from inside the repo already
#
# Requires: Node.js >=18, npm, git

param(
  [string]$Branch    = "claude/agentic-tdd-loop-9M9OP",
  [string]$Repo      = "scardoso-lu/smallcode",
  [string]$CloneDir  = "",
  [switch]$SkipClone
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── Helpers ──────────────────────────────────────────────────────────────────

function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "    WARNING: $msg" -ForegroundColor Yellow }
function Die($msg)  { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

function Require-Command($cmd) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    Die "'$cmd' not found. Please install it and re-run."
  }
}

# ─── Prerequisites ────────────────────────────────────────────────────────────

Step "Checking prerequisites"

Require-Command "node"
Require-Command "npm"
Require-Command "git"

$nodeMajor = (node -e "process.stdout.write(process.versions.node.split('.')[0])") -as [int]
if ($nodeMajor -lt 18) {
  Die "Node.js >=18 is required (found $nodeMajor). Download from https://nodejs.org"
}
Ok "node $(node --version)  npm $(npm --version)  git $(git --version)"

# ─── Locate / clone source ───────────────────────────────────────────────────

if ($SkipClone) {
  # Assume we're already inside the repo
  $repoDir = (Get-Location).Path
  Step "Using current directory: $repoDir"
} else {
  if (-not $CloneDir) {
    $CloneDir = Join-Path $env:USERPROFILE "smallcode-dev"
  }

  if (Test-Path (Join-Path $CloneDir ".git")) {
    Step "Repo already cloned at $CloneDir — fetching latest"
    Push-Location $CloneDir
    git fetch origin 2>&1 | Write-Host
    git checkout $Branch 2>&1 | Write-Host
    git pull origin $Branch 2>&1 | Write-Host
    Pop-Location
  } else {
    Step "Cloning https://github.com/$Repo into $CloneDir"
    git clone --branch $Branch "https://github.com/$Repo" $CloneDir
    Ok "Cloned branch '$Branch'"
  }

  $repoDir = $CloneDir
}

# ─── Install dependencies ────────────────────────────────────────────────────

Step "Installing npm dependencies in $repoDir"
Push-Location $repoDir
npm install --no-fund --no-audit 2>&1 | Write-Host
Ok "Dependencies installed"

# ─── Global link ─────────────────────────────────────────────────────────────

Step "Linking package globally (npm link)"
npm link 2>&1 | Write-Host
Ok "Linked: smallcode, smallcode-init, smallcode-rag-index"
Pop-Location

# ─── .env setup ──────────────────────────────────────────────────────────────

$envTarget = Join-Path $repoDir ".env"
$envExample = Join-Path $repoDir ".env.example"

if (-not (Test-Path $envTarget)) {
  if (Test-Path $envExample) {
    Step "Creating .env from .env.example"
    Copy-Item $envExample $envTarget
    Ok "Created $envTarget"
    Write-Host ""
    Write-Host "  Next: edit $envTarget and set at minimum:" -ForegroundColor Yellow
    Write-Host "    SMALLCODE_MODEL=<your-model-name>" -ForegroundColor Yellow
    Write-Host "    SMALLCODE_BASE_URL=http://localhost:1234/v1" -ForegroundColor Yellow
    Write-Host ""
  }
} else {
  Ok ".env already exists — skipping"
}

# ─── Verify ──────────────────────────────────────────────────────────────────

Step "Verifying installation"
$sc = Get-Command "smallcode" -ErrorAction SilentlyContinue
if ($sc) {
  Ok "smallcode is available at $($sc.Source)"
} else {
  Warn "'smallcode' not found on PATH yet."
  Write-Host "    If npm link succeeded, restart your terminal or run:" -ForegroundColor Yellow
  Write-Host "      `$env:Path = `"`$(npm config get prefix);`$env:Path`"" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==> Done!  Run 'smallcode --help' to get started." -ForegroundColor Cyan
