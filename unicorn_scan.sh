#!/bin/bash
# unicorn_scan.sh - Automated Recon Script
# By Alex 🦄
# ====================
# Stable, feature-complete version with readable Gobuster banner
# ====================

# ====================
# Colors
# ====================
NC="\033[0m"
RED="\033[1;31m"
GREEN="\033[1;32m"
ORANGE="\033[1;33m"
BLUE="\033[1;34m"
PURPLE="\033[1;35m"
PINK="\033[1;95m"
TEAL="\033[1;36m"
YELLOW="\033[1;93m"

TARGET=$1
if [ -z "$TARGET" ]; then
    echo "Usage: $0 <target>"
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="unicorn_report_${TARGET}_${TIMESTAMP}"
mkdir -p "$REPORT_DIR"

# ====================
# Unicorn Banner
# ====================
echo -e "${PINK}           _                                               ${NC}"
echo -e "${YELLOW} /\ /\ _ __ (_) ___ ___  _ __ _ __      ___  ___ __ _ _ __ ${NC}"
echo -e "${TEAL}/ / \ \ '_ \| |/ __/ _ \| '__| '_ \    / __|/ __/ _\` | '_ \\ ${NC}"
echo -e "${PINK}\\ \_/ / | | | | (_| (_) | |  | | | |   \__ \ (_| (_| | | | |${NC}"
echo -e "${YELLOW} \___/|_| |_|_|\___\___/|_|  |_| |_|___|___/\___\__,_|_| |_|${NC}"
echo -e "${TEAL}                                  |_____|                  ${NC}"
echo
echo "[*] Starting Unicorn Scan on $TARGET"
echo "[*] Reports will be saved to $REPORT_DIR"

# ====================
# Check dependencies
# ====================
DEPENDENCIES=(naabu nmap httpx gobuster nikto)
for cmd in "${DEPENDENCIES[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[!] Warning: $cmd not found. Related phases will be skipped."
    fi
done

# ====================
# Naabu Fast Scan
# ====================
NAABU_OUTPUT="$REPORT_DIR/naabu.txt"
if command -v naabu >/dev/null 2>&1; then
    echo "[*] Running Naabu..."
    naabu -host "$TARGET" -o "$NAABU_OUTPUT" || true
    PORTS=$(awk -F: '{print $2?$2:$1}' "$NAABU_OUTPUT" | tr '\n' ',' | sed 's/,$//')
else
    echo "[!] Naabu not found, skipping."
    PORTS=""
    touch "$NAABU_OUTPUT"
fi

echo "[*] Naabu results saved to $NAABU_OUTPUT"
echo "====================" >> "$REPORT_DIR/report.txt"
echo "Naabu Fast Scan" >> "$REPORT_DIR/report.txt"
cat "$NAABU_OUTPUT" >> "$REPORT_DIR/report.txt"

# ====================
# Nmap Phase
# ====================
echo -e "${ORANGE}====================================================${NC}"
echo -e "${ORANGE} .-----.--------.---.-.-----.${NC}"
echo -e "${ORANGE} |     |        |  _  |  _  |${NC}"
echo -e "${ORANGE} |__|__|__|__|__|___._|   __|${NC}"
echo -e "${ORANGE}                      |__|   ${NC}"
echo -e "${ORANGE}====================================================${NC}"

NMAP_OUTPUT="$REPORT_DIR/nmap.txt"
if [ -n "$PORTS" ] && command -v nmap >/dev/null 2>&1; then
    echo "[*] Running Nmap on discovered ports: $PORTS"
    nmap -p "$PORTS" -sV "$TARGET" -oN "$NMAP_OUTPUT" || touch "$NMAP_OUTPUT"
else
    echo "[!] No ports found or Nmap missing, skipping Nmap."
    touch "$NMAP_OUTPUT"
fi
echo "[*] Nmap results saved to $NMAP_OUTPUT"
echo "====================" >> "$REPORT_DIR/report.txt"
echo "Nmap Scan on Discovered Ports: $PORTS" >> "$REPORT_DIR/report.txt"
cat "$NMAP_OUTPUT" >> "$REPORT_DIR/report.txt"

# ====================
# HTTPX Phase
# ====================
echo -e "${PURPLE}====================================================${NC}"
echo -e "${PURPLE}               __    __  __            ${NC}"
echo -e "${PURPLE}   / /_  / /_/ /_____  _  __          ${NC}"
echo -e "${PURPLE}  / __ \\/ __/ __/ __ \\| |/_/          ${NC}"
echo -e "${PURPLE} / / / / /_/ /_/ /_/ />  <            ${NC}"
echo -e "${PURPLE}/_/ /_/\\__/\\__/ .___/_/|_|            ${NC}"
echo -e "${PURPLE}             /_/                      ${NC}"
echo -e "${PURPLE}====================================================${NC}"

