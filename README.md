# tmux-claude

A TPM-compatible tmux plugin to display Claude subscription usage in the status bar.

## How It Works

This plugin fetches your Claude subscription usage percentage and displays either:
- **Usage mode (default)**: How much of your rate limit you've consumed (0-100%)
- **Remaining mode**: How much of your rate limit remains available (0-100%)

**Authentication methods (in priority order):**

1. **OAuth API (Recommended)** - Uses Claude CLI credentials from `~/.claude/.credentials.json`. No manual setup required if you use Claude Code CLI.
2. **Web API (Fallback)** - Uses browser session cookies. Requires manual session key extraction.

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

### Option 1: OAuth (Recommended - Zero Configuration)

If you use [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code), this plugin works automatically with no configuration needed.

The CLI stores OAuth credentials in `~/.claude/.credentials.json` which are automatically refreshed when you use Claude Code. Just install the plugin and add `#{claude_usage}` to your status bar.

**Requirements:**
- Claude Code CLI installed and authenticated
- OAuth credentials must include `user:profile` scope (default for CLI auth)

### Option 2: Browser Session Key (Fallback)

If you don't use Claude Code CLI, you can use browser session cookies:

1. Open [claude.ai](https://claude.ai) in your browser and ensure you're logged in
2. Open Developer Tools (F12 or Cmd+Option+I on Mac)
3. Go to the **Network** tab
4. Refresh the page
5. Click on any request to `claude.ai`
6. In the **Headers** section, find the `Cookie` header
7. Look for `sessionKey=sk-ant-sid01-...` and copy the entire value (starting with `sk-ant-sid01-`)

Add to `~/.tmux.conf`:

```bash
set -g @claude_session_key "sk-ant-sid01-..."
```

**Note:** Session keys expire periodically (weeks to months) and will need to be refreshed manually.

## Configuration

Add these options to your `~/.tmux.conf`:

```bash
# Optional: Session key for Web API fallback (not needed if using Claude CLI)
# set -g @claude_session_key "sk-ant-sid01-..."

# Optional: Organization ID for Web API (auto-fetched if not set)
# set -g @claude_org_id "..."

# Optional: Which limit to show (default: "5h")
# Options: "5h" (5-hour), "7d" (7-day), "opus", "sonnet"
set -g @claude_limit_type "5h"

# Optional: Cache duration in seconds (default: 300)
set -g @claude_cache_interval "300"

# Optional: Display format (default: "Claude: #P%")
# #P is replaced with the usage percentage
set -g @claude_format "Claude: #P%"

# Optional: Show remaining percentage instead of usage (default: "false")
# When "true", shows how much quota is remaining (e.g., 55% left)
# When "false", shows how much quota has been used (e.g., 45% used)
set -g @claude_show_remaining "false"
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

### Normal Usage

| Mode | Configuration | Display |
|------|--------------|---------|
| Usage (default) | `@claude_show_remaining "false"` | `Claude: 45%` (45% used) |
| Remaining | `@claude_show_remaining "true"` | `Claude: 55%` (55% remaining) |

### Error States

| Status | Display |
|--------|---------|
| No credentials | `Claude: No credentials` |
| OAuth token expired | `Claude: Token expired` |
| Session key expired | `Claude: Session expired` |
| Authentication failed | `Claude: Auth failed` |
| API error | `Claude: API error` |

## Limit Types

Claude has multiple rate limits you can monitor:

| Option | Description |
|--------|-------------|
| `5h` | 5-hour rolling limit (default) |
| `7d` | 7-day rolling limit |
| `opus` | 7-day Opus-specific limit |
| `sonnet` | 7-day Sonnet-specific limit |

## Troubleshooting

### "No credentials" displayed

Neither OAuth credentials nor session key were found. Either:
- Install and authenticate with [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code), or
- Set `@claude_session_key` in your tmux.conf

### "Token expired" displayed

Your OAuth token has expired. Run any Claude Code CLI command to refresh it:

```bash
claude --version
```

### "Session expired" displayed

Your browser session key has expired. Follow the setup steps again to get a new session key from your browser.

### Usage not updating

The plugin caches results to avoid excessive API calls. By default, it only fetches new data every 5 minutes. You can adjust this with `@claude_cache_interval`.

### Clearing cached data

If you need to clear the cached data (e.g., after switching accounts):

```bash
rm -rf ~/.cache/tmux-claude
```

## Dependencies

- `curl` - for API requests
- `jq` (optional but recommended) - for JSON parsing. Falls back to grep/sed if not available.
- `bc` (optional) - for decimal math. Falls back gracefully if not available.

## How OAuth Works

The plugin reads Claude CLI's OAuth credentials from:
1. **macOS Keychain** (preferred): Service name `Claude Code-credentials`
2. **File fallback**: `~/.claude/.credentials.json`

Credentials format:
```json
{
  "claudeAiOauth": {
    "accessToken": "sk-ant-oat...",
    "refreshToken": "...",
    "expiresAt": 1234567890000,
    "scopes": ["user:profile", "user:inference"]
  }
}
```

It then calls the OAuth usage API:
- **Endpoint:** `https://api.anthropic.com/api/oauth/usage`
- **Auth:** Bearer token from credentials

This approach is more reliable than browser cookies because:
- Tokens are managed and refreshed by Claude CLI
- No manual cookie extraction needed
- More stable than the unofficial Web API

## Credits

Inspired by [CodexBar](https://github.com/steipete/CodexBar) for the OAuth API approach.

## License

MIT License - see [LICENSE](LICENSE) file.
