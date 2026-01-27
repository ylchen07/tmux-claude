#!/usr/bin/env bash
# Claude API usage fetcher for tmux status bar

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

# Default values
DEFAULT_CACHE_INTERVAL="300"
DEFAULT_FORMAT="Claude: #P%"
DEFAULT_MONTHLY_LIMIT=""

# Fetch usage from Anthropic API
fetch_usage() {
    local api_key="$1"
    local starting_at="$2"
    local ending_at="$3"

    local response
    response=$(curl -s -w "\n%{http_code}" \
        "https://api.anthropic.com/v1/organizations/usage_report/messages?starting_at=${starting_at}&ending_at=${ending_at}&bucket_width=1mo" \
        -H "x-api-key: ${api_key}" \
        -H "anthropic-version: 2023-06-01")

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

# Calculate total tokens from API response
calculate_total_tokens() {
    local response="$1"

    # Parse JSON and sum input_tokens + output_tokens from all buckets
    # Using basic tools available on most systems
    local total=0

    if command -v jq &>/dev/null; then
        total=$(echo "$response" | jq -r '[.data[].input_tokens, .data[].output_tokens] | add // 0')
    else
        # Fallback: basic grep/sed parsing
        local input_tokens output_tokens
        input_tokens=$(echo "$response" | grep -o '"input_tokens":[0-9]*' | grep -o '[0-9]*' | awk '{s+=$1} END {print s+0}')
        output_tokens=$(echo "$response" | grep -o '"output_tokens":[0-9]*' | grep -o '[0-9]*' | awk '{s+=$1} END {print s+0}')
        total=$((input_tokens + output_tokens))
    fi

    echo "$total"
}

# Main function
main() {
    # Get configuration from tmux options
    local api_key
    api_key=$(get_tmux_option "@claude_api_key" "")

    local cache_interval
    cache_interval=$(get_tmux_option "@claude_cache_interval" "$DEFAULT_CACHE_INTERVAL")

    local format
    format=$(get_tmux_option "@claude_format" "$DEFAULT_FORMAT")

    local monthly_limit
    monthly_limit=$(get_tmux_option "@claude_monthly_limit" "$DEFAULT_MONTHLY_LIMIT")

    # Check if API key is configured
    if [[ -z "$api_key" ]]; then
        echo "Claude: No API key"
        return 0
    fi

    # Check if monthly limit is configured (required for percentage calculation)
    if [[ -z "$monthly_limit" ]]; then
        echo "Claude: No limit set"
        return 0
    fi

    # Check cache
    local cache_file
    cache_file=$(get_cache_file)

    if is_cache_valid "$cache_file" "$cache_interval"; then
        read_cache "$cache_file"
        return 0
    fi

    # Fetch fresh data from API
    local starting_at ending_at
    starting_at=$(get_billing_start)
    ending_at=$(get_current_timestamp)

    local response
    response=$(fetch_usage "$api_key" "$starting_at" "$ending_at")

    # Check for API errors
    if [[ "$response" == API_ERROR:* ]]; then
        local error_code="${response#API_ERROR:}"
        case "$error_code" in
            401|403)
                echo "Claude: Auth error"
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

    # Calculate usage
    local total_tokens
    total_tokens=$(calculate_total_tokens "$response")

    # Calculate percentage
    local percentage
    if [[ "$monthly_limit" -gt 0 ]]; then
        percentage=$((total_tokens * 100 / monthly_limit))
    else
        percentage=0
    fi

    # Cap at 100+ for overflow display
    if [[ $percentage -gt 100 ]]; then
        percentage="100+"
    fi

    # Format output
    local output
    output=$(format_output "$percentage" "$format")

    # Cache the result
    write_cache "$cache_file" "$output"

    echo "$output"
}

main
