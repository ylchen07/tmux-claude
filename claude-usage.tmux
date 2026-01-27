#!/usr/bin/env bash
# tmux-claude - Display Claude API usage in tmux status bar
# TPM plugin entry point

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default option values
default_cache_interval="300"
default_format="Claude: #P%"
default_monthly_limit=""

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

# Set default options if not already set
set_defaults() {
    local current_value

    current_value=$(tmux show-option -gqv "@claude_cache_interval")
    if [[ -z "$current_value" ]]; then
        tmux set-option -g "@claude_cache_interval" "$default_cache_interval"
    fi

    current_value=$(tmux show-option -gqv "@claude_format")
    if [[ -z "$current_value" ]]; then
        tmux set-option -g "@claude_format" "$default_format"
    fi
}

# Register the interpolation
do_interpolation() {
    local string="$1"
    local usage_script="$CURRENT_DIR/scripts/claude_usage.sh"
    string="${string//\#\{claude_usage\}/#($usage_script)}"
    echo "$string"
}

# Update status bar options with interpolation
update_tmux_option() {
    local option="$1"
    local option_value
    option_value=$(get_tmux_option "$option")
    local new_option_value
    new_option_value=$(do_interpolation "$option_value")
    tmux set-option -gq "$option" "$new_option_value"
}

main() {
    set_defaults
    update_tmux_option "status-right"
    update_tmux_option "status-left"
}

main
