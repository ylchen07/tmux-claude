# tmux-claude

A TPM-compatible tmux plugin to display Claude API usage percentage in the status bar.

## Prerequisites

This plugin requires an **Admin API key** from Anthropic, which is only available to organizations.

To check if you have access:
1. Go to [console.anthropic.com](https://console.anthropic.com)
2. Navigate to Settings → Organization
3. If you see organization settings and can access "Admin Keys", you have org access
4. Create an Admin API key (starts with `sk-ant-admin-...`)

## Installation

### With TPM (recommended)

Add to your `~/.tmux.conf`:

```bash
set -g @plugin 'ylchen07/tmux-claude'
```

Then press `prefix + I` to install.

### Manual Installation

```bash
git clone https://github.com/ylchen07/tmux-claude ~/.tmux/plugins/tmux-claude
```

Add to `~/.tmux.conf`:

```bash
run-shell ~/.tmux/plugins/tmux-claude/claude-usage.tmux
```

## Configuration

Add these options to your `~/.tmux.conf`:

```bash
# Required: Your Anthropic Admin API key
set -g @claude_api_key "sk-ant-admin-..."

# Required: Your monthly token budget
set -g @claude_monthly_limit "10000000"

# Optional: Cache duration in seconds (default: 300)
set -g @claude_cache_interval "300"

# Optional: Display format (default: "Claude: #P%")
# #P is replaced with the percentage value
set -g @claude_format "Claude: #P%"
```

## Usage

Add `#{claude_usage}` to your status bar:

```bash
set -g status-right "#{claude_usage} | %H:%M"
```

Then reload tmux:

```bash
tmux source ~/.tmux.conf
```

## Display Examples

| Status | Display |
|--------|---------|
| Normal | `Claude: 45%` |
| Over limit | `Claude: 100+%` |
| No API key | `Claude: No API key` |
| No limit set | `Claude: No limit set` |
| Auth error | `Claude: Auth error` |

## How It Works

1. The plugin fetches usage data from the Anthropic Admin API
2. Results are cached to avoid excessive API calls (default: 5 minutes)
3. Usage is calculated as: `(input_tokens + output_tokens) / monthly_limit * 100`
4. The formatted result is displayed in your tmux status bar

## Troubleshooting

### "No API key" displayed
Ensure you've set `@claude_api_key` in your tmux.conf and reloaded the configuration.

### "Auth error" displayed
Your API key may be invalid or expired. Ensure you're using an Admin API key (`sk-ant-admin-...`), not a regular API key.

### "No limit set" displayed
Set your monthly token budget with `@claude_monthly_limit`.

### Usage not updating
Check the cache interval setting. By default, the plugin only fetches new data every 5 minutes to avoid excessive API calls.

## License

MIT License - see [LICENSE](LICENSE) file.
