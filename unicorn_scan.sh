#!/usr/bin/env bash
# unicorn_scan.sh - Full-featured Automated Recon Script (fixed)
# By Alex 🦄  — revised
set -euo pipefail
IFS=$'\n\t'

# ====================
# Safe color enable
# ====================
enable_colors() {
  # default to no colors
  NC=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; PURPLE=''; TEAL=''; ORANGE=''

  # Only enable colors if stdout is a terminal and TERM looks ok
  if [[ -t 1 ]] && [[ -n "${TERM:-}" ]]; then
    if command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
      NC=$'\e[0m'
      RED=$'\e[1;31m'
      GREEN=$'\e[1;32m'
      YELLOW=$'\e[0;93m'
      BLUE=$'\e[1;34m'
      PURPLE=$'\e[1;35m'
      TEAL=$'\e[1;36m'
      ORANGE=$'\e[38;5;208m'
    fi
  fi
}
enable_colors

# ====================
# Globals & arrays
# ====================
declare -A HTTPX_MAP
declare -A GOBUSTER_RESULTS
declare -A NUCLEI_RESULTS
declare -A HTTPX_RESULTS
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
    # remove temp dir if created
    if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR" || true
    fi
    # remove any temp files tracked
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
    printf '%b\n' "${RED}[!] Usage: $0 <target>${NC}"
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
        printf '%b\n' "${YELLOW}[*] Wordlists missing, cloning SecLists...${NC}"
        TMP_DIR=$(mktemp -d)
        TMP_FILES+=("$TMP_DIR")
        git clone --depth 1 https://github.com/danielmiessler/SecLists.git "$TMP_DIR/tmp_sec" >/dev/null 2>&1 || {
            printf '%b\n' "${RED}[!] Failed to clone SecLists. Check network/git.${NC}"
        }
        if [[ -d "$TMP_DIR/tmp_sec" ]]; then
            cp -f "$TMP_DIR/tmp_sec/Discovery/Web-Content/raft-small-directories.txt" "$SMALL_WL" 2>/dev/null || true
            cp -f "$TMP_DIR/tmp_sec/Discovery/Web-Content/quickhits.txt" "$QUICKHIT_WL" 2>/dev/null || true
            cp -f "$TMP_DIR/tmp_sec/Discovery/Web-Content/raft-medium-directories.txt" "$MEDIUM_WL" 2>/dev/null || true
            cp -f "$TMP_DIR/tmp_sec/Discovery/Web-Content/common.txt" "$COMMON_WL" 2>/dev/null || true
            rm -rf "$TMP_DIR/tmp_sec"
        else
            printf '%b\n' "${YELLOW}[!] SecLists not available — continuing without cloning.${NC}"
        fi
    else
        printf '%b\n' "${YELLOW}[!] git not found and wordlists missing — continuing.${NC}"
    fi
else
    printf '%b\n' "${GREEN}[*] Wordlists already present.${NC}"
fi

WORDLISTS=()
for wl in "$SMALL_WL" "$QUICKHIT_WL" "$MEDIUM_WL" "$COMMON_WL"; do
    [[ -f "$wl" ]] && WORDLISTS+=("$wl")
done

