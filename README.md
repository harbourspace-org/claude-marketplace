# Harbour.Space Claude Plugins

Claude Code plugin marketplace for the Harbour.Space engineering team.

## Available Plugins

| Plugin | Description |
|---|---|
| **harbour-docs** | Documentation management across project repos and the central MkDocs site |

## Installation

```bash
# Add the marketplace
/plugin marketplace add harbourspace/claude-plugins

# Install a plugin
/plugin install harbour-docs@harbourspace-claude-plugins
```

Or add to a project's `.claude/settings.json` to auto-enable for all team members:

```json
{
  "extraKnownMarketplaces": {
    "harbourspace-claude-plugins": {
      "source": { "source": "github", "repo": "harbourspace/claude-plugins" }
    }
  },
  "enabledPlugins": {
    "harbour-docs@harbourspace-claude-plugins": true
  }
}
```

## Local Development

Test a plugin locally without installing:

```bash
claude --plugin-dir ./plugins/harbour-docs
```
