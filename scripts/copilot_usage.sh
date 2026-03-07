#!/usr/bin/env bash
# Copilot usage fetcher for tmux status bar
# Reads OAuth token from ~/.config/github-copilot/apps.json
# Uses GitHub's internal Copilot user endpoint

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

# Default values
DEFAULT_CACHE_INTERVAL="300"
DEFAULT_FORMAT="Copilot: #C/#T"
DEFAULT_SHOW="completions"   # completions | chat | both

# Copilot credentials file
COPILOT_APPS_JSON="${HOME}/.config/github-copilot/apps.json"

# =============================================================================
# Credentials
# =============================================================================

# Read OAuth token from ~/.config/github-copilot/apps.json
get_copilot_token() {
    if [[ ! -f "$COPILOT_APPS_JSON" ]]; then
        return 1
    fi

    local token
    if command -v jq &>/dev/null; then
        token=$(jq -r '.[keys[0]].oauth_token // empty' "$COPILOT_APPS_JSON" 2>/dev/null)
    else
        # Fallback: extract first oauth_token value
        token=$(grep -o '"oauth_token"[[:space:]]*:[[:space:]]*"[^"]*"' "$COPILOT_APPS_JSON" | \
                head -1 | sed 's/.*"oauth_token"[[:space:]]*:[[:space:]]*"//;s/"$//')
    fi

    if [[ -n "$token" && "$token" != "null" ]]; then
        echo "$token"
        return 0
    fi
    return 1
}

# =============================================================================
# API
# =============================================================================

# Fetch user quota info from GitHub Copilot internal API
fetch_copilot_usage() {
    local token="$1"

    local response
    response=$(curl -s -w "\n%{http_code}" \
        "https://api.github.com/copilot_internal/user" \
        -H "Authorization: token ${token}" \
        -H "Accept: application/json")

    local http_code
    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" != "200" ]]; then
        echo "API_ERROR:${http_code}"
        return 1
    fi

    echo "$body"
}

# =============================================================================
# Parsing
# =============================================================================

extract_field() {
    local response="$1"
    local field="$2"      # e.g. "completions" or "chat"
    local quota_type="$3" # "limited_user_quotas" or "monthly_quotas"

    if command -v jq &>/dev/null; then
        echo "$response" | jq -r ".${quota_type}.${field} // 0" 2>/dev/null
    else
        # Fallback: find the quota_type block, then the field
        echo "$response" | \
            grep -A5 "\"${quota_type}\"" | \
            grep -o "\"${field}\"[[:space:]]*:[[:space:]]*[0-9]*" | \
            grep -o '[0-9]*$' | head -1
    fi
}

extract_reset_date() {
    local response="$1"

    if command -v jq &>/dev/null; then
        echo "$response" | jq -r '.limited_user_reset_date // empty' 2>/dev/null
    else
        echo "$response" | grep -o '"limited_user_reset_date"[[:space:]]*:[[:space:]]*"[^"]*"' | \
            head -1 | sed 's/.*"limited_user_reset_date"[[:space:]]*:[[:space:]]*"//;s/"$//'
    fi
}

# =============================================================================
# Formatting
# =============================================================================

# Format the output string
# Placeholders:
#   #C  - completions remaining
#   #T  - completions total (monthly quota)
#   #H  - chat remaining
#   #HT - chat total
#   #R  - reset date
build_output() {
    local format="$1"
    local comp_remaining="$2"
    local comp_total="$3"
    local chat_remaining="$4"
    local chat_total="$5"
    local reset_date="$6"

    local out="$format"
    out="${out//#C/$comp_remaining}"
    out="${out//#T/$comp_total}"
    out="${out//#HT/$chat_total}"
    out="${out//#H/$chat_remaining}"
    out="${out//#R/$reset_date}"
    echo "$out"
}

# =============================================================================
# Main
# =============================================================================

main() {
    local cache_interval
    cache_interval=$(get_tmux_option "@copilot_cache_interval" "$DEFAULT_CACHE_INTERVAL")

    local format
    format=$(get_tmux_option "@copilot_format" "$DEFAULT_FORMAT")

    # Check cache first
    local cache_file
    cache_file=$(get_copilot_cache_file)

    if is_cache_valid "$cache_file" "$cache_interval"; then
        read_cache "$cache_file"
        return 0
    fi

    # Get OAuth token
    local token
    token=$(get_copilot_token)

    if [[ -z "$token" ]]; then
        echo "Copilot: No credentials"
        return 0
    fi

    # Fetch usage
    local response
    response=$(fetch_copilot_usage "$token")

    if [[ "$response" == API_ERROR:* ]]; then
        local error_code="${response#API_ERROR:}"
        case "$error_code" in
            401|403) echo "Copilot: Auth failed" ;;
            429)     echo "Copilot: Rate limit" ;;
            *)       echo "Copilot: API error" ;;
        esac
        return 0
    fi

    # Extract fields
    local comp_remaining comp_total chat_remaining chat_total reset_date
    comp_remaining=$(extract_field "$response" "completions" "limited_user_quotas")
    comp_total=$(extract_field "$response" "completions" "monthly_quotas")
    chat_remaining=$(extract_field "$response" "chat" "limited_user_quotas")
    chat_total=$(extract_field "$response" "chat" "monthly_quotas")
    reset_date=$(extract_reset_date "$response")

    # Format output
    local output
    output=$(build_output "$format" "$comp_remaining" "$comp_total" "$chat_remaining" "$chat_total" "$reset_date")

    # Cache result
    write_cache "$cache_file" "$output"

    echo "$output"
}

main
