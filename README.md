# tmux-claude

A TPM-compatible tmux plugin to display Claude.ai subscription usage in the status bar.

## How It Works

This plugin uses Claude.ai's internal API to fetch your subscription usage percentage. It displays how much of your rate limit you've consumed (0-100%).

**Note:** This uses an unofficial API that could change without notice. Session keys expire periodically (weeks to months) and will need to be refreshed.

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

## Setup

### Getting Your Session Key

1. Open [claude.ai](https://claude.ai) in your browser and ensure you're logged in
2. Open Developer Tools (F12 or Cmd+Option+I on Mac)
3. Go to the **Network** tab
4. Refresh the page
5. Click on any request to `claude.ai`
6. In the **Headers** section, find the `Cookie` header
7. Look for `sessionKey=sk-ant-sid01-...` and copy the entire value (starting with `sk-ant-sid01-`)

### Configuration

Add these options to your `~/.tmux.conf`:

```bash
# Required: Your session key from browser cookies
set -g @claude_session_key "sk-ant-sid01-..."

# Optional: Organization ID (auto-fetched if not set)
# set -g @claude_org_id "..."

# Optional: Which limit to show (default: "5h")
# Options: "5h" (5-hour), "7d" (7-day), "opus", "sonnet"
set -g @claude_limit_type "5h"

# Optional: Cache duration in seconds (default: 300)
set -g @claude_cache_interval "300"

# Optional: Display format (default: "Claude: #P%")
# #P is replaced with the usage percentage
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
| Normal usage | `Claude: 45%` |
| No session key | `Claude: No session key` |
| Session expired | `Claude: Session expired` |
| API error | `Claude: API error` |

## Limit Types

Claude.ai has multiple rate limits you can monitor:

| Option | Description |
|--------|-------------|
| `5h` | 5-hour rolling limit (default) |
| `7d` | 7-day rolling limit |
| `opus` | 7-day Opus-specific limit |
| `sonnet` | 7-day Sonnet-specific limit |

## Troubleshooting

### "No session key" displayed

Ensure you've set `@claude_session_key` in your tmux.conf and reloaded the configuration.

### "Session expired" displayed

Your session key has expired. Follow the setup steps again to get a new session key from your browser.

### Usage not updating

The plugin caches results to avoid excessive API calls. By default, it only fetches new data every 5 minutes. You can adjust this with `@claude_cache_interval`.

### Clearing cached data

If you need to clear the cached organization ID (e.g., after switching accounts):

```bash
rm -rf ~/.cache/tmux-claude
```

## Caveats

- **Unofficial API**: Claude.ai's internal API is not officially documented and could change without notice
- **Session expiration**: Session keys expire after weeks to months; you'll need to refresh them periodically
- **No official support**: Anthropic does not officially support this use case

## License

MIT License - see [LICENSE](LICENSE) file.
