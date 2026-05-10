# install-linux-container universal installer (Windows / PowerShell 5.1+)
# 在含有 xxx.ovpn 的目錄下執行：
#   iex "& { $(iwr -useb <INSTALL_URL>) }"
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$Image = if ($env:LINUX_CONTAINER_IMAGE) { $env:LINUX_CONTAINER_IMAGE } else { 'ghcr.io/ader0226/install-linux-container:latest' }

function Write-Red    ($m) { Write-Host $m -ForegroundColor Red }
function Write-Green  ($m) { Write-Host $m -ForegroundColor Green }
function Write-Yellow ($m) { Write-Host $m -ForegroundColor Yellow }
function Write-Cyan   ($m) { Write-Host $m -ForegroundColor Cyan }

# ── 1. docker compose 可用？ ────────────────────────────────────
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Red '✗ 找不到 docker，請先安裝 Docker Desktop:'
  Write-Host '  https://www.docker.com/products/docker-desktop/'
  exit 1
}
& docker compose version *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Red "✗ 'docker compose' 子指令不可用（請更新 Docker Desktop 到 v2+）"
  exit 1
}
Write-Green '✓ docker compose 可用'

# ── 2. 找當前目錄的 .ovpn ────────────────────────────────────────
$ovpnDir = (Get-Location).Path
$ovpns = Get-ChildItem -Path $ovpnDir -Filter '*.ovpn' -File -ErrorAction SilentlyContinue
if (-not $ovpns) {
  Write-Red "✗ 在 $ovpnDir 找不到 .ovpn 檔"
  Write-Host '  請 cd 到含有 xxx.ovpn 的目錄再執行一次'
  exit 1
}
$ovpnFile = $ovpns[0].Name
Write-Green "✓ 使用 VPN 設定: $ovpnFile"

# ── 3. state dir ─────────────────────────────────────────────────
$stateDir    = Join-Path $ovpnDir '.install-linux-container'
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
$envFile     = Join-Path $stateDir '.env'
$composeFile = Join-Path $stateDir 'docker-compose.yml'

# ── 4. 找 / 沿用 proxy port ─────────────────────────────────────
$proxyPort = $null
if (Test-Path $envFile) {
  $line = (Get-Content $envFile | Where-Object { $_ -match '^PROXY_PORT=' } | Select-Object -First 1)
  if ($line) { $proxyPort = ($line -split '=', 2)[1].Trim() }
}
if (-not $proxyPort) {
  $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
  $listener.Start()
  $proxyPort = [string]$listener.LocalEndpoint.Port
  $listener.Stop()
  Set-Content -Path $envFile -Value "PROXY_PORT=$proxyPort" -Encoding ASCII
  Write-Green "✓ 配置新 proxy port: $proxyPort"
} else {
  Write-Cyan "↻ 沿用既有 proxy port: $proxyPort"
}

# ── 5. 產生 compose.yml ─────────────────────────────────────────
$ovpnDirYaml = ($ovpnDir -replace '\\','/')
@"
services:
  lab:
    image: $Image
    container_name: linux-container
    hostname: lab
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    volumes:
      - "${ovpnDirYaml}:/vpn:ro"
    ports:
      - "127.0.0.1:`${PROXY_PORT}:1080"
    restart: unless-stopped
"@ | Set-Content -Path $composeFile -Encoding UTF8

$DC = @('compose', '--env-file', $envFile, '-f', $composeFile)

# ── 6. 啟動容器 ──────────────────────────────────────────────────
& docker @DC pull *> $null
& docker @DC up -d
if ($LASTEXITCODE -ne 0) { Write-Red '✗ docker compose up 失敗'; exit 1 }
Write-Green '✓ 容器已啟動'

# ── 7. 等 VPN 上線 ───────────────────────────────────────────────
Write-Host -NoNewline '  等待 VPN 上線'
$ok = $false
for ($i = 1; $i -le 30; $i++) {
  & docker @DC exec -T lab ip link show tun0 *> $null
  if ($LASTEXITCODE -eq 0) { Write-Host ' ✓'; $ok = $true; break }
  Start-Sleep -Seconds 1
  Write-Host -NoNewline '.'
}
if (-not $ok) {
  Write-Host
  Write-Yellow '⚠ tun0 30 秒內未上線（可能 .ovpn 有問題或 THM 房間未開）'
  Write-Host  "   docker compose -f $composeFile logs 看細節"
}

# ── 8. 開 Chromium 系 browser，帶 SOCKS5 proxy ─────────────────
$tmpProfile = Join-Path $env:TEMP "linux-container-profile-$proxyPort"
New-Item -ItemType Directory -Force -Path $tmpProfile | Out-Null

$proxyArgs = @(
  "--user-data-dir=$tmpProfile",
  "--proxy-server=socks5://127.0.0.1:$proxyPort",
  '--no-first-run',
  '--no-default-browser-check',
  'about:blank'
)

$browsers = @(
  @{ Name = 'Chrome'; Path = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe" },
  @{ Name = 'Chrome'; Path = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe" },
  @{ Name = 'Edge';   Path = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe" },
  @{ Name = 'Edge';   Path = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe" },
  @{ Name = 'Brave';  Path = "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe" },
  @{ Name = 'Brave';  Path = "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser\Application\brave.exe" }
)
$launched = $false
foreach ($b in $browsers) {
  if ($b.Path -and (Test-Path $b.Path)) {
    Start-Process -FilePath $b.Path -ArgumentList $proxyArgs | Out-Null
    Write-Cyan "✓ 已用 $($b.Name) 開啟（SOCKS5 127.0.0.1:$proxyPort）"
    $launched = $true
    break
  }
}
if (-not $launched) {
  Write-Yellow "⚠ 沒找到 Chromium 系 browser，請手動設 SOCKS5: 127.0.0.1:$proxyPort"
  Write-Yellow '   推薦：Chrome / Edge / Brave'
}

# ── 9. 進容器互動 shell ─────────────────────────────────────────
Write-Host
Write-Green '════════════════════════════════════════════════════════'
Write-Host  '  進入容器互動 shell（Ctrl-D 離開不會停容器）'
Write-Host  "  Browser 已連 SOCKS5: 127.0.0.1:$proxyPort"
Write-Host  '  下次再執行此腳本可繼續同一個容器'
Write-Green '════════════════════════════════════════════════════════'
Write-Host

& docker @DC exec -u student lab bash
