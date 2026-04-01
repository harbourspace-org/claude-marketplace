# devkit — Multi-Instance Stack Orchestrator

Spin up isolated Docker development environments per task or agent for Harbour.Space projects. Each stack instance gets its own ports, branches, env files, containers, and Docker network — fully isolated from other instances.

## Prerequisites

| Requirement | Install | Verify |
|---|---|---|
| **Docker Desktop** | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) | `docker info` |
| **glab CLI** | `brew install glab` | `glab --version` |
| **glab authenticated** | `glab auth login` (select gitlab.com, HTTPS) | `glab auth status` |
| **python3** | `brew install python3` (usually pre-installed on macOS) | `python3 --version` |
| **GitLab access** | You need access to the `harbourspace/` group on gitlab.com | `glab repo list -g harbourspace` |

## Quick Start

```bash
# Create a new stack instance with all projects
/devkit create my-feature --branches laravel:feature/my-branch,website:feature/my-branch

# Start the stack (respects dependency order)
/devkit up my-feature

# Check status and health
/devkit status my-feature

# Run a command inside a container
/devkit exec my-feature laravel php -- php artisan migrate

# Stop the stack
/devkit down my-feature

# Destroy everything (containers, volumes, cloned code)
/devkit destroy my-feature
```

## Commands

| Command | Description |
|---|---|
| `devkit create <name>` | Create a new stack instance: clone repos, generate env, allocate ports |
| `devkit up <name> [project]` | Start containers (dependency order), run health checks |
| `devkit down <name> [project]` | Stop containers (reverse dependency order) |
| `devkit destroy <name>` | Stop, remove volumes, delete workspace, free port range |
| `devkit status [name]` | Show instance details: containers, ports, branches, health |
| `devkit list` | Quick table of all instances |
| `devkit logs <name> <project> [service]` | Tail logs for a service |
| `devkit env <name> <project>` | Show env file, optionally validate cross-project refs |
| `devkit branch <name> <project> <branch>` | Switch a project to a different branch |
| `devkit clone <new> --from <source>` | Duplicate a stack with a new port range |
| `devkit exec <name> <project> <service> -- <cmd>` | Run a command inside a container |
| `devkit gc` | Clean up stale instances (merged/closed MRs) |

## How Port Allocation Works

Each instance gets a range of 100 ports, starting from base port 9000:

```
Instance 0 ("main"):         ports 9000-9099
Instance 1 ("feature-auth"): ports 9100-9199
Instance 2 ("fix-payments"): ports 9200-9299
```

Port for a service = `base_port + (instance_index * 100) + service_port_offset`

## Project Registry

Projects and their services are defined in `skills/devkit/registry.json`. Currently registered:

- **laravel** — mysql (offset 1), php (2), nginx (3), phpmyadmin (4), mysql-test (5), queue (0)
- **website** — react (offset 10), nginx (11)

## Env Strategy

1. Clone project → project already has `.env.example`
2. Copy `.env.example` → `.env`
3. Patch only infra vars (DB_HOST, ports, cross-project endpoints) from registry
4. If `{workspace}/.env.secrets` exists, merge shared API keys
5. Everything else stays as-is — agent reads code + CLAUDE.md for task-specific config

## File Structure

```
plugins/devkit/
  .claude-plugin/plugin.json    <- plugin metadata
  skills/devkit/
    SKILL.md                    <- instructions Claude reads
    registry.json               <- project definitions
  scripts/
    devkit-compose.sh           <- generates docker-compose.devkit.yml
    devkit-ports.sh             <- port allocation & conflict detection
  README.md                     <- this file
```
