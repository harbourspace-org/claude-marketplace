#!/usr/bin/env bash
#
# promo-code.sh — manage application_promo_codes in the Harbour.Space prod backend.
#
# Connects via Teleport (tsh) to hs-prod and runs MySQL inside the laravel PHP
# container. The DB password is read from the container's .env at runtime and is
# NEVER printed, passed on a command line, or written anywhere. All string values
# are sent to MySQL as hex literals (0x..), so quoting/escaping and SQL injection
# are non-issues (apostrophes, accents, emoji, etc. all pass through untouched).
#
# Prerequisite: `tsh login` against teleport.harbour.space with a role that grants
# the `root` login on the `hs-prod` node.
#
# Subcommands:
#   lookup <code>     Show the record(s) for a code (case-insensitive)
#   list [N]          Show the N most recent non-deleted codes (default 10)
#   create            Insert a new code from PC_* env vars (see below)
#   update <code>     Update the provided PC_* fields for a code
#   delete <code>     Soft-delete a code (sets deleted_at = NOW())
#
# create / update inputs (env vars — unset or empty means "not provided"):
#   PC_CODE        promo code string            (create: required)
#   PC_SALES       salesperson_name             (create: required)
#   PC_MANAGER     manager_name                 (optional)
#   PC_FEE         application_fee in EUR        (default 125)
#   PC_DISCOUNT    discount percent             (create: PC_DISCOUNT or PC_PRICE required)
#   PC_PRICE       discounted price in EUR      (the other is computed from PC_FEE)
#   PC_COMMENTS    free-text comments           (optional)
#   PC_DEADLINE    'YYYY-MM-DD HH:MM:SS'        (optional; NULL = no expiry)
#   PC_PAYPAL      paypal_link                  (optional)
#   PC_FORCE=1     allow create even if the code already exists
#
# Infra overrides (prod defaults shown):
#   PROMO_SERVER=root@hs-prod
#   PROMO_CONTAINER=laravel-laravel-php7-1
#   PROMO_APP=/code/hs-laravel
#
set -euo pipefail

SERVER="${PROMO_SERVER:-root@hs-prod}"
CONTAINER="${PROMO_CONTAINER:-laravel-laravel-php7-1}"
APP="${PROMO_APP:-/code/hs-laravel}"
TABLE="application_promo_codes"

die() { echo "ERROR: $*" >&2; exit 1; }

command -v tsh >/dev/null 2>&1 || die "tsh not found — install Teleport, then 'tsh login'."
command -v xxd >/dev/null 2>&1 || die "xxd not found (ships with vim / macOS)."

# Run SQL (passed as $1) inside the container, reading creds from .env at runtime.
# The password is interpolated only inside the remote shell and never echoed.
run_sql() {
  local remote
  remote='docker exec -i '"$CONTAINER"' sh -c '\''cd '"$APP"' && MP=$(grep -E "^DB_PASSWORD=" .env | cut -d= -f2-) && DH=$(grep -E "^DB_HOST=" .env | cut -d= -f2-) && DB=$(grep -E "^DB_DATABASE=" .env | cut -d= -f2-) && U=$(grep -E "^DB_USERNAME=" .env | cut -d= -f2-) && exec mysql --default-character-set=utf8mb4 -h "$DH" -u "$U" -p"$MP" "$DB"'\'''
  printf '%s\n' "$1" | tsh ssh "$SERVER" "$remote"
}

# SQL string literal: hex-encode the value, or emit NULL when empty.
sqlstr() {
  if [ -z "${1:-}" ]; then
    printf 'NULL'
  else
    printf '0x%s' "$(printf '%s' "$1" | xxd -p | tr -d '\n')"
  fi
}

# Numeric literal, with an optional default; dies on anything non-numeric.
sqlnum() {
  local v="${1:-}" def="${2:-}"
  [ -z "$v" ] && v="$def"
  if [ -z "$v" ]; then printf 'NULL'; return; fi
  case "$v" in
    ''|*[!0-9.]*) die "expected a number, got '$v'";;
  esac
  printf '%s' "$v"
}

# Round f*(1-d/100) etc. to 2 decimals.
calc() { awk "BEGIN{printf \"%.2f\", $1}"; }

