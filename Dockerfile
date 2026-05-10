FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    TZ=Asia/Taipei

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        sudo ca-certificates locales tzdata \
        bash-completion less man-db manpages \
        tmux ncurses-term vim nano \
        openvpn microsocks \
        iproute2 iputils-ping iputils-tracepath dnsutils net-tools \
        netcat-openbsd socat curl wget \
        python3 \
        whois jq file tree procps psmisc lsof \
        git \
 && sed -i 's/^# *\(en_US.UTF-8\)/\1/; s/^# *\(zh_TW.UTF-8\)/\1/' /etc/locale.gen \
 && locale-gen \
 && rm -rf /var/lib/apt/lists/*

# Lab user with passwordless sudo for VPN ops only
RUN useradd -m -s /bin/bash -G adm student \
 && echo 'student:student' | chpasswd

# Pre-fetch a wordlist for gobuster / dirb practice
RUN mkdir -p /usr/share/wordlists/dirbuster \
 && curl -fsSL -o /usr/share/wordlists/dirbuster/directory-list-lowercase-2.3-medium.txt \
        https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/DirBuster-2007_directory-list-lowercase-2.3-medium.txt

COPY container/ /

RUN chmod 0440 /etc/sudoers.d/student \
 && chmod +x /usr/local/bin/lab-help \
              /usr/local/bin/tutorial \
              /usr/local/bin/cheat \
              /usr/local/bin/vpn-up \
              /usr/local/bin/vpn-down \
              /usr/local/bin/proxy-up \
              /usr/local/bin/proxy-down \
 && chown -R student:student /home/student

EXPOSE 1080

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
