---
name: devkit
description: >
  Multi-instance stack orchestrator for Harbour.Space local development.
  Spin up isolated Docker environments per task or agent — each with its own
  ports, branches, env files, and containers. Supports create, up, down,
  destroy, status, logs, env validation, branch switching, cloning, exec,
  and garbage collection of stale instances.
user-invocable: true
argument-hint: "<command> [instance] [options]"
---

# devkit — Multi-Instance Stack Orchestrator

You are the devkit skill. You orchestrate isolated Docker development environments for Harbour.Space projects. Each stack instance is a named group of projects (laravel, website, etc.) running in Docker with unique ports, container names, and network — fully isolated from other instances.

## Pre-flight Checks (run before EVERY command)

Before executing ANY devkit command, verify these are available. If any fails, stop and tell the user how to fix it:

1. **Docker Desktop** — `docker info >/dev/null 2>&1`
2. **glab CLI** — `which glab >/dev/null 2>&1` (must be authenticated: `glab auth status`)
3. **Python 3** — `which python3 >/dev/null 2>&1`

---

## Configuration Files

- **Registry:** `${CLAUDE_SKILL_DIR}/registry.json` — static project definitions (repos, services, ports, env overrides, dependencies)
- **Scripts:** `${CLAUDE_SKILL_DIR}/../../scripts/devkit-ports.sh` — port allocation helper
- **Scripts:** `${CLAUDE_SKILL_DIR}/../../scripts/devkit-compose.sh` — compose override generator
- **State:** `{workspace}/stacks/.devkit-instances.json` — runtime instance state (created dynamically)

Read `registry.json` at the start of every command to get project definitions and resolve the workspace path.

### Workspace Resolution

The `workspace` field in `registry.json` determines the root directory for all stacks:

- **`"auto"`** (default, recommended) — use your **primary working directory** (the directory where the Claude Code session was opened). This is always available in your session context. **Never hardcode a user-specific path.**
- **An explicit path** (e.g. `"~/my/custom/path"`) — use that path directly.

Store the resolved value as `{workspace}` and use it for all subsequent commands.

## Port Allocation

Ports are deterministic: `base_port + (instance_index * port_range_per_instance) + service_port_offset`

With defaults (`base_port: 9000`, `range: 100`):
- Instance 0 → ports 9000-9099
- Instance 1 → ports 9100-9199
- Instance 2 → ports 9200-9299

## Concurrency Safety

Multiple agents may run devkit commands simultaneously. All reads/writes to `.devkit-instances.json` **MUST** use file locking via `python3` with `fcntl.flock` (LOCK_EX / LOCK_UN). Always lock before reading, modify in memory, write back, then unlock.

---

## Commands

### `devkit create <instance-name> [options]`

Creates a new isolated stack instance.

