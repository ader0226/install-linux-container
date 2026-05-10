# Boot the lab container (Windows / PowerShell)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

docker compose up -d --build
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host 'Lab container is up.' -ForegroundColor Green
Write-Host ''
Write-Host '進入容器：' -ForegroundColor Cyan
Write-Host '  ssh -p 2222 student@127.0.0.1'
Write-Host '  （第一次會問 host key，輸入 yes；密碼是 student）'
Write-Host ''
Write-Host 'THM 靶機網頁轉發（另開一個終端機）：' -ForegroundColor Cyan
Write-Host '  .\forward.ps1   （會問靶機 IP/port 然後直接幫你連）'
Write-Host ''
Write-Host '停止：.\stop.ps1   （或 docker compose down）'
