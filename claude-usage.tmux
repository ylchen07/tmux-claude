#!/usr/bin/env bash
# tmux-claude - Display Claude.ai subscription usage in tmux status bar
# TPM plugin entry point

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default option values
default_cache_interval="300"
default_format="Claude: #P% #M"
default_limit_type="5h"
default_show_remaining="false"

# Copilot default option values
default_copilot_cache_interval="300"
default_copilot_format="Copilot: #C/#T"

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

    current_value=$(tmux show-option -gqv "@claude_limit_type")
    if [[ -z "$current_value" ]]; then
        tmux set-option -g "@claude_limit_type" "$default_limit_type"
    fi

    current_value=$(tmux show-option -gqv "@claude_show_remaining")
    if [[ -z "$current_value" ]]; then
        tmux set-option -g "@claude_show_remaining" "$default_show_remaining"
    fi

    current_value=$(tmux show-option -gqv "@copilot_cache_interval")
    if [[ -z "$current_value" ]]; then
        tmux set-option -g "@copilot_cache_interval" "$default_copilot_cache_interval"
    fi

    current_value=$(tmux show-option -gqv "@copilot_format")
    if [[ -z "$current_value" ]]; then
        tmux set-option -g "@copilot_format" "$default_copilot_format"
    fi
}

# Register the interpolation
do_interpolation() {
    local string="$1"
    local usage_script="$CURRENT_DIR/scripts/claude_usage.sh"
    local copilot_script="$CURRENT_DIR/scripts/copilot_usage.sh"
    string="${string//\#\{claude_usage\}/#($usage_script)}"
    string="${string//\#\{copilot_usage\}/#($copilot_script)}"
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
