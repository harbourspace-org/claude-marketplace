---
name: devkit
description: >
  Multi-instance stack orchestrator for Harbour.Space local development.
  Spin up isolated Docker environments per task or agent — each with its own
  ports, branches, env files, and containers. Supports create, up, down,
  destroy, status, logs, env validation, branch switching, cloning, exec,
  and garbage collection of stale instances.
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
argument-hint: "<command> [instance] [options]"
---

# devkit — Multi-Instance Stack Orchestrator

You are the devkit skill. You orchestrate isolated Docker development environments for Harbour.Space projects. Each stack instance is a named group of projects (laravel, website, etc.) running in Docker with unique ports, container names, and network — fully isolated from other instances.

## Configuration Files

- **Registry:** `${CLAUDE_SKILL_DIR}/registry.json` — static project definitions (repos, services, ports, env overrides, dependencies)
- **Scripts:** `${CLAUDE_SKILL_DIR}/../../scripts/devkit-ports.sh` — port allocation helper
- **Scripts:** `${CLAUDE_SKILL_DIR}/../../scripts/devkit-compose.sh` — compose override generator
- **State:** `{workspace}/stacks/.devkit-instances.json` — runtime instance state (created dynamically)

Read `registry.json` at the start of every command to get project definitions and workspace path.

## Port Allocation

Ports are deterministic: `base_port + (instance_index * port_range_per_instance) + service_port_offset`

With defaults (`base_port: 9000`, `range: 100`):
- Instance 0 → ports 9000-9099
- Instance 1 → ports 9100-9199
- Instance 2 → ports 9200-9299

## Concurrency Safety

Multiple agents may run devkit commands simultaneously. All reads/writes to `.devkit-instances.json` MUST use file locking:

```bash
(
  flock -x 200
  # read, modify, write .devkit-instances.json here
) 200>"${STACKS_DIR}/.devkit-instances.lock"
```

---

## Commands

### `devkit create <instance-name> [options]`

Creates a new isolated stack instance.

