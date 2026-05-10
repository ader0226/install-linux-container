# 連到容器並建立到 THM 靶機的 port forward。
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

$ip = Read-Host '靶機 IP'
if ([string]::IsNullOrWhiteSpace($ip)) {
    Write-Host '沒輸入 IP，結束。' -ForegroundColor Red
    exit 1
}
$ip = $ip.Trim()

$portInput = Read-Host '靶機 port（直接 Enter = 80）'
if ([string]::IsNullOrWhiteSpace($portInput)) {
    $port = 80
} else {
    $port = [int]$portInput.Trim()
}

# 80/443 用 8080/8443 比較好；其它 port 直接同號方便記
switch ($port) {
    80   { $localPort = 8080 }
    443  { $localPort = 8443 }
    default { $localPort = $port }
}

$scheme = if ($port -eq 443) { 'https' } else { 'http' }
$url = "${scheme}://127.0.0.1:$localPort"

Write-Host ''
Write-Host '─────────────────────────────────────────────' -ForegroundColor DarkGray
Write-Host "  靶機：     ${ip}:$port"
Write-Host "  瀏覽器開： $url" -ForegroundColor Cyan
Write-Host '  保持這個視窗開著；關掉就斷了。'
Write-Host '─────────────────────────────────────────────' -ForegroundColor DarkGray
Write-Host ''

ssh -p 2222 -L "${localPort}:${ip}:$port" student@127.0.0.1
