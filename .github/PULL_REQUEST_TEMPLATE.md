<!--
PR description rules:
- Sections must not repeat each other. Section 2 continues section 1, it does not rephrase it.
- Plain English throughout. Code only in section 2, and only for key contracts.
- Assign a reviewer who can actually review these changes. If you are not sure who
  that is, assign @Val4evr or @carlosmora-sys.
-->

## Summary

<!--
HUMAN-written, 50 words max, no code. What changed and why.
Link any related issues or PRs here.
Tell the reviewer where to start — e.g. "the only file that needs real scrutiny
is src/auth/session.ts".
Everything in this section must be something you can fully explain yourself.
-->

## Details

<!--
200 words max, mostly prose, and a continuation of the summary — do not restate it.
Code snippets only for key contracts or the few lines that really matter.
Cover, where they apply:
- Risk and rollback: what breaks if this is wrong, and how to undo it. Call out
  anything `git revert` alone will not fix — migrations, feature flags, config or
  env changes, data backfills.
- What you deliberately did NOT do: deferred edge cases, accepted tech debt, known
  follow-ups. Link the ticket if there is one.
-->

## Testing

<!--
Usually AI-generated (unit tests, browser e2e flows) — list those, plus any manual
testing you did yourself. Include the commands run and the environment they ran
against (local / pre-prod / prod). Say what you did NOT test.
-->

### Automated

### Manual

### Screenshots / video

<!--
REQUIRED for any frontend change: screenshots, gifs or mp4s of the change working,
on desktop AND mobile if both are supported.
Delete this section if there are no user-facing changes.
-->

#### Desktop

#### Mobile