**Options:**
- `--projects <list>` — comma-separated project names. **If omitted, clones ALL projects in registry.** This is the default and recommended behavior — each instance gets the full stack.
- `--branches <map>` — comma-separated `project:branch` pairs (default: each project's `default_branch`). Only specify branches for projects you want on a non-default branch; the rest use their `default_branch`.
- `--base-port <number>` — override auto port allocation
- `--no-build` — skip docker build
- `--no-setup` — skip post_setup commands

**Clone strategy:**
- **Default (`clone_strategy: "all"`):** Every project is cloned from its repo. The agent gets full source code for all projects and can modify any of them.
- **Future optimization:** When Docker Hub CI/CD is ready (HSDEV-224), projects with a non-null `image` field in the registry that are NOT in `--projects` will be pulled as pre-built images instead of cloned. This saves disk and time for projects the agent doesn't need to modify.

**Steps:**

1. Read `registry.json` for workspace path and project definitions
2. Determine project list: if `--projects` specified, use those; otherwise use ALL projects from registry
3. **Lock** `.devkit-instances.json` → allocate next available `index` → increment `next_index` → **unlock**
4. Calculate port range: `base_port + (index * range)`
5. For each project (respecting `depends_on` order):
   a. Clone repo: `glab repo clone {repo} {workspace}/stacks/{instance}/{project} -- --branch {branch}`
   b. Copy env file: `cp {project}/{env_file} {project}/.env`
   c. Patch `.env` with `env_overrides` — resolve `{{CONTAINER_*}}` to `devkit-{instance}-{project}-{service}` and `{{PORT_*}}` to calculated ports
   d. Patch `.env` with `env_links` — resolve cross-project refs like `{{laravel.PORT_nginx}}` and `{{laravel.CONTAINER_nginx}}`
   e. If `.env.secrets` exists at workspace root: merge matching vars into `.env` (secrets override env_overrides)
   f. Create Docker network: `docker network create devkit-{instance}-net 2>/dev/null || true`
   g. Generate compose override: run `devkit-compose.sh generate {instance} {index} {project} {project_dir}`
   h. Build (unless `--no-build`): `docker compose -f docker-compose.yml -f docker-compose.devkit.yml build`
   i. Run post_setup (unless `--no-setup`): execute each command via `docker compose exec` or in the project dir
6. **Lock** → update instance state with project branches and status "stopped" → **unlock**
7. Print summary: instance name, port range, projects, branches

**Resolving placeholders in env_overrides:**
- `{{CONTAINER_mysql}}` → `devkit-{instance}-{project}-mysql`
- `{{PORT_nginx}}` → calculated port for that service in this instance

**Resolving env_links (cross-project):**
- `{{laravel.PORT_nginx}}` → calculated nginx port for laravel in THIS instance
- `{{laravel.CONTAINER_nginx}}` → `devkit-{instance}-laravel-nginx`

**Secrets merging (`.env.secrets`):**
If `{workspace}/.env.secrets` exists, after patching env_overrides and env_links, read each line from `.env.secrets` and override the matching key in the project's `.env`. This allows shared API keys (AC, Sentry, Keycloak, etc.) to be injected automatically without the agent needing to know them.

### `devkit up <instance-name> [project]`

Starts containers for the instance.

**Steps:**
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
6. Print status table

### `devkit down <instance-name> [project]`

Stops containers in reverse dependency order.

**Steps:**
1. Read instance state
2. Resolve shutdown order (reverse of `depends_on`)
3. For each project:
   a. `cd` to project dir
   b. `docker compose -f docker-compose.yml -f docker-compose.devkit.yml down`
   c. If `--volumes` flag: add `-v` to remove volumes
4. **Lock** → update status to "stopped" → **unlock**

### `devkit destroy <instance-name>`

Completely removes an instance.

**Steps:**
1. If not `--force`: ask user for confirmation
2. Run `devkit down {instance} --volumes` for all projects
3. Remove Docker network: `docker network rm devkit-{instance}-net 2>/dev/null || true`
4. Delete workspace: `rm -rf {workspace}/stacks/{instance}`
5. **Lock** → remove instance from state file (do NOT decrement `next_index` — indices are never reused) → **unlock**
6. Print confirmation with freed port range

### `devkit status [instance-name]`

Shows instance details. If no instance specified, shows all.

**Output format:**
```
╔══════════════════════════════════════════════════════════════╗
║ Stack: feature-auth  (index: 1, ports: 9100-9199)          ║
╠══════════╦══════════════════════╦════════╦═════════╦════════╣
║ Project  ║ Branch               ║ Port   ║ Status  ║ Health ║
╠══════════╬══════════════════════╬════════╬═════════╬════════╣
║ laravel  ║ feature/auth         ║        ║         ║        ║
║  mysql   ║                      ║  9101  ║ running ║ ✓      ║
║  php     ║                      ║  9102  ║ running ║ ✓      ║
║  nginx   ║                      ║  9103  ║ running ║ ✓      ║
║ website  ║ feature/auth-ui      ║        ║         ║        ║
║  react   ║                      ║  9110  ║ running ║ ✓      ║
╚══════════╩══════════════════════╩════════╩═════════╩════════╝
```

Use `docker ps --filter name=devkit-{instance}` to get real container status.
If `--json` flag: output as JSON (useful for agent consumption).

### `devkit list`

Quick overview of all instances:

```
Instance         Index  Ports       Projects          Status
main             0      9000-9099   laravel, website  running
feature-auth     1      9100-9199   laravel, website  stopped
fix-payments     2      9200-9299   laravel           running
```

If `--json` flag: output as JSON.

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

If `--validate`:
1. **Cross-project port consistency** — for each `env_links` entry, verify the referenced port matches the actual allocated port
2. **Internal host references** — verify DB_HOST, REDIS_HOST etc. use the correct `devkit-{instance}-*` container names (not `127.0.0.1`)
3. **Port reachability** — for each service with a port, check if it's listening: `lsof -i :{port} -sTCP:LISTEN`

### `devkit branch <instance-name> <project> <branch>`

Switches a project to a different branch.

**Steps:**
1. `cd {workspace}/stacks/{instance}/{project}`
2. `git fetch origin`
3. `git checkout {branch}` (or `git checkout -b {branch} origin/{branch}` if remote-only)
4. If `--rebuild`: regenerate compose override and `docker compose build`
5. **Lock** → update branch in instance state → **unlock**

### `devkit clone <new-instance> --from <source-instance>`

Duplicates a stack with a new port range.

**Steps:**
1. Read source instance state
2. Create new instance (same as `devkit create` but with source's project list)
3. If `--branches` specified: override specific branches; otherwise use source branches
4. Copy `.env` files from source and re-patch with new instance's ports/containers

### `devkit exec <instance-name> <project> <service> -- <command>`

Runs a command inside a container.

```bash
docker exec -it devkit-{instance}-{project}-{service} {command}
```

### `devkit gc [options]`

Garbage collection — cleans up stale instances.

**Options:**
- `--dry-run` — show what would be cleaned without destroying
- `--force` — skip confirmation prompts
- `--max-age <duration>` — age threshold for dead instances (default: `7d`)

**Steps:**
1. Read all instances from state file (skip `main`)
2. For each instance, check staleness:
   a. Query GitLab for MR status: `glab mr list --source-branch={branch} --state=merged` and `--state=closed`
   b. If ALL project branches have merged/closed MRs → instance is STALE
   c. If all containers are stopped/missing AND instance is older than `--max-age` → instance is DEAD
3. If `--dry-run`: print report and exit
4. Otherwise, for each stale/dead instance: run `devkit destroy {instance} --force`
5. Log actions to `{workspace}/stacks/.devkit-gc.log`

---

## Important Notes

- **Clone all by default** — when no `--projects` is specified, clone ALL projects in the registry. Each instance gets the full stack. This is the team's decision; optimization (pre-built images for unmodified projects) comes later.
- **Never hardcode ports** — always calculate from registry + instance index
- **Always use file locking** when reading/writing `.devkit-instances.json`
- **Dependency order matters** — `depends_on` determines startup order (topological sort) and reverse for shutdown
- **The repo is public** — never write secrets into any file in this plugin
- **`.env.example` is the source of truth** — devkit only patches infra vars, the rest comes from the project
- **`.env.secrets` for shared secrets** — if `{workspace}/.env.secrets` exists, merge its vars into each project's `.env` during create. This file is NOT part of the plugin and must never be committed to this repo.
- **Indices are never reused** — when an instance is destroyed, its index stays taken. `next_index` only increments. This prevents port collision with containers that may still be shutting down
- **Docker Desktop must be running** — before any docker command, verify with `docker info >/dev/null 2>&1`
- **Use `glab` for GitLab operations** — cloning, MR checks, etc. SSH may not be configured
