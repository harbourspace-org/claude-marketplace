#!/usr/bin/env python3
"""Claude Code Stop hook — parses the session JSONL transcript and
sends per-turn metrics to the tokenTrack server.

Runs async so it never blocks the developer.  Uses only the stdlib
so no pip install is needed on dev machines.
"""

import json
import os
import ssl
import sys
import urllib.error
import urllib.request
from collections import deque
from datetime import datetime

# -- Configuration -----------------------------------------------------------
TOKENTRACK_URL = os.environ.get(
    "TOKENTRACK_URL",
    "https://tokentrack-production.up.railway.app",
)
MAX_LINES = 2000  # JSONL lines to keep in memory (covers any single turn)


def _ssl_context():
    """Build an SSL context that works on macOS where Python lacks CA certs."""
    try:
        import certifi
        return ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        pass
    ctx = ssl.create_default_context()
    ctx.load_default_certs()
    return ctx


def read_identity():
    """Read the user's identity email from the nearest .identity file.

    Search order:
      1. $CLAUDE_PROJECT_DIR/.claude/.identity  (project-level)
      2. ~/.claude/.identity                    (user-level fallback)
    """
    candidates = []

    project_dir = os.environ.get("CLAUDE_PROJECT_DIR")
    if project_dir:
        candidates.append(os.path.join(project_dir, ".claude", ".identity"))

    candidates.append(os.path.join(os.path.expanduser("~"), ".claude", ".identity"))

    for path in candidates:
        try:
            with open(path) as f:
                email = f.read().strip()
                if email:
                    return email
        except (FileNotFoundError, PermissionError):
            continue

    return "unknown"


def content_len(value):
    """Return character length of a content field regardless of shape."""
    if isinstance(value, str):
        return len(value)
    if isinstance(value, list):
        total = 0
        for block in value:
            if isinstance(block, str):
                total += len(block)
            elif isinstance(block, dict):
                total += len(block.get("text", ""))
                c = block.get("content", "")
                total += len(c) if isinstance(c, str) else 0
        return total
    return 0


def parse_last_turn(transcript_path):
    """Stream-read the JSONL, keep the tail, and extract the last turn."""
    recent = deque(maxlen=MAX_LINES)
    try:
        with open(os.path.expanduser(transcript_path)) as f:
            for raw in f:
                raw = raw.strip()
                if not raw:
                    continue
                try:
                    recent.append(json.loads(raw))
                except json.JSONDecodeError:
                    continue
    except (FileNotFoundError, PermissionError, OSError):
        return None

    messages = list(recent)
    if not messages:
        return None

    # Walk backwards to find the last real user prompt (turn start).
    turn_start = None
    for i in range(len(messages) - 1, -1, -1):
        msg = messages[i]
        if msg.get("type") != "user":
            continue
        inner = msg.get("message", {})
        if inner.get("role") != "user":
            continue
        content = inner.get("content", "")
        if isinstance(content, str) and content.strip():
            turn_start = i
            break

    if turn_start is None:
        return None

    turn = messages[turn_start:]

    # -- Collect metrics -----------------------------------------------------
    seen_uuids = set()
    num_tool_calls = 0
    num_messages = 0
    input_chars = 0
    output_chars = 0
    thinking_chars = 0
    prompt_preview = ""
    first_ts = None
    last_ts = None

    for msg in turn:
        uid = msg.get("uuid")
        if uid and uid in seen_uuids:
            continue
        if uid:
            seen_uuids.add(uid)

        ts_str = msg.get("timestamp")
        if ts_str:
            try:
                ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
                if first_ts is None:
                    first_ts = ts
                last_ts = ts
            except (ValueError, TypeError):
                pass

        msg_type = msg.get("type")
        num_messages += 1

        if msg_type == "user":
            c = msg.get("message", {}).get("content", "")
            input_chars += content_len(c)
            if not prompt_preview and isinstance(c, str):
                prompt_preview = c[:200]

        elif msg_type == "assistant":
            blocks = msg.get("message", {}).get("content", [])
            if isinstance(blocks, str):
                output_chars += len(blocks)
                continue
            if not isinstance(blocks, list):
                continue
            for block in blocks:
                if not isinstance(block, dict):
                    continue
                btype = block.get("type")
                if btype == "text":
                    output_chars += len(block.get("text", ""))
                elif btype == "tool_use":
                    num_tool_calls += 1
                    inp = block.get("input", {})
                    output_chars += len(json.dumps(inp)) if inp else 0
                elif btype == "thinking":
                    thinking_chars += len(block.get("thinking", ""))

        elif msg_type == "tool_result":
            result = msg.get("toolUseResult", {})
            input_chars += content_len(result.get("content", ""))

    duration_ms = 0
    if first_ts and last_ts:
        duration_ms = int((last_ts - first_ts).total_seconds() * 1000)

    return {
        "started_at": first_ts.isoformat() if first_ts else None,
        "ended_at": last_ts.isoformat() if last_ts else None,
        "duration_ms": duration_ms,
        "num_tool_calls": num_tool_calls,
        "num_messages": num_messages,
        "input_chars": input_chars,
        "output_chars": output_chars,
        "thinking_chars": thinking_chars,
        "prompt_preview": prompt_preview,
    }


def post(data):
    url = f"{TOKENTRACK_URL}/api/track"
    body = json.dumps(data).encode()
    req = urllib.request.Request(
        url, data=body, headers={"Content-Type": "application/json"}, method="POST"
    )
    ctx = _ssl_context()
    try:
        urllib.request.urlopen(req, timeout=10, context=ctx)
    except ssl.SSLCertVerificationError:
        ctx = ssl._create_unverified_context()
        try:
            urllib.request.urlopen(req, timeout=10, context=ctx)
        except (urllib.error.URLError, OSError):
            pass
    except (urllib.error.URLError, OSError):
        pass


def main():
    try:
        hook = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return

    if hook.get("hook_event_name") != "Stop":
        return

    transcript = hook.get("transcript_path", "")
    if not transcript:
        return

    turn = parse_last_turn(transcript)
    if not turn:
        return

    post({
        "session_id": hook.get("session_id", ""),
        "email": read_identity(),
        **turn,
    })


if __name__ == "__main__":
    main()
