#!/usr/bin/env bash
# Claude usage fetcher for tmux status bar
# Supports OAuth API (preferred) and Web API (fallback)

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

# Default values
DEFAULT_CACHE_INTERVAL="300"
DEFAULT_FORMAT="Claude: #P%"
DEFAULT_LIMIT_TYPE="5h"
DEFAULT_SHOW_REMAINING="false"

# OAuth credentials locations
CLAUDE_CREDENTIALS_FILE="${HOME}/.claude/.credentials.json"
CLAUDE_KEYCHAIN_SERVICE="Claude Code-credentials"

# =============================================================================
# OAuth API Functions (Preferred - uses Claude CLI credentials)
# =============================================================================

# Read OAuth credentials JSON from Keychain (macOS only)
get_credentials_from_keychain() {
    if [[ "$(uname)" != "Darwin" ]]; then
        return 1
    fi

    # Try to read from Keychain
    local creds
    creds=$(security find-generic-password -s "$CLAUDE_KEYCHAIN_SERVICE" -w 2>/dev/null)

    if [[ -n "$creds" ]]; then
        echo "$creds"
        return 0
    fi
    return 1
}

# Read OAuth credentials JSON from file
get_credentials_from_file() {
    if [[ -f "$CLAUDE_CREDENTIALS_FILE" ]]; then
        cat "$CLAUDE_CREDENTIALS_FILE" 2>/dev/null
        return 0
    fi
    return 1
}

# Get OAuth credentials JSON (tries Keychain first on macOS, then file)
get_credentials_json() {
    local creds

    # Try Keychain first (macOS)
    creds=$(get_credentials_from_keychain)
    if [[ -n "$creds" ]]; then
        echo "$creds"
        return 0
    fi

    # Fall back to file
    creds=$(get_credentials_from_file)
    if [[ -n "$creds" ]]; then
        echo "$creds"
        return 0
    fi

    return 1
}

