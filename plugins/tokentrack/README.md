# tokenTrack

Track Claude Code usage across the Harbour.Space engineering team.

A Stop hook runs after every Claude Code turn, parsing the session transcript and posting metrics (tool calls, character counts, duration) to a shared dashboard.

## Setup

After installing the plugin, run:

```
/setup-identity
```

Enter your `@harbour.space` email. That's it — your turns will appear on the dashboard automatically.

## Dashboard

[tokentrack-production.up.railway.app](https://tokentrack-production.up.railway.app)

Shows per-person usage, daily trends, hourly patterns, and recent activity.

## How It Works

On every session stop, `scripts/track.py` reads the JSONL transcript, extracts the last turn's metrics, and POSTs them to the dashboard server. The hook runs async with a 30-second timeout so it never blocks your workflow.

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `TOKENTRACK_URL` | `https://tokentrack-production.up.railway.app` | Dashboard server URL |