**Options:**
- `--projects <list>` — comma-separated project names. **If omitted, clones ALL projects in registry.**
- `--branches <map>` — comma-separated `project:branch` pairs (default: each project's `default_branch`).
- `--base-port <number>` — override auto port allocation
- `--no-build` — skip docker build
- `--no-setup` — skip post_setup commands

**Steps:**

1. Read `registry.json` for workspace path and project definitions
2. Determine project list: if `--projects` specified, use those; otherwise use ALL projects from registry
3. **Lock** `.devkit-instances.json` → allocate next available `index` → increment `next_index` → **unlock**
4. Calculate port range: `base_port + (index * range)`
5. **MANDATORY — Check for port conflicts:** Run `devkit-ports.sh check-range {index}`. If any port is in use, warn the user but proceed — they must free those ports before `devkit up`.
6. For each project (respecting `depends_on` order):
   a. Clone repo: `glab repo clone {repo} {workspace}/stacks/{instance}/{project} -- --branch {branch}`
   b. Copy env file: `cp {project}/{env_file} {project}/.env`
   c. Patch `.env` with `env_overrides` — resolve `{{CONTAINER_*}}` to `devkit-{instance}-{service}` and `{{PORT_*}}` to calculated ports
   d. Patch `.env` with `env_links` — resolve cross-project refs like `{{laravel.PORT_laravel-php7}}` and `{{laravel.CONTAINER_laravel-php7}}`
   e. If `.env.secrets` exists at workspace root: merge matching vars into `.env` (secrets override env_overrides)
   f. Create Docker network: `docker network create devkit-{instance}-net 2>/dev/null || true`
   g. Generate compose override: run `devkit-compose.sh generate {instance} {index} {project} {project_dir}`
   h. Build (unless `--no-build`): `docker compose -f docker-compose.yml -f docker-compose.devkit.yml build`
   i. Run post_setup (unless `--no-setup`): execute each command via `docker compose exec` or in the project dir
7. **Lock** → update instance state with project branches and status "stopped" → **unlock**
8. Print summary: instance name, port range, projects, branches

**Resolving placeholders in env_overrides:**
- `{{CONTAINER_laravel-mysql}}` → `devkit-{instance}-laravel-mysql`
- `{{PORT_laravel-php7}}` → calculated port for that service in this instance

**Resolving env_links (cross-project):**
- `{{laravel.PORT_laravel-php7}}` → calculated php7 port for laravel in THIS instance
- `{{laravel.CONTAINER_laravel-php7}}` → `devkit-{instance}-laravel-php7`

**Container naming:** `devkit-{instance}-{service}` (NOT `devkit-{instance}-{project}-{service}`). Service names in docker-compose already include the project prefix (e.g., `laravel-mysql`, `frontend-react`).

**Note:** Service names in the registry MUST match the actual service names in the project's `docker-compose.yml`.

**Secrets merging:** If `{workspace}/.env.secrets` exists, after patching env_overrides and env_links, merge its vars into each project's `.env`. This file is NOT part of the plugin and must never be committed.

### `devkit up <instance-name> [project]`

Starts containers for the instance.

1. Read instance state → verify instance exists
2. If no specific project, resolve startup order via topological sort of `depends_on`
3. Ensure Docker network exists: `docker network create devkit-{instance}-net 2>/dev/null || true`
4. For each project (in dependency order):
   a. `cd` to `{workspace}/stacks/{instance}/{project}`
   b. Regenerate compose override (ports/names may need refresh)
   c. `docker compose -f docker-compose.yml -f docker-compose.devkit.yml up -d`
   d. Run health check: poll `health_check.command` every `interval_seconds`, up to `retries` times
   e. If health check fails after all retries → log warning, continue (don't block dependents)
5. **Lock** → update status to "running" → **unlock**

### `devkit down <instance-name> [project]`

Stops containers in reverse dependency order.

1. Read instance state
2. Resolve shutdown order (reverse of `depends_on`)
3. For each project: `docker compose -f docker-compose.yml -f docker-compose.devkit.yml down` (add `-v` if `--volumes`)
4. **Lock** → update status to "stopped" → **unlock**

### `devkit destroy <instance-name>`

Completely removes an instance.

1. If not `--force`: ask user for confirmation
2. Run `devkit down {instance} --volumes` for all projects
3. Remove Docker network: `docker network rm devkit-{instance}-net 2>/dev/null || true`
4. Delete workspace: `rm -rf {workspace}/stacks/{instance}`
5. **Lock** → remove instance from state file (do NOT decrement `next_index` — indices are never reused) → **unlock**
6. Print confirmation with freed port range

### `devkit status [instance-name]`

Shows instance details. If no instance specified, shows all. Use `docker ps --filter name=devkit-{instance}` to get real container status. If `--json` flag: output as JSON.

### `devkit list`

Quick overview of all instances (name, index, ports, projects, status). If `--json` flag: output as JSON.

### `devkit logs <instance-name> <project> [service]`

Tails logs for a project/service.

```bash
cd {workspace}/stacks/{instance}/{project}
docker compose -f docker-compose.yml -f docker-compose.devkit.yml logs \
  --tail={--tail or 100} \
  {service if specified}
```

If `--follow`: add `-f` flag.

### `devkit env <instance-name> <project>`

Shows the current `.env` for a project in the instance.

If `--validate`: check cross-project port consistency, internal host references use correct container names, and port reachability.

### `devkit branch <instance-name> <project> <branch>`

Switches a project to a different branch.

1. `cd {workspace}/stacks/{instance}/{project}`
2. `git fetch origin`
3. `git checkout {branch}` (or `git checkout -b {branch} origin/{branch}` if remote-only)
4. If `--rebuild`: regenerate compose override and `docker compose build`
5. **Lock** → update branch in instance state → **unlock**

### `devkit clone <new-instance> --from <source-instance>`

Duplicates a stack with a new port range.

1. Read source instance state
2. Create new instance (same as `devkit create` but with source's project list)
3. If `--branches` specified: override specific branches; otherwise use source branches
4. Copy `.env` files from source and re-patch with new instance's ports/containers

### `devkit exec <instance-name> <project> <service> -- <command>`

Runs a command inside a container.

```bash
docker exec -it devkit-{instance}-{service} {command}
```

### `devkit gc [options]`

Garbage collection — cleans up stale instances.

**Options:** `--dry-run`, `--force`, `--max-age <duration>` (default: `7d`)

1. Read all instances from state file (skip `main`)
2. For each instance, check staleness:
   a. Query GitLab for MR status: if ALL project branches have merged/closed MRs → STALE
   b. If all containers are stopped/missing AND instance is older than `--max-age` → DEAD
3. If `--dry-run`: print report and exit
4. Otherwise, for each stale/dead instance: run `devkit destroy {instance} --force`
5. Log actions to `{workspace}/stacks/.devkit-gc.log`

---

## Important Notes

- **Clone all by default** — when no `--projects` is specified, clone ALL projects in the registry
- **Never hardcode ports** — always calculate from registry + instance index
- **Always use file locking** when reading/writing `.devkit-instances.json`
- **Dependency order matters** — `depends_on` determines startup order (topological sort) and reverse for shutdown
- **The repo is public** — never write secrets into any file in this plugin
- **`.env.example` is the source of truth** — devkit only patches infra vars, the rest comes from the project
- **`.env.secrets` for shared secrets** — if `{workspace}/.env.secrets` exists, merge its vars into each project's `.env` during create. This file must never be committed.
- **Indices are never reused** — when an instance is destroyed, its index stays taken. `next_index` only increments.
- **Use `glab` for GitLab operations** — cloning, MR checks, etc. SSH may not be configured