HTTPX_OUTPUT="$REPORT_DIR/httpx.txt"
if command -v httpx >/dev/null 2>&1 && [ -s "$NMAP_OUTPUT" ]; then
    grep 'open' "$NMAP_OUTPUT" | awk '$3 ~ /http/{print $1}' | cut -d/ -f1 | while read -r port; do
        echo "http://$TARGET:$port"
    done | httpx -silent -o "$HTTPX_OUTPUT" || touch "$HTTPX_OUTPUT"
    echo "[*] HTTPX results saved to $HTTPX_OUTPUT"
else
    echo "[!] HTTPX not found or no HTTP ports, skipping."
    touch "$HTTPX_OUTPUT"
fi
echo "====================" >> "$REPORT_DIR/report.txt"
echo "HTTPX Scan" >> "$REPORT_DIR/report.txt"
cat "$HTTPX_OUTPUT" >> "$REPORT_DIR/report.txt"

# ====================
# Gobuster Phase
# ====================
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}  _____       _               _            ${NC}"
echo -e "${GREEN} |  __ \     | |             | |           ${NC}"
echo -e "${GREEN} | |  \/ ___ | |__  _   _ ___| |_ ___ _ __ ${NC}"
echo -e "${GREEN} | | __ / _ \| '_ \| | | / __| __/ _ \ '__|${NC}"
echo -e "${GREEN} | |_\ \ (_) | |_) | |_| \__ \ ||  __/ |   ${NC}"
echo -e "${GREEN}  \____/\___/|_.__/ \__,_|___/\__\___|_|   ${NC}"
echo -e "${GREEN}                                          ${NC}"
echo -e "${GREEN}====================================================${NC}"

GOBUSTER_OUTPUT="$REPORT_DIR/gobuster.txt"
if command -v gobuster >/dev/null 2>&1 && [ -s "$HTTPX_OUTPUT" ]; then
    > "$GOBUSTER_OUTPUT"
    while read -r url; do
        [ -n "$url" ] && gobuster dir -u "$url" -w /usr/share/wordlists/dirb/common.txt >> "$GOBUSTER_OUTPUT" 2>&1 || true
    done < "$HTTPX_OUTPUT"
    echo "[*] Gobuster results saved to $GOBUSTER_OUTPUT"
else
    echo "[!] Gobuster not found or no HTTP services, skipping."
    touch "$GOBUSTER_OUTPUT"
fi
echo "====================" >> "$REPORT_DIR/report.txt"
echo "Gobuster Scan" >> "$REPORT_DIR/report.txt"
cat "$GOBUSTER_OUTPUT" >> "$REPORT_DIR/report.txt"

# ====================
# Nikto Phase
# ====================
echo -e "${RED}====================================================${NC}"
echo -e "${RED} _______  .__ __      __          ${NC}"
echo -e "${RED} \\      \\ |__|  | ___/  |_  ____  ${NC}"
echo -e "${RED} /   |   \\|  |  |/ /\\   __\\/  _ \\ ${NC}"
echo -e "${RED}/    |    \\  |    <  |  | (  <_> )${NC}"
echo -e "${RED}\\____|__  /__|__|_ \\ |__|  \\____/ ${NC}"
echo -e "${RED}        \\/        \\/              ${NC}"
echo -e "${RED}====================================================${NC}"

NIKTO_OUTPUT="$REPORT_DIR/nikto.txt"
if command -v nikto >/dev/null 2>&1 && [ -s "$HTTPX_OUTPUT" ]; then
    > "$NIKTO_OUTPUT"
    while read -r url; do
        [ -n "$url" ] && echo "[*] Scanning $url with Nikto..." && nikto -h "$url" >> "$NIKTO_OUTPUT" 2>&1 || true
    done < "$HTTPX_OUTPUT"
    echo "[*] Nikto results saved to $NIKTO_OUTPUT"
else
    echo "[!] Nikto not found or no HTTP services, skipping."
    touch "$NIKTO_OUTPUT"
fi
echo "====================" >> "$REPORT_DIR/report.txt"
echo "Nikto Scan Results" >> "$REPORT_DIR/report.txt"
cat "$NIKTO_OUTPUT" >> "$REPORT_DIR/report.txt"

echo "[*] Unicorn Scan finished! Reports saved in $REPORT_DIR"