cmd="${1:-}"
case "$cmd" in
  lookup)
    [ -n "${2:-}" ] || die "usage: promo-code.sh lookup <code>"
    run_sql "SELECT * FROM $TABLE WHERE code = $(sqlstr "$2")\\G"
    ;;

  list)
    n="${2:-10}"
    case "$n" in ''|*[!0-9]*) die "usage: promo-code.sh list [N]";; esac
    run_sql "SELECT id,code,salesperson_name,manager_name,application_fee,discount,price,deadline,comments,created_at FROM $TABLE WHERE deleted_at IS NULL ORDER BY id DESC LIMIT $n;"
    ;;

  create)
    [ -n "${PC_CODE:-}" ]  || die "PC_CODE is required"
    [ -n "${PC_SALES:-}" ] || die "PC_SALES is required"
    fee="${PC_FEE:-125}"
    disc="${PC_DISCOUNT:-}"
    price="${PC_PRICE:-}"
    if [ -z "$disc" ] && [ -z "$price" ]; then die "provide PC_DISCOUNT or PC_PRICE"; fi
    if [ -z "$price" ]; then price="$(calc "$fee*(1-$disc/100)")"; fi
    if [ -z "$disc" ];  then disc="$(calc "(1-$price/$fee)*100")"; fi

    # Uniqueness check — collation is case-insensitive, so this also catches case variants.
    existing="$(run_sql "SELECT id FROM $TABLE WHERE code = $(sqlstr "$PC_CODE") AND deleted_at IS NULL;" | sed -n '2p')"
    if [ -n "$existing" ] && [ "${PC_FORCE:-}" != "1" ]; then
      die "code '$PC_CODE' already exists (id $existing). Re-run with PC_FORCE=1 to add a duplicate."
    fi

    echo "Creating code '$PC_CODE' — fee ${fee}, discount ${disc}%, price ${price} EUR..." >&2
    run_sql "INSERT INTO $TABLE (code,salesperson_name,manager_name,application_fee,discount,price,comments,deadline,paypal_link,created_at,updated_at,deleted_at) VALUES ($(sqlstr "$PC_CODE"),$(sqlstr "$PC_SALES"),$(sqlstr "${PC_MANAGER:-}"),$(sqlnum "$fee"),$(sqlnum "$disc"),$(sqlnum "$price"),$(sqlstr "${PC_COMMENTS:-}"),$(sqlstr "${PC_DEADLINE:-}"),$(sqlstr "${PC_PAYPAL:-}"),NOW(),NOW(),NULL); SELECT * FROM $TABLE WHERE id = LAST_INSERT_ID()\\G"
    ;;

  update)
    [ -n "${2:-}" ] || die "usage: promo-code.sh update <code>"
    code="$2"
    sets=()
    if [ -n "${PC_SALES:-}" ];    then sets+=("salesperson_name = $(sqlstr "$PC_SALES")"); fi
    if [ -n "${PC_MANAGER:-}" ];  then sets+=("manager_name = $(sqlstr "$PC_MANAGER")"); fi
    if [ -n "${PC_FEE:-}" ];      then sets+=("application_fee = $(sqlnum "$PC_FEE")"); fi
    if [ -n "${PC_DISCOUNT:-}" ]; then sets+=("discount = $(sqlnum "$PC_DISCOUNT")"); fi
    if [ -n "${PC_PRICE:-}" ];    then sets+=("price = $(sqlnum "$PC_PRICE")"); fi
    if [ -n "${PC_COMMENTS:-}" ]; then sets+=("comments = $(sqlstr "$PC_COMMENTS")"); fi
    if [ -n "${PC_DEADLINE:-}" ]; then sets+=("deadline = $(sqlstr "$PC_DEADLINE")"); fi
    if [ -n "${PC_PAYPAL:-}" ];   then sets+=("paypal_link = $(sqlstr "$PC_PAYPAL")"); fi
    [ "${#sets[@]}" -gt 0 ] || die "no PC_* fields provided to update"
    sets+=("updated_at = NOW()")
    setclause="$(IFS=,; echo "${sets[*]}")"
    echo "Updating code '$code'..." >&2
    run_sql "UPDATE $TABLE SET $setclause WHERE code = $(sqlstr "$code") AND deleted_at IS NULL; SELECT * FROM $TABLE WHERE code = $(sqlstr "$code") AND deleted_at IS NULL\\G"
    ;;

  delete)
    [ -n "${2:-}" ] || die "usage: promo-code.sh delete <code>"
    echo "Soft-deleting code '$2'..." >&2
    run_sql "UPDATE $TABLE SET deleted_at = NOW() WHERE code = $(sqlstr "$2") AND deleted_at IS NULL; SELECT id,code,deleted_at FROM $TABLE WHERE code = $(sqlstr "$2")\\G"
    ;;

  *)
    die "usage: promo-code.sh {lookup|list|create|update|delete} [...]"
    ;;
esac
