# Parse recipes/darnlink-gate.ps1 without running it. One script, called by
# .github/workflows/ci.yml and by the Jenkinsfile. A parse error exits 1.
$errs = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
  (Resolve-Path recipes/darnlink-gate.ps1).Path, [ref]$null, [ref]$errs)
if ($errs) { $errs | ForEach-Object { Write-Host "::error::$($_.ToString())" }; exit 1 }
Write-Host "recipes/darnlink-gate.ps1 parses clean"
