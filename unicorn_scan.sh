#!/usr/bin/env bash
# unicorn_scan.sh - Full-featured Automated Recon Script (cleaned)
# By Alex 🦄  — revised
set -euo pipefail
IFS=$'\n\t'

# ====================
# Colors
# ====================
NC=$'\e[0m'
RED=$'\e[1;31m'
GREEN=$'\e[1;32m'
YELLOW=$'\e[0;93m'
BLUE=$'\e[1;34m'
PURPLE=$'\e[1;35m'
TEAL=$'\e[1;36m'
ORANGE=$'\e[38;5;208m'

# ====================
# Globals & arrays
# ====================
declare -A HTTPX_MAP
declare -A GOBUSTER_RESULTS
declare -A NUCLEI_RESULTS
TMP_FILES=()
TMP_DIR=""

# ====================
# Script directory
# ====================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ====================
# Cleanup (single trap)
# ====================
cleanup() {
    local rc=$?
    if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR" || true
    fi
    for f in "${TMP_FILES[@]:-}"; do
        [[ -e "$f" ]] && rm -f "$f" || true
    done
    exit $rc
}
trap cleanup EXIT

# ====================
# Tool finder (search common locations / PATH)
# ====================
find_tool() {
    local tool=$1
    local candidates=(
        "$SCRIPT_DIR/bin/$tool"
        "$HOME/go/bin/$tool"
        "/usr/local/bin/$tool"
        "/usr/bin/$tool"
        "/bin/$tool"
    )
    for p in "${candidates[@]}"; do
        [[ -x "$p" ]] && { echo "$p"; return 0; }
    done
    if command -v "$tool" >/dev/null 2>&1; then
        command -v "$tool"
        return 0
    fi
    echo ""
}

NAABU_BIN=$(find_tool naabu)
NMAP_BIN=$(find_tool nmap)
HTTPX_BIN=$(find_tool httpx)
GOBUSTER_BIN=$(find_tool gobuster)
NUCLEI_BIN=$(find_tool nuclei)
GIT_BIN=$(find_tool git)

# ====================
# Target
# ====================
TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
    echo -e "${RED}[!] Usage: $0 <target>${NC}"
    exit 1
fi

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
    if [[ -n "$GIT_BIN" ]]; then
        echo -e "${YELLOW}[*] Wordlists missing, cloning SecLists...${NC}"
        TMP_DIR=$(mktemp -d)
        TMP_FILES+=("$TMP_DIR")
        git clone --depth 1 https://github.com/danielmiessler/SecLists.git "$TMP_DIR/tmp_sec" >/dev/null 2>&1 || {
            echo -e "${RED}[!] Failed to clone SecLists. Check network/git.${NC}"
        }
        if [[ -d "$TMP_DIR/tmp_sec" ]]; then
            cp -f "$TMP_DIR/tmp_sec/Discovery/Web-Content/raft-small-directories.txt" "$SMALL_WL" 2>/dev/null || true
            cp -f "$TMP_DIR/tmp_sec/Discovery/Web-Content/quickhits.txt" "$QUICKHIT_WL" 2>/dev/null || true
            cp -f "$TMP_DIR/tmp_sec/Discovery/Web-Content/raft-medium-directories.txt" "$MEDIUM_WL" 2>/dev/null || true
            cp -f "$TMP_DIR/tmp_sec/Discovery/Web-Content/common.txt" "$COMMON_WL" 2>/dev/null || true
            rm -rf "$TMP_DIR/tmp_sec"
        else
            echo -e "${YELLOW}[!] SecLists not available — continuing without cloning.${NC}"
        fi
    else
        echo -e "${YELLOW}[!] git not found and wordlists missing — continuing.${NC}"
    fi
else
    echo -e "${GREEN}[*] Wordlists already present.${NC}"
fi

WORDLISTS=()
for wl in "$SMALL_WL" "$QUICKHIT_WL" "$MEDIUM_WL" "$COMMON_WL"; do
    [[ -f "$wl" ]] && WORDLISTS+=("$wl")
done

