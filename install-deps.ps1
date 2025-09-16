# install-deps.ps1 — unified dependency installer (Windows, ASCII-only)
[CmdletBinding()]
param(
  [switch]$InstallPgAdmin  # add -InstallPgAdmin to also install pgAdmin
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Ensure-Admin {
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
    IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
  if (-not $isAdmin) { throw 'Run this script as Administrator.' }
}

function Ensure-Winget {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found. Install 'App Installer' from the Microsoft Store, then rerun."
  }
}

function Test-PackageInstalled {
  param([string]$Id)
  $out = & winget list -e --id $Id 2>$null
  if ($LASTEXITCODE -eq 0 -and $out) { return $true } else { return $false }
}

function Install-Winget {
  param(
    [string]$Id,
    [string]$Name,
    [string]$Override = $null
  )
  if (Test-PackageInstalled -Id $Id) {
    Write-Host ("Already installed: {0}" -f $Id)
    return
  }
  Write-Host ("Installing {0} ..." -f $Name)
  $args = @('install','-e','--id',$Id,'--accept-source-agreements','--accept-package-agreements','--silent')
  if ($Override) { $args += @('--override', $Override) }
  & winget @args
  if ($LASTEXITCODE -ne 0) { throw ("winget failed installing {0} (exit {1})" -f $Name, $LASTEXITCODE) }
}

function Get-VSWherePath {
  $candidates = @(
    "$Env:ProgramFiles(x86)\Microsoft Visual Studio\Installer\vswhere.exe",
    "$Env:ProgramFiles\Microsoft Visual Studio\Installer\vswhere.exe"
  )
  foreach ($p in $candidates) { if (Test-Path $p) { return $p } }
  return $null
}

# Repo root where this script lives
$RepoRoot = $PSScriptRoot

function Test-PortableOBS {
  param([string]$Root)
  $candidates = @(
    (Join-Path $Root 'obs\bin\64bit\obs64.exe'),
    (Join-Path $Root 'Obs\bin\64bit\obs64.exe') # case-variation safety
  )
  foreach ($p in $candidates) { if (Test-Path $p) { return $p } }
  return $null
}

