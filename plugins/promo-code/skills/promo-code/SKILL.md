---
name: promo-code
description: >
  Create, update, or look up application fee promo codes in the production
  backend. Accepts natural language: code name, discounted price,
  salesperson, and optional deadline.
argument-hint: "<code> <price>€ [salesperson] [deadline]"
allowed-tools: Bash, Read, Glob
---

You are managing application fee promo codes in the production backend.

The input is: $ARGUMENTS

## Setup

Infrastructure details (server, container, artisan path, table name, standard fee)
are documented in the `CLAUDE.md` of the backend project in this repo. Read it before
proceeding — it contains the exact commands to run.

If no `CLAUDE.md` is found, ask the user for the connection details before continuing.

## Tasks

### Create a promo code

Parse the arguments to extract:
- **code** — the promo code string (uppercase)
- **price** — discounted price in EUR
- **salesperson_name** — who requested it (ask if not provided)
- **deadline** — optional; default to no expiration
- **comments** — optional

Calculate discount percentage from the standard fee defined in `CLAUDE.md`.

Confirm the result to the user showing: code, price, discount %, salesperson, deadline.

### Look up a promo code

Fetch and display the record for the given code.

### Update a promo code

Update only the fields specified. Always confirm the updated record afterward.

### List recent promo codes

Return the most recent promo codes ordered by creation date.

## Rules

- Always confirm the final record with the user after any write operation
- Promo codes should be uppercase
- If the salesperson name is not provided, ask before creating
- Never expose or log database credentials
- Never modify the standard application fee
