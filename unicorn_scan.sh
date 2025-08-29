#!/bin/bash
# unicorn_scan.sh - Automated Recon Script (Live output + default repo wordlists)
# By Alex 🦄

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
# Target
# ====================
TARGET=$1
[ -z "$TARGET" ] && { echo "Usage: $0 <target>"; exit 1; }
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# ====================
# Wordlists for Gobuster (auto-download if missing)
# ====================
WORDLIST_DIR="$SCRIPT_DIR/wordlists"
mkdir -p "$WORDLIST_DIR"

SMALL_WL="$WORDLIST_DIR/small.txt"
QUICKHIT_WL="$WORDLIST_DIR/quickhits.txt"
MEDIUM_WL="$WORDLIST_DIR/medium.txt"

[[ ! -f $SMALL_WL ]] && curl -sSL -o "$SMALL_WL" "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/common.txt"
[[ ! -f $QUICKHIT_WL ]] && curl -sSL -o "$QUICKHIT_WL" "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/quickhits.txt"
[[ ! -f $MEDIUM_WL ]] && curl -sSL -o "$MEDIUM_WL" "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/medium.txt"

WORDLISTS=(
    "$SMALL_WL"
    "$QUICKHIT_WL"
    "$MEDIUM_WL"
)

echo "[*] Gobuster wordlists ready:"
ls -1 "$WORDLIST_DIR"

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

# ====================
# Naabu Phase
# ====================
echo -e "\n${BLUE}[*] Running Naabu...${NC}"
if [ -n "$NAABU_BIN" ]; then
    PORTS=$($NAABU_BIN -host "$TARGET" -silent | tee /dev/tty | awk -F: '{print $2?$2:$1}' | tr '\n' ',' | sed 's/,$//')
else
    echo "[!] Naabu not found, skipping."
    PORTS=""
fi

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
    echo -e "${ORANGE}[*] Running Nmap on discovered ports: $PORTS${NC}"
    $NMAP_BIN -p "$PORTS" -sV "$TARGET" | tee /dev/tty > nmap_tmp.txt
else
    echo "[!] No ports found or Nmap missing, skipping."
    nmap_tmp.txt=""
fi

# ====================
# HTTPX Phase (live)
# ====================
echo -e "${PURPLE}====================================================${NC}"
echo -e "${PURPLE}               __    __  __            ${NC}"
echo -e "${PURPLE}   / /_  / /_/ /_____  _  __          ${NC}"
echo -e "${PURPLE}  / __ \\/ __/ __/ __ \\| |/_/          ${NC}"
echo -e "${PURPLE} / / / / /_/ /_/ /_/ />  <            ${NC}"
echo -e "${PURPLE}/_/ /_/\\__/\\__/ .___/_/|_|            ${NC}"
echo -e "${PURPLE}             /_/                      ${NC}"
echo -e "${PURPLE}====================================================${NC}"

HTTP_URLS=""
if [ -n "$HTTPX_BIN" ] && [ -f nmap_tmp.txt ]; then
    HTTP_URLS=$(grep 'open' nmap_tmp.txt | awk '$3 ~ /http/{print $1}' | cut -d/ -f1 | while read -r port; do
        echo "http://$TARGET:$port"
    done | $HTTPX_BIN -silent)
    echo "$HTTP_URLS"
fi

# ====================
# Gobuster Phase (live, auto wordlists)
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

if [ -n "$GOBUSTER_BIN" ] && [ -n "$HTTP_URLS" ]; then
    while IFS= read -r url; do
        [ -n "$url" ] && echo -e "${GREEN}[*] Scanning $url with Gobuster wordlists...${NC}"
        for WL in "${WORDLISTS[@]}"; do
            [ -f "$WL" ] && $GOBUSTER_BIN dir -u "$url" -w "$WL"
        done
    done <<< "$HTTP_URLS"
else
    echo "[!] Gobuster not found or no HTTP services, skipping."
fi

# ====================
# Nikto Phase (live)
# ====================
echo -e "${RED}====================================================${NC}"
echo -e "${RED} _______  .__ __      __          ${NC}"
echo -e "${RED} \\      \\ |__|  | ___/  |_  ____  ${NC}"
echo -e "${RED} /   |   \\|  |  |/ /\\   __\\/  _ \\ ${NC}"
echo -e "${RED}/    |    \\  |    <  |  | (  <_> )${NC}"
echo -e "${RED}\\____|__  /__|__|_ \\ |__|  \\____/ ${NC}"
echo -e "${RED}        \\/        \\/              ${NC}"
echo -e "${RED}====================================================${NC}"

if [ -n "$NIKTO_BIN" ] && [ -n "$HTTP_URLS" ]; then
    while IFS= read -r url; do
        [ -n "$url" ] && echo -e "${RED}[*] Scanning $url with Nikto...${NC}" && $NIKTO_BIN -h "$url"
    done <<< "$HTTP_URLS"
else
    echo "[!] Nikto not found or no HTTP services, skipping."
fi

echo "[*] Unicorn Scan finished!"
