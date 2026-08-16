Search past checkpoints across this repo's history (not just the most recent one). Use when asked "did we already decide X", "how did we fix Y before", or before re-reading a file or re-diagnosing an error you suspect you already investigated this session or an earlier one.

Follow this three-step workflow. Never fetch full checkpoint bodies without filtering first — the whole point is bounding token cost by looking at a cheap index before paying for detail.

## Step 1 — Search: get a compact index

```
python3 .claude/checkpoint_tool.py index --grep "<term>" --limit 20
```

Returns a compact table (id / timestamp / trigger / title / approx tokens) — cheap to read, no full checkpoint content yet. Narrow with `--phase`, `--trigger`, `--since`, `--until` if useful.

## Step 2 — Timeline: see chronological context (optional)

```
python3 .claude/checkpoint_tool.py timeline --anchor <id> --before 3 --after 3
```

Or `--query "<term>"` instead of `--anchor` to find the anchor automatically. Shows what happened immediately around a specific checkpoint, still in the compact index format.

## Step 3 — Show: fetch full detail, only for ids you actually need

```
python3 .claude/checkpoint_tool.py show <id> [<id> ...]
```

Batch multiple ids in one call rather than calling `show` repeatedly. This is the only step that returns full checkpoint bodies (decisions, pending work, resume instructions) — everything before this was index-only.

## What this does and does not mitigate

This is a partial, indirect mitigation for two of the five context-degradation signals the guide's Forced Handoff Protocol tracks (SD1: re-reading a file already read this session; SD2: reproducing an error already diagnosed) — it gives you a cheap way to check "have I already done this" before you do it again, not a mechanical detector that catches you doing it. The other three signals (SD3 narrating unprompted, SD4 hedging on prior facts, and the semantic-content half of SD5) remain your own judgment; no hook can see them.

Some entries in the index are mechanically captured (`post_commit_auto`, `pre_compact_auto`, `degradation_nudge_ignored`) and legitimately have empty decisions/pending/resume fields — a hook records objective git facts, it cannot synthesize what was decided.
