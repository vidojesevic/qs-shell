#!/usr/bin/env python3
"""Claude Code token usage for the active 5 hour limit window.

Reads the local session transcripts, groups assistant replies into 5 hour
blocks and prints the active block as JSON for the bar widget. The limit is
calibrated from the biggest block seen so far, because the plan quota is not
written anywhere on disk.
"""

import json
import os
import sys
from datetime import datetime, timedelta, timezone

BLOCK = timedelta(hours=5)
PROJECTS = os.path.expanduser("~/.claude/projects")

# Used until enough history exists to calibrate a real ceiling.
FALLBACK_LIMIT = 20_000_000


def entries():
    """Yield (timestamp, model, tokens, project) once per assistant reply."""
    seen = set()

    for root, _dirs, files in os.walk(PROJECTS):
        project = os.path.basename(root)

        for name in files:
            if not name.endswith(".jsonl"):
                continue

            with open(os.path.join(root, name), errors="replace") as handle:
                for line in handle:
                    line = line.strip()

                    if not line:
                        continue

                    try:
                        record = json.loads(line)
                    except ValueError:
                        continue

                    if record.get("type") != "assistant":
                        continue

                    message = record.get("message") or {}
                    usage = message.get("usage") or {}
                    stamp = record.get("timestamp")

                    if not usage or not stamp:
                        continue

                    # Streamed replies are appended more than once.
                    key = message.get("id") or record.get("uuid")

                    if key in seen:
                        continue

                    seen.add(key)

                    tokens = (
                        usage.get("input_tokens", 0)
                        + usage.get("output_tokens", 0)
                        + usage.get("cache_creation_input_tokens", 0)
                        + usage.get("cache_read_input_tokens", 0)
                    )

                    yield (
                        datetime.fromisoformat(stamp.replace("Z", "+00:00")),
                        message.get("model") or "unknown",
                        tokens,
                        project,
                    )


def blocks(items):
    """Split replies into 5 hour windows, each starting on the hour."""
    result = []

    for when, model, tokens, project in items:
        if not result or when >= result[-1]["end"]:
            start = when.replace(minute=0, second=0, microsecond=0)

            result.append({
                "start": start,
                "end": start + BLOCK,
                "tokens": 0,
                "messages": 0,
                "models": {},
                "projects": {},
            })

        block = result[-1]
        block["tokens"] += tokens
        block["messages"] += 1
        block["models"][model] = block["models"].get(model, 0) + tokens
        block["projects"][project] = block["projects"].get(project, 0) + tokens

    return result


def main():
    found = blocks(sorted(entries(), key=lambda item: item[0]))
    now = datetime.now(timezone.utc)

    active = found[-1] if found and now < found[-1]["end"] else None

    # Calibrate on completed blocks, so the active one cannot raise its own bar.
    past = [block["tokens"] for block in found if block is not active]
    limit = max(past) if past else 0
    limit = max(limit, FALLBACK_LIMIT)

    if not active:
        print(json.dumps({
            "active": False,
            "tokens": 0,
            "limit": limit,
            "percent": 0,
            "messages": 0,
            "remainingMinutes": 0,
            "models": [],
            "projects": [],
        }))
        return

    tokens = active["tokens"]
    elapsed = max((now - active["start"]).total_seconds() / 60, 1)

    def rank(counts):
        pairs = sorted(counts.items(), key=lambda pair: -pair[1])
        return [{"name": name, "tokens": value} for name, value in pairs[:4]]

    print(json.dumps({
        "active": True,
        "tokens": tokens,
        "limit": limit,
        "percent": round(100 * tokens / limit),
        "messages": active["messages"],
        "blockStart": active["start"].astimezone().strftime("%H:%M"),
        "blockEnd": active["end"].astimezone().strftime("%H:%M"),
        "remainingMinutes": max(int((active["end"] - now).total_seconds() / 60), 0),
        "burnPerMinute": round(tokens / elapsed),
        "models": rank(active["models"]),
        "projects": rank(active["projects"]),
    }))


if __name__ == "__main__":
    sys.exit(main())
