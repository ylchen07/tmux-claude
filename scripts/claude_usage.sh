#!/usr/bin/env bash
# Claude.ai usage fetcher for tmux status bar
# Uses Claude.ai's internal API with browser session cookies

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

# Default values
DEFAULT_CACHE_INTERVAL="300"
DEFAULT_FORMAT="Claude: #P%"
DEFAULT_LIMIT_TYPE="5h"

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

# Fetch usage from Claude.ai API
fetch_usage() {
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

# Extract utilization percentage from response
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
        utilization=$(echo "$response" | jq -r ".${json_path}.utilization // 0")
    else
        # Fallback: extract utilization for the specified limit type
        # This is more complex without jq, so we use a simpler approach
        local pattern="\"${json_path}\"[^}]*\"utilization\":[[:space:]]*([0-9]+)"
        utilization=$(echo "$response" | grep -oE "\"${json_path}\"[^}]*\"utilization\":[[:space:]]*[0-9]+" | grep -oE "[0-9]+$" | head -1)
        if [[ -z "$utilization" ]]; then
            utilization=0
        fi
    fi

    echo "$utilization"
}

# Main function
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

    local org_id
    org_id=$(get_tmux_option "@claude_org_id" "")

    # Check if session key is configured
    if [[ -z "$session_key" ]]; then
        echo "Claude: No session key"
        return 0
    fi

    # Check cache
    local cache_file
    cache_file=$(get_cache_file)

    if is_cache_valid "$cache_file" "$cache_interval"; then
        read_cache "$cache_file"
        return 0
    fi

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

    # Fetch usage data
    local response
    response=$(fetch_usage "$session_key" "$org_id")

    # Check for API errors
    if [[ "$response" == API_ERROR:* ]]; then
        local error_code="${response#API_ERROR:}"
        case "$error_code" in
            401|403)
                echo "Claude: Session expired"
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

    # Format output
    local output
    output=$(format_output "$utilization" "$format")

    # Cache the result
    write_cache "$cache_file" "$output"

    echo "$output"
}

main