function Test-VSHasVCTools {
  # Returns $true if any VS 2022 instance has the C++ toolchain.
  # 1) Preferred: vswhere with VC Tools component ID
  # 2) Fallback: probe for vcvarsall.bat or cl.exe in VS 2022 trees
  $vswhere = Get-VSWherePath
  if ($vswhere) {
    try {
      $json = & $vswhere -products * `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -version '[17.0,18.0)' -format json 2>$null
      if ($LASTEXITCODE -eq 0 -and $json) {
        $items = $json | ConvertFrom-Json
        if ($items -and $items.Count -ge 1) { return $true }
      }
    } catch { }
  }

  $roots = @("$Env:ProgramFiles\Microsoft Visual Studio\2022",
             "$Env:ProgramFiles(x86)\Microsoft Visual Studio\2022")
  $editions = @('BuildTools','Community','Professional','Enterprise')

  foreach ($r in $roots) {
    foreach ($e in $editions) {
      $base = Join-Path $r $e
      if (Test-Path $base) {
        $vcvars = Join-Path $base 'VC\Auxiliary\Build\vcvarsall.bat'
        if (Test-Path $vcvars) { return $true }
        $clGlob = Join-Path $base 'VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe'
        if (Get-ChildItem -Path $clGlob -ErrorAction SilentlyContinue) { return $true }
      }
    }
  }
  return $false
}

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------

Ensure-Admin
Ensure-Winget

# If sources are broken, try to repair
try {
  winget source list > $null 2>&1
  if ($LASTEXITCODE -ne 0) {
    winget source reset --force
    winget source update
  }
} catch { }

Write-Host '=== Installing prerequisites ==='

# Python 3.13 + Python Launcher (py.exe in C:\Windows)
Install-Winget -Id 'Python.Python.3.13' -Name 'Python 3.13'
Install-Winget -Id 'Python.Launcher'    -Name 'Python Launcher (py.exe)'

# NVM for Windows
Install-Winget -Id 'CoreyButler.NVMforWindows' -Name 'NVM for Windows'

# If Node not present and NVM missing (rare), install Node LTS as a backup
try {
  $haveNode = (Get-Command node -ErrorAction SilentlyContinue) -ne $null
  $haveNvm  = (Get-Command nvm  -ErrorAction SilentlyContinue) -ne $null
  if (-not $haveNode -and -not $haveNvm) {
    Install-Winget -Id 'OpenJS.NodeJS.LTS' -Name 'Node.js LTS'
  }
} catch { }

# OBS Studio (skip if portable OBS is bundled in the repo)
$portableObs = Test-PortableOBS -Root $RepoRoot
if ($portableObs) {
  Write-Host "OBS portable detected at: $portableObs"
  Write-Host "Skipping winget OBS install."
} else {
  Install-Winget -Id 'OBSProject.OBSStudio' -Name 'OBS Studio'
}

# PostgreSQL (prefer 17, then fall back)
$pgIds = @(
  'PostgreSQL.PostgreSQL.17',
  'PostgreSQL.PostgreSQL16',
  'PostgreSQL.PostgreSQL15',
  'PostgreSQL.PostgreSQL',
  'EDB.PostgreSQL'
)
$pgInstalled = $false
foreach ($pgId in $pgIds) {
  try {
    $out = winget show -e --id $pgId 2>$null
    if ($LASTEXITCODE -eq 0 -and $out) {
      Install-Winget -Id $pgId -Name ("PostgreSQL ({0})" -f $pgId)
      $pgInstalled = $true
      break
    }
  } catch { }
}
if (-not $pgInstalled) {
  Write-Warning 'PostgreSQL package not found in winget sources. You can:'
  Write-Warning ' - Run: winget source reset --force; winget source update; winget search PostgreSQL'
  Write-Warning ' - Or install PostgreSQL manually and rerun install-deps.ps1'
}

# Optional: pgAdmin
if ($InstallPgAdmin) {
  try {
    $pgAdminId = 'PostgreSQL.pgAdmin'
    $out = winget show -e --id $pgAdminId 2>$null
    if ($LASTEXITCODE -eq 0 -and $out) {
      Install-Winget -Id $pgAdminId -Name 'pgAdmin'
    } else {
      Write-Warning 'pgAdmin package not found in winget sources.'
    }
  } catch {
    Write-Warning ("pgAdmin installation attempt failed: {0}" -f $_.Exception.Message)
  }
}

# Visual Studio 2022 Build Tools (C++ toolchain)
if (Test-VSHasVCTools) {
  Write-Host 'Visual Studio 2022 C++ toolchain detected — skipping install.'
} else {
  $vsId = 'Microsoft.VisualStudio.2022.BuildTools'
  $vsOverride = '--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --passive --norestart'
  Install-Winget -Id $vsId -Name 'VS 2022 Build Tools (C++)' -Override $vsOverride
}

Write-Host ''
Write-Host '=== Verifications ==='

# Python
try {
  $pyv = & py -3 --version 2>$null
  if (-not $pyv) { $pyv = & python --version 2>$null }
  if ($pyv) { Write-Host ("Python: {0}" -f $pyv) } else { Write-Warning 'Python not on PATH yet.' }
} catch {
  Write-Warning 'Python not detected on PATH.'
}

# Node
try {
  $nv = & node --version 2>$null
  if ($nv) { Write-Host ("Node: {0}" -f $nv) } else { Write-Warning 'Node not on PATH yet.' }
} catch {
  Write-Warning 'Node not detected on PATH.'
}

# OBS WebSocket (built-in since OBS 28)
$obsDll = Join-Path ${env:ProgramFiles} 'obs-studio\obs-plugins\64bit\obs-websocket.dll'
if ($portableObs) {
  Write-Host 'Using portable OBS; configure WebSocket in OBS (Tools -> WebSocket Server Settings, default port 4455).'
} elseif (Test-Path $obsDll) {
  Write-Host 'OBS WebSocket detected (Tools -> WebSocket Server Settings, default port 4455).'
} else {
  Write-Warning 'OBS installed, but WebSocket DLL not found yet. After first launch, check Tools -> WebSocket.'
}

Write-Host ''
Write-Host 'All prerequisite installations attempted.'
exit 0
