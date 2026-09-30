#!/usr/bin/env bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[!] Please run as root (sudo -i).${NC}"
    exit 1
fi

BIN_PATH="/root/sni-spoofing"
CONF_PATH="/root/config.ini"
SVC_PATH="/etc/systemd/system/sni-spoofing.service"

install_sni_spoof() {
    echo -e "\n${CYAN}==================================================${NC}"
    echo -e "${GREEN}        Setup SNI Spoofing Service (TCP)          ${NC}"
    echo -e "${CYAN}==================================================${NC}"

    apt-get update -y >/dev/null 2>&1
    apt-get install -y wget curl >/dev/null 2>&1

    echo -e "${YELLOW}[+] Downloading SNI-Spoofing binary (v0.7.2)...${NC}"
    wget -qO "$BIN_PATH" 'https://github.com/aleskxyz/SNI-Spoofing-Go/releases/download/v0.7.2/sni-spoofing-linux-amd64'
    chmod +x "$BIN_PATH"

    echo -e "\n${CYAN}--- Configure Settings ---${NC}"
    read -p "Local Listen Address [Default: 127.0.0.1:40443]: " LISTEN_ADDR
    LISTEN_ADDR=${LISTEN_ADDR:-"127.0.0.1:40443"}

    read -p "Connect Destination (Remote Server IP:Port) [e.g. 104.19.229.21:443]: " CONNECT_ADDR
    while [ -z "$CONNECT_ADDR" ]; do
        echo -e "${RED}[!] Destination cannot be empty.${NC}"
        read -p "Connect Destination: " CONNECT_ADDR
    done

    read -p "Fake SNI Domain [Default: hcaptcha.com]: " FAKE_SNI
    FAKE_SNI=${FAKE_SNI:-"hcaptcha.com"}

    read -p "uTLS Fingerprint (firefox/chrome) [Default: firefox]: " UTLS_CLIENT
    UTLS_CLIENT=${UTLS_CLIENT:-"firefox"}

    # Create config.ini
    cat <<EOF > "$CONF_PATH"
listen = ${LISTEN_ADDR}
connect = ${CONNECT_ADDR}
fake-sni = ${FAKE_SNI}
utls = ${UTLS_CLIENT}
fake-repeat = 1
fake-delay = 2ms
ack-timeout = 2s
injector = active
enable-fragment = false
fragment-delay = 500ms
sni-chunk = 3
EOF

    # Create systemd service
    cat <<EOF > "$SVC_PATH"
[Unit]
Description=SNI Spoofing Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=${BIN_PATH} -config ${CONF_PATH}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now sni-spoofing.service

    echo -e "\n${GREEN}[✓] SNI Spoofing service installed and started successfully!${NC}"
    echo -e "Listening on : ${CYAN}${LISTEN_ADDR}${NC}"
    echo -e "Forwarding to: ${CYAN}${CONNECT_ADDR}${NC}"
    echo -e "Fake SNI     : ${YELLOW}${FAKE_SNI}${NC}"
    read -p "Press Enter to return..." DUMMY
}

manage_service() {
    clear
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${GREEN}           Manage SNI Spoofing Service            ${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo "1. Service Status"
    echo "2. Live Logs"
    echo "3. Restart Service"
    echo "4. Delete and Uninstall Service"
    echo "0. Back"
    read -p "Select action [0-4]: " ACTION

    case $ACTION in
        1)
            systemctl status sni-spoofing.service --no-pager
            read -p "Press Enter to return..." DUMMY
            ;;
        2)
            echo -e "${YELLOW}[!] Press Ctrl+C to exit logs.${NC}"
            sleep 1
            journalctl -u sni-spoofing.service -f -n 30
            ;;
        3)
            systemctl restart sni-spoofing.service
            echo -e "${GREEN}[✓] Service restarted.${NC}"
            sleep 2
            ;;
        4)
            systemctl disable --now sni-spoofing.service 2>/dev/null || true
            rm -f "$SVC_PATH" "$CONF_PATH" "$BIN_PATH"
            systemctl daemon-reload
            systemctl reset-failed 2>/dev/null || true
            echo -e "${GREEN}[✓] Service uninstalled successfully.${NC}"
            sleep 2
            ;;
        *) return ;;
    esac
}

while true; do
    clear
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${GREEN}       SNI-Spoofing Manager for TCP Traffic       ${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo "1. Setup / Reconfigure SNI Spoofing"
    echo "2. Manage Service (Status, Logs, Restart, Uninstall)"
    echo "3. Exit"
    echo -e "${CYAN}==================================================${NC}"
    read -p "Select option [1-3]: " OPT

    case $OPT in
        1) install_sni_spoof ;;
        2) manage_service ;;
        3) exit 0 ;;
        *) echo -e "${RED}[!] Invalid option.${NC}"; sleep 1 ;;
    esac
done
