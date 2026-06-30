# User Profile Disposable Cleanup

Preserve-first Windows PowerShell cleanup script for disposable user-profile cache, temp, log, and trash folders.

## Preview

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Clean-UserProfileDisposableSpace.ps1"
```

## Execute

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Clean-UserProfileDisposableSpace.ps1" -Execute
```

By default, reports are written to this project folder under `logs\`, not to `C:`.

The script refuses non-current-profile roots unless `-AllowTestProfileRoot` is supplied for test harness use. It protects personal and configuration paths including Documents, Downloads, Pictures, Saved Games, `.ssh`, `.docker`, `.codex\skills`, `.codex\plugins`, `.codex\memories`, `.agents`, `NTUSER.DAT`, and Codex auth/config files.
