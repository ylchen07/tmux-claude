#!/usr/bin/env bash
# Shared helper functions for tmux-claude plugin

# Get tmux option with default fallback
get_tmux_option() {
    local option="$1"
    local default_value="$2"
    local option_value
    option_value=$(tmux show-option -gqv "$option")
    if [[ -z "$option_value" ]]; then
        echo "$default_value"
    else
        echo "$option_value"
    fi
}

# Get cache directory (XDG compliant)
get_cache_dir() {
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-claude"
    mkdir -p "$cache_dir"
    echo "$cache_dir"
}

# Get cache file path
get_cache_file() {
    echo "$(get_cache_dir)/usage_cache"
}

# Check if cache is still valid
is_cache_valid() {
    local cache_file="$1"
    local cache_interval="$2"

    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi

    local cache_time
    cache_time=$(head -1 "$cache_file" 2>/dev/null)

    if [[ -z "$cache_time" ]]; then
        return 1
    fi

    local current_time
    current_time=$(date +%s)
    local age=$((current_time - cache_time))

    if [[ $age -lt $cache_interval ]]; then
        return 0
    else
        return 1
    fi
}

# Read cached value (second line of cache file)
read_cache() {
    local cache_file="$1"
    tail -1 "$cache_file" 2>/dev/null
}

# Write to cache (timestamp on first line, value on second)
write_cache() {
    local cache_file="$1"
    local value="$2"
    local timestamp
    timestamp=$(date +%s)
    echo -e "${timestamp}\n${value}" > "$cache_file"
}

# Get the start of current billing period (1st of current month)
get_billing_start() {
    date -u +"%Y-%m-01T00:00:00Z"
}

# Get current timestamp in ISO 8601 format
get_current_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Format the output string
format_output() {
    local percentage="$1"
    local format="$2"

    # Replace #P with the percentage value
    echo "${format//#P/$percentage}"
}
