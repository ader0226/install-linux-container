# install-linux-container universal installer (Windows / PowerShell 5.1+)
# Run inside a directory that contains an *.ovpn file:
#   iex (irm <INSTALL_URL>)
#Requires -Version 5.1

# EAP=Continue: this script invokes docker / docker compose heavily, and
# those native commands write progress ("Pulling", "Started") to stderr.
# With EAP=Stop, PS 5.1 wraps each stderr line as a NativeCommandError and
# throws, killing the script. We rely on $LASTEXITCODE after each docker
# call instead.
$ErrorActionPreference = 'Continue'

# Force UTF-8 console so non-ASCII characters (if any) render correctly on
# zh-TW / zh-CN Windows where the default code page is CP950 / CP936. The
# user-facing messages below are intentionally pure ASCII to sidestep
# codepage issues entirely, but this is kept as defense-in-depth.
try {
  [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
  $OutputEncoding           = [System.Text.UTF8Encoding]::new()
} catch {}

$Image = if ($env:LINUX_CONTAINER_IMAGE) { $env:LINUX_CONTAINER_IMAGE } else { 'ghcr.io/ader0226/install-linux-container:latest' }

function Write-Red    ($m) { Write-Host $m -ForegroundColor Red }
function Write-Green  ($m) { Write-Host $m -ForegroundColor Green }
function Write-Yellow ($m) { Write-Host $m -ForegroundColor Yellow }
function Write-Cyan   ($m) { Write-Host $m -ForegroundColor Cyan }

# ---- 1. docker compose available? --------------------------------------
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Red '[ERR] docker not found. Install Docker Desktop first:'
  Write-Host '      https://www.docker.com/products/docker-desktop/'
  exit 1
}
& docker compose version *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Red "[ERR] 'docker compose' subcommand unavailable. Update Docker Desktop to v2+."
  exit 1
}
Write-Green '[OK]  docker compose available'

# ---- 2. find *.ovpn in current directory -------------------------------
$ovpnDir = (Get-Location).Path
$ovpns = Get-ChildItem -Path $ovpnDir -Filter '*.ovpn' -File -ErrorAction SilentlyContinue
if (-not $ovpns) {
  Write-Red "[ERR] no *.ovpn file found in $ovpnDir"
  Write-Host '      cd into a directory that contains your .ovpn file and re-run.'
  exit 1
}
$ovpnFile = $ovpns[0].Name
Write-Green "[OK]  using VPN config: $ovpnFile"

# ---- 3. state directory ------------------------------------------------
$stateDir    = Join-Path $ovpnDir '.install-linux-container'
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
$envFile     = Join-Path $stateDir '.env'
$composeFile = Join-Path $stateDir 'docker-compose.yml'

# ---- 4. allocate / reuse proxy port ------------------------------------
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
  Write-Green "[OK]  allocated new proxy port: $proxyPort"
} else {
  Write-Cyan "[..]  reusing existing proxy port: $proxyPort"
}

# ---- 5. generate compose.yml -------------------------------------------
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

# ---- 6. start container ------------------------------------------------
& docker @DC pull *> $null
& docker @DC up -d
if ($LASTEXITCODE -ne 0) { Write-Red '[ERR] docker compose up failed'; exit 1 }
Write-Green '[OK]  container started'

# ---- 7. wait for VPN ---------------------------------------------------
Write-Host -NoNewline '      waiting for VPN'
$ok = $false
for ($i = 1; $i -le 30; $i++) {
  & docker @DC exec -T lab ip link show tun0 *> $null
  if ($LASTEXITCODE -eq 0) { Write-Host ' [OK]'; $ok = $true; break }
  Start-Sleep -Seconds 1
  Write-Host -NoNewline '.'
}
if (-not $ok) {
  Write-Host
  Write-Yellow '[WARN] tun0 did not come up within 30s (bad .ovpn or THM machine not started?)'
  Write-Host  "       inspect: docker compose -f $composeFile logs"
}

# ---- 8. launch Chromium-based browser with SOCKS5 ----------------------
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
    Write-Cyan "[OK]  launched $($b.Name) (SOCKS5 127.0.0.1:${proxyPort})"
    $launched = $true
    break
  }
}
if (-not $launched) {
  Write-Yellow "[WARN] no Chromium-based browser found. Set SOCKS5 manually: 127.0.0.1:$proxyPort"
  Write-Yellow '       Recommended: Chrome / Edge / Brave'
}

# ---- 9. drop into the container's interactive shell --------------------
Write-Host
Write-Green '========================================================'
Write-Host  '  Entering container shell (Ctrl-D to exit; container keeps running)'
Write-Host  "  Browser proxy: SOCKS5 127.0.0.1:$proxyPort"
Write-Host  '  Re-run this installer in the same directory to resume.'
Write-Green '========================================================'
Write-Host

& docker @DC exec -u student lab bash
