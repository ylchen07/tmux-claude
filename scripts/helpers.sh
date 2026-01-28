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

# Get org ID cache file path
get_org_id_cache_file() {
    echo "$(get_cache_dir)/org_id"
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

# Get cached organization ID
get_cached_org_id() {
    local org_id_file
    org_id_file=$(get_org_id_cache_file)
    if [[ -f "$org_id_file" ]]; then
        cat "$org_id_file" 2>/dev/null
    fi
}

# Cache organization ID
cache_org_id() {
    local org_id="$1"
    local org_id_file
    org_id_file=$(get_org_id_cache_file)
    echo "$org_id" > "$org_id_file"
}

# Clear cached organization ID (useful when session expires)
clear_org_id_cache() {
    local org_id_file
    org_id_file=$(get_org_id_cache_file)
    rm -f "$org_id_file"
}

# Format the output string
format_output() {
    local percentage="$1"
    local format="$2"

    # Replace #P with the percentage value
    echo "${format//#P/$percentage}"
}