# ====================
# ASCII Banner (main)
# ====================
print_banner() {
  local COLOR="${TEAL}"
  local RESET="${NC}"

  cat <<EOF
${COLOR}             _                                              
 /\ /\ _ __ (_) ___ ___  _ __ _ __      ___  ___ __ _ _ __ 
/ / \ \ '_ \| |/ __/ _ \| '__| '_ \    / __|/ __/ _\` | '_ \\
\ \_/ / | | | | (_| (_) | |  | | |     \__ \ (_| (_| | | | |
 \___/|_| |_|_|\\___\___/|_|  |_| |_|___|___/\\___\__,_|_| |_|
                                  |_____|                  
${RESET}
EOF
}

print_banner


printf '%b\n' "${GREEN}[*] Starting Unicorn Scan on $TARGET${NC}"

# Create a dedicated temp dir for per-run files
TMP_DIR="${TMP_DIR:-$(mktemp -d)}"
TMP_FILES+=("$TMP_DIR")

# ====================
# Naabu Phase
# ====================
print_naabu_banner() {
    printf '%b' "$BLUE"
    cat <<'EOF'
====================================================
                  __       
  ___  ___ ____ _/ /  __ __
 / _ \/ _ \/ _ \/ _ \/ // /
/_//_/\_,_/\_,_/_.__/\_,_/ 
====================================================
EOF
    printf '%b\n' "$NC"
}
print_naabu_banner

PORTS=""
if [[ -n "$NAABU_BIN" ]]; then
    printf '%b\n' "${BLUE}[*] Running Naabu to discover open ports...${NC}"
    NAABU_OUT="$TMP_DIR/naabu.out"
    TMP_FILES+=("$NAABU_OUT")
    # Naabu prints host:port lines (we extract ports)
    "$NAABU_BIN" -host "$TARGET" -silent 2>/dev/null | awk -F: '{print $2?$2:$1}' | sort -n -u > "$NAABU_OUT" || true
    if [[ -s "$NAABU_OUT" ]]; then
        PORTS=$(paste -sd, "$NAABU_OUT")
        printf '%b\n' "${GREEN}[*] Discovered ports: $PORTS${NC}"
    else
        printf '%b\n' "${YELLOW}[!] Naabu found no ports or failed.${NC}"
    fi
else
    printf '%b\n' "${RED}[!] Naabu not found, skipping port discovery.${NC}"
fi

# ====================
# Nmap Phase
# ====================
print_yellow_banner() {
    printf '%b' "$YELLOW"
    cat <<'EOF'
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
    printf '%b\n' "${ORANGE}[*] Running Nmap on discovered ports...${NC}"
    "$NMAP_BIN" -p "$PORTS" -sV "$TARGET" | tee "$NMAP_TMP"
else
    if [[ -z "$PORTS" ]]; then
        printf '%b\n' "${YELLOW}[!] No ports discovered; skipping targeted Nmap scan.${NC}"
    else
        printf '%b\n' "${RED}[!] Nmap missing, skipping Nmap phase.${NC}"
    fi
fi

# Generate HTTP_URLS array from discovered ports (explicit array)
declare -a HTTP_URLS=()
if [[ -n "$PORTS" ]]; then
    for p in ${PORTS//,/ }; do
        proto="http"
        host="$TARGET"
        if [[ "$p" == "443" || "$p" == "8443" || "$p" == "7443" ]]; then
            proto="https"
        fi
        if { [[ "$proto" == "http" && "$p" != "80" ]] || [[ "$proto" == "https" && "$p" != "443" ]]; }; then
            host="$TARGET:$p"
        fi
        HTTP_URLS+=("$proto://$host")
    done
fi

# ====================
# HTTPX Phase (safe: write to temp, then process in main shell)
# ====================
print_httpx_banner() {
    # Status lines in color
    printf '%b\n' "${GREEN}====================================================${NC}"
    printf '%b\n' "${GREEN}[*] HTTPX Phase${NC}"
    printf '%b\n' "${GREEN}====================================================${NC}"

    # ASCII art without color codes for reliability
    cat <<'EOF'
    __    __  __                      
   / /_  / /_/ /_____  _  __          
  / __ \/ __/ __/ __ \| |/_/          
 / / / /_/ /_/ /_/ /  >  <            
/_/ /_/\__/\__/ .___/_/|_|            
             /_/                      
EOF

    printf '%b\n' "${GREEN}====================================================${NC}"
}
print_httpx_banner

# Prepare temp files for HTTPX jobs
declare -a HTTPX_TMP_FILES=()
if [[ ${#HTTP_URLS[@]} -gt 0 ]] && [[ -n "$HTTPX_BIN" ]] && command -v "$HTTPX_BIN" &>/dev/null; then
    printf '%b\n' "${GREEN}[*] Running HTTPX on discovered URLs...${NC}"

    MAX_JOBS=${MAX_JOBS:-10}
    JOBS=0

    for url in "${HTTP_URLS[@]}"; do
        TMP_HTTP="$TMP_DIR/httpx_$(printf '%s' "$url" | md5sum | cut -d' ' -f1)"
        HTTPX_TMP_FILES+=("$TMP_HTTP")
        TMP_FILES+=("$TMP_HTTP")
        # Run httpx in background, save output to tmp file
        (
            "$HTTPX_BIN" -silent -title -status-code -u "$url" > "$TMP_HTTP" 2>&1 || true
        ) &
        ((JOBS++))
        if (( JOBS >= MAX_JOBS )); then
            wait
            JOBS=0
        fi
    done

    wait

    # Process HTTPX temp files in main shell so associative updates persist
    for tmp in "${HTTPX_TMP_FILES[@]}"; do
        [[ ! -f "$tmp" ]] && continue
        while IFS= read -r line || [[ -n "$line" ]]; do
            HTTPX_RESULTS["$tmp"]+="$line"$'\n'
            printf '%b\n' "${GREEN}[HTTPX][$tmp] $line${NC}"
        done < "$tmp"
    done

    printf '%b\n' "${GREEN}[+] HTTPX phase complete.${NC}"
else
    printf '%b\n' "${YELLOW}[!] HTTPX skipped: no URLs discovered or HTTPX binary missing.${NC}"
fi


# ====================
# Gobuster Phase (robust & uses wordlists)
# ====================
print_gobuster_banner() {
    printf '%b' "$ORANGE"
    cat <<'EOF'
====================================================
  _____       _               _            
 |  __ \     | |             | |           
 | |  \/ ___ | |__  _   _ ___| |_ ___ _ __ 
 | | __ / _ \| '_ \| | | / __| __/ _ \ '__|
 | |_\ \ (_) | |_) | |_| \__ \ ||  __/ |   
  \____/\___/|_.__/ \__,_|___/\__\___|_|   
====================================================
EOF
    printf '%b\n' "$NC"
}
print_gobuster_banner

# Ensure TMP_DIR exists (again to be safe)
mkdir -p "${TMP_DIR:-/tmp/unicorn_scan}"

if [[ -z "$GOBUSTER_BIN" ]]; then
    printf '%b\n' "${RED}[!] Gobuster binary not set. Skipping Gobuster phase.${NC}"
elif ! command -v "$GOBUSTER_BIN" &>/dev/null; then
    printf '%b\n' "${RED}[!] Gobuster not found in PATH. Skipping Gobuster phase.${NC}"
elif [[ ${#HTTP_URLS[@]} -eq 0 ]]; then
    printf '%b\n' "${YELLOW}[!] Gobuster skipped: No URLs provided.${NC}"
else
    VALID_WORDLISTS=("$SMALL_WL" "$QUICKHIT_WL" "$MEDIUM_WL" "$COMMON_WL")
    printf '%b\n' "${PURPLE}[+] Starting Gobuster scans...${NC}"

    declare -a SCAN_URLS=()
    declare -A SEEN_URL=()

    # Normalize HTTP_URLS entries: allow entries that are "host port1 port2" or single URL entries
    for entry in "${HTTP_URLS[@]}"; do
        # split on whitespace
        oldIFS="$IFS"; IFS=' ' read -r -a parts <<< "$entry"; IFS="$oldIFS"
        if (( ${#parts[@]} == 0 )); then
            continue
        elif (( ${#parts[@]} == 1 )); then
            candidate="${parts[0]}"
            [[ "$candidate" != *"://"* ]] && candidate="http://$candidate"
            if [[ -z "${SEEN_URL[$candidate]:-}" ]]; then
                SCAN_URLS+=("$candidate"); SEEN_URL["$candidate"]=1
            fi
        else
            base="${parts[0]}"
            [[ "$base" != *"://"* ]] && base="http://$base"
            scheme="${base%%:*}"
            hostport="${base#*://}"
            hostport="${hostport%%/*}"
            host="${hostport%%:*}"
            for ((i=1;i<${#parts[@]};i++)); do
                token="${parts[i]}"
                if [[ "$token" == *"://"* ]]; then
                    candidate="$token"
                    if [[ -z "${SEEN_URL[$candidate]:-}" ]]; then
                        SCAN_URLS+=("$candidate"); SEEN_URL["$candidate"]=1
                    fi
                    continue
                fi
                tmp="${token//:/,}"
                IFS=',' read -r -a ports <<< "$tmp"
                for p in "${ports[@]}"; do
                    p="${p//[!0-9]/}"
                    [[ -z "$p" ]] && continue
                    candidate="${scheme}://${host}:$p"
                    if [[ -z "${SEEN_URL[$candidate]:-}" ]]; then
                        SCAN_URLS+=("$candidate"); SEEN_URL["$candidate"]=1
                    fi
                done
            done
        fi
    done

    # fallback
    if (( ${#SCAN_URLS[@]} == 0 )); then
        for u in "${HTTP_URLS[@]}"; do
            [[ "$u" != *"://"* ]] && u="http://$u"
            if [[ -z "${SEEN_URL[$u]:-}" ]]; then
                SCAN_URLS+=("$u"); SEEN_URL["$u"]=1
            fi
        done
    fi

    # Run Gobuster in parallel, save to temp files
    declare -a GOB_TMP_FILES=()
    declare -A TMP_META=()
    MAX_JOBS=${MAX_JOBS:-5}
    JOBS=0

    for url in "${SCAN_URLS[@]}"; do
        for wordlist in "${VALID_WORDLISTS[@]}"; do
            [[ ! -f "$wordlist" ]] && continue
            url_md5="$(printf '%s' "$url" | md5sum | cut -d' ' -f1)"
            wordname="$(basename "$wordlist")"
            TMP_GOB="$TMP_DIR/gobuster_${url_md5}_${wordname}"
            GOB_TMP_FILES+=("$TMP_GOB")
            TMP_META["$TMP_GOB"]="$url|$wordname"
            TMP_FILES+=("$TMP_GOB")

            (
                printf '%b\n' "${TEAL}[Gobuster] Scanning $url with $wordname${NC}"
                "$GOBUSTER_BIN" dir -u "$url" -w "$wordlist" -t 30 -q > "$TMP_GOB" 2>&1 || true
            ) &

            ((JOBS++))
            if (( JOBS >= MAX_JOBS )); then
                wait
                JOBS=0
            fi
        done
    done

    wait

    # Process gobuster temp files in main shell
    for tmp in "${GOB_TMP_FILES[@]}"; do
        [[ ! -f "$tmp" ]] && continue
        meta="${TMP_META[$tmp]}"   # url|wordlist
        while IFS= read -r line || [[ -n "$line" ]]; do
            printf '%b\n' "${TEAL}[Gobuster][${meta}] $line${NC}"
            GOBUSTER_RESULTS["$meta"]+="$line"$'\n'
        done < "$tmp"
    done

    printf '%b\n' "${PURPLE}[+] Gobuster phase completed.${NC}"
fi

# ====================
# Nuclei Phase (safe: write to temp then process)
# ====================
print_nuclei_banner() {
    printf '%b' "$RED"
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
    printf '%b\n' "$NC"
}
print_nuclei_banner

printf '%b\n' "${ORANGE}==================== Nuclei Phase ====================${NC}"

declare -a NUCLEI_TMP_FILES=()
declare -A NUCLEI_META=()

if [[ ${#HTTP_URLS[@]} -gt 0 && -n "$NUCLEI_BIN" && command -v "$NUCLEI_BIN" &>/dev/null ]]; then
    MAX_JOBS=${MAX_JOBS:-5}
    JOBS=0

    for url in "${HTTP_URLS[@]}"; do
        TMP_NUC="$TMP_DIR/nuclei_$(printf '%s' "$url" | md5sum | cut -d' ' -f1)"
        NUCLEI_TMP_FILES+=("$TMP_NUC")
        NUCLEI_META["$TMP_NUC"]="$url"
        TMP_FILES+=("$TMP_NUC")

        (
            printf '%b\n' "${ORANGE}[Nuclei] Scanning $url${NC}"
            # run nuclei and capture
            "$NUCLEI_BIN" -u "$url" -silent > "$TMP_NUC" 2>&1 || true
        ) &

        ((JOBS++))
        if (( JOBS >= MAX_JOBS )); then
            wait
            JOBS=0
        fi
    done

    wait

    for tmp in "${NUCLEI_TMP_FILES[@]}"; do
        [[ ! -f "$tmp" ]] && continue
        url="${NUCLEI_META[$tmp]}"
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -n "$line" ]] && printf '%b\n' "${GREEN}[Nuclei][$url] $line${NC}"
            NUCLEI_RESULTS["$url"]+="$line"$'\n'
        done < "$tmp"
    done

    printf '%b\n' "${GREEN}[+] Nuclei phase completed.${NC}"
else
    printf '%b\n' "${YELLOW}[!] Nuclei skipped: missing URLs or binary.${NC}"
fi

printf '%b\n' "${YELLOW}[!] HTTPX → Gobuster → Nuclei processing complete.${NC}"

# ====================
# Summary
# ====================
printf '%b\n' "${GREEN}
====================================================
UNICORN SCAN SUMMARY
Target: $TARGET
Open Ports: ${PORTS:-None}
====================================================
HTTP URLs Discovered:
${NC}"

if [[ ${#HTTP_URLS[@]} -gt 0 ]]; then
   for url in "${!HTTPX_RESULTS[@]}"; do
       printf '%b\n' "$url -> ${HTTPX_RESULTS[$url]}"
    done
else
    printf '%b\n' "${YELLOW}[!] No HTTP URLs found.${NC}"
fi

printf '%b\n' "\nGobuster Results:"
if [[ ${#GOBUSTER_RESULTS[@]} -gt 0 ]]; then
    for key in "${!GOBUSTER_RESULTS[@]}"; do
        printf '%b\n' "$key:"
        [[ -n "${GOBUSTER_RESULTS[$key]}" ]] && printf '%b\n' "${GOBUSTER_RESULTS[$key]}"
    done
else
    printf '%b\n' "${YELLOW}[!] No Gobuster results.${NC}"
fi

printf '%b\n' "\nNuclei Results:"
if [[ ${#NUCLEI_RESULTS[@]} -gt 0 ]]; then
    for key in "${!NUCLEI_RESULTS[@]}"; do
        printf '%b\n' "$key:"
        [[ -n "${NUCLEI_RESULTS[$key]}" ]] && printf '%b\n' "${NUCLEI_RESULTS[$key]}"
    done
else
    printf '%b\n' "${YELLOW}[!] No Nuclei results.${NC}"
fi

printf '%b\n' "\nWordlists Used: ${WORDLISTS[*]:-None}"
printf '%b\n' "===================================================="
printf '%b\n' "${GREEN}[*] Unicorn Scan finished!${NC}"

