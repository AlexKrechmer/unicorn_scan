#!/bin/bash
# unicorn_scan.sh - Full-featured Automated Recon Script
# By Alex 🦄
# Usage: sudo ./unicorn_scan.sh <target>

set -euo pipefail
IFS=$'\n\t'

# ====================
# Colors
# ====================
NC="\033[0m"
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[0;93m"
BLUE="\033[1;34m"
PURPLE="\033[1;35m"
TEAL="\033[1;36m"
ORANGE="\033[1;33m"

# ====================
# Associative arrays
# ====================
declare -A HTTPX_MAP
declare -A GOBUSTER_RESULTS
declare -A NUCLEI_RESULTS

# ====================
# Script directory
# ====================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ====================
# Tool finder
# ====================
find_tool() {
    local tool=$1
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
NUCLEI_BIN=$(find_tool nuclei)

# ====================
# Target
# ====================
TARGET="${1:-}"
[ -z "$TARGET" ] && { echo -e "${RED}[!] Usage: $0 <target>${NC}"; exit 1; }

# ====================
# Wordlists
# ====================
WORDLIST_DIR="$SCRIPT_DIR/wordlists"
mkdir -p "$WORDLIST_DIR"

SMALL_WL="$WORDLIST_DIR/raft-small-directories.txt"
QUICKHIT_WL="$WORDLIST_DIR/quickhits.txt"
MEDIUM_WL="$WORDLIST_DIR/raft-medium-directories.txt"
COMMON_WL="$WORDLIST_DIR/common.txt"

if [[ ! -f "$SMALL_WL" || ! -f "$QUICKHIT_WL" || ! -f "$MEDIUM_WL" || ! -f "$COMMON_WL" ]]; then
    echo -e "${YELLOW}[*] Wordlists missing, cloning SecLists...${NC}"
    git clone --depth 1 https://github.com/danielmiessler/SecLists.git "$SCRIPT_DIR/tmp_sec"
    cp "$SCRIPT_DIR/tmp_sec/Discovery/Web-Content/raft-small-directories.txt" "$SMALL_WL"
    cp "$SCRIPT_DIR/tmp_sec/Discovery/Web-Content/quickhits.txt" "$QUICKHIT_WL"
    cp "$SCRIPT_DIR/tmp_sec/Discovery/Web-Content/raft-medium-directories.txt" "$MEDIUM_WL"
    cp "$SCRIPT_DIR/tmp_sec/Discovery/Web-Content/common.txt" "$COMMON_WL"
    rm -rf "$SCRIPT_DIR/tmp_sec"
else
    echo -e "${GREEN}[*] Wordlists already present.${NC}"
fi

WORDLISTS=("$SMALL_WL" "$QUICKHIT_WL" "$MEDIUM_WL" "$COMMON_WL")

# ====================
# ASCII Banner
# ====================
print_banner() {
    echo -e "${YELLOW}${TEAL}$"
    echo "           _                                               "
    echo " /\ /\ _ __ (_) ___ ___  _ __ _ __      ___  ___ __ _ _ __ "
    echo "/ / \ \ '_ \| |/ __/ _ \| '__| '_ \   / __|/ __/ _\` | '_ \\"
    echo "\ \_/ / | | | | (_| (_) | |  | | |     \__ \ (_| (_| | | | | "
    echo " \___/|_| |_|_|\___\___/|_|  |_| |_|___|___/\___\__,_|_| |_|"
    echo "                                  |_____|                  "
    echo -e "${NC}"
}
print_banner
echo -e "${GREEN}[*] Starting Unicorn Scan on $TARGET${NC}"

# ====================
# Naabu Phase
# ====================
echo -e "${PURPLE}"
echo "===================================================="
echo "                  __       "
echo "      ___  ___ ____ _/ /  __ __"
echo " / _ \/ _ \/ _ \/ _ \/ // /"
echo "/_//_/\_,_/\_,_/_.__/\_,_/ "
echo "===================================================="
echo -e "${NC}"

PORTS=""
if [ -n "$NAABU_BIN" ]; then
    echo -e "${BLUE}[*] Running Naabu to discover open ports...${NC}"
    PORTS=$($NAABU_BIN -host "$TARGET" -silent 2>/dev/null | awk -F: '{print $2?$2:$1}' | sort -nu | tr '\n' ',' | sed 's/,$//')
    [ -n "$PORTS" ] && echo -e "${GREEN}[*] Discovered ports: $PORTS${NC}"
else
    echo -e "${RED}[!] Naabu not found, skipping port discovery.${NC}"
fi

# ====================
# Nmap Phase
# ====================
echo -e "${YELLOW}"
echo "===================================================="
echo " .-----.--------.---.-.-----."
echo " |     |        |  _  |  _  |"
echo " |__|__|__|__|__|___._|   __|"
echo "                      |__|   "
echo "===================================================="
echo -e "${NC}"

NMAP_TMP=$(mktemp)
trap 'rm -f "$NMAP_TMP"' EXIT
if [ -n "$PORTS" ] && [ -n "$NMAP_BIN" ]; then
    echo -e "${ORANGE}[*] Running Nmap on discovered ports...${NC}"
    $NMAP_BIN -p "$PORTS" -sV "$TARGET" | tee /dev/tty > "$NMAP_TMP"
else
    echo -e "${RED}[!] No ports found or Nmap missing, skipping.${NC}"
fi

# Generate HTTP URLs from discovered ports
HTTP_URLS=""
if [ -n "$PORTS" ]; then
    for p in $(echo "$PORTS" | tr ',' ' '); do
        proto="http"
        url="$TARGET"
        [[ "$p" == "443" || "$p" == "8443" ]] && proto="https"
        [[ "$p" != "80" && "$p" != "443" ]] && url="$TARGET:$p"
        HTTP_URLS+="$proto://$url"$'\n'
    done
    HTTP_URLS=$(echo "$HTTP_URLS" | sed '/^\s*$/d')
fi

# ====================
# HTTPX Phase
# ====================
echo -e "${BLUE}"
echo "===================================================="
echo "    __    __  __                      "
echo "   / /_  / /_/ /_____  _  __          "
echo "  / __ \/ __/ __/ __ \| |/_/          "
echo " / / / / /_/ /_/ /_/ />  <            "
echo "/_/ /_/\__/\__/ .___/_/|_|            "
echo "             /_/                      "
echo "===================================================="
echo -e "${NC}"

declare -A HTTPX_MAP
if [[ -n "$HTTPX_BIN" && -n "$HTTP_URLS" ]]; then
    TMP_HTTP=$(mktemp)
    echo "$HTTP_URLS" > "$TMP_HTTP"
    trap 'rm -f "$TMP_HTTP"' EXIT

    HTTPX_RESULTS=$(
        $HTTPX_BIN -list "$TMP_HTTP" \
            -threads 50 \
            -timeout 10 \
            -status-code \
            -follow-redirects \
            -ports 80,443,8080,8443,8000,5000,3000 \
            -title \
            -vhost \
            -no-color
    )

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        url=$(echo "$line" | awk '{print $1}')
        meta=$(echo "$line" | cut -d' ' -f2-)
        HTTPX_MAP["$url"]="$meta"
    done <<< "$HTTPX_RESULTS"

    if [[ ${#HTTPX_MAP[@]} -gt 0 ]]; then
        echo -e "${GREEN}[*] Live HTTP URLs discovered:${NC}"
        for u in "${!HTTPX_MAP[@]}"; do
            echo "$u -> ${HTTPX_MAP[$u]}"
        done
    else
        echo -e "${YELLOW}[!] No responsive HTTP URLs found.${NC}"
    fi
else
    echo -e "${RED}[!] httpx not found or no URLs to scan.${NC}"
fi
# ====================
# Gobuster Phase
# ====================
echo -e "${GREEN}"
echo "===================================================="
echo "  _____       _               _            "
echo " |  __ \     | |             | |           "
echo " | |  \/ ___ | |__  _   _ ___| |_ ___ _ __ "
echo " | | __ / _ \| '_ \| | | / __| __/ _ \ '__|"
echo " | |_\ \ (_) | |_) | |_| \__ \ ||  __/ |   "
echo "  \____/\___/|_.__/ \__,_|___/\__\___|_|   "
echo "===================================================="
echo -e "${NC}"

declare -A GOBUSTER_RESULTS
if [[ -n "$GOBUSTER_BIN" && ${#HTTPX_MAP[@]} -gt 0 ]]; then
    for WL in "${WORDLISTS[@]}"; do
        echo -e "${YELLOW}[*] Using wordlist: $WL${NC}"
        for url in "${!HTTPX_MAP[@]}"; do
            TMP_GOB=$(mktemp)
            $GOBUSTER_BIN dir -u "$url" -w "$WL" -x php,html -t 50 -o "$TMP_GOB" -q
            [[ -s "$TMP_GOB" ]] && GOBUSTER_RESULTS["$url"]+=$(cat "$TMP_GOB")$'\n'
            rm -f "$TMP_GOB"
        done
    done
else
    echo -e "${YELLOW}[*] Gobuster skipped (missing tool or no live URLs).${NC}"
fi

# ====================
# Nuclei Phase
# ====================
echo -e "${RED}"
echo "===================================================="
echo "                     .__         .__ "
echo "  ____  __ __   ____ |  |   ____ |__|"
echo " /    \|  |  \_/ ___\|  | _/ __ \|  |"
echo "|   |  \  |  /\  \___|  |_\  ___/|  |"
echo "|___|  /____/  \___  >____/\___  >__|"
echo "     \/            \/          \/    "
echo "===================================================="
echo -e "${NC}"

declare -A NUCLEI_RESULTS
if [[ -n "$NUCLEI_BIN" && ${#HTTPX_MAP[@]} -gt 0 ]]; then
    for url in "${!HTTPX_MAP[@]}"; do
        TMP_NUC=$(mktemp)
        $NUCLEI_BIN -u "$url" -silent -o "$TMP_NUC" || echo "[!] Nuclei scan failed for $url"
        [[ -s "$TMP_NUC" ]] && NUCLEI_RESULTS["$url"]="$(cat "$TMP_NUC")"
        rm -f "$TMP_NUC"
    done
else
    echo -e "${BLUE}[*] Nuclei skipped (missing tool or no live URLs).${NC}"
fi

# ====================
# Summary
# ====================
echo -e "${GREEN}
====================================================
UNICORN SCAN SUMMARY
Target: $TARGET
Open Ports: ${PORTS:-None}
====================================================
HTTP URLs Discovered:
${NC}"

if [[ ${#HTTPX_MAP[@]} -gt 0 ]]; then
    for url in "${!HTTPX_MAP[@]}"; do
        echo "$url -> ${HTTPX_MAP[$url]}"
    done
else
    echo -e "${YELLOW}[!] No HTTP URLs found.${NC}"
fi

echo -e "\nGobuster Results:"
if [[ ${#GOBUSTER_RESULTS[@]} -gt 0 ]]; then
    for url in "${!GOBUSTER_RESULTS[@]}"; do
        echo "$url:"
        echo -e "${GOBUSTER_RESULTS[$url]}"
    done
else
    echo -e "${YELLOW}[!] No Gobuster results.${NC}"
fi

echo -e "\nNuclei Results:"
if [[ ${#NUCLEI_RESULTS[@]} -gt 0 ]]; then
    for url in "${!NUCLEI_RESULTS[@]}"; do
        echo "$url:"
        echo -e "${NUCLEI_RESULTS[$url]}"
    done
else
    echo -e "${YELLOW}[!] No Nuclei results.${NC}"
fi

echo -e "
Wordlists Used: ${WORDLISTS[*]}
====================================================
[*] Unicorn Scan finished!
${NC}"
