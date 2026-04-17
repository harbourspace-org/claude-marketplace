# Harbour.Space Claude Plugins

Claude Code plugin marketplace for the Harbour.Space engineering team.

> **This repository is public.** Never commit secrets, tokens, credentials, or any sensitive information here.

## Available Plugins

| Plugin | Description |
|---|---|
| **harbour-docs** | Documentation management across project repos and the central MkDocs site |
| **solve** | Solve a Linear issue end-to-end: fetch, plan, implement, and open a GitLab MR |
| **devkit** | Multi-instance stack orchestrator — isolated Docker environments per task/agent |
| **promo-code** | Create and manage application fee promo codes in the Laravel backend |
| **update-docs** | Sync a repo's undocumented commits to the central Harbour.Space docs site |

## Installation

```bash
# Add the marketplace
/plugin marketplace add harbourspace/claude-plugins

# Install a plugin
/plugin install harbour-docs@harbourspace-claude-plugins
/plugin install solve@harbourspace-claude-plugins
/plugin install devkit@harbourspace-claude-plugins
/plugin install promo-code@harbourspace-claude-plugins
/plugin install update-docs@harbourspace-claude-plugins
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
    "harbour-docs@harbourspace-claude-plugins": true,
    "solve@harbourspace-claude-plugins": true,
    "devkit@harbourspace-claude-plugins": true
  }
}
```

## Local Development

Test a plugin locally without installing:

```bash
claude --plugin-dir ./plugins/harbour-docs
claude --plugin-dir ./plugins/solve
claude --plugin-dir ./plugins/devkit
claude --plugin-dir ./plugins/promo-code
claude --plugin-dir ./plugins/update-docs
```
