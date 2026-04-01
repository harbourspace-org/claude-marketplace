#!/usr/bin/env bash
# devkit-ports.sh — Port allocation and conflict detection for devkit instances
#
# Usage:
#   devkit-ports.sh calc <instance_index> <port_offset>   → prints the allocated port
#   devkit-ports.sh range <instance_index>                 → prints base..max port range
#   devkit-ports.sh check <port>                           → exits 0 if port is free, 1 if in use
#   devkit-ports.sh check-range <instance_index>           → checks all ports in range, lists conflicts

set -euo pipefail

REGISTRY_FILE="${CLAUDE_SKILL_DIR:-$(dirname "$0")/../skills/devkit}/registry.json"

# Read config from registry
BASE_PORT=$(python3 -c "import json; print(json.load(open('$REGISTRY_FILE'))['base_port'])")
RANGE=$(python3 -c "import json; print(json.load(open('$REGISTRY_FILE'))['port_range_per_instance'])")

calc_port() {
  local index=$1
  local offset=$2
  echo $(( BASE_PORT + (index * RANGE) + offset ))
}

port_range() {
  local index=$1
  local start=$(( BASE_PORT + (index * RANGE) ))
  local end=$(( start + RANGE - 1 ))
  echo "${start}..${end}"
}

check_port() {
  local port=$1
  if lsof -i :"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "IN_USE"
    return 1
  else
    echo "FREE"
    return 0
  fi
}

check_range() {
  local index=$1
  local start=$(( BASE_PORT + (index * RANGE) ))
  local end=$(( start + RANGE - 1 ))
  local conflicts=0

  # Get all port offsets from registry
  local offsets
  offsets=$(python3 -c "
import json
reg = json.load(open('$REGISTRY_FILE'))
for proj in reg['projects'].values():
    for svc, cfg in proj['services'].items():
        offset = cfg.get('port_offset', 0)
        internal = cfg.get('internal_port', 0)
        if offset > 0 and internal > 0:
            port = $BASE_PORT + ($index * $RANGE) + offset
            print(f'{port} {svc}')
")

  while IFS=' ' read -r port svc; do
    if lsof -i :"$port" -sTCP:LISTEN >/dev/null 2>&1; then
      echo "CONFLICT: port $port ($svc) is already in use"
      conflicts=$((conflicts + 1))
    else
      echo "OK: port $port ($svc) is free"
    fi
  done <<< "$offsets"

  if [ "$conflicts" -gt 0 ]; then
    echo ""
    echo "Found $conflicts port conflict(s) in range $(port_range "$index")"
    return 1
  else
    echo ""
    echo "All ports free in range $(port_range "$index")"
    return 0
  fi
}

# Main dispatch
case "${1:-help}" in
  calc)
    calc_port "${2:?instance_index required}" "${3:?port_offset required}"
    ;;
  range)
    port_range "${2:?instance_index required}"
    ;;
  check)
    check_port "${2:?port required}"
    ;;
  check-range)
    check_range "${2:?instance_index required}"
    ;;
  help|*)
    echo "Usage: devkit-ports.sh {calc|range|check|check-range} [args]"
    echo ""
    echo "  calc <index> <offset>   Calculate port for instance index + offset"
    echo "  range <index>           Show port range for instance"
    echo "  check <port>            Check if a single port is free"
    echo "  check-range <index>     Check all ports for an instance index"
    exit 0
    ;;
esac
