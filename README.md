# shell-attack-lab

社課用的跨平台 Docker 容器，把 **shell 互動練習、reverse shell、TryHackMe VPN + browser-via-proxy** 三件事打包好。Windows / macOS / Linux 操作完全一致。

## 30 秒上手

1. 安裝 [Docker Desktop](https://www.docker.com/products/docker-desktop/) 與一個 Chromium 系 browser（Chrome / Edge / Brave）。
2. `cd` 到放 `xxx.ovpn` 的資料夾。
3. 貼一行指令：

   ```bash
   # macOS / Linux
   /bin/bash -c "$(curl -fsSL https://install-linux-container.ader.pw/)"
   ```
   ```powershell
   # Windows PowerShell
   iex "& { $(iwr -useb https://install-linux-container.ader.pw/) }"
   ```

腳本會自動：
1. 檢查 `docker compose` 是否可用
2. 找一個閒置 host port 當 SOCKS5 對外 port（同目錄重跑會沿用）
3. 啟動容器，容器內**自動連 OpenVPN**（讀目錄裡的第一個 `*.ovpn`）+ **microsocks SOCKS5 proxy**
4. 開獨立 profile 的 Chrome / Edge / Brave，已帶 `--proxy-server=socks5://127.0.0.1:<PORT>`
5. 把終端機帶進容器互動 shell（Ctrl-D 離開不會停容器；之後再跑同一行可恢復）

> **學員第一次用請看 [`學員指南.md`](學員指南.md)**。

---

## 三個情境

1. **Shell 互動練習**：互動式 tutorial 帶學員從 `pwd` 走到 pipe；每題實際在 sandbox 執行並驗證輸出。
2. **Reverse shell 練習**：學員進容器 `tmux` 切兩個 pane，一個當 attacker、一個當 victim，全部在同一容器完成。
3. **TryHackMe 實作**：容器自動跑 OpenVPN + SOCKS5 proxy；host 端 browser 已設好 proxy，直接 `http://<TARGET_IP>/` 就連得到。

## 系統需求

- Docker Engine 20.10+ / Docker Desktop（含 `docker compose` 子指令）
- Chrome / Edge / Brave 任一個（裝在系統預設位置）
- 一份 `.ovpn` 設定檔（從 TryHackMe 帳號下載）

## 容器內提供的指令

| 指令 | 用途 |
|------|------|
| `tutorial` | 互動式 shell 入門，10 關 |
| `cheat <主題>` | 速查表，主題：`shell`、`reverse-shell`、`tmux`、`thm` |
| `lab-help` | 顯示歡迎訊息與指令清單 |
| `vpn-up` | （重新）啟動 OpenVPN（讀 `/vpn/*.ovpn` 第一個） |
| `vpn-down` | 斷開 OpenVPN |
| `proxy-up` | （重新）啟動 microsocks SOCKS5 |
| `proxy-down` | 停止 microsocks |

預先安裝的工具：`tmux`、`vim`、`nano`、`netcat-openbsd`、`socat`、`curl`、`wget`、`python3`、`jq`、`tree`、`man-db`、`microsocks`、`openvpn` 等。

## 架構

```
┌─────────────────────────────────────────────────────────────────┐
│ HOST (Windows / macOS / Linux)                                  │
│                                                                 │
│   browser (獨立 profile, --proxy-server=socks5://127.0.0.1:PORT)│
│        │                                                        │
│        ▼ SOCKS5                                                 │
│   127.0.0.1:PORT  ◀──── docker compose port mapping ────┐       │
│                                                         │       │
│   $ docker compose exec -u student lab bash             │       │
└─────────────────────────────────────────────────┬───────┼───────┘
                                                  │       │
                                                  ▼       ▼
┌─────────────────────────────────────────────────────────────────┐
│ CONTAINER (debian:bookworm-slim)                                │
│                                                                 │
│   microsocks 0.0.0.0:1080  (SOCKS5)                             │
│   OpenVPN ─── tun0 ──► THM 靶機網段                             │
│                                                                 │
│   學員互動：tutorial / cheat / tmux / nmap / gobuster ...       │
└─────────────────────────────────────────────────────────────────┘
```

## CF Worker dispatcher

`worker/` 是 Cloudflare Worker（TS / ESM），負責 User-Agent routing：

| User-Agent | 回傳 | Content-Type |
|-----------|------|--------------|
| `curl/`、`Wget/`、`libcurl` | `scripts/install.sh` | `text/plain; charset=utf-8` |
| `PowerShell` | `scripts/install.ps1` | `text/plain; charset=utf-8` |
| 其他（瀏覽器） | HTML 用法說明 | `text/html; charset=utf-8` |

所有回應都帶 `Cache-Control: no-cache, no-store, must-revalidate`。

部署：

```bash
cd worker
npm install
npx wrangler deploy
```

## Docker image

GitHub Actions 已自動 build multi-arch（amd64 + arm64）push 到 GHCR：
`ghcr.io/ader0226/shell-attack-lab:latest`

要同時推 Docker Hub，在 `.github/workflows/build.yml` 增加：

```yaml
- uses: docker/login-action@v3
  with:
    username: ${{ secrets.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}
```

並在 `metadata-action` 的 `images:` 加上 `youruser/shell-attack-lab`。

## 疑難排解

| 症狀 | 對策 |
|------|------|
| `'docker compose' 子指令不可用` | 升級到 Docker Desktop v2+，或安裝 `docker-compose-plugin` |
| `tun0 30 秒內未上線` | `.ovpn` 壞掉重下一份；THM 房間要先 Start Machine |
| 沒找到 Chromium 系 browser | 裝 Chrome/Edge/Brave，或手動在現有 browser 設 SOCKS5（位址腳本會印） |
| browser 連不到靶機 | 確認用的是 install 腳本開的那個獨立 profile（你主 browser 沒設 proxy） |
| 想徹底重來 | `docker compose -f .shell-attack-lab/docker-compose.yml down && rm -rf .shell-attack-lab` |
