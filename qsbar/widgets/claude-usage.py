#!/usr/bin/env python3
"""Claude Code token usage for the session and weekly limit windows.

Reads the local session transcripts and prints three gauges as JSON for the
bar widget: the active 5 hour block, the rolling 7 day total and the rolling
7 day total for Fable models. Limits are calibrated from the biggest window
seen so far, because the plan quota is not written anywhere on disk.
"""

import json
import os
import sys
from datetime import datetime, timedelta, timezone

BLOCK = timedelta(hours=5)
WEEK = timedelta(days=7)
PROJECTS = os.path.expanduser("~/.claude/projects")

# Limits count a token by what it costs, not by its raw count. Cache reads are
# roughly a tenth of an input token and output is roughly five times one, and
# almost every token here is a cache read, so summing them raw overstates the
# usage about seven times over.
WEIGHT_INPUT = 1.0
WEIGHT_OUTPUT = 5.0
WEIGHT_CACHE_WRITE = 1.25
WEIGHT_CACHE_READ = 0.1

# Quotas are never written to disk, so they are set by hand. They are weighted
# tokens, not raw ones. Tune them against what "/usage" reports inside Claude
# Code: divide this widget's token figure by the percent that "/usage" shows.
SESSION_LIMIT = 25_000_000
WEEK_LIMIT = 1_000_000_000
FABLE_WEEK_LIMIT = 200_000_000


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

                    tokens = round(
                        usage.get("input_tokens", 0) * WEIGHT_INPUT
                        + usage.get("output_tokens", 0) * WEIGHT_OUTPUT
                        + usage.get("cache_creation_input_tokens", 0)
                        * WEIGHT_CACHE_WRITE
                        + usage.get("cache_read_input_tokens", 0)
                        * WEIGHT_CACHE_READ
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


def windows(items, span, now):
    """Sum tokens per span, counting back from now. First entry is current."""
    result = []

    for when, _model, tokens, _project in items:
        index = int((now - when) / span)

        while len(result) <= index:
            result.append(0)

        result[index] += tokens

    return result


def gauge(label, totals, limit):
    """Current window against a fixed quota."""
    current = totals[0] if totals else 0

    return {
        "label": label,
        "tokens": current,
        "limit": limit,
        "percent": round(100 * current / limit),
    }


def main():
    items = sorted(entries(), key=lambda item: item[0])
    found = blocks(items)
    now = datetime.now(timezone.utc)

    fable = [item for item in items if "fable" in item[1]]

    gauges = [
        gauge("Weekly (7 day)", windows(items, WEEK, now), WEEK_LIMIT),
        gauge("Weekly Fable", windows(fable, WEEK, now), FABLE_WEEK_LIMIT),
    ]

    active = found[-1] if found and now < found[-1]["end"] else None
    limit = SESSION_LIMIT

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
            "gauges": [
                {"label": "Session (5h)", "tokens": 0, "limit": limit, "percent": 0},
            ] + gauges,
        }))
        return

    tokens = active["tokens"]
    elapsed = max((now - active["start"]).total_seconds() / 60, 1)

    def rank(counts):
        pairs = sorted(counts.items(), key=lambda pair: -pair[1])
        return [{"name": name, "tokens": value} for name, value in pairs[:4]]

    session = {
        "label": "Session (5h)",
        "tokens": tokens,
        "limit": limit,
        "percent": round(100 * tokens / limit),
    }

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
        "gauges": [session] + gauges,
    }))


if __name__ == "__main__":
    sys.exit(main())
