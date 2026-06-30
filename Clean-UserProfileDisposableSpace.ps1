[CmdletBinding()]
param(
  [switch]$Execute,
  [switch]$AllowTestProfileRoot,
  [int]$MinAgeDays = 0,
  [string]$ProfileRoot = $env:USERPROFILE,
  [string]$LogRoot = $null
)
if ([string]::IsNullOrWhiteSpace($LogRoot)) { $LogRoot = Join-Path $PSScriptRoot 'logs' }
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
function Full([string]$p) { try { [IO.Path]::GetFullPath($p).TrimEnd('\') } catch { $null } }
function SizeOf([string]$p) { if (!(Test-Path -LiteralPath $p)) { return 0L }; $n = 0L; Get-ChildItem -LiteralPath $p -Force -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $n += $_.Length }; $n }
function Human([long]$b) { if ($b -ge 1GB) { '{0:N2} GB' -f ($b / 1GB) } elseif ($b -ge 1MB) { '{0:N2} MB' -f ($b / 1MB) } elseif ($b -ge 1KB) { '{0:N2} KB' -f ($b / 1KB) } else { "$b B" } }
$Profile = Full $ProfileRoot
if (!$Profile -or !(Test-Path -LiteralPath $Profile)) { throw "ProfileRoot not found: $ProfileRoot" }
if (!$AllowTestProfileRoot -and $Profile -ne (Full $env:USERPROFILE)) { throw "Refusing to clean anything except current profile: $env:USERPROFILE" }
$stamp = Get-Date -Format yyyyMMdd-HHmmss
$run = Join-Path $LogRoot $stamp
New-Item -ItemType Directory -Force -Path $run | Out-Null
$csv = Join-Path $run cleanup-summary.csv
$log = Join-Path $run cleanup-transcript.log
$protected = @('Documents','Desktop','Downloads','Pictures','Videos','Music','Saved Games','.ssh','.aws','.azure','.docker','.codex\skills','.codex\plugins','.codex\memories','.agents') | ForEach-Object { (Full (Join-Path $Profile $_)) + '\' }
$exact = @('NTUSER.DAT','.gitconfig','.codex\config.toml','.codex\auth.json') | ForEach-Object { Full (Join-Path $Profile $_) }
$results = New-Object System.Collections.Generic.List[object]
function IsProtected([string]$p) {
  $f = Full $p
  if (!$f) { return $true }
  foreach ($x in $exact) { if ($f -ieq $x) { return $true } }
  foreach ($x in $protected) { if ($f.StartsWith($x, [StringComparison]::OrdinalIgnoreCase)) { return $true } }
  return $false
}
function CleanDir([string]$p, [string]$why) {
  if (!(Test-Path -LiteralPath $p)) { return }
  $f = Full $p
  if (!$f.StartsWith($Profile + '\', [StringComparison]::OrdinalIgnoreCase)) { Write-Warning "skip outside profile $f"; return }
  if (IsProtected $f) { Write-Warning "skip protected $f"; return }
  $before = SizeOf $f
  $cut = (Get-Date).AddDays(-1 * $MinAgeDays)
  Get-ChildItem -LiteralPath $f -Force -ErrorAction SilentlyContinue | ForEach-Object {
    if ($MinAgeDays -gt 0 -and $_.LastWriteTime -gt $cut) { return }
    if ($Execute) {
      &('Remove' + '-Item') -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    } else {
      Write-Host "[preview] would delete: $($_.FullName)"
    }
  }
  $after = SizeOf $f
  $results.Add([pscustomobject]@{ Path=$f; Reason=$why; BeforeBytes=$before; AfterBytes=$after; FreedBytes=[Math]::Max(0L, $before-$after); Mode=if($Execute){'execute'}else{'preview'} }) | Out-Null
}
Start-Transcript -Path $log -Force | Out-Null
try {
  Write-Host "Profile cleanup root: $Profile"
  Write-Host "Mode: $(if($Execute){'EXECUTE'}else{'PREVIEW - no files deleted'})"
  Write-Host "Log directory: $run"
  $targets = @(
    @($env:TEMP,'current user temp'),
    @("$Profile\AppData\Local\Temp",'AppData temp'),
    @("$Profile\AppData\Local\CrashDumps",'crash dumps'),
    @("$Profile\AppData\Local\D3DSCache",'shader cache'),
    @("$Profile\AppData\Local\Microsoft\Windows\INetCache",'internet cache'),
    @("$Profile\AppData\Local\Microsoft\Windows\Explorer",'Explorer thumbnails'),
    @("$Profile\AppData\Local\Microsoft\Edge\User Data\Default\Cache",'Edge cache'),
    @("$Profile\AppData\Local\Microsoft\Edge\User Data\Default\Code Cache",'Edge code cache'),
    @("$Profile\AppData\Local\Google\Chrome\User Data\Default\Cache",'Chrome cache'),
    @("$Profile\AppData\Local\Google\Chrome\User Data\Default\Code Cache",'Chrome code cache'),
    @("$Profile\AppData\Local\npm-cache",'npm cache'),
    @("$Profile\AppData\Local\pnpm-store",'pnpm cache'),
    @("$Profile\AppData\Local\Yarn\Cache",'Yarn cache'),
    @("$Profile\AppData\Local\pip\Cache",'pip cache'),
    @("$Profile\AppData\Local\uv\cache",'uv cache'),
    @("$Profile\AppData\Local\NuGet\Cache",'NuGet cache'),
    @("$Profile\.cache",'user cache'),
    @("$Profile\.bun\install\cache",'Bun cache'),
    @("$Profile\.electron-gyp",'Electron build cache'),
    @("$Profile\.gradle\caches",'Gradle cache'),
    @("$Profile\.android\cache",'Android cache'),
    @("$Profile\.bubblewrap\cache",'Bubblewrap cache'),
    @("$Profile\scoop\cache",'Scoop cache'),
    @("$Profile\.codex\logs",'Codex logs'),
    @("$Profile\.codex\tmp",'Codex temp'),
    @("$Profile\.codex\cache",'Codex cache'),
    @("$Profile\.serena\cache",'Serena cache'),
    @("$Profile\.local\share\Trash",'local trash'),
    @("$Profile\.Trash",'trash folder')
  )
  foreach ($t in $targets) { CleanDir $t[0] $t[1] }
  $ff = "$Profile\AppData\Local\Mozilla\Firefox\Profiles"
  if (Test-Path -LiteralPath $ff) { Get-ChildItem -LiteralPath $ff -Directory -ErrorAction SilentlyContinue | ForEach-Object { CleanDir "$($_.FullName)\cache2" 'Firefox cache2'; CleanDir "$($_.FullName)\startupCache" 'Firefox startup cache' } }
  $results | Sort-Object FreedBytes -Descending | Export-Csv -NoTypeInformation $csv
  $before = [long](($results | Measure-Object BeforeBytes -Sum).Sum)
  $after = [long](($results | Measure-Object AfterBytes -Sum).Sum)
  Write-Host "Total scanned before: $(Human $before)"
  Write-Host "Total scanned after:  $(Human $after)"
  Write-Host "Total freed:          $(Human ([Math]::Max(0L,$before-$after)))"
  Write-Host "Summary CSV: $csv"
  Write-Host "Transcript: $log"
  if (!$Execute) { Write-Host 'No files were deleted. Add -Execute to perform cleanup.' }
} finally { Stop-Transcript | Out-Null }

