#requires -Version 5.1
<###
Searches local file-system drives for Git repositories whose origin URL matches
the allow-list below. It is a dry run unless -Delete is supplied.

Examples:
  .\remove-target-repos.ps1
  .\remove-target-repos.ps1 -Delete
  .\remove-target-repos.ps1 -Delete -Yes

If PowerShell blocks direct execution, use run-remove-target-repos.cmd.
###>

[CmdletBinding()]
param(
    [switch]$Delete,
    [switch]$Yes,
    [string[]]$Root
)

$ErrorActionPreference = 'SilentlyContinue'

$RepoPaths = @(
    'bootcoding-cicd', 'academic-prep-backend', 'academic-admin-backend',
    'email-service', 'academic-admin-frontend', 'academic-prep-frontend',
    'bootcoding-site', 'havet-website', 'havet-website-green',
    'aceint-analytics-backend', 'aceint-analytics-frontend', 'academic-agent',
    'hireskill-frontend', 'hireskill-site', 'student2developer',
    'bootcoding-media', 'data-scripts', 'client-agent', 'job-api'
    
)
$Allowed = @{}
foreach ($name in $RepoPaths) { $Allowed["github.com/devgpt0/$name"] = $true }

$FoundRepos = @{}
$Stats = [ordered]@{
    Entries = 0
    Directories = 0
    GitMetadata = 0
    AccessErrors = 0
}
$ScanTimer = [Diagnostics.Stopwatch]::StartNew()
$script:RootIndex = 0
$script:RootCount = 0

function Write-ScanProgress([switch]$Completed) {
    $percent = 0
    if ($script:RootCount -gt 0) {
        if ($Completed) { $percent = [int](($script:RootIndex / [double]$script:RootCount) * 100) }
        else { $percent = [int](($script:RootIndex - 1) / [double]$script:RootCount * 100) }
    }
    $status = "Roots $script:RootIndex/$script:RootCount | Entries $($Stats.Entries) | Directories $($Stats.Directories) | Git folders $($Stats.GitMetadata)"
    Write-Progress -Activity 'Scanning local computer' -Status $status -PercentComplete $percent
}

function Normalize-Remote([string]$Url) {
    if ([string]::IsNullOrWhiteSpace($Url)) { return $null }
    $u = $Url.Trim().Trim('"').Trim("'")
    $u = $u -replace '^[a-zA-Z][a-zA-Z0-9+.-]*://', ''
    $u = $u -replace '^git@', ''
    $u = $u -replace '^github\.com:', 'github.com/'
    $u = $u.Split('#')[0].Split('?')[0].TrimEnd('/')
    $u = $u -replace '\.git$', ''
    return $u.ToLowerInvariant()
}

function Get-MatchingRemote([string]$ConfigPath) {
    $inRemote = $false
    foreach ($line in (Get-Content -LiteralPath $ConfigPath -ErrorAction SilentlyContinue)) {
        if ($line -match '^\s*\[remote\s+"[^"]+"\]\s*$') { $inRemote = $true; continue }
        if ($line -match '^\s*\[') { $inRemote = $false; continue }
        if ($inRemote -and $line -match '^\s*url\s*=\s*(.+?)\s*$') {
            $normalized = Normalize-Remote $Matches[1]
            if ($Allowed.ContainsKey($normalized)) { return $normalized }
        }
    }
    return $null
}

function Find-GitMetadata([System.IO.DirectoryInfo]$Directory) {
    try { $items = $Directory.EnumerateFileSystemInfos() }
    catch { $Stats.AccessErrors++; return }
    foreach ($item in $items) {
        $Stats.Entries++
        if ($item -is [System.IO.DirectoryInfo]) { $Stats.Directories++ }
        if (($Stats.Entries % 1000) -eq 0) {
            Write-ScanProgress
            Write-Host ("  Progress: {0:N0} entries scanned, {1:N0} directories, {2:N0} access errors" -f $Stats.Entries, $Stats.Directories, $Stats.AccessErrors) -ForegroundColor DarkGray
        }
        if ($item.Name -eq '.git') { $item.FullName; continue }
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
        if ($item -is [System.IO.DirectoryInfo]) { Find-GitMetadata $item }
    }
}

