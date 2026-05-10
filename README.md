# shell-attack-lab

社課用的跨平台 Docker 容器，把 **shell 互動練習、reverse shell、TryHackMe VPN** 三件事打包好。Windows / macOS 操作完全一致。

## 30秒上手

1. 安裝 [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. 在這個資料夾跑 `./start.sh`（macOS）或 `.\start.ps1`（Windows）
3. `ssh -p 2222 student@127.0.0.1`（密碼 `student`），進去後輸入 `tutorial`

> **學員第一次用請看 [`學員指南.md`](學員指南.md)**（包含 Docker 安裝、常見問題）。

---

## 三個情境

1. **Shell 互動練習**：互動式 tutorial 帶學員從 `pwd` 走到 pipe；每題實際在 sandbox 執行並驗證輸出。
2. **Reverse shell 練習**：學員 SSH 進容器後 `tmux` 切兩個 pane，一個當 attacker、一個當 victim，全部在同一容器完成，不需多開機器。
3. **TryHackMe 實作**：容器內跑 OpenVPN；host 端 `forward.ps1` / `forward.sh` 問靶機 IP 後一鍵 `ssh -L`，瀏覽器直接看 THM 靶機網頁。

## 系統需求

- Docker Engine 20.10+ / Docker Desktop（含 `docker compose` 子指令）
- 一個 SSH 客戶端（Win10/11 內建 OpenSSH，macOS 內建）
- 想跑 THM 段：一份 `.ovpn` 設定檔（從 TryHackMe 帳號下載）

## 快速開始

```bash
# 啟動
./start.sh        # macOS / Linux
.\start.ps1       # Windows PowerShell

# 進容器
ssh -p 2222 student@127.0.0.1     # 密碼: student
```

進去之後直接打 `tutorial` 就會跑互動教學。`lab-help` 隨時看選單。

## 容器內提供的指令

| 指令 | 用途 |
|------|------|
| `tutorial` | 互動式 shell 入門，10 關 |
| `cheat <主題>` | 速查表，主題：`shell`、`reverse-shell`、`tmux`、`thm` |
| `lab-help` | 顯示歡迎訊息與指令清單 |
| `vpn-up` | 啟動 OpenVPN（讀 `/vpn/config.ovpn`，背景跑） |
| `vpn-down` | 斷開 OpenVPN |

預先安裝的工具：`tmux`、`vim`、`nano`、`netcat-openbsd`、`socat`、`curl`、`wget`、`python3`、`jq`、`tree`、`man-db` 等。

## 架構

```
┌────────────────────────────────────────────────────────────┐
│ HOST (Windows / macOS / Linux)                             │
│                                                            │
│   $ ssh -p 2222 student@127.0.0.1                          │
│   $ ssh -p 2222 -L 8080:<TARGET_IP>:80 student@127.0.0.1   │
│   browser → http://127.0.0.1:8080                          │
│                          │                                 │
└──────────────────────────┼─────────────────────────────────┘
                           │  127.0.0.1:2222 → :22
                           ▼
┌────────────────────────────────────────────────────────────┐
│ CONTAINER (debian:bookworm-slim)                           │
│   sshd  (always running)                                   │
│   user:  student / student                                 │
│                                                            │
│   $ tutorial / cheat / tmux / vpn-up                       │
│                          │                                 │
│                       OpenVPN ─── tun0 ──► THM 靶機網段     │
└────────────────────────────────────────────────────────────┘
```

`forward` 腳本只是包裝 `ssh -p 2222 -L <local>:<TARGET_IP>:<port> student@127.0.0.1`，不想用腳本的可以直接下指令，公式看 `cheat thm`。

## 疑難排解

| 症狀                                                             | 對策                                                                                    |
|----------------------------------------------------------------|---------------------------------------------------------------------------------------|
| `ssh: connect to host 127.0.0.1 port 2222: Connection refused` | 容器還沒起來。`docker compose ps` 看狀態，`docker compose logs lab` 看 log                        |
| `Permission denied (publickey,password)`                       | 密碼是 `student`（小寫，沒空白）                                                                 |
| `vpn-up` 卡住 / AUTH_FAILED                                      | `.ovpn` 壞了或不對；THM 不需要帳密，重下一份                                                          |
| `ping` 不到 <TARGET_IP>                                          | THM 房間要按 Start Machine；`ip route` 看 tun0 路由是否存在                                       |
| Port forward 沒反應                                               | 確認用的是「另一個」SSH 連線、且容器內 `vpn-up` 真的成功                                                   |
| 重 build 後 SSH 報錯 host key changed                              | 我們把 host key 烤進 image；如果你 rebuild 過，刪掉 `~/.ssh/known_hosts` 內 `[127.0.0.1]:2222` 那行即可 |
