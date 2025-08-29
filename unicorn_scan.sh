#!/bin/bash
# unicorn_scan.sh - Automated Recon Script
# By Alex 🦄
# ====================
# Clean output + ASCII banners

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

# ====================
# Tool finder
# ====================
find_tool() {
    local tool=$1
    for path in "$HOME/go/bin/$tool" "/usr/local/bin/$tool" "/usr/bin/$tool"; do
        [ -x "$path" ] && echo "$path" && return
    done
    command -v "$tool" >/dev/null 2>&1 && command -v "$tool" && return
    echo ""
}

NAABU_BIN=$(find_tool naabu)
NMAP_BIN=$(find_tool nmap)
HTTPX_BIN=$(find_tool httpx)
GOBUSTER_BIN=$(find_tool gobuster)
NIKTO_BIN=$(find_tool nikto)

# ====================
# Target & Reports
# ====================
TARGET=$1
[ -z "$TARGET" ] && { echo "Usage: $0 <target>"; exit 1; }
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="unicorn_report_${TARGET}_${TIMESTAMP}"
mkdir -p "$REPORT_DIR"

NAABU_OUTPUT="$REPORT_DIR/naabu.txt"
NMAP_OUTPUT="$REPORT_DIR/nmap.txt"
HTTPX_OUTPUT="$REPORT_DIR/httpx.txt"
GOBUSTER_OUTPUT="$REPORT_DIR/gobuster.txt"
NIKTO_OUTPUT="$REPORT_DIR/nikto.txt"
REPORT_FILE="$REPORT_DIR/report.txt"

# ====================
# Unicorn Banner
# ====================
echo -e "${PINK}           _                                               ${NC}"
echo -e "${YELLOW} /\ /\ _ __ (_) ___ ___  _ __ _ __      ___  ___ __ _ _ __ ${NC}"
echo -e "${TEAL}/ / \ \ '_ \| |/ __/ _ \| '__| '_ \    / __|/ __/ _\` | '_ \\ ${NC}"
echo -e "${PINK}\\ \_/ / | | | | (_| (_) | |  | | | |   \__ \ (_| (_| | | | |${NC}"
echo -e "${YELLOW} \___/|_| |_|_|\___\___/|_|  |_| |_|___|___/\___\__,_|_| |_|${NC}"
echo -e "${TEAL}                                  |_____|                  ${NC}"
echo "[*] Starting Unicorn Scan on $TARGET"
echo "[*] Reports will be saved to $REPORT_DIR"

# ====================
# Naabu Phase
# ====================
[ -n "$NAABU_BIN" ] && echo "[*] Running Naabu..." && $NAABU_BIN -host "$TARGET" -o "$NAABU_OUTPUT" || touch "$NAABU_OUTPUT"
PORTS=$(awk -F: '{print $2?$2:$1}' "$NAABU_OUTPUT" | tr '\n' ',' | sed 's/,$//')
echo "[*] Naabu results saved to $NAABU_OUTPUT"
echo "====================" >> "$REPORT_FILE"
echo "Naabu Fast Scan" >> "$REPORT_FILE"
cat "$NAABU_OUTPUT" >> "$REPORT_FILE"

# ====================
# Nmap Phase
# ====================
echo -e "${ORANGE}====================================================${NC}"
echo -e "${ORANGE} .-----.--------.---.-.-----.${NC}"
echo -e "${ORANGE} |     |        |  _  |  _  |${NC}"
echo -e "${ORANGE} |__|__|__|__|__|___._|   __|${NC}"
echo -e "${ORANGE}                      |__|   ${NC}"
echo -e "${ORANGE}====================================================${NC}"

if [ -n "$PORTS" ] && [ -n "$NMAP_BIN" ]; then
    echo "[*] Running Nmap on discovered ports: $PORTS"
    $NMAP_BIN -p "$PORTS" -sV "$TARGET" -oN "$NMAP_OUTPUT" || touch "$NMAP_OUTPUT"
else
    echo "[!] No ports found or Nmap missing, skipping Nmap."
    touch "$NMAP_OUTPUT"
fi
echo "[*] Nmap results saved to $NMAP_OUTPUT"
echo "====================" >> "$REPORT_FILE"
echo "Nmap Scan on Discovered Ports: $PORTS" >> "$REPORT_FILE"
cat "$NMAP_OUTPUT" >> "$REPORT_FILE"

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

if [ -n "$HTTPX_BIN" ] && [ -s "$NMAP_OUTPUT" ]; then
    grep 'open' "$NMAP_OUTPUT" | awk '$3 ~ /http/{print $1}' | cut -d/ -f1 | while read -r port; do
        echo "http://$TARGET:$port"
    done | $HTTPX_BIN -silent -o "$HTTPX_OUTPUT" || touch "$HTTPX_OUTPUT"
    echo "[*] HTTPX results saved to $HTTPX_OUTPUT"
else
    echo "[!] HTTPX not found or no HTTP ports, skipping."
    touch "$HTTPX_OUTPUT"
fi
echo "====================" >> "$REPORT_FILE"
echo "HTTPX Scan" >> "$REPORT_FILE"
cat "$HTTPX_OUTPUT" >> "$REPORT_FILE"

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

if [ -n "$GOBUSTER_BIN" ] && [ -s "$HTTPX_OUTPUT" ]; then
    > "$GOBUSTER_OUTPUT"
    while read -r url; do
        [ -n "$url" ] && $GOBUSTER_BIN dir -u "$url" -w /usr/share/wordlists/dirb/common.txt >> "$GOBUSTER_OUTPUT" 2>&1 || true
    done < "$HTTPX_OUTPUT"
    echo "[*] Gobuster results saved to $GOBUSTER_OUTPUT"
else
    echo "[!] Gobuster not found or no HTTP services, skipping."
    touch "$GOBUSTER_OUTPUT"
fi
echo "====================" >> "$REPORT_FILE"
echo "Gobuster Scan" >> "$REPORT_FILE"
cat "$GOBUSTER_OUTPUT" >> "$REPORT_FILE"

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

if [ -n "$NIKTO_BIN" ] && [ -s "$HTTPX_OUTPUT" ]; then
    > "$NIKTO_OUTPUT"
    while read -r url; do
        [ -n "$url" ] && echo "[*] Scanning $url with Nikto..." && $NIKTO_BIN -h "$url" >> "$NIKTO_OUTPUT" 2>&1 || true
    done < "$HTTPX_OUTPUT"
    echo "[*] Nikto results saved to $NIKTO_OUTPUT"
else
    echo "[!] Nikto not found or no HTTP services, skipping."
    touch "$NIKTO_OUTPUT"
fi
echo "====================" >> "$REPORT_FILE"
echo "Nikto Scan Results" >> "$REPORT_FILE"
cat "$NIKTO_OUTPUT" >> "$REPORT_FILE"

echo "[*] Unicorn Scan finished! Reports saved in $REPORT_DIR"