if (-not $Root) {
    $Root = @(Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Root })
}

$script:RootCount = @($Root).Count
Write-Host "`nTarget repositories to check ($($RepoPaths.Count)):`n" -ForegroundColor Cyan
foreach ($name in $RepoPaths) { Write-Host "  [CHECKING] https://github.com/devgpt0/$name.git" -ForegroundColor DarkCyan }
Write-Host "`nScanning $script:RootCount local file-system root(s). Progress is shown by root and filesystem entries; exact byte percentages are not meaningful for directory scans.`n" -ForegroundColor Cyan

$script:RootIndex = 0
foreach ($r in $Root) {
    $script:RootIndex++
    if (-not (Test-Path -LiteralPath $r -PathType Container)) { continue }
    Write-Host "[ROOT $script:RootIndex/$script:RootCount] Scanning $r" -ForegroundColor White
    Write-ScanProgress
    foreach ($gitPath in (Find-GitMetadata ([IO.DirectoryInfo]$r))) {
        $Stats.GitMetadata++
        $gitItem = Get-Item -LiteralPath $gitPath -Force
        if ($gitItem -is [IO.DirectoryInfo]) { $config = Join-Path $gitPath 'config' }
        else { $config = Join-Path (Split-Path $gitPath) 'config' }
        if (-not (Test-Path -LiteralPath $config -PathType Leaf)) { continue }
        $remote = Get-MatchingRemote $config
        if ($remote) {
            $repoDir = Split-Path $gitPath -Parent
            if (-not $FoundRepos.ContainsKey($repoDir)) {
                $FoundRepos[$repoDir] = $remote
                Write-Host "  [FOUND] $remote at $repoDir" -ForegroundColor Green
            }
        }
    }
    Write-ScanProgress -Completed
    Write-Host "[ROOT $script:RootIndex/$script:RootCount] Complete: $r" -ForegroundColor White
}

$ScanTimer.Stop()
Write-Progress -Activity 'Scanning local computer' -Completed

Write-Host "`nScan summary:" -ForegroundColor Cyan
Write-Host ("  Elapsed: {0:g}" -f $ScanTimer.Elapsed)
Write-Host ("  Filesystem entries scanned: {0:N0}" -f $Stats.Entries)
Write-Host ("  Directories scanned: {0:N0}" -f $Stats.Directories)
Write-Host ("  Git metadata folders checked: {0:N0}" -f $Stats.GitMetadata)
Write-Host ("  Access errors/skipped areas: {0:N0}" -f $Stats.AccessErrors)

Write-Host "`nRepository status:`n" -ForegroundColor Cyan
foreach ($name in $RepoPaths) {
    $key = "github.com/devgpt0/$name"
    $paths = @($FoundRepos.GetEnumerator() | Where-Object { $_.Value -eq $key } | ForEach-Object { $_.Key })
    if ($paths.Count -gt 0) {
        Write-Host "  [PRESENT] $name" -ForegroundColor Green
        foreach ($path in $paths) { Write-Host "             $path" -ForegroundColor DarkGreen }
    } else {
        Write-Host "  [NOT FOUND] $name" -ForegroundColor Yellow
    }
}

if ($FoundRepos.Count -eq 0) {
    Write-Host "`nNo matching repositories were found." -ForegroundColor Yellow
    exit 0
}

Write-Host "`nMatching repository folders ($($FoundRepos.Count)):`n" -ForegroundColor Yellow
$FoundRepos.GetEnumerator() | Sort-Object Name | ForEach-Object { Write-Host "[$($_.Value)] $($_.Key)" }

if (-not $Delete) {
    Write-Host "`nDry run only. Re-run with -Delete to remove these folders." -ForegroundColor Cyan
    exit 0
}
if (-not $Yes) {
    $answer = Read-Host "`nType DELETE to permanently remove these folders"
    if ($answer -cne 'DELETE') { Write-Host 'Cancelled.'; exit 0 }
}

foreach ($repoDir in @($FoundRepos.Keys)) {
    try {
        Remove-Item -LiteralPath $repoDir -Recurse -Force -ErrorAction Stop
        Write-Host "Removed: $repoDir" -ForegroundColor Green
    } catch { Write-Warning "Could not remove $repoDir : $($_.Exception.Message)" }
}
