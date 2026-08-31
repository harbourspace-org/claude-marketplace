---
name: promo-code
description: >
  Create, look up, update, or list application-fee promo codes in the
  Harbour.Space production backend. Use when someone asks to add a new promo /
  discount code for the application fee, check what a code does, change a code's
  discount/price/deadline, or list recent codes. Accepts natural language:
  code name, discount % or discounted price, salesperson, optional deadline.
argument-hint: <code> <discount%|price€> [salesperson] [deadline]
allowed-tools: Bash, Read
---

You manage **application-fee promo codes** in the Harbour.Space production backend.

The request is: $ARGUMENTS

## What these codes are

When an applicant pays the application fee, they can enter a promo code that
reduces (or zeroes) that fee. These codes live in the **`application_promo_codes`**
table of the `laravel` backend (Laravel 6). The standard application fee is
**€125**; a code stores a percentage `discount` and the resulting `price`.

> **Do not confuse this with the legacy `promo_code` table** (7 rows, untouched
> since 2020 — old `techscouts` / `muscatbootcamp` bootcamp codes with PayPal
> buttons). New codes almost always belong in `application_promo_codes`. If the
> user genuinely means the legacy bootcamp table, stop and confirm first — this
> skill targets `application_promo_codes`.

## Infrastructure (already wired into the helper script)

| | |
|---|---|
| Access | Teleport: `tsh ssh root@hs-prod` (run `tsh login` first if not authenticated) |
| Container | `laravel-laravel-php7-1` |
| App path | `/code/hs-laravel` |
| Database | MySQL `laravel`, user `laravel` — **password is read from the container `.env` at runtime, never hardcoded** |
| Table | `application_promo_codes` |

You don't run these by hand — the bundled script does. Override any of them with
`PROMO_SERVER` / `PROMO_CONTAINER` / `PROMO_APP` env vars (e.g. to target a
pre-prod box) when needed.

## The table

| Column | Meaning |
|---|---|
| `code` | The string the applicant types. **Case-insensitive** in MySQL (collation `utf8mb4_unicode_520_ci`), so `ICAN2026` and `ican2026` collide. Stored verbatim — real data is mixed-case, so **do not force uppercase**. |
| `salesperson_name` | Who requested it — a person (`Polina Nazarova`) or a partner org (`ICAN EDUCATION PTE LTD`). Required. |
| `manager_name` | Optional, usually NULL. |
| `application_fee` | Base fee, **€125** on effectively every row. |
| `discount` | **Percentage** (e.g. `40` = 40% off). |
| `price` | Discounted fee in EUR. **`price = application_fee × (1 − discount/100)`** — e.g. 125 with 40% → 75.00; 100% → 0.00 (free application). |
| `comments` | Free text — often the requester's email. Optional. |
| `deadline` | Expiry `datetime`. Mostly NULL = no expiry. |
| `paypal_link` | Optional PayPal hosted-button URL. |
| `deleted_at` | Soft delete (the model uses Laravel SoftDeletes; the app's lookup ignores soft-deleted rows). |

There is **no API endpoint to create codes** — the backend only validates them
(`/api/check_app_promocode`). New codes are added straight to the table, which
is exactly what this skill does.

## The helper script

All operations go through `${CLAUDE_SKILL_DIR}/../../scripts/promo-code.sh`. It
connects over Teleport, runs MySQL inside the container, reads the DB password
from `.env` at runtime (never printed), and sends every string value as a hex
literal — so quotes, apostrophes, accents, and emoji are injection-safe.

```bash
SCRIPT="${CLAUDE_SKILL_DIR}/../../scripts/promo-code.sh"

# Look up a code (vertical output, case-insensitive)
bash "$SCRIPT" lookup ICAN2026

# List the 10 most recent (or N) non-deleted codes
bash "$SCRIPT" list 10

# Create — pass fields as PC_* env vars. Give discount OR price; the other is computed.
PC_CODE="SUMMER2026" PC_SALES="Polina Nazarova" PC_DISCOUNT=40 \
  PC_COMMENTS="polina.nazarova@harbour.space" bash "$SCRIPT" create

# Update only the fields you pass
PC_DISCOUNT=50 bash "$SCRIPT" update SUMMER2026

# Soft-delete
bash "$SCRIPT" delete SUMMER2026
```

`create` / `update` inputs (env vars): `PC_CODE`, `PC_SALES`, `PC_MANAGER`,
`PC_FEE` (default 125), `PC_DISCOUNT`, `PC_PRICE`, `PC_COMMENTS`, `PC_DEADLINE`
(`'YYYY-MM-DD HH:MM:SS'`), `PC_PAYPAL`, `PC_FORCE=1` (allow a duplicate code).
For `create`, give **either** `PC_DISCOUNT` **or** `PC_PRICE` — the script
computes the missing one from the fee. The script refuses to create a code that
already exists unless `PC_FORCE=1`.

## How to handle a request

1. **Parse** the natural-language request into fields. Extract the code, the
   discount **or** price, the salesperson, and any deadline/comments.
2. **Ask before guessing.** `salesperson_name` is required — if it's not given,
   ask who requested the code. Don't invent it.
3. **Compute and preview.** Work out both `discount` and `price` from the €125
   fee and show the user the full record you're about to write: code, fee,
   discount %, price, salesperson, deadline, comments.
4. **Confirm, then write.** Only after the user confirms, run `create` (or
   `update` / `delete`). The script prints the resulting row — relay it back.
5. **On a duplicate**, the script aborts. Tell the user the existing code's
   details (run `lookup`) and ask whether to update it, pick a new name, or
   force a duplicate with `PC_FORCE=1`.

## Rules

- **Always confirm the final record with the user before any write** (create,
  update, delete). This is the production database.
- Reads (`lookup`, `list`) need no confirmation — run them freely.
- Never force codes to uppercase; store what the user gave.
- `salesperson_name` is required — ask if missing.
- Keep `discount` and `price` consistent (`price = 125 × (1 − discount/100)`)
  unless the user explicitly overrides the price.
- Never expose, log, or hardcode the DB password — the script handles it.
- Never change the standard €125 application fee.
- Deletes are soft (set `deleted_at`); they don't hard-remove rows.
