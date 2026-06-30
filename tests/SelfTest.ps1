$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$script = Join-Path $root 'Clean-UserProfileDisposableSpace.ps1'
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count) { throw ($errors | Select-Object -First 1 -ExpandProperty Message) }
$proof = Join-Path $root 'tmp-proof-profile'
if (Test-Path $proof) { Remove-Item -LiteralPath $proof -Recurse -Force }
New-Item -ItemType Directory -Force -Path "$proof\AppData\Local\Temp", "$proof\.cache", "$proof\Documents", "$proof\.codex\skills" | Out-Null
Set-Content -LiteralPath "$proof\AppData\Local\Temp\delete.tmp" -Value 'trash'
Set-Content -LiteralPath "$proof\.cache\delete.cache" -Value 'trash'
Set-Content -LiteralPath "$proof\Documents\keep.txt" -Value 'keep'
Set-Content -LiteralPath "$proof\.codex\skills\keep.txt" -Value 'keep'
powershell -NoProfile -ExecutionPolicy Bypass -File $script -ProfileRoot $proof -AllowTestProfileRoot -Execute -LogRoot (Join-Path $proof 'logs') | Out-Null
if (Test-Path "$proof\AppData\Local\Temp\delete.tmp") { throw 'Temp proof file was not deleted' }
if (Test-Path "$proof\.cache\delete.cache") { throw 'Cache proof file was not deleted' }
if (!(Test-Path "$proof\Documents\keep.txt")) { throw 'Protected Documents file was deleted' }
if (!(Test-Path "$proof\.codex\skills\keep.txt")) { throw 'Protected Codex skills file was deleted' }
Remove-Item -LiteralPath $proof -Recurse -Force
'SELFTEST_OK'
