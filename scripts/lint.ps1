# Lint one Dockerfile (default: .\Dockerfile) with Hadolint running in Docker.
# Usage: .\scripts\lint.ps1 [path\to\Dockerfile]
param([string]$File = "Dockerfile")

Write-Host "==> hadolint $File"
Get-Content $File -Raw | docker run --rm -i `
  -v "${PWD}\.hadolint.yaml:/.config/hadolint.yaml:ro" `
  hadolint/hadolint:v2.12.0
if ($LASTEXITCODE -eq 0) { Write-Host "    (no issues found)" }
exit $LASTEXITCODE
