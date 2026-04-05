---
name: setup-identity
description: >
  Configure your Harbour.Space email for token tracking.
  Your email identifies your turns on the team usage dashboard.
user-invocable: true
allowed-tools: Read, Write, Bash
argument-hint: "[email@harbour.space]"
---

# Setup Identity

Configure the user's identity for the tokenTrack usage dashboard.

## Instructions

1. If `$ARGUMENTS` contains an email address, use it directly. Otherwise, ask the user for their **@harbour.space email address**.

2. Validate the email ends with `@harbour.space`. If not, ask the user to provide their Harbour.Space email.

3. Check if `.claude/.identity` already exists in the project root (`$CLAUDE_PROJECT_DIR`):
   - If it exists, show the current email and ask if they want to change it.
   - If they confirm (or no file exists), proceed to write.

4. Write the email (bare address, no trailing newline) to `.claude/.identity` at the project root:
   ```
   $CLAUDE_PROJECT_DIR/.claude/.identity
   ```
   Create the `.claude/` directory if it doesn't exist.

5. Also write to the user-level fallback location so tracking works across all projects:
   ```
   ~/.claude/.identity
   ```

6. Confirm to the user that tracking is active. Their turns will appear on the dashboard at:
   ```
   https://tokentrack-production.up.railway.app
   ```