# ====================
# ASCII Banner
# ====================
print_banner() {
    # Set color
    printf '%b' "$TEAL"

    # Print ASCII banner literally (heredoc quoted)
    cat <<'EOF'
             _                                              
 /\ /\ _ __ (_) ___ ___  _ __ _ __      ___  ___ __ _ _ __ 
/ / \ \ '_ \| |/ __/ _ \| '__| '_ \    / __|/ __/ _` | '_ \
\ \_/ / | | | | (_| (_) | |  | | |     \__ \ (_| (_| | | | |
 \___/|_| |_|_|\___\___/|_|  |_| |_|___|___/\___\__,_|_| |_|
                                  |_____|                  
EOF

    # Reset color
    printf '%b\n' "$NC"
}

# Call it
print_banner

echo -e "${GREEN}[*] Starting Unicorn Scan on $TARGET${NC}"

# Create a dedicated temp dir for per-run files
TMP_DIR="${TMP_DIR:-$(mktemp -d)}"
TMP_FILES+=("$TMP_DIR")

# ====================
# Naabu Phase
# ====================
print_blue_banner() {
    printf '%b' "$BLUE"
    cat <<EOF
====================================================
                  __       
  ___  ___ ____ _/ /  __ __
 / _ \/ _ \/ _ \/ _ \/ // /
/_//_/\_,_/\_,_/_.__/\_,_/ 
====================================================
EOF
    printf '%b\n' "$NC"
}

print_blue_banner

PORTS=""
if [[ -n "$NAABU_BIN" ]]; then
    echo -e "${BLUE}[*] Running Naabu to discover open ports...${NC}"
    # using -silent for compact output; expect lines like host:port
    NAABU_OUT="$TMP_DIR/naabu.out"
    TMP_FILES+=("$NAABU_OUT")
    "$NAABU_BIN" -host "$TARGET" -silent 2>/dev/null | awk -F: '{print $2?$2:$1}' | sort -n -u > "$NAABU_OUT" || true
    if [[ -s "$NAABU_OUT" ]]; then
        PORTS=$(paste -sd, "$NAABU_OUT")
        echo -e "${GREEN}[*] Discovered ports: $PORTS${NC}"
    else
        echo -e "${YELLOW}[!] Naabu found no ports or failed.${NC}"
    fi
else
    echo -e "${RED}[!] Naabu not found, skipping port discovery.${NC}"
fi

# ====================
# Nmap Phase
# ====================
print_yellow_banner() {
    printf '%b' "$YELLOW"
    cat <<EOF
====================================================
 .-----.--------.---.-.-----.
 |     |        |  _  |  _  |
 |__|__|__|__|__|___._|   __|
                      |__|   
====================================================
EOF
    printf '%b\n' "$NC"
}

print_yellow_banner
if [[ -n "$PORTS" && -n "$NMAP_BIN" ]]; then
    NMAP_TMP="$TMP_DIR/nmap.out"
    TMP_FILES+=("$NMAP_TMP")
    echo -e "${ORANGE}[*] Running Nmap on discovered ports...${NC}"
    # -Pn omitted so hosts that block ping can still be checked if you want add -Pn
    "$NMAP_BIN" -p "$PORTS" -sV "$TARGET" | tee "$NMAP_TMP"
else
    if [[ -z "$PORTS" ]]; then
        echo -e "${YELLOW}[!] No ports discovered; skipping targeted Nmap scan.${NC}"
    else
        echo -e "${RED}[!] Nmap missing, skipping Nmap phase.${NC}"
    fi
fi

# Generate HTTP URLs from discovered ports
HTTP_URLS=""
if [[ -n "$PORTS" ]]; then
    for p in ${PORTS//,/ }; do
        proto="http"
        host="$TARGET"
        # Treat common TLS ports as https
        if [[ "$p" == "443" || "$p" == "8443" || "$p" == "7443" ]]; then
            proto="https"
        fi
        # only append :port if not default for proto
        if { [[ "$proto" == "http" && "$p" != "80" ]] || [[ "$proto" == "https" && "$p" != "443" ]]; }; then
            host="$TARGET:$p"
        fi
        HTTP_URLS+="$proto://$host"$'\n'
    done
    HTTP_URLS=$(echo "$HTTP_URLS" | sed '/^\s*$/d' | sort -u)
fi

# ====================
# HTTPX Phase
# ====================
print_httpx_banner() {
    # Use printf with %b to interpret ANSI codes
    printf '%b' "$GREEN"
    cat <<EOF
====================================================
    __    __  __                      
   / /_  / /_/ /_____  _  __          
  / __ \/ __/ __/ __ \| |/_/          
 / / / /_/ /_/ /_/ /  >  <            
/_/ /_/\__/\__/ .___/_/|_|            
             /_/                      
====================================================
EOF
    printf '%b\n' "$NC"
}

# Call the banner
print_httpx_banner

# Initialize array and results map
declare -a HTTP_URLS=()
declare -A HTTPX_RESULTS

# Populate URLs from discovered ports (output from Naabu/Nmap)
if [[ -n "$PORTS" ]]; then
    for p in ${PORTS//,/ }; do
        proto="http"
        [[ "$p" == "443" || "$p" == "8443" || "$p" == "7443" ]] && proto="https"

        host="$TARGET"
        # Append port if non-default
        [[ "$proto" == "http" && "$p" != "80" ]] && host="$TARGET:$p"
        [[ "$proto" == "https" && "$p" != "443" ]] && host="$TARGET:$p"

        HTTP_URLS+=("$proto://$host")
    done
fi

# Check if HTTPX exists and URLs are available
if [[ ${#HTTP_URLS[@]} -gt 0 && -n "$HTTPX_BIN" && command -v "$HTTPX_BIN" &>/dev/null ]]; then
    echo -e "${GREEN}[*] Running HTTPX on discovered URLs...${NC}"

    for url in "${HTTP_URLS[@]}"; do
        {
            TMP_HTTP="$TMP_DIR/httpx_$(echo "$url" | md5sum | awk '{print $1}')"
            TMP_FILES+=("$TMP_HTTP")
            
            # Corrected: -u for single URL
            "$HTTPX_BIN" -silent -title -status-code -u "$url" \
            | while read -r line; do
                echo -e "${GREEN}[HTTPX][$url] $line${NC}"
                HTTPX_RESULTS["$url"]+="$line"$'\n'
            done > "$TMP_HTTP" 2>/dev/null

        } &
    done

    # Wait for all parallel jobs to finish
    wait
    echo -e "${GREEN}[+] HTTPX phase complete.${NC}"
else
    echo -e "${YELLOW}[!] HTTPX skipped: no URLs discovered or HTTPX binary missing.${NC}"
fi
# ====================
# Gobuster Phase
# ====================
print_gobuster_banner() {
    cat <<EOF
${ORANGE}
====================================================
  _____       _               _            
 |  __ \     | |             | |           
 | |  \/ ___ | |__  _   _ ___| |_ ___ _ __ 
 | | __ / _ \| '_ \| | | / __| __/ _ \ '__|
 | |_\ \ (_) | |_) | |_| \__ \ ||  __/ |   
  \____/\___/|_.__/ \__,_|___/\__\___|_|   
====================================================
${NC}
EOF
}

print_gobuster_banner

# Ensure TMP_DIR exists
mkdir -p "${TMP_DIR:-/tmp/unicorn_scan}"

# Validate Gobuster binary
if [[ -z "$GOBUSTER_BIN" ]] || ! command -v "$GOBUSTER_BIN" &>/dev/null; then
    echo -e "${RED}[!] Gobuster binary not found. Skipping Gobuster phase.${NC}"
elif [[ ${#HTTP_URLS[@]} -eq 0 ]]; then
    echo -e "${YELLOW}[!] Gobuster skipped: No URLs provided.${NC}"
else
    # Wordlists should already exist; use them directly
    VALID_WORDLISTS=("$SMALL_WL" "$QUICKHIT_WL" "$MEDIUM_WL" "$COMMON_WL")

    echo -e "${PURPLE}[+] Starting Gobuster scans...${NC}"

    # Limit parallel jobs
    MAX_JOBS=5
    JOBS=0

    for url in "${HTTP_URLS[@]}"; do
        # Skip empty URLs just in case
        [[ -z "$url" ]] && continue

        for wordlist in "${VALID_WORDLISTS[@]}"; do
            # Skip missing wordlists (edge case)
            [[ ! -f "$wordlist" ]] && continue

            {
                WORDLIST_NAME=$(basename "$wordlist")
                echo -e "${TEAL}[Gobuster] Scanning $url with $WORDLIST_NAME${NC}"

                TMP_GOB="$TMP_DIR/gobuster_$(echo "$url" | md5sum | awk '{print $1}')_$WORDLIST_NAME"
                TMP_FILES+=("$TMP_GOB")

                # Run Gobuster safely, output to file and stdout simultaneously
                "$GOBUSTER_BIN" dir -u "$url" -w "$wordlist" -t 30 -q 2>/dev/null \
                | tee "$TMP_GOB" \
                | while IFS= read -r line || [[ -n "$line" ]]; do
                    echo -e "${TEAL}[Gobuster][$url|$WORDLIST_NAME] $line${NC}"
                    GOBUSTER_RESULTS["$url|$WORDLIST_NAME"]+="$line"$'\n'
                done
            } &

            ((JOBS++))
            if (( JOBS >= MAX_JOBS )); then
                wait
                JOBS=0
            fi
        done
    done

    # Wait for all remaining jobs
    wait
    echo -e "${PURPLE}[+] Gobuster phase completed.${NC}"
fi

# ====================
# Nuclei Phase
# ====================
print_nmap_banner() {
    printf "%b" "$RED"
    cat <<'EOF'
===================================================
                     .__         .__ 
  ____  __ __   ____ |  |   ____ |__|
 /    \|  |  \_/ ___\|  | _/ __ \|  |
|   |  \  |  /\  \___|  |_\  ___/|  |
|___|  /____/  \___  >____/\___  >__|
     \/            \/          \/    
===================================================
EOF
    printf "%b\n" "$NC"
}

# Call the Nmap banner when desired
print_nmap_banner

echo -e "${ORANGE}==================== Nuclei Phase ====================${NC}"

declare -A NUCLEI_RESULTS
NUCLEI_TEMPLATES=()  # Ensure exists, even if empty

# Ensure TMP_DIR exists
mkdir -p "${TMP_DIR:-/tmp/unicorn_scan}"

if [[ ${#HTTP_URLS[@]} -gt 0 && -n "$NUCLEI_BIN" && command -v "$NUCLEI_BIN" &>/dev/null ]]; then

    MAX_JOBS=5
    JOBS=0

    for url in "${HTTP_URLS[@]}"; do
        {
            echo -e "${ORANGE}[Nuclei] Scanning $url${NC}"

            # Use md5 hash of URL for temp file
            TMP_NUC="$TMP_DIR/nuclei_$(echo "$url" | md5sum | awk '{print $1}')"
            TMP_FILES+=("$TMP_NUC")

            # Build template parameters if any
            TEMPLATE_ARGS=()
            if [[ ${#NUCLEI_TEMPLATES[@]} -gt 0 ]]; then
                for t in "${NUCLEI_TEMPLATES[@]}"; do
                    [[ -f "$t" ]] && TEMPLATE_ARGS+=("-t" "$t")
                done
            fi

            # Run Nuclei scan safely
            if [[ ${#TEMPLATE_ARGS[@]} -gt 0 ]]; then
                "$NUCLEI_BIN" -u "$url" "${TEMPLATE_ARGS[@]}" -silent 2>/dev/null \
                | while read -r line; do
                    [[ -n "$line" ]] && echo -e "${GREEN}[Nuclei][$url] $line${NC}" && \
                    NUCLEI_RESULTS["$url"]+="$line"$'\n'
                done > "$TMP_NUC"
            else
                "$NUCLEI_BIN" -u "$url" -silent 2>/dev/null \
                | while read -r line; do
                    [[ -n "$line" ]] && echo -e "${GREEN}[Nuclei][$url] $line${NC}" && \
                    NUCLEI_RESULTS["$url"]+="$line"$'\n'
                done > "$TMP_NUC"
            fi

        } &

        ((JOBS++))
        if (( JOBS >= MAX_JOBS )); then
            wait
            JOBS=0
        fi
    done

    wait
    echo -e "${GREEN}[+] Nuclei phase completed.${NC}"

else
    echo -e "${YELLOW}[!] Nuclei skipped: missing URLs or binary.${NC}"
fi

echo -e "${YELLOW}[!] HTTPX → Gobuster → Nuclei processing complete.${NC}"

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

if [[ ${#HTTP_URLS[@]} -gt 0 ]]; then
   for url in "${!HTTPX_RESULTS[@]}"; do
       echo "$url -> ${HTTPX_RESULTS[$url]}"
   done
else
    echo -e "${YELLOW}[!] No HTTP URLs found.${NC}"
fi

echo -e "\nGobuster Results:"
if [[ ${#GOBUSTER_RESULTS[@]} -gt 0 ]]; then
    for url in "${!GOBUSTER_RESULTS[@]}"; do
        echo "$url:"
        [[ -n "${GOBUSTER_RESULTS[$url]}" ]] && echo -e "${GOBUSTER_RESULTS[$url]}"
    done
else
    echo -e "${YELLOW}[!] No Gobuster results.${NC}"
fi

echo -e "\nNuclei Results:"
if [[ ${#NUCLEI_RESULTS[@]} -gt 0 ]]; then
    for url in "${!NUCLEI_RESULTS[@]}"; do
        echo "$url:"
        [[ -n "${NUCLEI_RESULTS[$url]}" ]] && echo -e "${NUCLEI_RESULTS[$url]}"
    done
else
    echo -e "${YELLOW}[!] No Nuclei results.${NC}"
fi

echo -e "\nWordlists Used: ${WORDLISTS[*]:-None}"
echo -e "===================================================="
echo -e "${GREEN}[*] Unicorn Scan finished!${NC}"
