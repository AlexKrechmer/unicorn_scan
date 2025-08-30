#!/bin/bash
# unicorn_scan.sh - Automated Recon Script (Live output + default repo wordlists)
# By Alex 🦄
# Safe to run with: sudo ./unicorn_scan.sh <target>

set -euo pipefail
IFS=$'\n\t'

# Detect script directory reliably
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
# Script directory
# ====================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ====================
# Tool finder
# ====================
find_tool() {
    local tool=$1
    # Check custom script bin first
    for path in "$SCRIPT_DIR/bin/$tool" "$HOME/go/bin/$tool" "/usr/local/bin/$tool" "/usr/bin/$tool"; do
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
# Wordlists for Gobuster
# ====================
WORDLIST_DIR="$SCRIPT_DIR/wordlists"
mkdir -p "$WORDLIST_DIR"

GOBUSTER_DEFAULTS=(
    "/usr/share/gobuster/wordlists"
    "/usr/share/wordlists/gobuster"
)

SMALL_WL=""
QUICKHIT_WL=""
MEDIUM_WL=""
for path in "${GOBUSTER_DEFAULTS[@]}"; do
    [ -f "$path/common.txt" ] && SMALL_WL="$path/common.txt"
    [ -f "$path/quickhits.txt" ] && QUICKHIT_WL="$path/quickhits.txt"
    [ -f "$path/medium.txt" ] && MEDIUM_WL="$path/medium.txt"
done

[[ ! -f "$SMALL_WL" ]] && SMALL_WL="$WORDLIST_DIR/small.txt" && curl -sSL -o "$SMALL_WL" "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/common.txt"
[[ ! -f "$QUICKHIT_WL" ]] && QUICKHIT_WL="$WORDLIST_DIR/quickhits.txt" && curl -sSL -o "$QUICKHIT_WL" "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/quickhits.txt"
[[ ! -f "$MEDIUM_WL" ]] && MEDIUM_WL="$WORDLIST_DIR/medium.txt" && curl -sSL -o "$MEDIUM_WL" "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/medium.txt"

WORDLISTS=("$SMALL_WL" "$QUICKHIT_WL" "$MEDIUM_WL")
echo "[*] Gobuster wordlists ready:"
for wl in "${WORDLISTS[@]}"; do
    [ -f "$wl" ] && echo " - $wl"
done

# ====================
# Unicorn Banner
# ====================
echo -e "${PINK}           _                                               ${NC}"
echo -e "${YELLOW} /\ /\ _ __ (_) ___ ___  _ __ _ __      ___  ___ __ _ _ __ ${NC}"
echo -e "${TEAL}/ / \ \ '_ \| |/ __/ _ \| '__| '_ \    / __|/ __/ _\` | '_ \\ ${NC}"
echo -e "${PINK}\\ \_/ / | | | | (_| (_) | |  | | |   \__ \ (_| (_| | | | |${NC}"
echo -e "${YELLOW} \___/|_| |_|_|\___\___/|_|  |_| |_|___|___/\___\__,_|_| |_|${NC}"
echo -e "${TEAL}                                  |_____|                  ${NC}"
echo "[*] Starting Unicorn Scan on $TARGET"

# ====================
# Naabu Phase
# ====================
echo -e "${BLUE}
                  __       
  ___  ___ ____ _/ /  __ __
 / _ \/ _ \`/ _ \`/ _ \/ // /
/_//_/\_,_/\_,_/_.__/\_,_/ 
${NC}"

PORTS=""
if [ -n "$NAABU_BIN" ]; then
    PORTS=$($NAABU_BIN -host "$TARGET" -silent | awk -F: '{print $2?$2:$1}' | sort -nu | tr '\n' ',' | sed 's/,$//')
    [ -n "$PORTS" ] && echo "[*] Discovered ports: $PORTS"
else
    echo "[!] Naabu not found, skipping."
fi

# ====================
# Nmap Phase
# ====================
echo -e "${ORANGE}
====================================================
 .-----.--------.---.-.-----.
 |     |        |  _  |  _  |
 |__|__|__|__|__|___._|   __|
                      |__|   
====================================================
${NC}"

NMAP_TMP=$(mktemp)
if [ -n "$PORTS" ] && [ -n "$NMAP_BIN" ]; then
    echo -e "${ORANGE}[*] Running Nmap on discovered ports...${NC}"
    $NMAP_BIN -p "$PORTS" -sV "$TARGET" | tee /dev/tty > "$NMAP_TMP"
else
    echo "[!] No ports found or Nmap missing, skipping."
fi

# ====================
# HTTP URL Generation (with HTTPX fallback)
# ====================
echo -e "${PURPLE}
====================================================
               __    __  __            
   / /_  / /_/ /_____  _  __          
  / __ \\/ __/ __/ __ \\| |/_/          
 / / / / /_/ /_/ /_/ />  <            
/_/ /_/\\__/\\__/ .___/_/|_|            
             /_/                      
====================================================
${NC}"

# Extract HTTP ports from Nmap
HTTP_PORTS=$(awk '/open/ && $3 ~ /http/ {gsub("/tcp","",$1); print $1}' "$NMAP_TMP")
HTTP_URLS=""
for port in $HTTP_PORTS; do
    HTTP_URLS+="http://$TARGET:$port"$'\n'
done

# Run through HTTPX if installed, fallback silently
if [ -n "$HTTPX_BIN" ] && [ -n "$HTTP_URLS" ]; then
    HTTP_URLS=$($HTTPX_BIN -silent <<< "$HTTP_URLS" || echo "$HTTP_URLS")
fi

# Show URLs
[ -n "$HTTP_URLS" ] && echo -e "${GREEN}[*] HTTP URLs:${NC}\n$HTTP_URLS"

# ====================
# Gobuster Phase
# ====================
echo -e "${GREEN}
====================================================
  _____       _               _            
 |  __ \\     | |             | |           
 | |  \\/ ___ | |__  _   _ ___| |_ ___ _ __ 
 | | __ / _ \\| '_ \\| | | / __| __/ _ \\ '__|
 | |_\\ \\ (_) | |_) | |_| \\__ \\ ||  __/ |   
  \\____/\\___/|_.__/ \\__,_|___/\\__\\___|_|   
====================================================
${NC}"

if [ -n "$GOBUSTER_BIN" ] && [ -n "$HTTP_URLS" ]; then
    while IFS= read -r url; do
        [ -n "$url" ] && url="${url%/}"
        echo -e "${GREEN}[*] Scanning $url with Gobuster wordlists...${NC}"
        for WL in "${WORDLISTS[@]}"; do
            [ -f "$WL" ] && $GOBUSTER_BIN dir -u "$url" -w "$WL" -q
        done
    done <<< "$HTTP_URLS"
fi

# ====================
# Nikto Phase
# ====================
echo -e "${RED}
====================================================
 _______  .__ __      __          
 \\      \\ |__|  | ___/  |_  ____  
 /   |   \\|  |  |/ /\\   __\\/  _ \\ 
/    |    \\  |    <  |  | (  <_> )
\\____|__  /__|__|_ \\ |__|  \\____/ 
        \\/        \\/              
====================================================
${NC}"

if [ -n "$NIKTO_BIN" ] && [ -n "$HTTP_URLS" ]; then
    while IFS= read -r url; do
        [ -n "$url" ] && url="${url%/}"
        echo -e "${RED}[*] Scanning $url with Nikto...${NC}" 
        $NIKTO_BIN -h "$url"
    done <<< "$HTTP_URLS"
fi

# ====================
# Cleanup
# ====================
rm -f "$NMAP_TMP"
echo "[*] Unicorn Scan finished!"