# Read OAuth access token from Claude CLI credentials
get_oauth_token() {
    local creds
    creds=$(get_credentials_json)

    if [[ -z "$creds" ]]; then
        return 1
    fi

    local token
    if command -v jq &>/dev/null; then
        token=$(echo "$creds" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    else
        # Fallback: extract accessToken using grep/sed
        token=$(echo "$creds" | grep -o '"accessToken"[[:space:]]*:[[:space:]]*"[^"]*"' | \
                head -1 | sed 's/.*"accessToken"[[:space:]]*:[[:space:]]*"//;s/"$//')
    fi

    if [[ -n "$token" && "$token" != "null" ]]; then
        echo "$token"
        return 0
    fi
    return 1
}

# Check if OAuth credentials have the required scope
has_profile_scope() {
    local creds
    creds=$(get_credentials_json)

    if [[ -z "$creds" ]]; then
        return 1
    fi

    if command -v jq &>/dev/null; then
        local has_scope
        has_scope=$(echo "$creds" | jq -r '.claudeAiOauth.scopes // [] | any(. == "user:profile")' 2>/dev/null)
        [[ "$has_scope" == "true" ]]
    else
        # Fallback: check if user:profile appears in the scopes array
        echo "$creds" | grep -q '"user:profile"' 2>/dev/null
    fi
}

# Check if OAuth token is expired
is_oauth_expired() {
    local creds
    creds=$(get_credentials_json)

    if [[ -z "$creds" ]]; then
        return 0  # Treat as expired if no credentials
    fi

    local expires_at
    if command -v jq &>/dev/null; then
        expires_at=$(echo "$creds" | jq -r '.claudeAiOauth.expiresAt // 0' 2>/dev/null)
    else
        # Fallback: extract expiresAt
        expires_at=$(echo "$creds" | grep -o '"expiresAt"[[:space:]]*:[[:space:]]*[0-9]*' | \
                     grep -o '[0-9]*$' | head -1)
    fi

    if [[ -z "$expires_at" || "$expires_at" == "0" || "$expires_at" == "null" ]]; then
        return 0  # Treat as expired if no expiry
    fi

    # expiresAt is in milliseconds, convert to seconds
    local expires_seconds=$((expires_at / 1000))
    local current_time
    current_time=$(date +%s)

    [[ $current_time -ge $expires_seconds ]]
}

# Fetch usage via OAuth API
fetch_usage_oauth() {
    local token="$1"

    local response
    response=$(curl -s -w "\n%{http_code}" \
        "https://api.anthropic.com/api/oauth/usage" \
        -H "Authorization: Bearer ${token}" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json")

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
# Web API Functions (Fallback - uses browser session cookies)
# =============================================================================

# Fetch organization ID from Claude.ai
fetch_org_id() {
    local session_key="$1"

    local response
    response=$(curl -s -w "\n%{http_code}" \
        "https://claude.ai/api/organizations" \
        -H "Cookie: sessionKey=${session_key}" \
        -H "Accept: application/json")

    local http_code
    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" != "200" ]]; then
        echo "API_ERROR:${http_code}"
        return 1
    fi

    # Parse org ID from response
    local org_id
    if command -v jq &>/dev/null; then
        org_id=$(echo "$body" | jq -r '.[0].uuid // empty')
    else
        # Fallback: extract first uuid from response
        org_id=$(echo "$body" | grep -o '"uuid":"[^"]*"' | head -1 | sed 's/"uuid":"//;s/"//')
    fi

    if [[ -z "$org_id" ]]; then
        echo "PARSE_ERROR"
        return 1
    fi

    echo "$org_id"
}

# Fetch usage from Claude.ai Web API
fetch_usage_web() {
    local session_key="$1"
    local org_id="$2"

    local response
    response=$(curl -s -w "\n%{http_code}" \
        "https://claude.ai/api/organizations/${org_id}/usage" \
        -H "Cookie: sessionKey=${session_key}" \
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
# Shared Functions
# =============================================================================

# Extract utilization percentage from response (works for both OAuth and Web API)
extract_utilization() {
    local response="$1"
    local limit_type="$2"

    local json_path
    case "$limit_type" in
        "5h"|"5hour"|"five_hour")
            json_path="five_hour"
            ;;
        "7d"|"7day"|"seven_day")
            json_path="seven_day"
            ;;
        "opus"|"seven_day_opus")
            json_path="seven_day_opus"
            ;;
        "sonnet"|"seven_day_sonnet")
            json_path="seven_day_sonnet"
            ;;
        *)
            json_path="five_hour"
            ;;
    esac

    local utilization
    if command -v jq &>/dev/null; then
        # OAuth API returns utilization as decimal (0.0-1.0)
        # Web API returns utilization as percentage (0-100)
        utilization=$(echo "$response" | jq -r ".${json_path}.utilization // 0")

        # If utilization is a decimal (less than 1.01), convert to percentage
        if [[ $(echo "$utilization < 1.01" | bc -l 2>/dev/null || echo "0") == "1" ]]; then
            # It's a decimal, multiply by 100
            utilization=$(echo "$utilization * 100" | bc -l 2>/dev/null | cut -d'.' -f1)
            [[ -z "$utilization" ]] && utilization=0
        fi
    else
        # Fallback: extract utilization for the specified limit type
        utilization=$(echo "$response" | grep -oE "\"${json_path}\"[^}]*\"utilization\":[[:space:]]*[0-9.]+" | \
                      grep -oE "[0-9.]+$" | head -1)

        # Check if it's a decimal and convert
        if [[ "$utilization" == "0."* ]]; then
            # Remove leading "0." and treat as percentage
            utilization=${utilization#0.}
            utilization=${utilization:0:2}  # Take first 2 digits
        fi

        if [[ -z "$utilization" ]]; then
            utilization=0
        fi
    fi

    # Ensure it's an integer
    printf "%.0f" "$utilization" 2>/dev/null || echo "0"
}

# =============================================================================
# Main Function
# =============================================================================

main() {
    # Get configuration from tmux options
    local session_key
    session_key=$(get_tmux_option "@claude_session_key" "")

    local cache_interval
    cache_interval=$(get_tmux_option "@claude_cache_interval" "$DEFAULT_CACHE_INTERVAL")

    local format
    format=$(get_tmux_option "@claude_format" "$DEFAULT_FORMAT")

    local limit_type
    limit_type=$(get_tmux_option "@claude_limit_type" "$DEFAULT_LIMIT_TYPE")

    local show_remaining
    show_remaining=$(get_tmux_option "@claude_show_remaining" "$DEFAULT_SHOW_REMAINING")

    local org_id
    org_id=$(get_tmux_option "@claude_org_id" "")

    # Check cache first
    local cache_file
    cache_file=$(get_cache_file)

    if is_cache_valid "$cache_file" "$cache_interval"; then
        read_cache "$cache_file"
        return 0
    fi

    local response=""
    local source_used=""

    # Try OAuth API first (preferred)
    local oauth_token
    oauth_token=$(get_oauth_token)

    if [[ -n "$oauth_token" ]]; then
        # Check if token might be expired
        if ! is_oauth_expired; then
            response=$(fetch_usage_oauth "$oauth_token")

            if [[ "$response" != API_ERROR:* ]]; then
                source_used="oauth"
            else
                # OAuth failed, will try Web API fallback
                response=""
            fi
        fi
    fi

    # Fallback to Web API if OAuth didn't work
    if [[ -z "$response" && -n "$session_key" ]]; then
        # Get or fetch organization ID
        if [[ -z "$org_id" ]]; then
            org_id=$(get_cached_org_id)
            if [[ -z "$org_id" ]]; then
                org_id=$(fetch_org_id "$session_key")

                # Check for errors
                if [[ "$org_id" == API_ERROR:* ]]; then
                    local error_code="${org_id#API_ERROR:}"
                    case "$error_code" in
                        401|403)
                            echo "Claude: Session expired"
                            ;;
                        *)
                            echo "Claude: API error"
                            ;;
                    esac
                    return 0
                fi

                if [[ "$org_id" == "PARSE_ERROR" ]]; then
                    echo "Claude: Parse error"
                    return 0
                fi

                # Cache the org ID
                cache_org_id "$org_id"
            fi
        fi

        # Fetch usage data via Web API
        response=$(fetch_usage_web "$session_key" "$org_id")
        source_used="web"
    fi

    # No credentials available
    if [[ -z "$response" ]]; then
        if [[ -z "$oauth_token" && -z "$session_key" ]]; then
            echo "Claude: No credentials"
        else
            echo "Claude: Auth failed"
        fi
        return 0
    fi

    # Check for API errors
    if [[ "$response" == API_ERROR:* ]]; then
        local error_code="${response#API_ERROR:}"
        case "$error_code" in
            401|403)
                if [[ "$source_used" == "oauth" ]]; then
                    echo "Claude: Token expired"
                else
                    echo "Claude: Session expired"
                fi
                ;;
            429)
                echo "Claude: Rate limit"
                ;;
            *)
                echo "Claude: API error"
                ;;
        esac
        return 0
    fi

    # Extract utilization
    local utilization
    utilization=$(extract_utilization "$response" "$limit_type")

    # Calculate remaining percentage if requested
    local display_value="$utilization"
    if [[ "$show_remaining" == "true" ]]; then
        display_value=$((100 - utilization))
    fi

    # Format output
    local output
    output=$(format_output "$display_value" "$format")

    # Cache the result
    write_cache "$cache_file" "$output"

    echo "$output"
}

main
